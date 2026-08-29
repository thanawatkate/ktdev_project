import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/features/auth/presentation/providers/simple_auth_provider.dart';
import 'package:saccm/features/budget_source/presentation/pages/budget_source_page.dart';
import 'package:saccm/features/cheque_account/presentation/pages/cheque_account_page.dart';
import 'package:saccm/features/expense_type/presentation/pages/expense_type_page.dart';
import 'package:saccm/features/income_type/presentation/pages/income_type_page.dart';
import 'package:saccm/features/income_type/presentation/providers/income_type_provider.dart';
import 'package:saccm/features/member/presentation/pages/member_page.dart';
import 'package:saccm/features/member/presentation/providers/member_provider.dart';
import 'package:saccm/features/party/presentation/pages/party_management_page.dart';
import 'package:saccm/features/prefix/presentation/pages/prefix_management_page.dart';
import 'package:saccm/features/register/presentation/pages/register_page.dart';
import 'package:saccm/features/setting/presentation/pages/audit/audit_log_page.dart';
import 'package:saccm/features/setting/presentation/pages/database/database_maintenance_page.dart';
import 'package:saccm/features/setting/presentation/pages/database/db_health_page.dart';
import 'package:saccm/features/setting/presentation/pages/security/pin_security_page.dart';
import 'package:saccm/features/appointment_order/presentation/pages/appointment_order_page.dart';
import 'package:saccm/features/fiscal_year_opening/presentation/pages/fiscal_year_opening_page.dart';
import 'package:saccm/features/license/license_mode.dart';
import 'package:saccm/features/license/presentation/pages/license_admin_page.dart';
import 'package:saccm/features/license/presentation/pages/license_info_page.dart';
import 'package:saccm/features/license/presentation/pages/product_plan_page.dart';
import 'package:saccm/features/setting/presentation/pages/general/school_profile_page.dart';
import 'package:saccm/features/setting/presentation/pages/system/doc_group_settings_page.dart';
import 'package:saccm/features/setting/presentation/pages/system/menu_configuration_page.dart';
import 'package:saccm/features/setting/presentation/pages/system/setting_default_page.dart';
import 'package:saccm/features/user/presentation/pages/user_management_page.dart';
import 'package:saccm/widgets/layout/embedded_home_scaffold.dart';

class SettingTab extends StatelessWidget {
  const SettingTab({
    super.key,
    this.embeddedInHome = false,
  });

  final bool embeddedInHome;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final auth = context.watch<SimpleAuthProvider>();
    final canUserAdmin = auth.can(PermissionKey.userAdminView);
    final canAuditLog = auth.can(PermissionKey.auditLogView);
    final canBudgetSource = auth.can(PermissionKey.budgetSourceView);
    final canMenuConfigure = auth.can(PermissionKey.menuConfigure);

