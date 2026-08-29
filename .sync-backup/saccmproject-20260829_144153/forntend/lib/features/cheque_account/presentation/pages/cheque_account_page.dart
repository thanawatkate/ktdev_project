// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/local_data_source/bank_account_local_data_source.dart';
import 'package:saccm/core/local_data_source/cheque_account_local_data_source.dart';
import 'package:saccm/features/cheque_account/data/datasources/cheque_account_remote_data_source.dart';
import 'package:saccm/features/license/license_mode.dart';
import 'package:saccm/widgets/widgets.dart';
import 'package:saccm/widgets/dialog/alertDialog/custom_autodismiss_alert.dart'
    show showAutoDismissAlert;
import 'package:shared_preferences/shared_preferences.dart';

class ChequeAccountPage extends StatefulWidget {
  const ChequeAccountPage({super.key});

  @override
  State<ChequeAccountPage> createState() => _ChequeAccountPageState();
}

class _ChequeAccountPageState extends State<ChequeAccountPage> {
  static const String _fontFamily = 'Kanit';
  static const double _maxResponsiveFormWidth = 1440;

  final _local = ChequeAccountLocalDataSource();
  final _bankLocal = BankAccountLocalDataSource();
  final _remote = ChequeAccountRemoteDataSource();

  final _searchCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _noCtrl = TextEditingController();

