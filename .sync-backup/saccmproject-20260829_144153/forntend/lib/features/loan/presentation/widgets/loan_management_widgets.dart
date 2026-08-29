import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';

class LoanManagementHeader extends StatelessWidget {
  const LoanManagementHeader({super.key, required this.total});

  final double total;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final fmt = NumberFormat('#,##0.00');
    return Container(
      width: double.infinity,
      color: c.cardWhite,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            TransactionUiText.loanManagementPageTitle,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: c.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            TransactionUiText.loanManagementTotalOutstandingTitle,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                fmt.format(total),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: c.navy,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                TransactionUiText.baht,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: c.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class LoanManagementCard extends StatelessWidget {
  const LoanManagementCard({
    super.key,
    required this.borrower,
    required this.docno,
    required this.dueText,
    required this.obligation,
    required this.outstanding,
    required this.repaid,
    required this.isOverdue,
    required this.onTap,
  });

  final String borrower;
  final String docno;
  final String dueText;
  final double obligation;
  final double outstanding;
  final double repaid;
  final bool isOverdue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final fmt = NumberFormat('#,##0.00');
    final partial = repaid > 0.0001;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.cardBorder),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        borrower,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    if (partial)
                      _LoanManagementBadge(
                        text: TransactionUiText
                            .loanManagementPartiallyRepaidBadge,
                        color: c.loanAmber,
                      )
                    else
                      _LoanManagementBadge(
                        text: TransactionUiText.loanOutstandingBadge,
                        color: c.navy,
                      ),
                    if (isOverdue) ...[
                      const SizedBox(width: 6),
                      _LoanManagementBadge(
                        text: TransactionUiText.loanOverdueBadge,
                        color: c.expenseRed,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _LoanManagementNumberBlock(
                        label: TransactionUiText.loanManagementPrincipalShort,
                        value: fmt.format(obligation),
                      ),
                    ),
                    Expanded(
                      child: _LoanManagementNumberBlock(
                        label: TransactionUiText.loanManagementRemainingShort,
                        value: fmt.format(outstanding),
                        emphasize: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${TransactionUiText.loanManagementLoanDocShort}: $docno',
                  style: TextStyle(fontSize: 11, color: c.textSecondary),
                ),
                Text(
                  '${TransactionUiText.loanDueDate}: $dueText',
                  style: TextStyle(fontSize: 11, color: c.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LoanRepayMethodChip extends StatelessWidget {
  const LoanRepayMethodChip({
    super.key,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: selected ? c.navy.withValues(alpha: 0.1) : c.surface,
      borderRadius: BorderRadius.circular(50),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: selected ? c.navy : c.cardBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? c.navy : c.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _LoanManagementBadge extends StatelessWidget {
  const _LoanManagementBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _LoanManagementNumberBlock extends StatelessWidget {
  const _LoanManagementNumberBlock({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: c.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasize ? 17 : 14,
            fontWeight: FontWeight.w800,
            color: emphasize ? c.navy : c.textPrimary,
          ),
        ),
        Text(
          TransactionUiText.baht,
          style: TextStyle(fontSize: 10, color: c.textHint),
        ),
      ],
    );
  }
}