    return EmbeddedHomeScaffold(
      embeddedInHome: embeddedInHome,
      backgroundColor: c.background,
      standaloneAppBar: AppBar(
        title: Text(
          TransactionUiText.settings,
          style: TextStyle(
            color: c.textPrimary,
            fontFamily: 'Kanit',
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: c.cardWhite,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: c.cardBorder),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding =
              constraints.maxWidth >= 900 ? AppTheme.sp24 : AppTheme.sp16;

          final foundationItems = <_Item>[
            _Item(
              icon: Icons.school_rounded,
              iconBg: c.iconBgIncome,
              iconColor: scheme.primary,
              title: TransactionUiText.schoolProfileTitle,
              subtitle: TransactionUiText.schoolProfileSubtitle,
              tooltip:
                  'ตั้งค่าชื่อโรงเรียน ที่ตั้ง และข้อมูลพื้นฐาน\nต้องกำหนดก่อนเริ่มใช้งานระบบ',
              onTap: () => _push(context, const SchoolProfilePage()),
            ),
            if (canUserAdmin)
              _Item(
                icon: Icons.manage_accounts_rounded,
                iconBg: c.iconBgIncome,
                iconColor: scheme.primary,
                title: TransactionUiText.systemUsers,
                subtitle: TransactionUiText.userAccountManage,
                tooltip:
                    'เพิ่ม แก้ไข และกำหนดสิทธิ์ผู้ใช้งานระบบ\nสำคัญมากสำหรับการควบคุมการเข้าถึง',
                onTap: () => _push(context, const UserManagementPage()),
              ),
            _Item(
              icon: Icons.pin_rounded,
              iconBg: c.iconBgExpense,
              iconColor: c.expenseRed,
              title: TransactionUiText.pinSecurityTitle,
              subtitle: TransactionUiText.pinSecurityMenuSubtitle,
              tooltip:
                  'ตั้ง PIN 6 หลักเพื่อล็อกหน้าจอ\nบันทึกใน setting table — ตั้งก่อนตรวจสุขภาพ DB',
              onTap: () => _push(context, const PinSecurityPage()),
            ),
          ];

          final peopleItems = <_Item>[
            _Item(
              icon: Icons.badge_outlined,
              iconBg: c.iconBgIncome,
              iconColor: scheme.primary,
              title: TransactionUiText.prefixManagementTitle,
              subtitle: TransactionUiText.prefixManagementSubtitle,
              tooltip: TransactionUiText.prefixManagementTooltip,
              onTap: () => _push(context, const PrefixManagementPage()),
            ),
            _Item(
              icon: Icons.groups_rounded,
              iconBg: c.iconBgLoan,
              iconColor: c.loanAmber,
              title: TransactionUiText.members,
              subtitle: TransactionUiText.cooperativeMembersManage,
              tooltip:
                  'member ถูก reference โดย expense, expensereq, loan\n→ ต้องสร้างก่อน app_menu (MenuConfig)',
              onTap: () => _push(
                context,
                ChangeNotifierProvider(
                  create: (_) => MemberProvider(prefix: []),
                  child: const Member(),
                ),
              ),
            ),
            _Item(
              icon: Icons.people_alt_rounded,
              iconBg: c.iconBgIncome,
              iconColor: scheme.primary,
              title: TransactionUiText.partyPayeePayerTitle,
              subtitle: TransactionUiText.partyPayeePayerSubtitle,
              tooltip:
                  'party ถูก FK โดย income และ expense (refparty)\n→ ต้องมีก่อนบันทึก record รายรับ/รายจ่าย',
              onTap: () => _push(context, const PartyManagementPage()),
            ),
          ];

          final financeItems = <_Item>[
            if (canBudgetSource)
              _Item(
                icon: Icons.account_balance_outlined,
                iconBg: c.iconBgLoan,
                iconColor: c.loanAmber,
                title: TransactionUiText.budgetSourceTitle,
                subtitle: TransactionUiText.budgetSourceManage,
                tooltip:
                    'budgetsource ใช้ผูกกับหมวดรายรับได้\n→ ตั้งค่าไว้ก่อนจะจัดการหมวดรายรับได้สะดวกขึ้น (แต่ไม่บังคับ)',
                onTap: () => _push(context, const BudgetSourcePage()),
              ),
            _Item(
              icon: Icons.account_balance_wallet_rounded,
              iconBg: c.iconBgExpense,
              iconColor: c.expenseRed,
              title: TransactionUiText.incomeTypeTitle,
              subtitle: TransactionUiText.incomeTypeManage,
              tooltip:
                  'incometype รองรับการผูก budgetsource ใน dropdown (ถ้ามี)\nและถูก FK โดย incomesub, expensesub, loansub ฯลฯ — บัญชีธนาคารตั้งที่แหล่งเงิน',
              onTap: () => _push(
                context,
                ChangeNotifierProvider(
                  create: (_) => IncomeTypeProvider(
                    moneyType: [],
                    sourceGroups: [],
                  ),
                  child: const IncomeType(),
                ),
              ),
            ),
            _Item(
              icon: Icons.receipt_long_rounded,
              iconBg: c.iconBgExpense,
              iconColor: c.expenseRed,
              title: TransactionUiText.expenseTypeTitle,
              subtitle: TransactionUiText.expenseTypeManageSubtitle,
              tooltip:
                  'กำหนดประเภทรายจ่าย เช่น ค่าวัสดุ ค่าใช้สอย ค่าครุภัณฑ์\nตามระเบียบพัสดุ พ.ศ. 2560 — ถูก FK โดย expense_sub',
              onTap: () => _push(context, const ExpenseTypePage()),
            ),
            _Item(
              icon: Icons.compare_arrows_rounded,
              iconBg: c.iconBgLoan,
              iconColor: c.loanAmber,
              title: TransactionUiText.fiscalYearOpeningTitle,
              subtitle: TransactionUiText.fiscalYearOpeningSubtitle,
              tooltip: TransactionUiText.fiscalYearOpeningTooltip,
              onTap: () => _push(context, const FiscalYearOpeningPage()),
            ),
          ];

          final documentItems = <_Item>[
            _Item(
              icon: Icons.payments_outlined,
              iconBg: c.iconBgLoan,
              iconColor: c.loanAmber,
              title: TransactionUiText.chequeAccountPageTitle,
              subtitle: TransactionUiText.chequeAccountManageSubtitle,
              tooltip:
                  'เล่มเช็ค/บัญชีที่ใช้สั่งจ่าย — อ้างอิงเมื่อบันทึกรายจ่ายแบบเช็ค\nและทะเบียนคุมจ่ายเช็ค',
              onTap: () => _push(context, const ChequeAccountPage()),
            ),
            _Item(
              icon: Icons.confirmation_number_outlined,
              iconBg: c.iconBgIncome,
              iconColor: scheme.primary,
              title: TransactionUiText.receiptBookSettingShortcutTitle,
              subtitle: TransactionUiText.receiptBookSettingShortcutSubtitle,
              tooltip:
                  'เพิ่มเล่มใบเสร็จและช่วงเลขที่ก่อนออกใบเสร็จจากรายการรับเงิน',
              onTap: () =>
                  _push(context, const RegisterPage(initialTabIndex: 5)),
            ),
            _Item(
              icon: Icons.assignment_ind_outlined,
              iconBg: c.iconBgLoan,
              iconColor: c.loanAmber,
              title: TransactionUiText.appointmentOrderPageTitle,
              subtitle: TransactionUiText.appointmentOrderMenuSubtitle,
              tooltip:
                  'บันทึกคำสั่งแต่งตั้งกรรมการเก็บรักษาเงินและเจ้าหน้าที่\nข้อมูลเก็บในเครื่อง (SQLite)',
              onTap: () => _push(context, const AppointmentOrderPage()),
            ),
            if (context.select<SimpleAuthProvider, bool>(
              (provider) => provider.can(PermissionKey.docGroupConfigure),
            ))
              _Item(
                icon: Icons.pin_outlined,
                iconBg: c.iconBgIncome,
                iconColor: scheme.primary,
                title: TransactionUiText.docGroupSettingsTitle,
                subtitle: TransactionUiText.docGroupSettingsSubtitle,
                tooltip: 'ตั้งรหัสนำหน้าและรูปแบบเลขรันของเอกสารหลักในระบบ',
                onTap: () => _push(context, const DocGroupSettingsPage()),
              ),
          ];

          final maintenanceItems = <_Item>[
            _Item(
              icon: Icons.tune_rounded,
              iconBg: c.iconBgIncome,
              iconColor: scheme.primary,
              title: TransactionUiText.defaults,
              subtitle: TransactionUiText.setDefaultSystem,
              tooltip:
                  'กำหนดค่าพื้นฐานของระบบ เช่น ปีการศึกษา\nรูปแบบวันที่ และการแสดงผลต่างๆ',
              onTap: () => _push(context, const SettingDefault()),
            ),
            if (canMenuConfigure)
              _Item(
                icon: Icons.menu_open_rounded,
                iconBg: c.iconBgLoan,
                iconColor: c.loanAmber,
                title: TransactionUiText.menuConfigurationTitle,
                subtitle: TransactionUiText.menuConfigurationSubtitle,
                tooltip:
                    'app_menu refs ตัวเอง (self-ref เท่านั้น)\nไม่มี FK ต่างหาก — มาหลัง member',
                onTap: () => _push(context, const MenuConfigurationPage()),
              ),
            _Item(
              icon: Icons.health_and_safety_rounded,
              iconBg: c.iconBgLoan,
              iconColor: c.loanAmber,
              title: 'ตรวจสุขภาพฐานข้อมูล',
              subtitle: 'ตรวจ foreign key และ orphan references',
              tooltip:
                  'ตรวจสอบ FK และ orphan references\nทำหลังตั้งค่าเสร็จ ก่อนสำรองข้อมูล',
              onTap: () => _push(context, const DbHealthPage()),
            ),
            _Item(
              icon: Icons.storage_rounded,
              iconBg: c.iconBgIncome,
              iconColor: scheme.primary,
              title: TransactionUiText.databaseMaintenanceTitle,
              subtitle: TransactionUiText.databaseMaintenanceSubtitle,
              tooltip: TransactionUiText.databaseMaintenanceTooltip,
              onTap: () => _push(context, const DatabaseMaintenancePage()),
            ),
            if (canAuditLog)
              _Item(
                icon: Icons.history_rounded,
                iconBg: c.iconBgExpense,
                iconColor: c.expenseRed,
                title: TransactionUiText.auditLogs,
                subtitle: TransactionUiText.auditLogsSubtitle,
                tooltip:
                    'ตรวจสอบประวัติการใช้งานและบันทึกกิจกรรม\nของผู้ใช้ทุกคนในระบบ',
                onTap: () => _push(context, const AuditLogPage()),
              ),
          ];

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              AppTheme.sp12,
              horizontalPadding,
              AppTheme.sp16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPageHeader(context, c),
                const SizedBox(height: AppTheme.sp8),
                Text(
                  TransactionUiText.systemSettingsSchoolBasicsHint,
                  style: TextStyle(
                    color: c.textPrimary.withValues(alpha: 0.62),
                    fontSize: 12,
                    height: 1.35,
                    fontFamily: 'Kanit',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppTheme.sp8),
                FutureBuilder<bool>(
                  future: LicenseMode.isLicensed(),
                  builder: (context, snap) {
                    final registered = snap.data == true;
                    return _buildSectionCard(
                      context: context,
                      width: double.infinity,
                      sectionTitle: TransactionUiText.settingsStepFoundation,
                      items: [
                        ..._licenseSettingItems(
                          registered: registered,
                          auth: auth,
                          c: c,
                          scheme: scheme,
                          onPush: (page) => _push(context, page),
                        ),
                        ...foundationItems,
                      ],
                      colors: c,
                    );
                  },
                ),
                const SizedBox(height: AppTheme.sp8),
                _buildSectionCard(
                  context: context,
                  width: double.infinity,
                  sectionTitle: TransactionUiText.settingsStepPeople,
                  items: peopleItems,
                  colors: c,
                ),
                const SizedBox(height: AppTheme.sp8),
                _buildSectionCard(
                  context: context,
                  width: double.infinity,
                  sectionTitle: TransactionUiText.settingsStepFinance,
                  items: financeItems,
                  colors: c,
                ),
                const SizedBox(height: AppTheme.sp8),
                _buildSectionCard(
                  context: context,
                  width: double.infinity,
                  sectionTitle: TransactionUiText.settingsStepDocuments,
                  items: documentItems,
                  colors: c,
                ),
                const SizedBox(height: AppTheme.sp8),
                _buildSectionCard(
                  context: context,
                  width: double.infinity,
                  sectionTitle: TransactionUiText.settingsStepMaintenance,
                  items: maintenanceItems,
                  colors: c,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Page header ──────────────────────────────────────────────────
  Widget _buildPageHeader(BuildContext context, AppColors c) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.sp12,
        vertical: AppTheme.sp12,
      ),
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r12),
        border: Border.all(color: c.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.iconBgIncome,
              borderRadius: BorderRadius.circular(AppTheme.r12),
            ),
            child:
                Icon(Icons.settings_rounded, color: scheme.primary, size: 20),
          ),
          const SizedBox(width: AppTheme.sp12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  TransactionUiText.systemSettings,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Kanit',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  TransactionUiText.manageDataAndSettings,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12,
                    fontFamily: 'Kanit',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section label ────────────────────────────────────────────────
  Widget _sectionLabel(BuildContext context, String label) {
    final c = AppColors.of(context);
    return Text(
      label,
      style: TextStyle(
        color: c.textPrimary.withValues(alpha: 0.78),
        fontSize: 12,
        fontWeight: FontWeight.w700,
        fontFamily: 'Kanit',
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required double width,
    required String sectionTitle,
    required List<_Item> items,
    required AppColors colors,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(context, sectionTitle),
          const SizedBox(height: AppTheme.sp4),
          _menuCard(context, items, colors),
        ],
      ),
    );
  }

  // ─── Menu card ────────────────────────────────────────────────────
  Widget _menuCard(BuildContext context, List<_Item> items, AppColors c) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.sp4),
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r12),
        border: Border.all(color: c.cardBorder, width: 1),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth >= 1100
              ? 4
              : constraints.maxWidth >= 760
                  ? 3
                  : 2;
          const crossSpacing = AppTheme.sp4;
          final tileWidth =
              (constraints.maxWidth - ((crossAxisCount - 1) * crossSpacing)) /
                  crossAxisCount;
          final childAspectRatio = tileWidth / 96;

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: crossSpacing,
              mainAxisSpacing: crossSpacing,
              childAspectRatio: childAspectRatio,
            ),
            itemBuilder: (context, index) =>
                _menuItem(context, index + 1, items[index], c),
          );
        },
      ),
    );
  }

  Widget _menuItem(BuildContext context, int number, _Item item, AppColors c) {
    return Tooltip(
      message: item.tooltip,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(AppTheme.r8),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.sp4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.r8),
            border: Border.all(
              color: Color.lerp(c.cardBorder, c.textHint, 0.22)!,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: item.iconBg,
                      borderRadius: BorderRadius.circular(AppTheme.r8),
                    ),
                    child: Icon(item.icon, color: item.iconColor, size: 16),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: c.textHint.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$number',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary.withValues(alpha: 0.72),
                          fontFamily: 'Kanit',
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: c.textSecondary.withValues(alpha: 0.85),
                    size: 16,
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.sp4),
              Text(
                item.title,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Kanit',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              if (item.subtitle != null)
                Text(
                  item.subtitle!,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 10,
                    fontFamily: 'Kanit',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

List<_Item> _licenseSettingItems({
  required bool registered,
  required SimpleAuthProvider auth,
  required AppColors c,
  required ColorScheme scheme,
  required void Function(Widget page) onPush,
}) {
  if (!registered) {
    return [
      _Item(
        icon: Icons.layers_outlined,
        iconBg: c.iconBgIncome,
        iconColor: scheme.primary,
        title: TransactionUiText.productPlanTitle,
        subtitle: TransactionUiText.productPlanSettingSubtitle,
        tooltip: 'ดูสถานะทดลองใช้ แพ็กเกจออฟไลน์/ออนไลน์ และลงทะเบียนด้วยรหัส',
        onTap: () => onPush(const ProductPlanPage()),
      ),
    ];
  }

  final items = <_Item>[
    _Item(
      icon: Icons.layers_outlined,
      iconBg: c.iconBgIncome,
      iconColor: scheme.primary,
      title: TransactionUiText.productPlanTitle,
      subtitle: TransactionUiText.productPlanSettingSubtitle,
      tooltip: 'ดูแพ็กเกจและสถานะปัจจุบัน',
      onTap: () => onPush(const ProductPlanPage()),
    ),
    _Item(
      icon: Icons.verified_user_outlined,
      iconBg: c.iconBgIncome,
      iconColor: scheme.primary,
      title: TransactionUiText.licenseInfoTitle,
      subtitle: TransactionUiText.licenseInfoSubtitle,
      tooltip: 'ดูรหัสโรงเรียน จำนวนเครื่องที่ลงทะเบียน และสถานะซิงก์',
      onTap: () => onPush(const LicenseInfoPage()),
    ),
  ];
  if (auth.isAdmin) {
    items.add(
      _Item(
        icon: Icons.vpn_key_rounded,
        iconBg: c.iconBgExpense,
        iconColor: c.expenseRed,
        title: TransactionUiText.licenseAdminTitle,
        subtitle: TransactionUiText.licenseAdminSubtitle,
        tooltip: 'สร้าง/ยกเลิกรหัสเปิดใช้งาน — สำหรับผู้ให้บริการ server กลาง',
        onTap: () => onPush(const LicenseAdminPage()),
      ),
    );
  }
  return items;
}

// ─── Data model ───────────────────────────────────────────────────────────────
class _Item {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final String tooltip;
  final VoidCallback onTap;

  const _Item({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.tooltip,
    required this.onTap,
  });
}
