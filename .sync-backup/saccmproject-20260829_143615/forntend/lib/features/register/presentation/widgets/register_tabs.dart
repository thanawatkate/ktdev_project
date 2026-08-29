import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/widgets/widgets.dart';

import 'agency_deposit_register_tab.dart';
import 'cheque_register_tab.dart';
import 'current_account_register_tab.dart';
import 'deposit_guarantee_register_section.dart';
import 'evidence_register_tab.dart';
import 'loan_register_tab.dart';
import 'offbudget_register_tab.dart';
import 'receipt_book_tab.dart';
import 'treasury_remit_register_tab.dart';
import 'voucher_register_tab.dart';

/// รวมรายการแท็บทะเบียนคุมทั้งหมดไว้ในที่เดียว
/// เพื่อให้ `RegisterPage` เหลือหน้าที่ประกอบ scaffold เท่านั้น
class RegisterTabs {
  const RegisterTabs._();

  static const items = [
    RegisterTabInfo(
      index: 0,
      label: TransactionUiText.registerOffBudgetTabLabel,
      groupLabel: TransactionUiText.registerMenuGroupMoney,
      description: TransactionUiText.registerDescOffBudget,
      icon: Icons.account_balance_wallet_outlined,
    ),
    RegisterTabInfo(
      index: 6,
      label: TransactionUiText.registerDepositGuaranteeTabLabel,
      groupLabel: TransactionUiText.registerMenuGroupMoney,
      description: TransactionUiText.registerDescDepositGuarantee,
      icon: Icons.verified_user_outlined,
    ),
    RegisterTabInfo(
      index: 1,
      label: TransactionUiText.registerEvidenceTabLabel,
      groupLabel: TransactionUiText.registerMenuGroupDocument,
      description: TransactionUiText.registerDescEvidence,
      icon: Icons.assignment_outlined,
    ),
    RegisterTabInfo(
      index: 2,
      label: TransactionUiText.registerVoucherTabLabel,
      groupLabel: TransactionUiText.registerMenuGroupDocument,
      description: TransactionUiText.registerDescVoucher,
      icon: Icons.receipt_long_outlined,
    ),
    RegisterTabInfo(
      index: 3,
      label: TransactionUiText.registerChequeTabLabel,
      groupLabel: TransactionUiText.registerMenuGroupDocument,
      description: TransactionUiText.registerDescCheque,
      icon: Icons.payments_outlined,
    ),
    RegisterTabInfo(
      index: 4,
      label: TransactionUiText.registerLoanTabLabel,
      groupLabel: TransactionUiText.registerMenuGroupControl,
      description: TransactionUiText.registerDescLoan,
      icon: Icons.handshake_outlined,
    ),
    RegisterTabInfo(
      index: 5,
      label: TransactionUiText.registerReceiptBookTabLabel,
      groupLabel: TransactionUiText.registerMenuGroupControl,
      description: TransactionUiText.registerDescReceiptBook,
      icon: Icons.confirmation_number_outlined,
    ),
    RegisterTabInfo(
      index: 7,
      label: TransactionUiText.registerCurrentAccountTabLabel,
      groupLabel: TransactionUiText.registerMenuGroupControl,
      description: TransactionUiText.registerDescCurrentAccount,
      icon: Icons.account_balance_outlined,
    ),
    RegisterTabInfo(
      index: 8,
      label: TransactionUiText.registerAgencyDepositTabLabel,
      groupLabel: TransactionUiText.registerMenuGroupControl,
      description: TransactionUiText.registerDescAgencyDeposit,
      icon: Icons.business_outlined,
    ),
    RegisterTabInfo(
      index: 9,
      label: TransactionUiText.registerTreasuryRemitTabLabel,
      groupLabel: TransactionUiText.registerMenuGroupControl,
      description: TransactionUiText.registerDescTreasuryRemit,
      icon: Icons.upload_file_outlined,
    ),
  ];

  static const groupLabels = [
    TransactionUiText.registerMenuGroupMoney,
    TransactionUiText.registerMenuGroupDocument,
    TransactionUiText.registerMenuGroupControl,
  ];

  static int get count => items.length;

  static RegisterTabInfo infoAt(int index) {
    return items.firstWhere(
      (item) => item.index == index,
      orElse: () => items.first,
    );
  }
}

