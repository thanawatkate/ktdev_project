import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';

/// การ์ดหนึ่งรายการใน Workflow อนุมัติ
class ApprovalItemCard extends StatelessWidget {
  const ApprovalItemCard({
    super.key,
    required this.item,
    required this.status,
    required this.syncing,
    this.onApprove,
    this.onReject,
    this.onViewLog,
    this.onPostExpense,
  });

  final Map<String, dynamic> item;
  final String status;
  final bool syncing;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onViewLog;
  final VoidCallback? onPostExpense;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final amount = double.tryParse(item['amount']?.toString() ?? '0') ?? 0;
    final fmt = NumberFormat('#,##0.00');
    final Color statusColor = status == 'pending'
        ? c.loanAmber
        : status == 'approved'
            ? c.incomeGreen
            : c.expenseRed;
    final String statusLabel = status == 'pending'
        ? TransactionUiText.pendingApproval
        : status == 'approved'
            ? TransactionUiText.approved
            : TransactionUiText.rejected;

    return Card(
      elevation: Theme.of(context).brightness == Brightness.dark ? 0 : 1,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.r16),
        side: BorderSide(color: c.cardBorder),
      ),
      color: c.cardWhite,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sp16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item['docno']?.toString() ?? '-',
                    style: TextStyle(
                      fontFamily: 'Kanit',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                if (syncing) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.sp8, vertical: AppTheme.sp4),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.r12),
                      border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.28)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: AppTheme.sp8),
                        Text(
                          TransactionUiText.approvalSyncingWithServer,
                          style: TextStyle(
                            fontFamily: 'Kanit',
                            color: scheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppTheme.sp8),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.sp8, vertical: AppTheme.sp4),
                  decoration: BoxDecoration(
                    color: status == 'pending'
                        ? c.iconBgLoan
                        : status == 'approved'
                            ? c.iconBgIncome
                            : c.iconBgExpense,
                    borderRadius: BorderRadius.circular(AppTheme.r12),
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.45)),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontFamily: 'Kanit',
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.sp8),
            if (item['member_name'] != null)
              Text(
                '${TransactionUiText.requesterPrefix}${item['member_name']}',
                style: TextStyle(
                    fontFamily: 'Kanit', color: c.textSecondary, fontSize: 13),
              ),
            if (item['budget_source_name'] != null)
              Text(
                '${TransactionUiText.budgetSourcePrefix}${item['budget_source_name']}',
                style: TextStyle(
                    fontFamily: 'Kanit', color: c.textSecondary, fontSize: 13),
              ),
            const SizedBox(height: AppTheme.sp12),
            LayoutBuilder(
              builder: (context, rowConstraints) {
                final narrow = rowConstraints.maxWidth < 340;
                final amountWidget = Text(
                  '${fmt.format(amount)} ${TransactionUiText.baht}',
                  style: TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: c.expenseRed,
                  ),
                );
                final actions = status == 'pending' &&
                        (onApprove != null || onReject != null)
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (onReject != null)
                            OutlinedButton(
                              onPressed: onReject,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: c.expenseRed,
                                side: BorderSide(
                                    color:
                                        c.expenseRed.withValues(alpha: 0.85)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppTheme.sp12,
                                    vertical: AppTheme.sp8),
                                minimumSize: const Size(48, 40),
                                tapTargetSize: MaterialTapTargetSize.padded,
                              ),
                              child: const Text(
                                TransactionUiText.rejectAction,
                                style: TextStyle(
                                    fontFamily: 'Kanit',
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          if (onReject != null && onApprove != null)
                            const SizedBox(width: AppTheme.sp8),
                          if (onApprove != null)
                            FilledButton(
                              onPressed: onApprove,
                              style: FilledButton.styleFrom(
                                backgroundColor: c.incomeGreen,
                                foregroundColor:
                                    AppTheme.foregroundFor(c.incomeGreen),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppTheme.sp16,
                                    vertical: AppTheme.sp8),
                                minimumSize: const Size(48, 40),
                                tapTargetSize: MaterialTapTargetSize.padded,
                              ),
                              child: const Text(
                                TransactionUiText.approveAction,
                                style: TextStyle(
                                    fontFamily: 'Kanit',
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                        ],
                      )
                    : null;
                if (actions == null) {
                  return amountWidget;
                }
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      amountWidget,
                      const SizedBox(height: AppTheme.sp12),
                      actions,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: amountWidget),
                    actions,
                  ],
                );
              },
            ),
            if (status == 'rejected' && item['reject_reason'] != null) ...[
              const SizedBox(height: AppTheme.sp8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.sp12),
                decoration: BoxDecoration(
                  color: c.iconBgExpense,
                  borderRadius: BorderRadius.circular(AppTheme.r12),
                  border:
                      Border.all(color: c.expenseRed.withValues(alpha: 0.22)),
                ),
                child: Text(
                  '${TransactionUiText.reasonPrefix}${item['reject_reason']}',
                  style: TextStyle(
                    fontFamily: 'Kanit',
                    color: c.expenseRed,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ),
            ],
            if (onViewLog != null || onPostExpense != null) ...[
              const SizedBox(height: AppTheme.sp8),
              Wrap(
                spacing: AppTheme.sp8,
                runSpacing: AppTheme.sp4,
                children: [
                  if (onViewLog != null)
                    TextButton.icon(
                      onPressed: onViewLog,
                      icon: Icon(Icons.history_rounded,
                          size: 18, color: c.textSecondary),
                      label: const Text(
                        TransactionUiText.approvalLogViewAction,
                        style: TextStyle(
                            fontFamily: 'Kanit', fontWeight: FontWeight.w600),
                      ),
                    ),
                  if (onPostExpense != null)
                    FilledButton.icon(
                      onPressed: onPostExpense,
                      style: FilledButton.styleFrom(
                        backgroundColor: c.expenseRed,
                        foregroundColor: AppTheme.foregroundFor(c.expenseRed),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.sp12,
                          vertical: AppTheme.sp8,
                        ),
                      ),
                      icon: const Icon(Icons.payments_outlined, size: 18),
                      label: const Text(
                        TransactionUiText.expensePostFromApprovalAction,
                        style: TextStyle(
                            fontFamily: 'Kanit', fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ],
            if (status == 'approved' && item['approver_name'] != null) ...[
              const SizedBox(height: AppTheme.sp8),
              Row(
                children: [
                  Icon(Icons.verified_outlined, size: 16, color: c.incomeGreen),
                  const SizedBox(width: AppTheme.sp4),
                  Expanded(
                    child: Text(
                      '${TransactionUiText.approvedByPrefix}${item['approver_name']}',
                      style: TextStyle(
                        fontFamily: 'Kanit',
                        color: c.incomeGreen,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
