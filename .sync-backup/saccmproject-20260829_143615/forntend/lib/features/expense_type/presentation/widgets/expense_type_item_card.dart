import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';

/// รายการประเภทรายจ่ายสำหรับแสดงในรายการหน้าตั้งค่าประเภทรายจ่าย
class ExpenseTypeListItem {
  final String id;
  final String code;
  final String name;
  final String remark;
  final int sort;
  final String use;

  /// SQLite `expense_type.refDefaultBudgetSource` (= `budget_source_budget.id` / server `budgetsource.id`)
  final String refDefaultBudgetSourceId;

  /// จาก join (แสดงใต้ชื่อรายการ)
  final String? defaultBudgetSummary;

  const ExpenseTypeListItem({
    required this.id,
    required this.code,
    required this.name,
    required this.remark,
    required this.sort,
    required this.use,
    required this.refDefaultBudgetSourceId,
    this.defaultBudgetSummary,
  });
}

class ExpenseTypeItemCard extends StatefulWidget {
  final ExpenseTypeListItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ExpenseTypeItemCard({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<ExpenseTypeItemCard> createState() => _ExpenseTypeItemCardState();
}

class _ExpenseTypeItemCardState extends State<ExpenseTypeItemCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final item = widget.item;
    final isInactive = item.use != 'Y';
    return Opacity(
      opacity: isInactive ? 0.55 : 1.0,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: item.remark.trim().isEmpty
              ? null
              : () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (item.code.trim().isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.iconBgExpense,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          item.code,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: c.expenseRed,
                                  fontWeight: FontWeight.w700),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        item.name.isEmpty ? '-' : item.name,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: c.textPrimary,
                                ),
                      ),
                    ),
                    if (isInactive)
                      Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.cardBorder,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'ปิดใช้งาน',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: c.textSecondary),
                        ),
                      ),
                    PopupMenuButton<String>(
                      tooltip: 'จัดการรายการ',
                      color: c.cardWhite,
                      onSelected: (v) {
                        if (v == 'edit') widget.onEdit();
                        if (v == 'delete') widget.onDelete();
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem<String>(
                          value: 'edit',
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading:
                                const Icon(Icons.edit_outlined, size: 18),
                            title: Text(TransactionUiText.edit,
                                style: TextStyle(
                                    color: c.textPrimary,
                                    fontFamily: 'Kanit')),
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.delete_outline_rounded,
                                size: 18, color: c.expenseRed),
                            title: Text(TransactionUiText.delete,
                                style: TextStyle(
                                    color: c.expenseRed,
                                    fontFamily: 'Kanit')),
                          ),
                        ),
                      ],
                      icon: const Icon(Icons.more_vert_rounded, size: 18),
                    ),
                  ],
                ),
                if (item.refDefaultBudgetSourceId.trim().isEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    TransactionUiText.expenseTypeDefaultBudgetMissingOnCard,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: c.expenseRed, fontWeight: FontWeight.w600),
                  ),
                ],
                if (item.defaultBudgetSummary != null &&
                    item.defaultBudgetSummary!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.defaultBudgetSummary!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: c.textSecondary),
                  ),
                ],
                if (item.remark.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.remark,
                    maxLines: _expanded ? null : 1,
                    overflow: _expanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: c.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _expanded ? 'แตะเพื่อย่อ' : 'แตะเพื่ออ่านทั้งหมด',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: c.textHint),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
