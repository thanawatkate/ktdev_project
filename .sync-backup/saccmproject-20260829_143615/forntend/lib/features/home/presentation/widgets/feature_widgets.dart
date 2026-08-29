import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saccm/features/expense/presentation/pages/expense_list_page.dart';
import 'package:saccm/features/expense/presentation/providers/expense_provider.dart';
import 'package:saccm/features/income/presentation/providers/income_provider.dart';
import 'package:saccm/features/income/presentation/pages/income_list_page.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/features/loan/presentation/pages/loan/loan_list_page.dart';
import 'package:saccm/features/loan/presentation/pages/loan_management_page.dart';
import 'package:saccm/features/loan/presentation/pages/repay_loan/repay_loan_list_page.dart';
import 'package:saccm/features/loan/presentation/providers/loan_provider.dart';
import 'package:saccm/features/loan/presentation/providers/repay_loan_provider.dart';
import 'package:saccm/providers/customTable/custom_table_providers.dart';
import 'package:saccm/providers/customTable/select_table_provider.dart';

/// คำนวณ inputWidth ตาม breakpoint
double inputWidthFor(double screenWidth) {
  if (screenWidth < 600) return screenWidth;
  if (screenWidth < 900) return screenWidth / 2;
  return screenWidth / 4;
}

class IncomeWidget extends StatelessWidget {
  const IncomeWidget({super.key, required this.inputWidth});
  final double inputWidth;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => IncomeProvider(monneyType: [], incomeType: [])),
        ChangeNotifierProvider(create: (_) => CustomTableProvider(rowData: [])),
        ChangeNotifierProvider(create: (_) => SelectionModel(0, [])),
      ],
      child: IncomeList(inputWidth: inputWidth, embeddedInHome: true),
    );
  }
}

class ExpenseWidget extends StatelessWidget {
  const ExpenseWidget({super.key, required this.inputWidth});
  final double inputWidth;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => CustomTableProvider(rowData: [])),
        ChangeNotifierProvider(create: (_) => SelectionModel(0, [])),
      ],
      child: ExpenseList(inputWidth: inputWidth, embeddedInHome: true),
    );
  }
}

class LoanWidget extends StatelessWidget {
  const LoanWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LoanProvider()),
        ChangeNotifierProvider(create: (_) => RepayLoanProvider()),
      ],
      child: const DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Material(
              child: TabBar(
                tabs: [
                  Tab(text: 'ยืมเงิน'),
                  Tab(text: 'คืนเงินยืม'),
                  Tab(text: TransactionUiText.loanManagementTabLabel),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  LoanListPage(embeddedInHome: true),
                  RepayLoanListPage(embeddedInHome: true),
                  LoanManagementPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
