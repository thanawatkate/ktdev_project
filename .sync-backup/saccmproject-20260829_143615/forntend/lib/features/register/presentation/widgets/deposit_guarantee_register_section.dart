import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'deposit_guarantee_tab.dart';

@Deprecated('Use DepositGuaranteeRegisterTab instead.')
class DepositGuaranteeRegisterSection extends StatelessWidget {
  const DepositGuaranteeRegisterSection({super.key, required this.dio});

  final Dio dio;

  @override
  Widget build(BuildContext context) => DepositGuaranteeRegisterTab(dio: dio);
}

/// แท็บทะเบียนเงินประกันสัญญา / ภาษีหัก ณ ที่จ่าย
///
/// มีแท็บย่อย: ทั้งหมด / ประกันสัญญา / ภาษีหัก ณ ที่จ่าย
class DepositGuaranteeRegisterTab extends StatefulWidget {
  const DepositGuaranteeRegisterTab({super.key, required this.dio});

  final Dio dio;

  @override
  State<DepositGuaranteeRegisterTab> createState() =>
      _DepositGuaranteeRegisterTabState();
}

class _DepositGuaranteeRegisterTabState
    extends State<DepositGuaranteeRegisterTab>
    with SingleTickerProviderStateMixin {
  late TabController _innerTab;

  @override
  void initState() {
    super.initState();
    _innerTab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _innerTab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _innerTab,
            isScrollable: true,
            tabs: const [
              Tab(text: TransactionUiText.registerDepositSubTabAll),
              Tab(text: TransactionUiText.registerDepositTypeContractGuarantee),
              Tab(text: TransactionUiText.registerDepositTypeWithholdingTax),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _innerTab,
            children: [
              DepositGuaranteeTab(dio: widget.dio),
              DepositGuaranteeTab(
                dio: widget.dio,
                fixedDepositType: 'contract_guarantee',
              ),
              DepositGuaranteeTab(
                dio: widget.dio,
                fixedDepositType: 'withholding_tax',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
