// ignore_for_file: use_build_context_synchronously
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/services/app_notification_service.dart';
import 'package:saccm/core/utils/fiscal_year.dart';
import 'package:saccm/core/utils/user_error_message.dart';
import 'package:saccm/features/fiscal_year_opening/data/models/fiscal_year_opening_row.dart';
import 'package:saccm/features/fiscal_year_opening/data/repositories/fiscal_year_opening_repository.dart';
import 'package:saccm/features/license/license_mode.dart';
import 'package:saccm/widgets/widgets.dart';

/// หน้า "ยอดยกมาต้นปีงบประมาณ" (Fiscal Year Opening)
///
/// ใช้กำหนดยอดเงินคงเหลือต้นปีงบประมาณ (1 ต.ค.) แยกตาม 7 ประเภท × 3 บัญชี
/// ค่านี้จะถูกใช้เป็น opening balance ของรายงานเงินคงเหลือประจำวันหน้า 34
class FiscalYearOpeningPage extends StatefulWidget {
  const FiscalYearOpeningPage({super.key});

  @override
  State<FiscalYearOpeningPage> createState() => _FiscalYearOpeningPageState();
}

class _FiscalYearOpeningPageState extends State<FiscalYearOpeningPage> {
  static const String _fontFamily = 'Kanit';
  static const double _maxResponsiveFormWidth = 1440;

  static final NumberFormat _fmt = NumberFormat('#,##0.00');

  final FiscalYearOpeningRepository _repo = FiscalYearOpeningRepository();
  final TextEditingController _yearCtrl = TextEditingController();

  bool _loading = true;
  bool _syncing = false;
  bool _saving = false;
  String _currentYear = '';

  /// Nested map keyed by bucket then pocket.
  final Map<String, Map<String, TextEditingController>> _ctrls = {};

  /// แหล่งที่มาของยอด (manual/computed/year_end_close) ต่อ slot
  final Map<String, String> _sourceByKey = {};

