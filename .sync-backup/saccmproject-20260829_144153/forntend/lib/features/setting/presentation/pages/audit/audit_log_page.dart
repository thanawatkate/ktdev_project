import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/local_data_source/audit_log_local_data_source.dart';
import 'package:saccm/core/platform/local_file_ops.dart';
import 'package:saccm/features/auth/presentation/providers/simple_auth_provider.dart';
import 'package:saccm/features/setting/data/datasources/school_profile_local_data_source.dart';
import 'package:saccm/features/setting/data/school_profile_csv_header.dart';
import 'package:saccm/features/setting/domain/entities/school_profile.dart';
import 'package:saccm/widgets/widgets.dart';

class AuditLogPage extends StatefulWidget {
  const AuditLogPage({super.key});

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  static const String _fontFamily = 'Kanit';
  static const double _maxResponsiveFormWidth = 1440;
  static const int _pageSize = 100;
  final AuditLogLocalDataSource _audit = AuditLogLocalDataSource();
  final ScrollController _scrollController = ScrollController();
  bool _loading = true;
  bool _loadingMore = false;
  int _loadedCount = 0;
  int _totalCount = 0;
  List<AuditLogEntry> _logs = const <AuditLogEntry>[];
  String _moduleFilter = 'all';
  String _actionFilter = 'all';
  DateTime? _fromDate;
  DateTime? _toDate;
  String? _lastExportPath;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<AuditLogEntry> get _filteredLogs {
    return _logs.where((log) {
      final byModule = _moduleFilter == 'all' || log.module == _moduleFilter;
      final byAction = _actionFilter == 'all' || log.action == _actionFilter;
      final created = DateTime.tryParse(log.createdAt);
      final byFrom = _fromDate == null ||
          (created != null &&
              !created.isBefore(DateTime(
                _fromDate!.year,
                _fromDate!.month,
                _fromDate!.day,
              )));
      final byTo = _toDate == null ||
          (created != null &&
              !created.isAfter(DateTime(
                _toDate!.year,
                _toDate!.month,
                _toDate!.day,
                23,
                59,
                59,
              )));
      return byModule && byAction && byFrom && byTo;
    }).toList();
  }

  List<String> get _modules =>
      {'all', ..._logs.map((e) => e.module)}.toList(growable: false);
  List<String> get _actions =>
      {'all', ..._logs.map((e) => e.action)}.toList(growable: false);

  Widget _buildAuditFilterField({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    final items = options
        .map((e) => AppDropdownItem<String>(value: e, label: e))
        .toList();
    if (items.length > 6) {
      return AppLookupPickerField<String>(
        label: label,
        value: value,
        items: items,
        clearable: false,
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      );
    }
    return AppDropdownField<String>(
      label: label,
      density: AppDropdownDensity.compact,
      value: value,
      items: items,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: isFrom ? (_fromDate ?? now) : (_toDate ?? now),
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      locale: const Locale('th', 'TH'),
      currentDate: now,
      helpText: TransactionUiText.pickDate,
      cancelText: TransactionUiText.cancel,
      confirmText: TransactionUiText.ok,
      fieldLabelText: TransactionUiText.date,
      fieldHintText: TransactionUiText.dateFieldHint,
    );
    if (selected == null) return;
    setState(() {
      if (isFrom) {
        _fromDate = selected;
      } else {
        _toDate = selected;
      }
    });
  }

  String _csvEscape(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  String _buildCsv(List<AuditLogEntry> logs, SchoolProfile school) {
    final buffer = StringBuffer();
    for (final line in schoolProfileCsvCommentLines(school)) {
      buffer.writeln(line);
    }
    buffer.writeln('id,module,action,entityId,createdAt,payload');
    for (final log in logs) {
      final payload = log.payload == null ? '' : jsonEncode(log.payload);
      buffer.writeln([
        _csvEscape(log.id),
        _csvEscape(log.module),
        _csvEscape(log.action),
        _csvEscape(log.entityId),
        _csvEscape(log.createdAt),
        _csvEscape(payload),
      ].join(','));
    }
    return buffer.toString();
  }

  Future<void> _exportCsv() async {
    final logs = _filteredLogs;
    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(TransactionUiText.noData)),
      );
      return;
    }

