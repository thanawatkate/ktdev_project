import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/widgets/widgets.dart';

enum RepayLoanDocFilter { all, outstanding, upcoming7Days, overdue }

enum RepayLoanDocSort { dueDateAsc, remainingDesc }

/// Bottom sheet — เลือกเลขที่ใบยืมจากรายการใน SQLite
class LoanDocPickerSheet extends StatefulWidget {
  const LoanDocPickerSheet({
    super.key,
    required this.loanRows,
    required this.remainingForDocno,
    required this.isOverdueForDocno,
    this.initialDocno,
  });

  final List<Map<String, dynamic>> loanRows;
  final double Function(String docno) remainingForDocno;
  final bool Function(String docno) isOverdueForDocno;
  final String? initialDocno;

  @override
  State<LoanDocPickerSheet> createState() => _LoanDocPickerSheetState();
}

class _LoanDocPickerSheetState extends State<LoanDocPickerSheet> {
  static const _fontFamily = 'Kanit';
  late final TextEditingController _search;
  RepayLoanDocFilter _filter = RepayLoanDocFilter.outstanding;
  RepayLoanDocSort _sort = RepayLoanDocSort.dueDateAsc;

  bool _isDueSoonWithin7Days(Map<String, dynamic> row) {
    final docno = row['docno']?.toString() ?? '';
    final remain = widget.remainingForDocno(docno);
    if (remain <= 0) return false;
    final due = DateTime.tryParse(row['duedate']?.toString() ?? '');
    if (due == null) return false;
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    final dueOnly = DateTime(due.year, due.month, due.day);
    final upcomingMax = todayOnly.add(const Duration(days: 7));
    return !dueOnly.isBefore(todayOnly) && !dueOnly.isAfter(upcomingMax);
  }

