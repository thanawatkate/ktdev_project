// ignore_for_file: use_build_context_synchronously

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/di/service_locator.dart';
import 'package:saccm/core/local_data_source/app_database.dart';
import 'package:saccm/core/services/backup_restore_service.dart';
import 'package:saccm/core/services/network_info_service.dart';
import 'package:saccm/widgets/widgets.dart';

/// รวมเครื่องมือดูแลฐานข้อมูล SQLite ในเครื่อง: สำรอง กู้คืน และรีเซท
class DatabaseMaintenancePage extends StatefulWidget {
  const DatabaseMaintenancePage({super.key});

  @override
  State<DatabaseMaintenancePage> createState() =>
      _DatabaseMaintenancePageState();
}

class _DatabaseMaintenancePageState extends State<DatabaseMaintenancePage> {
  static const String _fontFamily = 'Kanit';
  static const double _maxResponsiveFormWidth = 1440;

  bool _busy = false;
  String? _precheckMessage;
  BackupPrecheckOnline? _lastPrecheck;

  BackupRestoreService get _svc =>
      ServiceLocator.instance.get<BackupRestoreService>();

  Future<void> _runPrecheck() async {
    final networkInfo = context.read<NetworkInfoService>();
    setState(() {
      _busy = true;
      _precheckMessage = null;
      _lastPrecheck = null;
    });
    try {
      final online = await networkInfo.isConnected;
      if (!online) {
        setState(() {
          _precheckMessage = TransactionUiText.backupPrecheckOfflineHint;
        });
        return;
      }
      final pre = await _svc.runOnlinePrecheckOrNull();
      if (!mounted) return;
      if (pre == null) {
        setState(() {
          _precheckMessage = TransactionUiText.backupPrecheckLocalTokenHint;
        });
        return;
      }
      setState(() {
        _lastPrecheck = pre;
        _precheckMessage = pre.isAligned
            ? TransactionUiText.backupPrecheckAligned
            : TransactionUiText.backupPrecheckMismatch(
                pre.mismatchedTables.join(', '),
              );
      });
    } catch (e) {
      if (mounted) {
        setState(() => _precheckMessage = e.toString());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export({required bool requireServerAlignment}) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            TransactionUiText.backupUnsupportedWeb,
            style: TextStyle(fontFamily: _fontFamily),
          ),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final path = await _svc.exportDatabaseFile(
        requireOnlineAlignment: requireServerAlignment,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${TransactionUiText.backupSavedTo}\n$path',
            style: const TextStyle(fontFamily: _fontFamily),
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString(),
            style: const TextStyle(fontFamily: _fontFamily),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAndScheduleRestore() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            TransactionUiText.backupUnsupportedWeb,
            style: TextStyle(fontFamily: _fontFamily),
          ),
        ),
      );
      return;
    }
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['db'],
      withReadStream: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;

    final ok = await _svc.validateSaccmSqliteFile(path);
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            TransactionUiText.backupRestoreInvalidFile,
            style: TextStyle(fontFamily: _fontFamily),
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmDialog(
        isDestructive: false,
        title: TransactionUiText.backupRestoreConfirmTitle,
        message: TransactionUiText.backupRestoreConfirmBody,
        cancelText: TransactionUiText.cancel,
        confirmText: TransactionUiText.confirm,
        confirmColor: Theme.of(ctx).colorScheme.primary,
      ),
    );
    if (go != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await _svc.scheduleRestoreFromPickedFile(path);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: false,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          final c = AppColors.of(sheetContext);
          return SafeArea(
            child: AdaptiveContentSheet(
              title: TransactionUiText.backupRestoreScheduledTitle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.sp16,
                  0,
                  AppTheme.sp16,
                  AppTheme.sp16,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        TransactionUiText.backupRestoreScheduledBody,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontFamily: _fontFamily,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: AppTheme.sp12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: AppButton.primary(
                          label: TransactionUiText.ok,
                          fullWidth: false,
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString(),
            style: const TextStyle(fontFamily: _fontFamily),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final dialogColors = AppColors.of(dialogContext);
        return ConfirmDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.r16),
          ),
          icon: Icon(
            Icons.delete_forever_rounded,
            color: dialogColors.expenseRed,
            size: 36,
          ),
          title: TransactionUiText.resetDbConfirmTitle,
          message: TransactionUiText.resetDbConfirmMessage,
          cancelText: TransactionUiText.cancel,
          confirmText: TransactionUiText.resetDbConfirmButton,
          confirmColor: dialogColors.expenseRed,
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await AppDatabase().resetDatabase();
      if (!mounted) return;
      await Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            TransactionUiText.resetDbError(e),
            style: const TextStyle(fontFamily: _fontFamily),
          ),
        ),
      );
    }
  }

  Future<void> _showPageGuideDialog() async {
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    await PageGuideDialog.show(
      context: context,
      title: TransactionUiText.databaseMaintenanceTitle,
      items: [
        PageGuideItem(
          icon: Icons.backup_outlined,
          text: TransactionUiText.backupRestoreIntro,
          backgroundColor: scheme.primary.withValues(alpha: 0.08),
        ),
        PageGuideItem(
          icon: Icons.cloud_done_outlined,
          text: TransactionUiText.backupPrecheckDescription,
          backgroundColor: c.cardWhite,
        ),
        PageGuideItem(
          icon: Icons.restore_page_outlined,
          text: TransactionUiText.backupRestorePickHint,
          backgroundColor: c.cardWhite,
        ),
        PageGuideItem(
          icon: Icons.delete_forever_rounded,
          text: TransactionUiText.resetDbHelpBackupFirst,
          accentColor: c.expenseRed,
          backgroundColor: c.cardWhite,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return DefaultTabController(
      length: 3,
      child: SafeArea(
        child: Scaffold(
          backgroundColor: c.background,
          appBar: _buildAppBar(c),
          body: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Stack(
              children: [
                TabBarView(
                  children: [
                    _buildBackupTab(c),
                    _buildRestoreTab(c),
                    _buildResetTab(c),
                  ],
                ),
                if (_busy)
                  Container(
                    color: Colors.black26,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(),
                  ),
              ],
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
        TransactionUiText.databaseMaintenanceTitle,
        style: TextStyle(
          color: c.textPrimary,
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
      centerTitle: true,
      backgroundColor: c.cardWhite,
      elevation: 0,
      scrolledUnderElevation: 0,
      actions: [
        Padding(
          padding: const EdgeInsetsDirectional.only(end: AppTheme.sp12),
          child: IconButton(
            icon: Icon(
              Icons.help_outline_rounded,
              size: 20,
              color: c.textSecondary,
            ),
            tooltip: TransactionUiText.databaseMaintenanceTitle,
            visualDensity: VisualDensity.compact,
            onPressed: _showPageGuideDialog,
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(49),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Divider(height: 1, color: c.cardBorder),
            TabBar(
              labelStyle: const TextStyle(
                fontFamily: _fontFamily,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontFamily: _fontFamily,
                fontWeight: FontWeight.w500,
              ),
              labelColor: c.textPrimary,
              unselectedLabelColor: c.textSecondary,
              indicatorColor: Theme.of(context).colorScheme.primary,
              tabs: const [
                Tab(text: TransactionUiText.backupTabLabel),
                Tab(text: TransactionUiText.restoreTabLabel),
                Tab(text: TransactionUiText.resetDbTabLabel),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupTab(AppColors c) {
    return _buildTabContent(
      padding: const EdgeInsets.all(AppTheme.sp16),
      child: _actionCard(
        c,
        children: [
          _buildCardSection(
            c,
            icon: Icons.cloud_done_outlined,
            title: TransactionUiText.backupSectionOnline,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  TransactionUiText.backupPrecheckDescription,
                  style: _bodyTextStyle(c),
                ),
                const SizedBox(height: AppTheme.sp12),
                AppButton.primary(
                  label: TransactionUiText.backupPrecheckButton,
                  icon: const Icon(Icons.fact_check_outlined, size: 20),
                  onPressed: _busy ? null : _runPrecheck,
                ),
                if (_precheckMessage != null) ...[
                  const SizedBox(height: AppTheme.sp12),
                  _buildPrecheckMessage(c),
                ],
                const SizedBox(height: AppTheme.sp16),
                AppButton.primary(
                  label: TransactionUiText.backupExportWithServerCheck,
                  icon: const Icon(Icons.backup_outlined, size: 20),
                  onPressed: _busy
                      ? null
                      : () => _export(requireServerAlignment: true),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.cardBorder),
          _buildCardSection(
            c,
            icon: Icons.save_alt_outlined,
            title: TransactionUiText.backupSectionOffline,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  TransactionUiText.backupLocalOnlyDescription,
                  style: _bodyTextStyle(c),
                ),
                const SizedBox(height: AppTheme.sp12),
                AppButton.outlined(
                  label: TransactionUiText.backupExportLocalOnly,
                  icon: const Icon(Icons.save_alt_outlined, size: 20),
                  onPressed: _busy
                      ? null
                      : () => _export(requireServerAlignment: false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestoreTab(AppColors c) {
    return _buildTabContent(
      padding: const EdgeInsets.all(AppTheme.sp16),
      child: _actionCard(
        c,
        children: [
          _buildCardSection(
            c,
            icon: Icons.restore_page_outlined,
            title: TransactionUiText.backupRestoreSection,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  TransactionUiText.backupRestorePickHint,
                  style: _bodyTextStyle(c),
                ),
                const SizedBox(height: AppTheme.sp12),
                AppButton.primary(
                  label: TransactionUiText.backupRestorePickButton,
                  icon: const Icon(Icons.restore_page_outlined, size: 20),
                  onPressed: _busy ? null : _pickAndScheduleRestore,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetTab(AppColors c) {
    return _buildTabContent(
      padding: const EdgeInsets.all(AppTheme.sp16),
      child: _actionCard(
        c,
        children: [
          _buildCardSection(
            c,
            icon: Icons.warning_amber_rounded,
            title: TransactionUiText.resetDbWarningSectionTitle,
            child: _buildWarningPanel(c),
          ),
          Divider(height: 1, color: c.cardBorder),
          _buildCardSection(
            c,
            icon: Icons.info_outline_rounded,
            title: TransactionUiText.resetDbProcessSectionTitle,
            child: _buildResetProcess(c),
          ),
          Divider(height: 1, color: c.cardBorder),
          _buildCardSection(
            c,
            icon: Icons.delete_forever_rounded,
            title: TransactionUiText.resetDbActionSectionTitle,
            child: _buildResetActionPanel(c),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent({
    required EdgeInsetsGeometry padding,
    required Widget child,
  }) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: padding,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxResponsiveFormWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              child,
              const SizedBox(height: AppTheme.sp24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionCard(AppColors c, {required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r16),
        border: Border.all(color: c.cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildCardSection(
    AppColors c, {
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(c, icon: icon, title: title),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.sp16,
            0,
            AppTheme.sp16,
            AppTheme.sp16,
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
    AppColors c, {
    required IconData icon,
    required String title,
  }) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.sp16,
        AppTheme.sp16,
        AppTheme.sp16,
        AppTheme.sp12,
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: AppTheme.sp8),
          Text(
            title,
            style: TextStyle(
              fontFamily: _fontFamily,
              color: c.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningPanel(AppColors c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.sp12),
      decoration: BoxDecoration(
        color: c.expenseRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.r12),
        border: Border.all(color: c.expenseRed.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: c.expenseRed, size: 24),
          const SizedBox(width: AppTheme.sp12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  TransactionUiText.resetDbWarningTitle,
                  style: _bodyTextStyle(
                    c,
                    color: c.expenseRed,
                    fontSize: 14,
                    weight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppTheme.sp4),
                Text(
                  TransactionUiText.resetDbWarningBody,
                  style: _bodyTextStyle(c, height: 1.55),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetProcess(AppColors c) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepRow(c, '1', TransactionUiText.resetDbStepDeleteFile),
        _stepRow(c, '2', TransactionUiText.resetDbStepMigrateSchema),
        _stepRow(c, '3', TransactionUiText.resetDbStepSeedInitialData),
        _stepRow(c, '4', TransactionUiText.resetDbStepGoLogin),
        const SizedBox(height: AppTheme.sp8),
        Text(
          TransactionUiText.resetDbServerNote,
          style: _bodyTextStyle(
            c,
            color: scheme.primary,
            fontSize: 12,
            weight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildResetActionPanel(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          TransactionUiText.resetDbActionDescription,
          style: _bodyTextStyle(c),
        ),
        const SizedBox(height: AppTheme.sp12),
        LayoutBuilder(
          builder: (context, box) {
            final isCompact = box.maxWidth < 560;
            final button = AppButton.danger(
              label: _busy
                  ? TransactionUiText.resetDbBusy
                  : TransactionUiText.resetDbTitle,
              icon: const Icon(Icons.delete_forever_rounded, size: 20),
              fullWidth: isCompact,
              isLoading: _busy,
              onPressed: _busy ? null : _confirmReset,
            );
            if (isCompact) return button;
            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [SizedBox(width: 220, child: button)],
            );
          },
        ),
      ],
    );
  }

  Widget _stepRow(AppColors c, String num, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.sp8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                num,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                  fontFamily: _fontFamily,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.sp8),
          Expanded(
            child: Text(
              text,
              style: _bodyTextStyle(c, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrecheckMessage(AppColors c) {
    final aligned = _lastPrecheck?.isAligned == true;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.sp12),
      decoration: BoxDecoration(
        color: aligned
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
            : c.expenseRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.r12),
        border: Border.all(
          color: aligned
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.18)
              : c.expenseRed.withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        _precheckMessage!,
        style: TextStyle(
          color: aligned ? c.textPrimary : c.expenseRed,
          fontSize: 13,
          height: 1.35,
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  TextStyle _bodyTextStyle(
    AppColors c, {
    Color? color,
    double fontSize = 13,
    FontWeight weight = FontWeight.w500,
    double height = 1.45,
  }) {
    return TextStyle(
      color: color ?? c.textSecondary,
      fontSize: fontSize,
      height: height,
      fontFamily: _fontFamily,
      fontWeight: weight,
    );
  }
}
