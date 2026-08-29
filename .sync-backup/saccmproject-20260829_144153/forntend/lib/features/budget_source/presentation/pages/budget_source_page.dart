import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/local_data_source/bank_account_local_data_source.dart';
import 'package:saccm/core/local_data_source/budget_source_local_data_source.dart';
import 'package:saccm/core/utils/fiscal_year.dart';
import 'package:saccm/core/utils/user_error_message.dart';
import 'package:saccm/features/auth/presentation/providers/simple_auth_provider.dart';
import 'package:saccm/features/license/license_mode.dart';
import 'package:saccm/widgets/dialog/alertDialog/custom_autodismiss_alert.dart';
import 'package:saccm/widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/datasources/budget_source_remote_data_source.dart';
import '../../data/models/budget_source_model.dart';
import 'budget_dashboard_page.dart';
import '../widgets/budget_source_amounts_dialog.dart';
import '../widgets/budget_source_filter_section.dart';
import '../widgets/budget_source_form_dialog.dart';
import '../widgets/budget_source_item_card.dart';

class BudgetSourcePage extends StatefulWidget {
  const BudgetSourcePage({super.key});

  @override
  State<BudgetSourcePage> createState() => _BudgetSourcePageState();
}

class _BudgetSourcePageState extends State<BudgetSourcePage> {
  final _ds = BudgetSourceRemoteDataSourceImpl(dio: Dio());
  final _localDs = BudgetSourceLocalDataSource();
  final _bankAccountLocalDs = BankAccountLocalDataSource();
  List<BudgetSourceModel> _items = [];
  List<MoneyGroupOption> _moneyGroups = [];
  List<LocalBankAccountItem> _bankAccounts = [];
  bool _isLoading = false;
  int _busyDepth = 0;
  String _busyMessage = 'กำลังโหลดแหล่งเงิน...';
  String? _token;
  bool _disposed = false;
  String _searchQuery = '';
  String _yearFilter = 'all';
  String _sortBy = 'year_desc';
  static const _budgetCodePattern =
      r'^SRC-(GOV|NONGOV|GEN|SPEC|SCH)-\d{4}-\d{3}$';
  static const _auditFarYearTag = '[AUDIT:FAR_YEAR]';
  bool _showFarYearAuditOnly = false;

