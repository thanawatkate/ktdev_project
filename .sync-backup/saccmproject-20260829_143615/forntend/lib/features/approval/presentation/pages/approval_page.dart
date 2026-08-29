// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/di/service_locator.dart';
import 'package:saccm/core/services/app_notification_service.dart';
import 'package:saccm/core/utils/user_error_message.dart';
import 'package:saccm/features/approval/data/expense_entry_prefill_resolver.dart';
import 'package:saccm/features/approval/data/repositories/approval_repository.dart';
import 'package:saccm/features/expense/presentation/pages/expense_entry_page.dart';
import 'package:saccm/features/auth/presentation/providers/simple_auth_provider.dart';
import 'package:saccm/features/approval/presentation/widgets/approval_decision_dialog.dart';
import 'package:saccm/features/approval/presentation/widgets/approval_empty_state.dart';
import 'package:saccm/features/approval/presentation/widgets/approval_item_card.dart';
import 'package:saccm/features/approval/presentation/widgets/approval_no_access_view.dart';
import 'package:saccm/features/approval/presentation/widgets/approval_log_sheet.dart';
import 'package:saccm/widgets/layout/embedded_home_scaffold.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApprovalPage extends StatefulWidget {
  const ApprovalPage({
    super.key,
    this.embeddedInHome = false,
  });

  final bool embeddedInHome;
  @override
  State<ApprovalPage> createState() => _ApprovalPageState();
}

