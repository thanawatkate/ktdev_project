import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/di/service_locator.dart';
import 'package:saccm/features/loan/data/repositories/loan_repository_offline.dart';

class LoanOutstandingTab extends StatefulWidget {
  const LoanOutstandingTab({super.key});

  @override
  State<LoanOutstandingTab> createState() => _LoanOutstandingTabState();
}

class _LoanOutstandingTabState extends State<LoanOutstandingTab>
    with AutomaticKeepAliveClientMixin {
  final _fmt = NumberFormat('#,##0.00');
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];
  double _totalOutstanding = 0;
  int _overdueCount = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ServiceLocator.instance.get<LoanRepository>();
      final loans = await repo.getLoanList();
      final outstanding = loans
          .where((e) => e.outstanding > 0.0001)
          .map(
            (e) => {
              'docno': e.docno,
              'borrower': e.borrowerLabel,
              'duedate': e.duedate,
              'outstanding': e.outstanding,
              'is_overdue': e.isOverdue,
            },
          )
          .toList();
      outstanding.sort((a, b) {
        final ao = a['is_overdue'] == true ? 0 : 1;
        final bo = b['is_overdue'] == true ? 0 : 1;
        if (ao != bo) return ao.compareTo(bo);
        final da = DateTime.tryParse(a['duedate']?.toString() ?? '') ??
            DateTime(2100);
        final db = DateTime.tryParse(b['duedate']?.toString() ?? '') ??
            DateTime(2100);
        return da.compareTo(db);
      });
      final total = outstanding.fold<double>(
        0,
        (s, m) => s + (m['outstanding'] as double),
      );
      final overdue = outstanding.where((m) => m['is_overdue'] == true).length;
      if (mounted) {
        setState(() {
          _rows = outstanding;
          _totalOutstanding = total;
          _overdueCount = overdue;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(TransactionUiText.view),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: scheme.primary))
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(_error!, style: TextStyle(color: c.expenseRed)),
                      ),
                    )
                  : _rows.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              TransactionUiText.loanOutstandingEmpty,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: c.textSecondary,
                                fontFamily: 'Kanit',
                              ),
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            Text(
                              TransactionUiText.loanOutstandingSummaryTitle,
                              style: TextStyle(
                                fontFamily: 'Kanit',
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: c.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: c.cardBorder),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            TransactionUiText.loanOutstandingTotalLabel,
                                            style: TextStyle(
                                              color: c.textSecondary,
                                              fontFamily: 'Kanit',
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${_fmt.format(_totalOutstanding)} ${TransactionUiText.baht}',
                                          style: TextStyle(
                                            color: c.loanAmber,
                                            fontWeight: FontWeight.w800,
                                            fontFamily: 'Kanit',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            TransactionUiText.loanOutstandingContractsLabel,
                                            style: TextStyle(
                                              color: c.textSecondary,
                                              fontFamily: 'Kanit',
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${_rows.length} ${TransactionUiText.items}',
                                          style: TextStyle(
                                            color: c.navy,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'Kanit',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            TransactionUiText.loanOutstandingOverdueLabel,
                                            style: TextStyle(
                                              color: c.textSecondary,
                                              fontFamily: 'Kanit',
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '$_overdueCount ${TransactionUiText.items}',
                                          style: TextStyle(
                                            color: _overdueCount > 0
                                                ? c.expenseRed
                                                : c.textPrimary,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'Kanit',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ..._rows.map((m) {
                              final overdue = m['is_overdue'] == true;
                              final due = m['duedate']?.toString() ?? '';
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(
                                    color: overdue
                                        ? c.expenseRed.withValues(alpha: 0.5)
                                        : c.cardBorder,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              m['docno']?.toString() ?? TransactionUiText.unspecified,
                                              style: TextStyle(
                                                fontFamily: 'Kanit',
                                                fontWeight: FontWeight.w700,
                                                color: c.navy,
                                              ),
                                            ),
                                          ),
                                          if (overdue)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: c.expenseRed
                                                    .withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                TransactionUiText.loanOverdueBadge,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: c.expenseRed,
                                                  fontFamily: 'Kanit',
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${TransactionUiText.loanOutstandingBorrower}: ${m['borrower']}',
                                        style: TextStyle(
                                          fontFamily: 'Kanit',
                                          fontSize: 13,
                                          color: c.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${TransactionUiText.loanDueDate}: ${due.isEmpty ? TransactionUiText.unspecified : due.substring(0, due.length >= 10 ? 10 : due.length)}',
                                        style: TextStyle(
                                          fontFamily: 'Kanit',
                                          fontSize: 12,
                                          color: c.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          '${TransactionUiText.loanOutstandingBalance}: ${_fmt.format(m['outstanding'] as double)} ${TransactionUiText.baht}',
                                          style: TextStyle(
                                            fontFamily: 'Kanit',
                                            fontWeight: FontWeight.w700,
                                            color: c.loanAmber,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
        ),
      ],
    );
  }
}
