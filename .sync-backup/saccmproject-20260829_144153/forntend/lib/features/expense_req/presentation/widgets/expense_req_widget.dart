import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saccm/features/expense_req/presentation/pages/expense_req_list_page.dart';
import 'package:saccm/features/expense_req/presentation/providers/expense_req_provider.dart';

/// หน้าใบขอเบิก — เมนูหลักแยก (ไม่ใช้แท็บในเบิกเงิน)
class ExpenseReqWidget extends StatelessWidget {
  const ExpenseReqWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ExpenseReqProvider(),
      child: const ExpenseReqListPage(embeddedInHome: true),
    );
  }
}