  @override
  void initState() {
    super.initState();
    _search = TextEditingController();
    _search.addListener(() => setState(() {}));
    final hasOverdue = widget.loanRows.any((row) {
      final docno = row['docno']?.toString() ?? '';
      final remain = widget.remainingForDocno(docno);
      return remain > 0 && widget.isOverdueForDocno(docno);
    });
    final hasDueSoon = widget.loanRows.any(_isDueSoonWithin7Days);
    _filter = hasOverdue
        ? RepayLoanDocFilter.overdue
        : hasDueSoon
            ? RepayLoanDocFilter.upcoming7Days
            : RepayLoanDocFilter.outstanding;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _formatDateBrief(String raw) {
    final d = DateTime.tryParse(raw);
    if (d == null) return raw.trim().isEmpty ? '-' : raw;
    return '${d.day}/${d.month}/${d.year + 543}';
  }

  DateTime? _dueDayOnly(Map<String, dynamic> row) {
    final d = DateTime.tryParse(row['duedate']?.toString() ?? '');
    if (d == null) return null;
    return DateTime(d.year, d.month, d.day);
  }

  int _compareRows(Map<String, dynamic> a, Map<String, dynamic> b) {
    final da = a['docno']?.toString() ?? '';
    final db = b['docno']?.toString() ?? '';
    final ra = widget.remainingForDocno(da);
    final rb = widget.remainingForDocno(db);
    final oa = widget.isOverdueForDocno(da) && ra > 0;
    final ob = widget.isOverdueForDocno(db) && rb > 0;
    if (oa != ob) return oa ? -1 : 1;

    switch (_sort) {
      case RepayLoanDocSort.remainingDesc:
        if (ra != rb) return rb.compareTo(ra);
        return da.compareTo(db);
      case RepayLoanDocSort.dueDateAsc:
        final va = _dueDayOnly(a);
        final vb = _dueDayOnly(b);
        if (va == null && vb == null) return da.compareTo(db);
        if (va == null) return 1;
        if (vb == null) return -1;
        final cmp = va.compareTo(vb);
        if (cmp != 0) return cmp;
        return da.compareTo(db);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final maxH = MediaQuery.sizeOf(context).height * 0.62;
    final query = _search.text.trim().toLowerCase();
    final rows = widget.loanRows.where((row) {
      final docno = row['docno']?.toString() ?? '';
      final borrower = row['borrower']?.toString().toLowerCase() ?? '';
      final match = query.isEmpty ||
          docno.toLowerCase().contains(query) ||
          borrower.contains(query);
      if (!match) return false;
      final remain = widget.remainingForDocno(docno);
      switch (_filter) {
        case RepayLoanDocFilter.all:
          return true;
        case RepayLoanDocFilter.outstanding:
          return remain > 0;
        case RepayLoanDocFilter.upcoming7Days:
          return _isDueSoonWithin7Days(row);
        case RepayLoanDocFilter.overdue:
          return remain > 0 && widget.isOverdueForDocno(docno);
      }
    }).toList();

    rows.sort(_compareRows);

    return SafeArea(
      child: SizedBox(
        height: maxH,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      TransactionUiText.repayLoanPickerTitle,
                      style: TextStyle(
                        fontFamily: _fontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: c.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AppDropdownField<RepayLoanDocFilter>(
                label: TransactionUiText.repayLoanPickerFilterLabel,
                value: _filter,
                items: const [
                  AppDropdownItem(
                    value: RepayLoanDocFilter.all,
                    label: TransactionUiText.repayLoanFilterAll,
                  ),
                  AppDropdownItem(
                    value: RepayLoanDocFilter.outstanding,
                    label: TransactionUiText.repayLoanFilterOutstandingOnly,
                  ),
                  AppDropdownItem(
                    value: RepayLoanDocFilter.upcoming7Days,
                    label: TransactionUiText.repayLoanFilterDueSoon7Days,
                  ),
                  AppDropdownItem(
                    value: RepayLoanDocFilter.overdue,
                    label: TransactionUiText.repayLoanFilterOverdueOnly,
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _filter = v);
                },
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AppDropdownField<RepayLoanDocSort>(
                label: TransactionUiText.repayLoanPickerSortLabel,
                value: _sort,
                items: const [
                  AppDropdownItem(
                    value: RepayLoanDocSort.dueDateAsc,
                    label: TransactionUiText.repayLoanPickerSortDueDateAsc,
                  ),
                  AppDropdownItem(
                    value: RepayLoanDocSort.remainingDesc,
                    label: TransactionUiText.repayLoanPickerSortRemainingDesc,
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _sort = v);
                },
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AppInput(
                hint: TransactionUiText.repayLoanPickerSearchHint,
                controller: _search,
                action: const AppInputAction.text(),
                prefixIcon: Icon(Icons.search_rounded, color: c.textSecondary),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          widget.loanRows.isEmpty
                              ? TransactionUiText.repayLoanPickerNoLoansInDb
                              : TransactionUiText.repayLoanPickerEmpty,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: _fontFamily,
                            color: c.textSecondary,
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: rows.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: c.cardBorder),
                      itemBuilder: (context, i) {
                        final row = rows[i];
                        final docno = row['docno']?.toString() ?? '';
                        final borrower = row['borrower']?.toString() ?? '-';
                        final remain = widget.remainingForDocno(docno);
                        final dueRaw = row['duedate']?.toString() ?? '';
                        final overdue =
                            widget.isOverdueForDocno(docno) && remain > 0;
                        final dueSoon = !overdue && _isDueSoonWithin7Days(row);
                        final selected = widget.initialDocno != null &&
                            widget.initialDocno == docno;
                        return ListTile(
                          selected: selected,
                          title: Text(
                            docno,
                            style: TextStyle(
                              fontFamily: _fontFamily,
                              fontWeight: FontWeight.w700,
                              color: c.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            TransactionUiText.repayLoanPickerRowSubtitle(
                              borrower: borrower,
                              dueDisplay: _formatDateBrief(dueRaw),
                              remaining: remain.toStringAsFixed(2),
                            ),
                            style: TextStyle(
                              fontFamily: _fontFamily,
                              fontSize: 12,
                              color: c.textSecondary,
                              height: 1.35,
                            ),
                          ),
                          trailing: overdue
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: c.expenseRed.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    TransactionUiText.loanOverdueBadge,
                                    style: TextStyle(
                                      fontFamily: _fontFamily,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: c.expenseRed,
                                    ),
                                  ),
                                )
                              : dueSoon
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            c.loanAmber.withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        TransactionUiText.loanDueSoonBadge,
                                        style: TextStyle(
                                          fontFamily: _fontFamily,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: c.loanAmber,
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      Icons.chevron_right_rounded,
                                      color: c.textHint,
                                    ),
                          onTap: () =>
                              Navigator.pop(context, row['id']?.toString() ?? ''),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