  @override
  void initState() {
    super.initState();
    _initControllers();
    final fy = FiscalYear.currentBuddhist();
    _yearCtrl.text = fy.toString();
    _currentYear = fy.toString();
    _loadForYear(_currentYear);
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    for (final m in _ctrls.values) {
      for (final c in m.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  void _initControllers() {
    for (final bucket in FiscalYearOpeningConst.buckets) {
      _ctrls[bucket] = <String, TextEditingController>{};
      for (final pocket in FiscalYearOpeningConst.pockets) {
        _ctrls[bucket]![pocket] = TextEditingController();
      }
    }
  }

  String _slotKey(String bucket, String pocket) => '$bucket::$pocket';

  void _applyRows(List<FiscalYearOpeningRow> rows) {
    for (final r in rows) {
      final c = _ctrls[r.bucket]?[r.pocket];
      if (c == null) continue;
      c.text = r.openingAmount == 0 ? '' : r.openingAmount.toString();
      _sourceByKey[_slotKey(r.bucket, r.pocket)] = r.source;
    }
  }

  void _clearControllers() {
    for (final m in _ctrls.values) {
      for (final c in m.values) {
        c.text = '';
      }
    }
    _sourceByKey.clear();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _loadForYear(String year) async {
    if (year.isEmpty) return;
    setState(() {
      _loading = true;
      _currentYear = year;
    });
    try {
      final local = await _repo.loadLocal(year);
      _clearControllers();
      _applyRows(local);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    // pull-down from remote in background
    unawaited(_syncFromRemote(year, silent: true));
  }

  Future<void> _syncFromRemote(String year, {bool silent = false}) async {
    if (!mounted) return;
    if (!await LicenseMode.canSyncOnline()) return;
    setState(() => _syncing = true);
    try {
      await _repo.syncFromRemote(year);
      final local = await _repo.loadLocal(year);
      if (!mounted) return;
      setState(() {
        _clearControllers();
        _applyRows(local);
      });
    } catch (e) {
      if (!silent && mounted) {
        AppNotificationService.instance.showError(
          TransactionUiText.error,
          toUserErrorMessage(e),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      AppNotificationService.instance.showWarning(
        TransactionUiText.warning,
        TransactionUiText.registerPleaseSignInAgain,
      );
      return;
    }

    final year = _yearCtrl.text.trim();
    if (year.isEmpty || year.length != 4) {
      AppNotificationService.instance.showWarning(
        TransactionUiText.warning,
        TransactionUiText.invalidDataPleaseCheck,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final rows = <FiscalYearOpeningRow>[];
      for (final bucket in FiscalYearOpeningConst.buckets) {
        for (final pocket in FiscalYearOpeningConst.pockets) {
          final txt = _ctrls[bucket]![pocket]!.text.trim().replaceAll(',', '');
          final amount = double.tryParse(txt) ?? 0;
          final src = _sourceByKey[_slotKey(bucket, pocket)] ?? 'manual';
          rows.add(FiscalYearOpeningRow(
            fiscalYear: year,
            bucket: bucket,
            pocket: pocket,
            openingAmount: amount,
            source: src,
          ));
        }
      }
      await _repo.saveGrid(token: token, fiscalYear: year, rows: rows);
      if (!mounted) return;
      AppNotificationService.instance.showSuccess(
        TransactionUiText.success,
        TransactionUiText.fiscalYearOpeningSaveSuccess,
      );
    } catch (e) {
      if (!mounted) return;
      AppNotificationService.instance.showError(
        TransactionUiText.error,
        toUserErrorMessage(e),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _onCopyFromPrev() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => const ConfirmDialog(
        title: TransactionUiText.fiscalYearOpeningConfirmCopyTitle,
        message: TransactionUiText.fiscalYearOpeningConfirmCopyMessage,
        confirmText: TransactionUiText.fiscalYearOpeningCopyFromPrev,
        isDestructive: false,
      ),
    );
    if (confirm != true) return;
    final token = await _getToken();
    final year = _yearCtrl.text.trim();
    if (year.isEmpty) return;
    setState(() => _syncing = true);
    try {
      await _repo.copyFromPrevious(token: token, fiscalYear: year);
      final rows = await _repo.loadLocal(year);
      if (!mounted) return;
      setState(() {
        _clearControllers();
        _applyRows(rows);
      });
      AppNotificationService.instance.showSuccess(
        TransactionUiText.success,
        TransactionUiText.fiscalYearOpeningSaveSuccess,
      );
    } catch (e) {
      if (!mounted) return;
      AppNotificationService.instance.showError(
        TransactionUiText.error,
        toUserErrorMessage(e),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _onFetchSuggested() async {
    final year = _yearCtrl.text.trim();
    if (year.isEmpty) return;
    setState(() => _syncing = true);
    try {
      final rows = await _repo.fetchSuggested(year);
      if (!mounted) return;
      setState(() {
        _clearControllers();
        _applyRows(rows);
      });
    } catch (e) {
      if (!mounted) return;
      AppNotificationService.instance.showError(
        TransactionUiText.error,
        toUserErrorMessage(e),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  double _bucketTotal(String bucket) {
    double s = 0;
    for (final pocket in FiscalYearOpeningConst.pockets) {
      final txt = _ctrls[bucket]![pocket]!.text.trim().replaceAll(',', '');
      s += double.tryParse(txt) ?? 0;
    }
    return s;
  }

  double _grandTotal() {
    double s = 0;
    for (final bucket in FiscalYearOpeningConst.buckets) {
      s += _bucketTotal(bucket);
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Scaffold(
        backgroundColor: c.background,
        appBar: _buildAppBar(c),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: scheme.primary))
            : GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
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
                          _buildHeader(c, scheme),
                          const SizedBox(height: AppTheme.sp16),
                          _buildYearFilter(c, scheme),
                          const SizedBox(height: AppTheme.sp12),
                          _buildActionRow(c, scheme),
                          const SizedBox(height: AppTheme.sp12),
                          _buildGridCard(c, scheme),
                          const SizedBox(height: AppTheme.sp16),
                          _buildSaveCard(c),
                          const SizedBox(height: AppTheme.sp24),
                        ],
                      ),
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
        TransactionUiText.fiscalYearOpeningTitle,
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
      actions: [
        AppBarActionButton(
          label: TransactionUiText.save,
          isLoading: _saving,
          onPressed: _saving ? null : _save,
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: c.cardBorder),
      ),
    );
  }

  Widget _buildHeader(AppColors c, ColorScheme scheme) {
    return TransactionFormHeader(
      icon: Icons.compare_arrows_rounded,
      iconColor: scheme.primary,
      iconBgColor: c.iconBgIncome,
      title: TransactionUiText.fiscalYearOpeningTitle,
      subtitle: TransactionUiText.fiscalYearOpeningSubtitle,
      quickHint: TransactionUiText.fiscalYearOpeningTooltip,
      hintAccentColor: scheme.primary,
      hintBorderColor: c.cardBorder,
      textPrimaryColor: c.textPrimary,
    );
  }

  Widget _buildYearFilter(AppColors c, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.sp12, vertical: AppTheme.sp8),
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r12),
        border: Border.all(color: c.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: BuddhistYearField.picker(
              controller: _yearCtrl,
              onChanged: (v) {
                if (v.length == 4 && v != _currentYear) {
                  _loadForYear(v);
                }
              },
            ),
          ),
          const SizedBox(width: AppTheme.sp8),
          IconButton(
            tooltip: TransactionUiText.retry,
            onPressed: _syncing ? null : () => _syncFromRemote(_currentYear),
            icon: _syncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.refresh_rounded, color: scheme.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(AppColors c, ColorScheme scheme) {
    return Wrap(
      spacing: AppTheme.sp8,
      runSpacing: AppTheme.sp8,
      children: [
        Tooltip(
          message: TransactionUiText.fiscalYearOpeningCopyFromPrevHint,
          child: AppButton.outlined(
            label: TransactionUiText.fiscalYearOpeningCopyFromPrev,
            icon: const Icon(Icons.history_rounded, size: 16),
            onPressed: _syncing ? null : _onCopyFromPrev,
          ),
        ),
        Tooltip(
          message: TransactionUiText.fiscalYearOpeningFetchSuggestedHint,
          child: AppButton.outlined(
            label: TransactionUiText.fiscalYearOpeningFetchSuggested,
            icon: const Icon(Icons.calculate_outlined, size: 16),
            onPressed: _syncing ? null : _onFetchSuggested,
          ),
        ),
      ],
    );
  }

  Widget _buildGridCard(AppColors c, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.sp12),
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r16),
        border: Border.all(color: c.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.grid_view_rounded, color: scheme.primary, size: 18),
              const SizedBox(width: AppTheme.sp8),
              Expanded(
                child: Text(
                  TransactionUiText.fiscalYearOpeningSectionRows,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Kanit',
                  ),
                ),
              ),
              Text(
                '${TransactionUiText.fiscalYearOpeningGrandTotal}: ${_fmt.format(_grandTotal())}',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 12,
                  fontFamily: 'Kanit',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.sp8),
          Divider(height: 1, color: c.cardBorder),
          const SizedBox(height: AppTheme.sp8),
          for (final bucket in FiscalYearOpeningConst.buckets) ...[
            _buildBucketBlock(bucket, c, scheme),
            const SizedBox(height: AppTheme.sp12),
          ],
        ],
      ),
    );
  }

  Widget _buildBucketBlock(String bucket, AppColors c, ColorScheme scheme) {
    final label = FiscalYearOpeningConst.bucketLabelTh[bucket] ?? bucket;
    return LayoutBuilder(builder: (ctx, cstr) {
      final isWide = cstr.maxWidth >= 560;
      return Container(
        padding: const EdgeInsets.all(AppTheme.sp8),
        decoration: BoxDecoration(
          color: c.background,
          borderRadius: BorderRadius.circular(AppTheme.r8),
          border: Border.all(color: c.cardBorder.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Kanit',
                    ),
                  ),
                ),
                Text(
                  '${TransactionUiText.fiscalYearOpeningRowTotal}: ${_fmt.format(_bucketTotal(bucket))}',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 11,
                    fontFamily: 'Kanit',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.sp4),
            if (isWide)
              Row(
                children: [
                  for (final pocket in FiscalYearOpeningConst.pockets) ...[
                    Expanded(
                      child: _buildPocketField(bucket, pocket, c),
                    ),
                    if (pocket != FiscalYearOpeningConst.pockets.last)
                      const SizedBox(width: AppTheme.sp8),
                  ],
                ],
              )
            else
              Column(
                children: [
                  for (final pocket in FiscalYearOpeningConst.pockets) ...[
                    _buildPocketField(bucket, pocket, c),
                    const SizedBox(height: AppTheme.sp4),
                  ],
                ],
              ),
          ],
        ),
      );
    });
  }

  Widget _buildPocketField(String bucket, String pocket, AppColors c) {
    final ctl = _ctrls[bucket]![pocket]!;
    final pocketLabel = FiscalYearOpeningConst.pocketLabelTh[pocket] ?? pocket;
    return AppInput(
      controller: ctl,
      label: pocketLabel,
      hint: '0.00',
      action: const AppInputAction.number(allowDecimal: true),
      textAlign: TextAlign.right,
      onChanged: (_) => setState(() {
        _sourceByKey[_slotKey(bucket, pocket)] = 'manual';
      }),
    );
  }

  Widget _buildSaveCard(AppColors c) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.sp16),
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r16),
        border: Border.all(color: c.cardBorder),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final button = AppButton.primary(
            label: TransactionUiText.save,
            icon: const Icon(Icons.save_rounded, size: 18),
            fullWidth: box.maxWidth < 560,
            isLoading: _saving,
            onPressed: _saving ? null : _save,
          );
          if (box.maxWidth < 560) return button;
          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [SizedBox(width: 180, child: button)],
          );
        },
      ),
    );
  }
}
