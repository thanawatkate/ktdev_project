import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';

/// รายการหมวดรายรับสำหรับแสดงในหน้าจัดการหมวดรายรับ
class IncomeTypeListItem {
  final String id;
  final String code;
  final String name;
  final String detail;
  final String lastModified;
  final int linkedBudgetSources;

  const IncomeTypeListItem({
    required this.id,
    required this.code,
    required this.name,
    required this.detail,
    required this.lastModified,
    required this.linkedBudgetSources,
  });
}

class IncomeTypeItemCard extends StatefulWidget {
  final IncomeTypeListItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const IncomeTypeItemCard({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<IncomeTypeItemCard> createState() => _IncomeTypeItemCardState();
}

class _IncomeTypeItemCardState extends State<IncomeTypeItemCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final item = widget.item;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: item.detail.trim().isEmpty
            ? null
            : () {
                setState(() => _expanded = !_expanded);
              },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name.isEmpty ? '-' : item.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                          ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.iconBgIncome,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      TransactionUiText.incomeTypeLinkedSourcesLabel(
                        item.linkedBudgetSources,
                      ),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: c.incomeGreen),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: TransactionUiText.incomeTypeRowMenuTooltip,
                    color: c.cardWhite,
                    onSelected: (value) {
                      if (value == 'edit') widget.onEdit();
                      if (value == 'delete') widget.onDelete();
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.edit_outlined, size: 18),
                          title: Text(
                            TransactionUiText.edit,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontFamily: 'Kanit',
                            ),
                          ),
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: c.expenseRed,
                          ),
                          title: Text(
                            TransactionUiText.delete,
                            style: TextStyle(
                              color: c.expenseRed,
                              fontFamily: 'Kanit',
                            ),
                          ),
                        ),
                      ),
                    ],
                    icon: const Icon(Icons.more_vert_rounded, size: 18),
                  ),
                ],
              ),
              if (item.code.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  TransactionUiText.incomeTypeCodeLine(item.code),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: c.textSecondary),
                ),
              ],
              if (item.detail.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  item.detail,
                  maxLines: _expanded ? null : 1,
                  overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  _expanded
                      ? TransactionUiText.detailTapToCollapse
                      : TransactionUiText.detailTapToExpand,
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
    );
  }
}