    final school = await SchoolProfileLocalDataSourceImpl().load();
    if (!mounted) return;
    final csv = _buildCsv(logs, school);
    if (kIsWeb) {
      await Clipboard.setData(ClipboardData(text: csv));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('คัดลอก CSV ลงคลิปบอร์ดแล้ว')),
      );
      return;
    }

    final file = await writeTextFileToDocuments(
      filename: 'audit_logs_${DateTime.now().millisecondsSinceEpoch}.csv',
      content: csv,
    );
    if (file == null) return;
    if (!mounted) return;
    setState(() => _lastExportPath = file.path);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('บันทึกไฟล์แล้ว: ${file.path}')),
    );
  }

  Future<void> _openExportFolder() async {
    final path = _lastExportPath;
    if (path == null || kIsWeb) return;
    await openFileLocation(path);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await _audit.init();
    final total = await _audit.countLogs();
    final logs = await _audit.getRecentLogs(limit: _pageSize, offset: 0);
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _loadedCount = logs.length;
      _totalCount = total;
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loadedCount >= _totalCount) return;
    setState(() => _loadingMore = true);
    final more = await _audit.getRecentLogs(
      limit: _pageSize,
      offset: _loadedCount,
    );
    if (!mounted) return;
    setState(() {
      _logs = [..._logs, ...more];
      _loadedCount += more.length;
      _loadingMore = false;
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 280) {
      _loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (!context.read<SimpleAuthProvider>().can(PermissionKey.auditLogView)) {
      return SafeArea(
        child: Scaffold(
          backgroundColor: c.background,
          appBar: _buildAppBar(c),
          body: const Center(child: Text(TransactionUiText.noPermissionData)),
        ),
      );
    }
    return SafeArea(
      child: Scaffold(
        backgroundColor: c.background,
        appBar: _buildAppBar(c),
        body: _loading
            ? Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
            : _logs.isEmpty
                ? const Center(child: Text(TransactionUiText.noData))
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: _maxResponsiveFormWidth,
                            ),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                SizedBox(
                                  width: 180,
                                  child: _buildAuditFilterField(
                                    label: 'Module',
                                    value: _moduleFilter,
                                    options: _modules,
                                    onChanged: (v) =>
                                        setState(() => _moduleFilter = v),
                                  ),
                                ),
                                SizedBox(
                                  width: 200,
                                  child: _buildAuditFilterField(
                                    label: 'Action',
                                    value: _actionFilter,
                                    options: _actions,
                                    onChanged: (v) =>
                                        setState(() => _actionFilter = v),
                                  ),
                                ),
                                SizedBox(
                                  width: 160,
                                  child: AppButton.outlined(
                                    label: _fromDate == null
                                        ? TransactionUiText.fromDate
                                        : ThaiDateFormatter.format(_fromDate),
                                    icon: const Icon(Icons.date_range_rounded),
                                    onPressed: () => _pickDate(isFrom: true),
                                  ),
                                ),
                                SizedBox(
                                  width: 160,
                                  child: AppButton.outlined(
                                    label: _toDate == null
                                        ? TransactionUiText.toDate
                                        : ThaiDateFormatter.format(_toDate),
                                    icon: const Icon(Icons.date_range_rounded),
                                    onPressed: () => _pickDate(isFrom: false),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _moduleFilter = 'all';
                                      _actionFilter = 'all';
                                      _fromDate = null;
                                      _toDate = null;
                                    });
                                  },
                                  child: const Text('Reset'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: _maxResponsiveFormWidth,
                            ),
                            child: ListView.separated(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(12),
                              itemCount: _filteredLogs.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final log = _filteredLogs[index];
                                return ListTile(
                                  tileColor: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerLowest,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(AppTheme.r12),
                                  ),
                                  title: Text('${log.module} • ${log.action}'),
                                  subtitle: Text(
                                    'entity=${log.entityId}\n${ThaiDateFormatter.formatDateTime(log.createdAt)}\n${log.payload == null ? '-' : jsonEncode(log.payload)}',
                                  ),
                                  isThreeLine: true,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      if (_loadingMore)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: CircularProgressIndicator(),
                        ),
                    ],
                  ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppColors c) {
    return AppBar(
      toolbarHeight: 52,
      title: Text(
        TransactionUiText.auditLogs,
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
          onPressed: _exportCsv,
          icon: Icon(Icons.download_rounded, color: c.textSecondary),
          tooltip: TransactionUiText.exportCsv,
        ),
        if (!kIsWeb && _lastExportPath != null)
          IconButton(
            onPressed: _openExportFolder,
            icon: Icon(Icons.folder_open_rounded, color: c.textSecondary),
            tooltip: 'เปิดโฟลเดอร์ไฟล์',
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: c.cardBorder),
      ),
    );
  }
}