  List<ChequeAccountRow> _items = [];
  List<LocalBankItem> _banks = [];
  String? _token;
  bool _loading = true;
  String? _error;
  int _busyDepth = 0;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (mounted) setState(() => _search = _searchCtrl.text);
    });
    SchedulerBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _noCtrl.dispose();
    super.dispose();
  }

  List<ChequeAccountRow> get _filtered {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((e) {
      return e.chequename.toLowerCase().contains(q) ||
          e.chequeno.toLowerCase().contains(q) ||
          e.bankName.toLowerCase().contains(q);
    }).toList();
  }

  Future<T> _busy<T>(String msg, Future<T> Function() fn) async {
    setState(() => _busyDepth++);
    try {
      return await fn();
    } finally {
      if (mounted) setState(() => _busyDepth--);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('token');
      await _local.ensureInitialized();
      await _bankLocal.ensureInitialized();
      final items = await _local.listAll();
      final banks = await _bankLocal.getAllBanks();
      if (!mounted) return;
      setState(() {
        _items = items;
        _banks = banks;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _pushRemoteCreate(String id) async {
    if (!await LicenseMode.canSyncOnline()) return false;
    final token = _token;
    if (token == null || token.isEmpty) return false;
    try {
      final res = await _remote.create(
        token: token,
        chequeno: _noCtrl.text.trim(),
        chequename: _nameCtrl.text.trim(),
        refBank: _sheetBankId ?? '',
      );
      if (res['status']?.toString() == 'successfully') {
        await _local.setSynced(id);
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> _pushRemoteUpdate(ChequeAccountRow existing) async {
    if (!await LicenseMode.canSyncOnline()) return false;
    final token = _token;
    if (token == null || token.isEmpty) return false;
    try {
      final res = await _remote.update(
        id: existing.id,
        token: token,
        chequeno: _noCtrl.text.trim(),
        chequename: _nameCtrl.text.trim(),
        refBank: _sheetBankId ?? existing.refBank,
        use: _sheetActive ? 'Y' : 'N',
      );
      if (res['status']?.toString() == 'successfully') {
        await _local.setSynced(existing.id);
        return true;
      }
    } catch (_) {}
    return false;
  }

  String? _sheetBankId;
  bool _sheetActive = true;

  Future<void> _showEditor({ChequeAccountRow? existing}) async {
    _nameCtrl.text = existing?.chequename ?? '';
    _noCtrl.text = existing?.chequeno ?? '';
    _sheetBankId =
        existing?.refBank.isNotEmpty == true ? existing!.refBank : null;
    if (_sheetBankId != null && !_banks.any((b) => b.id == _sheetBankId)) {
      _sheetBankId = null;
    }
    _sheetActive = existing?.isActive ?? true;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: AdaptiveContentSheet(
            title: existing == null
                ? TransactionUiText.chequeAccountAdd
                : TransactionUiText.chequeAccountEdit,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppTheme.sp16,
                0,
                AppTheme.sp16,
                MediaQuery.viewInsetsOf(ctx).bottom + AppTheme.sp16,
              ),
              child: StatefulBuilder(
                builder: (context, setSheet) {
                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppInput(
                          controller: _nameCtrl,
                          label: TransactionUiText.chequeAccountNameLabel,
                          required: true,
                        ),
                        const SizedBox(height: 12),
                        AppInput(
                          controller: _noCtrl,
                          label: TransactionUiText.chequeAccountNoLabel,
                          helperText: TransactionUiText.chequeAccountNoHelper,
                          required: true,
                        ),
                        const SizedBox(height: 12),
                        AppLookupPickerField<String>(
                          label: TransactionUiText.bankName,
                          required: true,
                          hint: TransactionUiText.bankNameRequired,
                          value: _sheetBankId,
                          clearable: false,
                          items: _banks
                              .map(
                                (b) => AppDropdownItem<String>(
                                  value: b.id,
                                  label: b.name,
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setSheet(() => _sheetBankId = v),
                        ),
                        if (existing != null) ...[
                          const SizedBox(height: 12),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                                TransactionUiText.chequeAccountActiveLabel),
                            value: _sheetActive,
                            onChanged: (v) => setSheet(() => _sheetActive = v),
                          ),
                        ],
                        const SizedBox(height: 20),
                        AppButton.primary(
                          label: TransactionUiText.save,
                          onPressed: () {
                            if (_nameCtrl.text.trim().isEmpty) {
                              showAutoDismissAlert(
                                context,
                                TransactionUiText.warning,
                                TransactionUiText.chequeAccountNameRequired,
                                3,
                              );
                              return;
                            }
                            if (_noCtrl.text.trim().isEmpty) {
                              showAutoDismissAlert(
                                context,
                                TransactionUiText.warning,
                                TransactionUiText.chequeAccountNoRequired,
                                3,
                              );
                              return;
                            }
                            if (_sheetBankId == null || _sheetBankId!.isEmpty) {
                              showAutoDismissAlert(
                                context,
                                TransactionUiText.warning,
                                TransactionUiText.bankNameRequired,
                                3,
                              );
                              return;
                            }
                            Navigator.pop(ctx, true);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );

    if (saved != true || !mounted) return;

    await _busy(TransactionUiText.chequeAccountSavingBusy, () async {
      if (existing == null) {
        final id = await _local.insert(
          chequeno: _noCtrl.text.trim(),
          chequename: _nameCtrl.text.trim(),
          refBank: _sheetBankId!,
        );
        unawaited(_pushRemoteCreate(id));
        if (!mounted) return;
        showAutoDismissAlert(
          context,
          TransactionUiText.success,
          TransactionUiText.chequeAccountSaved,
          3,
        );
      } else {
        await _local.update(
          id: existing.id,
          chequeno: _noCtrl.text.trim(),
          chequename: _nameCtrl.text.trim(),
          refBank: _sheetBankId!,
          use: _sheetActive ? 'Y' : 'N',
        );
        unawaited(_pushRemoteUpdate(existing));
        if (!mounted) return;
        showAutoDismissAlert(
          context,
          TransactionUiText.success,
          TransactionUiText.chequeAccountSaved,
          3,
        );
      }
      await _load();
    });
  }

  Future<void> _confirmDelete(ChequeAccountRow row) async {
    final inUse = await _local.countPayChequeReferences(row.id) > 0;

    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmDialog(
        isDestructive: !inUse,
        title: inUse
            ? TransactionUiText.chequeAccountInUseWarning
            : TransactionUiText.confirmDelete,
        message: inUse
            ? TransactionUiText.chequeAccountDeactivateConfirm
            : TransactionUiText.chequeAccountDeleteConfirm,
        confirmText: inUse
            ? TransactionUiText.chequeAccountDeactivate
            : TransactionUiText.delete,
        confirmColor: inUse
            ? Theme.of(ctx).colorScheme.primary
            : AppColors.of(ctx).expenseRed,
      ),
    );
    if (ok != true || !mounted) return;

    await _busy(TransactionUiText.chequeAccountDeletingBusy, () async {
      if (inUse) {
        await _local.setActive(row.id, false);
        if (_token != null &&
            _token!.isNotEmpty &&
            await LicenseMode.canSyncOnline()) {
          unawaited(_remote
              .update(
                id: row.id,
                token: _token!,
                chequeno: row.chequeno,
                chequename: row.chequename,
                refBank: row.refBank,
                use: 'N',
              )
              .catchError((_) => <String, dynamic>{}));
        }
      } else {
        await _local.deleteById(row.id);
        if (_token != null &&
            _token!.isNotEmpty &&
            await LicenseMode.canSyncOnline()) {
          unawaited(
            _remote
                .remove(id: row.id, token: _token!)
                .catchError((_) => <String, dynamic>{}),
          );
        }
      }
      if (!mounted) return;
      showAutoDismissAlert(
        context,
        TransactionUiText.success,
        TransactionUiText.chequeAccountDeleted,
        3,
      );
      await _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: AppBusyBackdrop(
        isBusy: _busyDepth > 0,
        message: TransactionUiText.chequeAccountSavingBusy,
        child: Scaffold(
          backgroundColor: c.background,
          appBar: _buildAppBar(c),
          body: _loading
              ? Center(
                  child: CircularProgressIndicator(
                    color: scheme.primary,
                  ),
                )
              : _error != null
                  ? ScrollSafeErrorState(
                      title: TransactionUiText.loadFailedTitle,
                      message: _error!,
                      onRetry: _load,
                      retryLabel: TransactionUiText.tryAgain,
                      iconBackgroundColor: c.iconBgExpense,
                      iconColor: c.expenseRed,
                      titleColor: c.textPrimary,
                      messageColor: c.textSecondary,
                      buttonColor: c.navy,
                    )
                  : _buildContent(c, scheme),
          floatingActionButton: FloatingActionButton(
            onPressed: _banks.isEmpty ? null : () => _showEditor(),
            backgroundColor: c.navy,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppColors c) {
    return AppBar(
      toolbarHeight: 52,
      title: Text(
        TransactionUiText.chequeAccountPageTitle,
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
          tooltip: TransactionUiText.retry,
          onPressed: _loading ? null : _load,
          icon: Icon(Icons.refresh_rounded, color: c.textSecondary),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: c.cardBorder),
      ),
    );
  }

  Widget _buildContent(AppColors c, ColorScheme scheme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.sp16),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: _maxResponsiveFormWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TransactionFormHeader(
                    icon: Icons.account_balance_outlined,
                    iconColor: scheme.primary,
                    iconBgColor: c.iconBgIncome,
                    title: TransactionUiText.chequeAccountPageTitle,
                    subtitle: TransactionUiText.chequeAccountManageSubtitle,
                    quickHint: TransactionUiText.chequeAccountEmptyMessage,
                    hintAccentColor: scheme.primary,
                    hintBorderColor: c.cardBorder,
                    textPrimaryColor: c.textPrimary,
                    showQuickHint: false,
                  ),
                  const SizedBox(height: AppTheme.sp16),
                  _buildSearchCard(c),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: _maxResponsiveFormWidth),
              child: _filtered.isEmpty
                  ? _buildEmptyState(c)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppTheme.sp16,
                          0,
                          AppTheme.sp16,
                          88,
                        ),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppTheme.sp8),
                        itemBuilder: (_, i) =>
                            _buildChequeCard(_filtered[i], c),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchCard(AppColors c) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.sp16),
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r16),
        border: Border.all(color: c.cardBorder),
      ),
      child: AppInput(
        controller: _searchCtrl,
        label: TransactionUiText.search,
        prefixIcon: const Icon(Icons.search_rounded),
        textInputAction: TextInputAction.search,
      ),
    );
  }

  Widget _buildEmptyState(AppColors c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sp24),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.sp16),
          decoration: BoxDecoration(
            color: c.cardWhite,
            borderRadius: BorderRadius.circular(AppTheme.r16),
            border: Border.all(color: c.cardBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_balance_outlined,
                size: 48,
                color: c.textSecondary,
              ),
              const SizedBox(height: AppTheme.sp12),
              Text(
                TransactionUiText.chequeAccountEmptyTitle,
                style: TextStyle(
                  fontFamily: _fontFamily,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: AppTheme.sp8),
              Text(
                TransactionUiText.chequeAccountEmptyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: _fontFamily,
                  color: c.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChequeCard(ChequeAccountRow row, AppColors c) {
    return Card(
      elevation: 0,
      color: c.cardWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.r16),
        side: BorderSide(color: c.cardBorder),
      ),
      child: ListTile(
        title: Text(
          row.chequename,
          style: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '${row.bankName.isNotEmpty ? row.bankName : '-'} · เลขเริ่ม ${row.chequeno}',
          style: TextStyle(fontFamily: _fontFamily, color: c.textSecondary),
        ),
        trailing: row.isActive
            ? null
            : Chip(
                label: const Text(
                  TransactionUiText.chequeAccountInactiveLabel,
                  style: TextStyle(fontFamily: _fontFamily, fontSize: 11),
                ),
              ),
        onTap: () => _showEditor(existing: row),
        onLongPress: () => _confirmDelete(row),
      ),
    );
  }
}