class RegisterTabInfo {
  const RegisterTabInfo({
    required this.index,
    required this.label,
    required this.groupLabel,
    required this.description,
    required this.icon,
  });

  final int index;
  final String label;
  final String groupLabel;
  final String description;
  final IconData icon;
}

class RegisterTabBar extends StatelessWidget {
  const RegisterTabBar({
    super.key,
    required this.controller,
  });

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final selectedIndex =
            controller.index.clamp(0, RegisterTabs.count - 1).toInt();
        final currentTab = RegisterTabs.infoAt(selectedIndex);
        final groupRegisters = RegisterTabs.items
            .where((item) => item.groupLabel == currentTab.groupLabel)
            .toList();

        final groupField = AppDropdownField<String>(
          label: TransactionUiText.registerSelectGroupLabel,
          value: currentTab.groupLabel,
          density: AppDropdownDensity.compact,
          prefixIcon: const Icon(Icons.folder_outlined),
          items: RegisterTabs.groupLabels
              .map(
                (label) => AppDropdownItem<String>(
                  value: label,
                  label: label,
                  leadingIcon:
                      Icon(Icons.folder_open_outlined, size: 18, color: c.navy),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null || value == currentTab.groupLabel) return;
            final firstInGroup = RegisterTabs.items.firstWhere(
              (item) => item.groupLabel == value,
              orElse: () => RegisterTabs.items.first,
            );
            controller.animateTo(firstInGroup.index);
          },
        );

        final registerField = AppDropdownField<int>(
          label: TransactionUiText.registerSelectRegisterLabel,
          value: selectedIndex,
          density: AppDropdownDensity.compact,
          prefixIcon: const Icon(Icons.fact_check_outlined),
          items: groupRegisters
              .map(
                (item) => AppDropdownItem<int>(
                  value: item.index,
                  label: item.label,
                  leadingIcon: Icon(item.icon, size: 18, color: c.navy),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) controller.animateTo(value);
          },
        );

        return Material(
          color: c.cardWhite,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stackFields = constraints.maxWidth < 460;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (stackFields) ...[
                      groupField,
                      const SizedBox(height: AppTheme.sp8),
                      registerField,
                    ] else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(flex: 4, child: groupField),
                          const SizedBox(width: AppTheme.sp8),
                          Expanded(flex: 5, child: registerField),
                        ],
                      ),
                    const SizedBox(height: AppTheme.sp8),
                    RegisterSelectedTabHint(currentIndex: selectedIndex),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class RegisterSelectedTabHint extends StatelessWidget {
  const RegisterSelectedTabHint({
    super.key,
    required this.currentIndex,
  });

  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final currentTab = RegisterTabs.infoAt(currentIndex);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.sp12,
        vertical: AppTheme.sp8,
      ),
      decoration: BoxDecoration(
        color: c.navy.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.navy.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(currentTab.icon, size: 18, color: c.navy),
          ),
          const SizedBox(width: AppTheme.sp8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${TransactionUiText.registerCurrentRegisterPrefix}: '
                  '${currentTab.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontFamily: 'Kanit',
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: AppTheme.sp4),
                Text(
                  currentTab.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontFamily: 'Kanit',
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.sp8),
          Text(
            '${TransactionUiText.registerSequencePrefix} ${currentIndex + 1} '
            '${TransactionUiText.registerSequenceMiddle} ${RegisterTabs.count}',
            style: TextStyle(
              color: c.navy,
              fontFamily: 'Kanit',
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class RegisterTabView extends StatelessWidget {
  const RegisterTabView({
    super.key,
    required this.controller,
    required this.dio,
  });

  final TabController controller;
  final Dio dio;

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      controller: controller,
      children: [
        const OffBudgetRegisterTab(),
        const EvidenceRegisterTab(),
        const VoucherRegisterTab(),
        ChequeRegisterTab(dio: dio),
        const LoanRegisterTab(),
        ReceiptBookRegisterTab(dio: dio),
        DepositGuaranteeRegisterTab(dio: dio),
        const CurrentAccountRegisterTab(),
        const AgencyDepositRegisterTab(),
        const TreasuryRemitRegisterTab(),
      ],
    );
  }
}