class _ApprovalPageState extends State<ApprovalPage>
    with SingleTickerProviderStateMixin {
  static const String _fontFamily = 'Kanit';

  ApprovalRepository get _approvalRepo =>
      ServiceLocator.instance.get<ApprovalRepository>();

  late TabController _tabController;
  List _pending = [], _approved = [], _rejected = [];
  final Set<String> _syncingIds = <String>{};
  final bool _isLoading = false;
  String? _token;

  final _tabs = const [
    TransactionUiText.pendingApproval,
    TransactionUiText.approved,
    TransactionUiText.rejected
  ];

  bool get _canApproveWithdraw =>
      context.read<SimpleAuthProvider>().can(PermissionKey.approvalApprove);
  bool get _canRejectWithdraw =>
      context.read<SimpleAuthProvider>().can(PermissionKey.approvalReject);

  /// แจ้งเมื่อสิทธิ์อนุมัติ/ปฏิเสธไม่ครบทั้งคู่ (หรือไม่มีทั้งคู่)
  String? get _approvalPermissionBannerText {
    if (_canApproveWithdraw && _canRejectWithdraw) return null;
    if (_canApproveWithdraw && !_canRejectWithdraw) {
      return TransactionUiText.approvalPermissionApproveOnlyHint;
    }
    if (!_canApproveWithdraw && _canRejectWithdraw) {
      return TransactionUiText.approvalPermissionRejectOnlyHint;
    }
    return TransactionUiText.approvalPermissionViewOnlyHint;
  }

  void _safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  void _notifyWarning(String message) {
    AppNotificationService.instance
        .showWarning(TransactionUiText.warning, message);
  }

  void _notifyError(String message) {
    AppNotificationService.instance.showError(TransactionUiText.error, message);
  }

  void _notifySuccess(String message) {
    AppNotificationService.instance
        .showSuccess(TransactionUiText.success, message);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _bootstrap();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _loadToken();
    if (!mounted) return;
    await _loadFromLocalFirst();
    unawaited(_syncApprovalsFromRemote());
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
  }

  Future<void> _loadFromLocalFirst() async {
    final snap = await _approvalRepo.loadLocalSnapshot();
    if (!mounted) return;
    _safeSetState(() {
      _pending = snap.pending;
      _approved = snap.approved;
      _rejected = snap.rejected;
    });
  }

  Future<void> _syncApprovalsFromRemote() async {
    try {
      await _approvalRepo.syncAllFromRemote();
      if (!mounted) return;
      await _loadFromLocalFirst();
    } catch (_) {}
  }

  Map<String, dynamic> _normalizeApprovalItem(dynamic item) {
    return Map<String, dynamic>.from(item as Map)
      ..putIfAbsent('id', () => '')
      ..putIfAbsent('docno', () => '-')
      ..putIfAbsent('amount', () => '0');
  }

  void _applyOptimisticStatus(
    dynamic rawItem,
    String newStatus, {
    String? rejectReason,
  }) {
    final item = _normalizeApprovalItem(rawItem);
    final itemId = item['id']?.toString() ?? '';
    if (itemId.isEmpty) return;

    _safeSetState(() {
      _pending =
          _pending.where((e) => (e['id']?.toString() ?? '') != itemId).toList();
      _approved = _approved
          .where((e) => (e['id']?.toString() ?? '') != itemId)
          .toList();
      _rejected = _rejected
          .where((e) => (e['id']?.toString() ?? '') != itemId)
          .toList();

      final updated = Map<String, dynamic>.from(item)
        ..['status'] = newStatus
        ..['reject_reason'] = rejectReason;

      if (newStatus == 'approved') {
        _approved = [updated, ..._approved];
      } else if (newStatus == 'rejected') {
        _rejected = [updated, ..._rejected];
      } else {
        _pending = [updated, ..._pending];
      }
    });

    unawaited(_approvalRepo.upsertLocalItem({
      ...item,
      'status': newStatus,
      'reject_reason': rejectReason,
    }));
  }

  void _markSyncing(String itemId, bool syncing) {
    if (itemId.isEmpty) return;
    _safeSetState(() {
      if (syncing) {
        _syncingIds.add(itemId);
      } else {
        _syncingIds.remove(itemId);
      }
    });
  }

  Future<void> _approve(dynamic item) async {
    if (!_canApproveWithdraw) {
      _notifyWarning(TransactionUiText.noPermissionData);
      return;
    }
    final note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (_) => ApprovalDecisionDialog(
        title: TransactionUiText.approveConfirmTitle,
        docNoText:
            '${TransactionUiText.withdrawDocPrefix}${item['docno'] ?? '-'}',
        amountText:
            '${TransactionUiText.amountPrefix}${NumberFormat('#,##0.00').format(double.tryParse(item['amount']?.toString() ?? '0') ?? 0)} ${TransactionUiText.baht}',
        inputLabel: TransactionUiText.optionalRemark,
        cancelText: TransactionUiText.cancel,
        confirmText: TransactionUiText.approveAction,
        confirmButtonColor: AppColors.of(context).incomeGreen,
      ),
    );
    if (note == null) return;
    final itemId = item['id']?.toString() ?? '';
    _markSyncing(itemId, true);
    _applyOptimisticStatus(item, 'approved');
    try {
      await _approvalRepo.submitApprove(
        id: item['id']?.toString() ?? '',
        token: _token,
        note: note,
      );
      if (mounted) {
        _notifySuccess(TransactionUiText.approveSuccess);
        final approvedItem = Map<String, dynamic>.from(item as Map)
          ..['status'] = 'approved';
        unawaited(_openExpenseEntryFromApproval(approvedItem));
      }
      unawaited(_syncApprovalsFromRemote());
    } catch (e) {
      unawaited(_syncApprovalsFromRemote());
      if (mounted) _notifyError(toUserErrorMessage(e));
    } finally {
      _markSyncing(itemId, false);
    }
  }

  Future<void> _reject(dynamic item) async {
    if (!_canRejectWithdraw) {
      _notifyWarning(TransactionUiText.noPermissionData);
      return;
    }
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (_) => ApprovalDecisionDialog(
        title: TransactionUiText.rejectWithdrawTitle,
        docNoText:
            '${TransactionUiText.withdrawDocPrefix}${item['docno'] ?? '-'}',
        inputLabel: TransactionUiText.rejectReasonRequired,
        cancelText: TransactionUiText.cancel,
        confirmText: TransactionUiText.rejectAction,
        confirmButtonColor: AppColors.of(context).expenseRed,
        requireInput: true,
        requireInputMessage: TransactionUiText.pleaseProvideReason,
      ),
    );
    if (reason == null) return;
    final itemId = item['id']?.toString() ?? '';
    _markSyncing(itemId, true);
    _applyOptimisticStatus(item, 'rejected', rejectReason: reason);
    try {
      await _approvalRepo.submitReject(
        id: item['id']?.toString() ?? '',
        token: _token,
        rejectReason: reason,
      );
      if (mounted) {
        _notifySuccess(TransactionUiText.rejectSuccess);
      }
      unawaited(_syncApprovalsFromRemote());
    } catch (e) {
      unawaited(_syncApprovalsFromRemote());
      if (mounted) _notifyError(toUserErrorMessage(e));
    } finally {
      _markSyncing(itemId, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!context.read<SimpleAuthProvider>().can(PermissionKey.approvalView)) {
      return const ApprovalNoAccessView();
    }
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final approvalTabs = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TabBar(
          controller: _tabController,
          labelColor: c.textPrimary,
          unselectedLabelColor: c.textSecondary,
          indicatorColor: c.navy,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontFamily: 'Kanit',
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Kanit',
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          tabs: [
            Tab(text: '${_tabs[0]} (${_pending.length})'),
            Tab(text: '${_tabs[1]} (${_approved.length})'),
            Tab(text: '${_tabs[2]} (${_rejected.length})'),
          ],
        ),
        Divider(height: 1, thickness: 1, color: c.dividerColor),
      ],
    );

    return EmbeddedHomeScaffold(
      embeddedInHome: widget.embeddedInHome,
      backgroundColor: c.background,
      standaloneAppBar: AppBar(
        toolbarHeight: 52,
        title: Text(
          TransactionUiText.approvalWorkflow,
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: approvalTabs,
        ),
      ),
      embeddedAppBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: c.cardWhite,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: approvalTabs,
        ),
      ),
      body: Column(
        children: [
          if (_approvalPermissionBannerText != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.sp16,
                0,
                AppTheme.sp16,
                AppTheme.sp8,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.sp12,
                  vertical: AppTheme.sp8,
                ),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(AppTheme.r12),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: AppTheme.sp8),
                    Expanded(
                      child: Text(
                        _approvalPermissionBannerText!,
                        style: TextStyle(
                          fontFamily: 'Kanit',
                          fontSize: 13,
                          height: 1.35,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_isLoading)
            LinearProgressIndicator(
              minHeight: 2,
              color: scheme.primary,
              backgroundColor:
                  scheme.surfaceContainerHighest.withValues(alpha: 0.35),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildList(_pending, 'pending', scheme),
                _buildList(_approved, 'approved', scheme),
                _buildList(_rejected, 'rejected', scheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openExpenseEntryFromApproval(Map<String, dynamic> item) async {
    final prefill = await ExpenseEntryPrefillResolver().resolve(item);
    if (!mounted) return;
    if (prefill == null) {
      _notifyWarning(TransactionUiText.expenseEntryPrefillResolveFailed);
      return;
    }
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ExpenseEntryPage(prefill: prefill),
      ),
    );
    if (mounted) {
      unawaited(_syncApprovalsFromRemote());
    }
  }

  void _openApprovalLog(Map<String, dynamic> map) {
    final refId = map['id']?.toString() ?? '';
    if (refId.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ApprovalLogSheet(
        refId: refId,
        docNo: map['docno']?.toString() ?? '-',
      ),
    );
  }

  Widget _buildList(List items, String status, ColorScheme scheme) {
    if (items.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return RefreshIndicator(
            color: scheme.primary,
            onRefresh: () async {
              await _loadFromLocalFirst();
              unawaited(_syncApprovalsFromRemote());
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(child: ApprovalEmptyState(status: status)),
              ),
            ),
          );
        },
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        return RefreshIndicator(
          color: scheme.primary,
          onRefresh: () async {
            await _loadFromLocalFirst();
            unawaited(_syncApprovalsFromRemote());
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppTheme.sp16,
              AppTheme.sp16,
              AppTheme.sp16,
              AppTheme.sp16,
            ),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppTheme.sp8),
            itemBuilder: (_, i) {
              final raw = items[i];
              final map = Map<String, dynamic>.from(raw as Map);
              final itemId = map['id']?.toString() ?? '';
              final syncing = _syncingIds.contains(itemId);
              return ApprovalItemCard(
                item: map,
                status: status,
                syncing: syncing,
                onApprove: status == 'pending' && _canApproveWithdraw
                    ? () => _approve(raw)
                    : null,
                onReject: status == 'pending' && _canRejectWithdraw
                    ? () => _reject(raw)
                    : null,
                onViewLog: () => _openApprovalLog(map),
                onPostExpense: status == 'approved'
                    ? () => _openExpenseEntryFromApproval(map)
                    : null,
              );
            },
          ),
        );
      },
    );
  }
}