  final _budgetTypes = [
    TransactionUiText.budgetTypeGov,
    TransactionUiText.budgetTypeNonGov,
    TransactionUiText.budgetTypeGeneralGrant,
    TransactionUiText.budgetTypeSpecificGrant,
    TransactionUiText.budgetTypeSchoolIncome,
  ];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (mounted && !_disposed) setState(fn);
  }

  Future<T> _runWithBusy<T>({
    required String message,
    required Future<T> Function() action,
  }) async {
    _safeSetState(() {
      _busyDepth += 1;
      _busyMessage = message;
    });
    try {
      return await action();
    } finally {
      _safeSetState(() {
        _busyDepth = _busyDepth > 0 ? _busyDepth - 1 : 0;
      });
    }
  }

  Future<void> _bootstrap() async {
    await _localDs.init();
    await _bankAccountLocalDs.init();
    await _loadToken();
    if (!mounted || _disposed) return;
    await Future.wait([_loadMoneyGroups(), _loadBankAccounts()]);
    await _loadData();
  }

  Future<void> _loadMoneyGroups() async {
    try {
      final groups = await _localDs.getAllMoneyGroups();
      if (!_disposed) {
        _safeSetState(() => _moneyGroups = groups);
      }
    } catch (_) {
      // เงียบไว้ — dropdown จะว่างถ้าโหลดไม่สำเร็จ ผู้ใช้กรอกอย่างอื่นได้
    }
  }

  Future<void> _loadBankAccounts() async {
    try {
      final accounts = await _bankAccountLocalDs.getAllBankAccounts();
      if (!_disposed) {
        _safeSetState(() => _bankAccounts = accounts);
      }
    } catch (_) {}
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
  }

  Future<void> _pullBudgetRemoteInBackground() async {
    if (!await LicenseMode.canSyncOnline()) return;
    try {
      final remote = await _ds.getAll();
      await _localDs.saveBudgetSources(remote);
      final refreshedLocal = await _localDs.getAllBudgetSources();
      _safeSetState(() => _items = refreshedLocal);
    } catch (e) {
      if (mounted && !_disposed) {
        showAutoDismissAlert(
          context,
          TransactionUiText.error,
          toUserErrorMessage(e),
          3,
          position: AutoDismissAlertPosition.bottomLeft,
        );
      }
    }
  }

  Future<void> _loadData() async {
    await _runWithBusy(
      message: 'กำลังโหลดแหล่งเงิน...',
      action: () async {
        _safeSetState(() => _isLoading = true);
        try {
          await _ensureLocalDefaultsIfNeeded();
          final local = await _localDs.getAllBudgetSources();
          _safeSetState(() => _items = local);
          if (await LicenseMode.canSyncOnline()) {
            unawaited(_pullBudgetRemoteInBackground());
          }
        } catch (e) {
          if (mounted && !_disposed) {
            showAutoDismissAlert(
              context,
              TransactionUiText.error,
              toUserErrorMessage(e),
              3,
              position: AutoDismissAlertPosition.bottomLeft,
            );
          }
        } finally {
          _safeSetState(() => _isLoading = false);
        }
      },
    );
  }

  Future<void> _ensureLocalDefaultsIfNeeded() async {
    final existing = await _localDs.getAllBudgetSources();
    if (existing.isNotEmpty) return;

    final fiscalYear = FiscalYear.currentBuddhist().toString();
    final seedItems = <BudgetSourceModel>[
      BudgetSourceModel(
        id: 'bs_budget_gov_$fiscalYear',
        masterId: 'bs_master_gov',
        code: 'SRC-GOV-$fiscalYear-001',
        name: 'เงินงบประมาณแผ่นดิน',
        fiscalYear: fiscalYear,
        budgetAmount: 0,
        broughtForwardAmount: 0,
        usedAmount: 0,
        budgetType: TransactionUiText.budgetTypeGov,
      ),
      BudgetSourceModel(
        id: 'bs_budget_nongov_$fiscalYear',
        masterId: 'bs_master_nongov',
        code: 'SRC-NONGOV-$fiscalYear-001',
        name: 'เงินนอกงบประมาณ',
        fiscalYear: fiscalYear,
        budgetAmount: 0,
        broughtForwardAmount: 0,
        usedAmount: 0,
        budgetType: TransactionUiText.budgetTypeNonGov,
      ),
    ];

    for (final item in seedItems) {
      await _localDs.saveBudgetSource(item, synced: false);
    }
  }

  bool get _isRealRemoteToken =>
      (_token ?? '').trim().isNotEmpty && !(_token ?? '').startsWith('local_');

  bool get _canViewBudgetSource =>
      context.read<SimpleAuthProvider>().can(PermissionKey.budgetSourceView);

  bool get _canCreateBudgetSource =>
      context.read<SimpleAuthProvider>().can(PermissionKey.budgetSourceCreate);

  bool get _canUpdateBudgetSource =>
      context.read<SimpleAuthProvider>().can(PermissionKey.budgetSourceUpdate);

  bool get _canDeleteBudgetSource =>
      context.read<SimpleAuthProvider>().can(PermissionKey.budgetSourceDelete);

  List<String> get _yearOptions {
    final years = <String>{'all'};
    for (final item in _items) {
      if (item.fiscalYear.trim().isNotEmpty) years.add(item.fiscalYear.trim());
    }
    final list = years.toList();
    list.sort((a, b) {
      if (a == 'all') return -1;
      if (b == 'all') return 1;
      return b.compareTo(a);
    });
    return list;
  }

  List<BudgetSourceModel> get _filteredItems {
    final filtered = _items.where((item) {
      final byAudit = !_showFarYearAuditOnly ||
          (item.description ?? '').contains(_auditFarYearTag);
      final byYear = _yearFilter == 'all' || item.fiscalYear == _yearFilter;
      final q = _searchQuery.trim().toLowerCase();
      final bySearch = q.isEmpty ||
          item.code.toLowerCase().contains(q) ||
          item.name.toLowerCase().contains(q) ||
          item.budgetType.toLowerCase().contains(q) ||
          (item.description ?? '').toLowerCase().contains(q);
      return byAudit && byYear && bySearch;
    }).toList();
    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'year_asc':
          return a.fiscalYear.compareTo(b.fiscalYear);
        case 'remaining_desc':
          return b.remaining.compareTo(a.remaining);
        case 'name_asc':
          return a.name.compareTo(b.name);
        case 'year_desc':
        default:
          return b.fiscalYear.compareTo(a.fiscalYear);
      }
    });
    return filtered;
  }

  bool get _hasActiveFilter =>
      _searchQuery.trim().isNotEmpty ||
      _yearFilter != 'all' ||
      _sortBy != 'year_desc' ||
      _showFarYearAuditOnly;

  void _resetFilters() {
    _safeSetState(() {
      _searchQuery = '';
      _yearFilter = 'all';
      _sortBy = 'year_desc';
      _showFarYearAuditOnly = false;
    });
  }

  String _budgetTypeCode(String budgetType) {
    switch (budgetType) {
      case TransactionUiText.budgetTypeGov:
        return 'GOV';
      case TransactionUiText.budgetTypeNonGov:
        return 'NONGOV';
      case TransactionUiText.budgetTypeGeneralGrant:
        return 'GEN';
      case TransactionUiText.budgetTypeSpecificGrant:
        return 'SPEC';
      case TransactionUiText.budgetTypeSchoolIncome:
        return 'SCH';
      default:
        return 'GEN';
    }
  }

  bool _isCodeFormatValid(String code) =>
      RegExp(_budgetCodePattern).hasMatch(code);

  bool _isCodeDuplicate(String code, {String? excludeId}) {
    final normalized = code.trim().toUpperCase();
    return _items.any(
        (e) => e.id != excludeId && e.code.trim().toUpperCase() == normalized);
  }

  bool _isYearDuplicateForMaster({
    required String masterId,
    required String fiscalYear,
    String? excludeId,
  }) {
    final year = fiscalYear.trim();
    return _items.any(
      (e) =>
          e.id != excludeId &&
          e.masterId.trim() == masterId.trim() &&
          e.fiscalYear.trim() == year,
    );
  }

  String _generateBudgetCode({
    required String budgetType,
    required String fiscalYear,
    String? excludeId,
  }) {
    final year = fiscalYear.trim();
    final type = _budgetTypeCode(budgetType);
    final prefix = 'SRC-$type-$year-';
    int maxSeq = 0;
    for (final item in _items) {
      if (item.id == excludeId) continue;
      final code = item.code.trim().toUpperCase();
      if (!code.startsWith(prefix)) continue;
      final seq = int.tryParse(code.substring(prefix.length));
      if (seq != null && seq > maxSeq) maxSeq = seq;
    }
    return '$prefix${(maxSeq + 1).toString().padLeft(3, '0')}';
  }

  String _appendAuditTag({
    required String? description,
    required int targetYear,
    required int currentYear,
  }) {
    const tagPrefix = _auditFarYearTag;
    final text = (description ?? '').trim();
    if (text.contains(tagPrefix)) return text;
    final tag = '$tagPrefix target=$targetYear current=$currentYear';
    if (text.isEmpty) return tag;
    return '$text\n$tag';
  }

  Future<void> _showForm({
    BudgetSourceModel? existing,
    BudgetSourceModel? template,
    bool addFarYearAuditTag = false,
  }) async {
    final isEditMode = existing != null;
    final canManage =
        isEditMode ? _canUpdateBudgetSource : _canCreateBudgetSource;
    if (!canManage) {
      showAutoDismissAlert(
        context,
        TransactionUiText.warning,
        TransactionUiText.noPermissionData,
        2,
        position: AutoDismissAlertPosition.bottomLeft,
      );
      return;
    }
    if (!mounted || _disposed) return;
    if (_moneyGroups.isEmpty) {
      // เผื่อ bootstrap ยังโหลดไม่เสร็จ
      await _loadMoneyGroups();
    }
    if (_bankAccounts.isEmpty) {
      await _loadBankAccounts();
    }
    if (!mounted || _disposed) return;
    final initial = existing ?? template;
    final result = await showBudgetSourceFormDialog(
      context: context,
      budgetTypes: _budgetTypes,
      moneyGroups: _moneyGroups,
      bankAccounts: _bankAccounts,
      existing: initial,
      isCodeFormatValid: _isCodeFormatValid,
      isCodeDuplicate: (code) =>
          _isCodeDuplicate(code, excludeId: existing?.id),
      generateCode: (budgetType, fiscalYear) => _generateBudgetCode(
        budgetType: budgetType,
        fiscalYear: fiscalYear,
        excludeId: existing?.id,
      ),
    );
    if (result == null) return;
    if (!mounted || _disposed) return;
    await _runWithBusy(
      message: isEditMode
          ? 'กำลังบันทึกการแก้ไขแหล่งเงิน...'
          : 'กำลังบันทึกแหล่งเงิน...',
      action: () async {
        try {
          final generatedMasterId =
              'bs_master_${DateTime.now().microsecondsSinceEpoch}';
          final targetMasterId =
              existing?.masterId ?? template?.masterId ?? generatedMasterId;
          final fiscalYearValue = int.tryParse(result.fiscalYear.trim());
          final currentBuddhistYear = FiscalYear.currentBuddhist();
          final finalDescription = addFarYearAuditTag && fiscalYearValue != null
              ? _appendAuditTag(
                  description: result.description,
                  targetYear: fiscalYearValue,
                  currentYear: currentBuddhistYear,
                )
              : result.description;
          if (_isYearDuplicateForMaster(
            masterId: targetMasterId,
            fiscalYear: result.fiscalYear,
            excludeId: existing?.id,
          )) {
            showAutoDismissAlert(
              context,
              TransactionUiText.warning,
              'ปีงบประมาณนี้มีอยู่แล้วในแหล่งเงินเดียวกัน',
              2,
              position: AutoDismissAlertPosition.bottomLeft,
            );
            return;
          }
          final localId = existing?.id.isNotEmpty == true
              ? existing!.id
              : DateTime.now().microsecondsSinceEpoch.toString();
          final selectedGroup = result.refMoneyGroup == null
              ? null
              : _moneyGroups.firstWhere(
                  (g) => g.id == result.refMoneyGroup,
                  orElse: () => const MoneyGroupOption(id: '', name: ''),
                );
          final selectedBankAcc = result.refBankAccount == null
              ? null
              : _bankAccounts.firstWhere(
                  (b) => b.id == result.refBankAccount,
                  orElse: () => const LocalBankAccountItem(id: '', name: ''),
                );
          final localModel = BudgetSourceModel(
            id: localId,
            masterId: targetMasterId,
            code: result.code,
            name: result.name,
            fiscalYear: result.fiscalYear,
            budgetAmount: existing?.budgetAmount ?? template?.budgetAmount ?? 0,
            broughtForwardAmount: existing?.broughtForwardAmount ??
                template?.broughtForwardAmount ??
                0,
            usedAmount: existing?.usedAmount ?? template?.usedAmount ?? 0,
            reservedAmount:
                existing?.reservedAmount ?? template?.reservedAmount ?? 0,
            budgetType: result.budgetType,
            description: finalDescription,
            refMoneyGroup: result.refMoneyGroup,
            moneyGroupName: (selectedGroup == null || selectedGroup.id.isEmpty)
                ? null
                : selectedGroup.name,
            refBankAccount: result.refBankAccount,
            bankAccountName:
                (selectedBankAcc == null || selectedBankAcc.id.isEmpty)
                    ? null
                    : selectedBankAcc.name,
          );
          final canSyncOnline = await LicenseMode.canSyncOnline();
          await _localDs.saveBudgetSource(localModel, synced: false);

          if (canSyncOnline && _isRealRemoteToken) {
            if (!isEditMode) {
              unawaited(_ds
                  .create(
                    token: _token ?? '',
                    code: result.code,
                    name: result.name,
                    fiscalYear: result.fiscalYear,
                    budgetAmount: 0,
                    broughtForwardAmount: 0,
                    budgetType: result.budgetType,
                    description: finalDescription,
                    refMoneyGroup: result.refMoneyGroup,
                    refBankAccount: result.refBankAccount,
                  )
                  .catchError((_) {}));
            } else {
              unawaited(_ds.update(
                token: _token ?? '',
                id: existing.id,
                fields: {
                  'code': result.code,
                  'name': result.name,
                  'fiscal_year': result.fiscalYear,
                  'budget_type': result.budgetType,
                  'refmoneygroup': result.refMoneyGroup ?? '',
                  'refbankaccount': result.refBankAccount ?? '',
                  'description': finalDescription,
                },
              ).catchError((_) {}));
            }
          }
          if (!mounted || _disposed) return;
          showAutoDismissAlert(
            context,
            TransactionUiText.success,
            TransactionUiText.saveSuccessDone,
            2,
            position: AutoDismissAlertPosition.bottomLeft,
          );
          await _loadData();
        } catch (e) {
          if (mounted && !_disposed) {
            showAutoDismissAlert(
              context,
              TransactionUiText.error,
              toUserErrorMessage(e),
              3,
              position: AutoDismissAlertPosition.bottomLeft,
            );
          }
        }
      },
    );
  }

  Future<void> _editBudgetAmounts(BudgetSourceModel item) async {
    if (!_canUpdateBudgetSource) {
      showAutoDismissAlert(
        context,
        TransactionUiText.warning,
        TransactionUiText.noPermissionData,
        2,
        position: AutoDismissAlertPosition.bottomLeft,
      );
      return;
    }
    final result =
        await showBudgetSourceAmountsDialog(context: context, item: item);
    if (result == null || !mounted || _disposed) return;
    await _runWithBusy(
      message: 'กำลังบันทึกยอดงบประมาณ...',
      action: () async {
        try {
          final updated = BudgetSourceModel(
            id: item.id,
            masterId: item.masterId,
            code: item.code,
            name: item.name,
            fiscalYear: item.fiscalYear,
            budgetAmount: result.budgetAmount,
            broughtForwardAmount: result.broughtForwardAmount,
            usedAmount: item.usedAmount,
            reservedAmount: item.reservedAmount,
            budgetType: item.budgetType,
            description: item.description,
            refMoneyGroup: item.refMoneyGroup,
            moneyGroupName: item.moneyGroupName,
            refBankAccount: item.refBankAccount,
            bankAccountName: item.bankAccountName,
          );
          final canSyncOnline = await LicenseMode.canSyncOnline();
          await _localDs.saveBudgetSource(updated, synced: false);
          if (canSyncOnline && _isRealRemoteToken) {
            unawaited(_ds.update(
              token: _token ?? '',
              id: item.id,
              fields: {
                'budget_amount': result.budgetAmount,
                'brought_forward_amount': result.broughtForwardAmount,
                'budgetAmount': result.budgetAmount,
                'broughtForwardAmount': result.broughtForwardAmount,
              },
            ).catchError((_) {}));
          }
          if (!mounted || _disposed) return;
          showAutoDismissAlert(
            context,
            TransactionUiText.success,
            TransactionUiText.saveSuccessDone,
            2,
            position: AutoDismissAlertPosition.bottomLeft,
          );
          await _loadData();
        } catch (e) {
          if (mounted && !_disposed) {
            showAutoDismissAlert(
              context,
              TransactionUiText.error,
              toUserErrorMessage(e),
              3,
              position: AutoDismissAlertPosition.bottomLeft,
            );
          }
        }
      },
    );
  }

  Future<void> _showCreateOptions() async {
    if (!_canCreateBudgetSource) {
      showAutoDismissAlert(
        context,
        TransactionUiText.warning,
        TransactionUiText.noPermissionData,
        2,
        position: AutoDismissAlertPosition.bottomLeft,
      );
      return;
    }

    if (_items.isEmpty) {
      await _showForm();
      return;
    }

    final latestByMaster = <String, BudgetSourceModel>{};
    for (final item in _items) {
      final current = latestByMaster[item.masterId];
      if (current == null ||
          item.fiscalYear.compareTo(current.fiscalYear) > 0) {
        latestByMaster[item.masterId] = item;
      }
    }
    final candidates = latestByMaster.values.where((item) {
      final latestYear = int.tryParse(item.fiscalYear);
      if (latestYear == null) return true;
      final nextYearText = (latestYear + 1).toString();
      return !_isYearDuplicateForMaster(
        masterId: item.masterId,
        fiscalYear: nextYearText,
      );
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (candidates.isEmpty) {
      showAutoDismissAlert(
        context,
        TransactionUiText.warning,
        'ทุกแหล่งเงินมีงบปีถัดไปแล้ว',
        2,
        position: AutoDismissAlertPosition.bottomLeft,
      );
      return;
    }

    if (!mounted || _disposed) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: AdaptiveContentSheet(
            title: 'เพิ่มแหล่งเงิน',
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.sp8,
                0,
                AppTheme.sp8,
                AppTheme.sp8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline_rounded),
                    title: const Text('สร้างแหล่งเงินใหม่'),
                    subtitle: const Text('เพิ่มแหล่งเงินและปีงบประมาณใหม่'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showForm();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.copy_all_rounded),
                    title: const Text('เพิ่มงบปีถัดไปจากแหล่งเงินเดิม'),
                    subtitle: const Text('สร้างรายการปีใหม่จาก master เดิม'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final selected =
                          await _pickBudgetSourceForNextYear(candidates);
                      if (selected == null) return;
                      if (!mounted || _disposed) return;
                      final nextYear =
                          (int.tryParse(selected.fiscalYear) ?? 0) + 1;
                      final currentBuddhistYear = FiscalYear.currentBuddhist();
                      final isFarFromCurrentYear =
                          nextYear - currentBuddhistYear > 1;
                      if (nextYear <= 0) {
                        showAutoDismissAlert(
                          context,
                          TransactionUiText.warning,
                          'ไม่สามารถสร้างปีงบถัดไปได้',
                          2,
                          position: AutoDismissAlertPosition.bottomLeft,
                        );
                        return;
                      }
                      if (isFarFromCurrentYear) {
                        final shouldContinue = await showDialog<bool>(
                              context: context,
                              builder: (warnCtx) => ConfirmDialog(
                                isDestructive: false,
                                title: 'ยืนยันการสร้างปีงบประมาณ',
                                message:
                                    'ปีที่จะสร้างคือ $nextYear ซึ่งห่างจากปีปัจจุบันมากกว่า 1 ปี\nต้องการดำเนินการต่อหรือไม่?',
                                confirmText: 'ดำเนินการต่อ',
                                confirmColor:
                                    Theme.of(warnCtx).colorScheme.primary,
                              ),
                            ) ??
                            false;
                        if (!shouldContinue) return;
                        if (!mounted || _disposed) return;
                      }
                      final nextYearText = nextYear.toString();
                      final isDuplicate = _isYearDuplicateForMaster(
                        masterId: selected.masterId,
                        fiscalYear: nextYearText,
                      );
                      if (isDuplicate) {
                        showAutoDismissAlert(
                          context,
                          TransactionUiText.warning,
                          'มีงบปี $nextYearText ของแหล่งเงินนี้อยู่แล้ว',
                          2,
                          position: AutoDismissAlertPosition.bottomLeft,
                        );
                        return;
                      }
                      final template = BudgetSourceModel(
                        id: '',
                        masterId: selected.masterId,
                        code: _generateBudgetCode(
                          budgetType: selected.budgetType,
                          fiscalYear: nextYearText,
                        ),
                        name: selected.name,
                        fiscalYear: nextYearText,
                        budgetAmount: 0,
                        broughtForwardAmount: 0,
                        usedAmount: 0,
                        reservedAmount: 0,
                        budgetType: selected.budgetType,
                        description: selected.description,
                      );
                      await _showForm(
                        template: template,
                        addFarYearAuditTag: isFarFromCurrentYear,
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<BudgetSourceModel?> _pickBudgetSourceForNextYear(
    List<BudgetSourceModel> candidates,
  ) {
    return showModalBottomSheet<BudgetSourceModel>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final sheetColors = AppColors.of(sheetContext);
        final sheetScheme = Theme.of(sheetContext).colorScheme;
        final currentBuddhistYear = FiscalYear.currentBuddhist();
        return SafeArea(
          child: AdaptiveContentSheet(
            title: 'เลือกแหล่งเงินที่ต้องการเพิ่มปี',
            maxHeightFactor: 0.88,
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(
                AppTheme.sp16,
                0,
                AppTheme.sp16,
                AppTheme.sp16,
              ),
              itemCount: candidates.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final item = candidates[index];
                final nextYear = (int.tryParse(item.fiscalYear) ?? 0) + 1;
                final isFarFromCurrentYear = nextYear - currentBuddhistYear > 1;
                final nextYearBg = isFarFromCurrentYear
                    ? sheetColors.iconBgLoan
                    : sheetScheme.primaryContainer.withValues(alpha: 0.35);
                final nextYearFg = isFarFromCurrentYear
                    ? sheetColors.loanAmber
                    : sheetScheme.onPrimaryContainer;
                final nextYearLabel = isFarFromCurrentYear
                    ? 'ปีที่จะสร้าง $nextYear (ตรวจสอบปี)'
                    : 'ปีที่จะสร้าง $nextYear';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.name),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: AppTheme.sp8,
                      runSpacing: 6,
                      children: [
                        _buildPickerChip(
                          context: sheetContext,
                          text: 'ปีล่าสุด ${item.fiscalYear}',
                          background: sheetColors.surface,
                          foreground: sheetColors.textSecondary,
                          borderColor: sheetColors.cardBorder,
                        ),
                        _buildPickerChip(
                          context: sheetContext,
                          text: nextYearLabel,
                          background: nextYearBg,
                          foreground: nextYearFg,
                        ),
                      ],
                    ),
                  ),
                  onTap: () => Navigator.pop(sheetContext, item),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildPickerChip({
    required BuildContext context,
    required String text,
    required Color background,
    required Color foreground,
    Color? borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: borderColor == null ? null : Border.all(color: borderColor),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: foreground,
            ),
      ),
    );
  }

  void _confirmDelete(BudgetSourceModel item) {
    if (!_canDeleteBudgetSource) {
      showAutoDismissAlert(
        context,
        TransactionUiText.warning,
        TransactionUiText.noPermissionData,
        2,
        position: AutoDismissAlertPosition.bottomLeft,
      );
      return;
    }
    showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: TransactionUiText.confirmDelete,
        message: TransactionUiText.confirmDeleteBudgetSource
            .replaceFirst('%s', item.name),
        cancelText: TransactionUiText.cancel,
        confirmText: TransactionUiText.delete,
      ),
    ).then((shouldDelete) async {
      if (shouldDelete != true) return;
      await _runWithBusy(
        message: 'กำลังลบแหล่งเงิน...',
        action: () async {
          try {
            await _localDs.deleteBudgetSource(item.id);
            if (await LicenseMode.canSyncOnline() && _isRealRemoteToken) {
              unawaited(_ds
                  .delete(token: _token ?? '', id: item.id)
                  .catchError((_) {}));
            }
            if (mounted && !_disposed) {
              showAutoDismissAlert(
                context,
                TransactionUiText.success,
                TransactionUiText.deleteSuccess,
                2,
                position: AutoDismissAlertPosition.bottomLeft,
              );
            }
            await _loadData();
          } catch (e) {
            if (mounted && !_disposed) {
              showAutoDismissAlert(
                context,
                TransactionUiText.error,
                toUserErrorMessage(e),
                3,
                position: AutoDismissAlertPosition.bottomLeft,
              );
            }
          }
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_canViewBudgetSource) {
      return Scaffold(
        appBar: AppBar(title: const Text(TransactionUiText.budgetSourceTitle)),
        body: const Center(child: Text(TransactionUiText.noPermissionData)),
      );
    }
    final c = AppColors.of(context);
    return AppBusyBackdrop(
      isBusy: _busyDepth > 0,
      message: _busyMessage,
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          title: const Text(TransactionUiText.budgetSourceTitle),
          backgroundColor: c.cardWhite,
          elevation: 0,
          actions: [
            IconButton(
              tooltip: TransactionUiText.budgetDashboardOpenTooltip,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const BudgetDashboardPage(),
                  ),
                );
              },
              icon: Icon(Icons.insights_outlined, color: c.textSecondary),
            ),
            IconButton(
              tooltip: _showFarYearAuditOnly
                  ? 'แสดงทั้งหมด'
                  : 'แสดงเฉพาะรายการเตือนปีไกล',
              onPressed: () => _safeSetState(
                  () => _showFarYearAuditOnly = !_showFarYearAuditOnly),
              icon: Icon(
                _showFarYearAuditOnly
                    ? Icons.warning_amber_rounded
                    : Icons.warning_amber_outlined,
                color: _showFarYearAuditOnly
                    ? Colors.orange.shade700
                    : c.textSecondary,
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: c.cardBorder),
          ),
        ),
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary))
            : _items.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.account_balance_wallet_outlined,
                              size: 56, color: c.textHint),
                          const SizedBox(height: 16),
                          Text(
                            TransactionUiText.emptyBudgetSource,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            TransactionUiText.budgetSourceManage,
                            textAlign: TextAlign.center,
                            style:
                                TextStyle(color: c.textSecondary, height: 1.4),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            TransactionUiText.budgetSourceListIntro,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 12,
                                height: 1.35),
                          ),
                          const SizedBox(height: 20),
                          if (_canCreateBudgetSource)
                            FilledButton.icon(
                              onPressed: _showCreateOptions,
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('เพิ่มแหล่งเงิน'),
                            ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: _loadData,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('โหลดข้อมูลอีกครั้ง'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _filteredItems.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off_rounded,
                                  size: 48, color: c.textHint),
                              const SizedBox(height: 12),
                              Text(
                                TransactionUiText.notFound,
                                style: TextStyle(
                                    color: c.textPrimary,
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                TransactionUiText.budgetSourceListIntro,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: c.textSecondary,
                                    fontSize: 12,
                                    height: 1.35),
                              ),
                              const SizedBox(height: 16),
                              if (_hasActiveFilter)
                                TextButton.icon(
                                  onPressed: _resetFilters,
                                  icon:
                                      const Icon(Icons.filter_alt_off_rounded),
                                  label: const Text(
                                      TransactionUiText.clearFilters),
                                ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: Column(
                          children: [
                            const _BudgetSourceIntroBar(),
                            BudgetSourceFilterSection(
                              searchQuery: _searchQuery,
                              yearFilter: _yearFilter,
                              sortBy: _sortBy,
                              yearOptions: _yearOptions,
                              hasActiveFilter: _hasActiveFilter,
                              resultCount: _filteredItems.length,
                              onSearchChanged: (v) =>
                                  _safeSetState(() => _searchQuery = v),
                              onYearChanged: (v) =>
                                  _safeSetState(() => _yearFilter = v ?? 'all'),
                              onSortChanged: (v) => _safeSetState(
                                  () => _sortBy = v ?? 'year_desc'),
                              onResetFilters: _resetFilters,
                            ),
                            Expanded(
                              child: ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: _filteredItems.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (_, i) => BudgetSourceItemCard(
                                  item: _filteredItems[i],
                                  onEdit: () =>
                                      _showForm(existing: _filteredItems[i]),
                                  onEditAmounts: () =>
                                      _editBudgetAmounts(_filteredItems[i]),
                                  onDelete: () =>
                                      _confirmDelete(_filteredItems[i]),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
        floatingActionButton: SizedBox(
          width: 56,
          height: 56,
          child: FloatingActionButton(
            onPressed: _showCreateOptions,
            backgroundColor: c.navy,
            foregroundColor: AppTheme.foregroundFor(c.navy),
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }
}

class _BudgetSourceIntroBar extends StatelessWidget {
  const _BudgetSourceIntroBar();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.30),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.cardBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.tips_and_updates_outlined,
                  size: 20, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TransactionUiText.budgetSourceManage,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      TransactionUiText.budgetSourceListIntro,
                      style: TextStyle(
                        fontSize: 12,
                        color: c.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
