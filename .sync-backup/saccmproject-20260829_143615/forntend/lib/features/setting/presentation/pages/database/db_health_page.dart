import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/platform/local_file_ops.dart';
import 'package:saccm/features/setting/data/datasources/db_health_local_data_source.dart';
import 'package:saccm/widgets/widgets.dart';

class DbHealthPage extends StatefulWidget {
  const DbHealthPage({super.key});

  @override
  State<DbHealthPage> createState() => _DbHealthPageState();
}

class _DbHealthPageState extends State<DbHealthPage> {
  static const String _fontFamily = 'Kanit';
  static const double _maxResponsiveFormWidth = 1440;

  final DbHealthLocalDataSource _dataSource = DbHealthLocalDataSourceImpl();

  bool _loading = true;
  Map<String, int> _report = <String, int>{};
  String? _errorMessage;
  String? _lastExportPath;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final report = await _dataSource.loadRelationshipHealthReport();
      if (!mounted) return;
      setState(() => _report = report);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _report = <String, int>{};
        _errorMessage = '${TransactionUiText.dbHealthLoadFailed}: $e';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _csvEscape(String value) => '"${value.replaceAll('"', '""')}"';

  String _buildCsv() {
    final entries = _report.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final buffer = StringBuffer();
    buffer.writeln(TransactionUiText.dbHealthCsvHeader);
    for (final e in entries) {
      buffer.writeln(
        '${_csvEscape(e.key)},${_csvEscape('${e.value}')},${_csvEscape(e.value == 0 ? TransactionUiText.dbHealthStatusOk : TransactionUiText.dbHealthStatusError)}',
      );
    }
    return buffer.toString();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _exportCsv() async {
    if (_report.isEmpty) {
      _showSnack(TransactionUiText.noData);
      return;
    }
    try {
      final csv = _buildCsv();
      if (kIsWeb) {
        await Clipboard.setData(ClipboardData(text: csv));
        if (!mounted) return;
        _showSnack(TransactionUiText.dbHealthCopiedCsv);
        return;
      }

      final file = await writeTextFileToDocuments(
        filename: 'db_health_${DateTime.now().millisecondsSinceEpoch}.csv',
        content: csv,
      );
      if (file == null) return;
      if (!mounted) return;
      setState(() => _lastExportPath = file.path);
      _showSnack(TransactionUiText.dbHealthSavedTo(file.path));
    } catch (e) {
      if (!mounted) return;
      _showSnack('${TransactionUiText.dbHealthExportFailed}: $e');
    }
  }

  String _buildSummaryText() {
    final entries = _report.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalIssues = _report.values.fold<int>(0, (sum, e) => sum + e);
    final topIssues = entries.where((e) => e.value > 0).take(5).toList();

    final buffer = StringBuffer();
    buffer.writeln(TransactionUiText.dbHealthSummaryTitle);
    buffer.writeln(TransactionUiText.dbHealthTotalIssues(totalIssues));
    if (topIssues.isEmpty) {
      buffer.writeln(TransactionUiText.dbHealthSummaryOk);
      return buffer.toString();
    }
    buffer.writeln(TransactionUiText.dbHealthTopIssues);
    for (final item in topIssues) {
      buffer.writeln('- ${item.key}: ${item.value}');
    }
    return buffer.toString();
  }

  Future<void> _copySummaryReport() async {
    if (_report.isEmpty) {
      _showSnack(TransactionUiText.noData);
      return;
    }
    await Clipboard.setData(ClipboardData(text: _buildSummaryText()));
    if (!mounted) return;
    _showSnack(TransactionUiText.dbHealthCopiedSummary);
  }

  Future<void> _openExportFolder() async {
    final path = _lastExportPath;
    if (path == null || kIsWeb) return;
    try {
      await openFileLocation(path);
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final totalIssues = _report.values.fold<int>(0, (sum, e) => sum + e);
    final sortedEntries = _report.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return SafeArea(
      child: Scaffold(
        backgroundColor: c.background,
        appBar: _buildAppBar(c),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: scheme.primary))
            : Padding(
                padding: const EdgeInsets.all(AppTheme.sp16),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _maxResponsiveFormWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeaderCard(c, scheme),
                        const SizedBox(height: AppTheme.sp16),
                        if (_errorMessage != null)
                          _buildErrorCard(c, scheme, _errorMessage!)
                        else ...[
                          _buildSummaryCard(c, totalIssues),
                          const SizedBox(height: AppTheme.sp16),
                          Expanded(
                            child: _buildRelationshipList(c, sortedEntries),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppColors c) {
    return AppBar(
      toolbarHeight: 52,
      title: Text(
        TransactionUiText.dbHealthTitle,
        style: TextStyle(
          fontFamily: _fontFamily,
          color: c.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      centerTitle: true,
      backgroundColor: c.cardWhite,
      elevation: 0,
      actions: [
        IconButton(
          onPressed: _loading ? null : _copySummaryReport,
          icon: Icon(Icons.content_copy_rounded, color: c.textSecondary),
          tooltip: TransactionUiText.dbHealthCopySummaryTooltip,
        ),
        IconButton(
          onPressed: _loading ? null : _exportCsv,
          icon: Icon(Icons.download_rounded, color: c.textSecondary),
          tooltip: TransactionUiText.exportCsv,
        ),
        if (!kIsWeb && _lastExportPath != null)
          IconButton(
            onPressed: _openExportFolder,
            icon: Icon(Icons.folder_open_rounded, color: c.textSecondary),
            tooltip: TransactionUiText.dbHealthOpenExportFolder,
          ),
        IconButton(
          onPressed: _loading ? null : _load,
          icon: Icon(Icons.refresh_rounded, color: c.textSecondary),
          tooltip: TransactionUiText.retry,
        ),
        const SizedBox(width: AppTheme.sp8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: c.cardBorder),
      ),
    );
  }

  Widget _buildHeaderCard(AppColors c, ColorScheme scheme) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(AppTheme.sp16),
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r16),
        border: Border.all(color: c.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TransactionFormHeader(
        icon: Icons.health_and_safety_outlined,
        iconColor: scheme.primary,
        iconBgColor: c.iconBgIncome,
        title: TransactionUiText.dbHealthTitle,
        subtitle: TransactionUiText.dbHealthSubtitle,
        quickHint: _lastExportPath ?? TransactionUiText.exportCsv,
        hintAccentColor: scheme.primary,
        hintBorderColor: c.cardBorder,
        textPrimaryColor: c.textPrimary,
        showQuickHint: false,
      ),
    );
  }

  Widget _buildSummaryCard(AppColors c, int totalIssues) {
    final isOk = totalIssues == 0;
    final accent = isOk ? Colors.green : Colors.red;
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(AppTheme.sp16),
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r16),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.r12),
            ),
            child: Icon(
              isOk ? Icons.check_circle_outline : Icons.error_outline,
              color: accent,
            ),
          ),
          const SizedBox(width: AppTheme.sp12),
          Expanded(
            child: Text(
              isOk
                  ? TransactionUiText.dbHealthRelationshipOk
                  : TransactionUiText.dbHealthRelationshipIssueCount(
                      totalIssues,
                    ),
              style: TextStyle(
                fontFamily: _fontFamily,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(AppColors c, ColorScheme scheme, String message) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(AppTheme.sp16),
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r16),
        border: Border.all(color: c.expenseRed.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.expenseRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.r12),
            ),
            child: Icon(Icons.error_outline_rounded, color: c.expenseRed),
          ),
          const SizedBox(width: AppTheme.sp12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: _fontFamily,
                color: c.textPrimary,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.sp12),
          TextButton.icon(
            onPressed: _load,
            icon: Icon(Icons.refresh_rounded, color: scheme.primary, size: 18),
            label: Text(
              TransactionUiText.retry,
              style: TextStyle(
                color: scheme.primary,
                fontFamily: _fontFamily,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelationshipList(
    AppColors c,
    List<MapEntry<String, int>> sortedEntries,
  ) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r16),
        border: Border.all(color: c.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: sortedEntries.isEmpty
          ? Center(
              child: Text(
                TransactionUiText.dbHealthNoRelationships,
                style: TextStyle(
                  color: c.textSecondary,
                  fontFamily: _fontFamily,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppTheme.sp12),
              itemCount: sortedEntries.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppTheme.sp8),
              itemBuilder: (context, index) {
                return _buildRelationshipTile(
                  context,
                  c,
                  sortedEntries[index],
                );
              },
            ),
    );
  }

  Widget _buildRelationshipTile(
    BuildContext context,
    AppColors c,
    MapEntry<String, int> entry,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final isOk = entry.value == 0;
    final accent = isOk ? Colors.green : c.expenseRed;
    final tileColor = Color.alphaBlend(
      scheme.primary.withValues(alpha: 0.035),
      c.cardWhite,
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.sp16,
        vertical: AppTheme.sp12,
      ),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(AppTheme.r12),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          Icon(
            isOk ? Icons.check_circle_outline_rounded : Icons.error_outline,
            color: accent,
            size: 20,
          ),
          const SizedBox(width: AppTheme.sp12),
          Expanded(
            child: Text(
              entry.key,
              style: TextStyle(
                fontFamily: _fontFamily,
                color: c.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.sp12),
          Container(
            constraints: const BoxConstraints(minWidth: 32),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${entry.value}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: _fontFamily,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
