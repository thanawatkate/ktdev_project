// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/local_data_source/app_menu_local_data_source.dart';
import 'package:saccm/core/services/expense_sync_warning_service.dart';
import 'package:saccm/core/services/menu_refresh_bus.dart';
import 'package:saccm/core/services/menu_service.dart';
import 'package:saccm/core/services/network_info_service.dart';
import 'package:saccm/core/utils/single_open_navigation.dart';
import 'package:saccm/core/window/desktop_window_chrome.dart';
import 'package:saccm/features/appointment_order/presentation/pages/appointment_order_page.dart';
import 'package:saccm/features/budget_source/presentation/pages/budget_source_page.dart';
import 'package:saccm/features/cheque_account/presentation/pages/cheque_account_page.dart';
import 'package:saccm/features/expense_type/presentation/pages/expense_type_page.dart';
import 'package:saccm/features/fiscal_year_opening/presentation/pages/fiscal_year_opening_page.dart';
import 'package:saccm/features/license/license_mode.dart';
import 'package:saccm/features/license/product_tier.dart';
import 'package:saccm/features/member/presentation/pages/member_page.dart';
import 'package:saccm/features/member/presentation/providers/member_provider.dart';
import 'package:saccm/features/party/presentation/pages/party_management_page.dart';
import 'package:saccm/features/setting/data/datasources/school_profile_local_data_source.dart';
import 'package:saccm/features/setting/domain/entities/school_profile.dart';
import 'package:saccm/features/setting/presentation/pages/database/database_maintenance_page.dart';
import 'package:saccm/features/setting/presentation/pages/general/school_profile_page.dart';
import 'package:saccm/features/setting/presentation/pages/system/doc_group_settings_page.dart';
import 'package:saccm/features/setting/presentation/pages/system/menu_configuration_page.dart';
import 'package:saccm/features/income_type/presentation/pages/income_type_page.dart';
import 'package:saccm/features/income_type/presentation/providers/income_type_provider.dart';
import 'package:saccm/features/auth/presentation/providers/simple_auth_provider.dart';
import 'package:saccm/features/home/presentation/pages/home_nav_index.dart';
import 'package:saccm/features/home/presentation/pages/home_router.dart';
import 'package:saccm/features/user/presentation/pages/user_management_page.dart';
import 'package:saccm/widgets/dialog/form_leave_confirm_dialog.dart';
import 'package:saccm/widgets/offline_status_widgets.dart';
import 'package:saccm/widgets/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Navigation items ────────────────────────────────────────────────────────

class _NavItem {
  final String label;
  final IconData icon;

  const _NavItem({required this.label, required this.icon});
}

class _NavSection {
  final String title;
  final List<int> indexes;

  const _NavSection({required this.title, required this.indexes});
}

class _MenuSearchEntry {
  final int navIndex;
  final String label;
  final String sectionTitle;
  final IconData icon;

  const _MenuSearchEntry({
    required this.navIndex,
    required this.label,
    required this.sectionTitle,
    required this.icon,
  });
}

// ─── HomeScreen ───────────────────────────────────────────────────────────────

/// Entry point สำหรับ route /home — ไม่ซ้อน MaterialApp
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const _HomeScaffold();
}

// ─── _HomeScaffold ────────────────────────────────────────────────────────────

class _HomeScaffold extends StatefulWidget {
  const _HomeScaffold();

  @override
  State<_HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends State<_HomeScaffold> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  GlobalKey<NavigatorState> _contentNavigatorKey = GlobalKey<NavigatorState>();
  static const _sidebarCollapsedPrefKey = 'home.sidebar.collapsed';
  static const _lastSelectedIndexPrefKey = 'home.selected.index';
  final Map<int, FocusNode> _sidebarItemFocusNodes = {};
  final MenuService _menuService = MenuService();
  NavMenuSnapshot _menu = NavMenuSnapshot.fallback();
  int _selectedIndex = HomeNavIndex.home;
  int? _registerInitialTabIndex;
  int? _reportsInitialTabIndex;
  bool _isSidebarCollapsed = false;
  int? _hoveredIndex;
  int? _focusedIndex;
  bool _draggingTitlebar = false;

  void _onMenuRefreshFromBus() => unawaited(_reloadNavMenu());

  @override
  void initState() {
    super.initState();
    MenuRefreshBus.register(_onMenuRefreshFromBus);
    unawaited(_loadHomePreferences());
    unawaited(_reloadNavMenu());
  }

  Future<void> _reloadNavMenu() async {
    final snap = await _menuService.loadMenuSnapshot();
    if (!mounted) return;
    setState(() => _menu = snap);
  }

  _NavItem? _slotItem(int navIndex) {
    final slot = _menu.slotsByNavIndex[navIndex];
    if (slot == null) return null;
    return _NavItem(label: slot.label, icon: slot.icon);
  }

  @override
  void dispose() {
    MenuRefreshBus.unregister(_onMenuRefreshFromBus);
    for (final node in _sidebarItemFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _loadHomePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSidebar = prefs.getBool(_sidebarCollapsedPrefKey);
    final savedIndex = prefs.getInt(_lastSelectedIndexPrefKey);
    if (!mounted) return;
    setState(() {
      if (savedSidebar != null) {
        _isSidebarCollapsed = savedSidebar;
      }
      if (_isRestorableNavIndex(savedIndex)) {
        _selectedIndex = savedIndex!;
      }
    });
  }

  Future<void> _toggleSidebarCollapsed() async {
    final next = !_isSidebarCollapsed;
    setState(() => _isSidebarCollapsed = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sidebarCollapsedPrefKey, next);
  }

  bool _isRestorableNavIndex(int? index) {
    return index != null && index != _logoutIndex;
  }

  Future<void> _saveSelectedIndex(int index) async {
    if (!_isRestorableNavIndex(index)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSelectedIndexPrefKey, index);
  }

  FocusNode _focusNodeForSidebarIndex(int index) {
    return _sidebarItemFocusNodes.putIfAbsent(
      index,
      () => FocusNode(debugLabel: 'sidebar_item_$index'),
    );
  }

  void _cycleSidebarFocus(
    List<int> sidebarNavIndexes, {
    required bool backward,
  }) {
    if (sidebarNavIndexes.isEmpty) return;
    final nodes = sidebarNavIndexes.map(_focusNodeForSidebarIndex).toList();
    final currentFocus = FocusManager.instance.primaryFocus;
    final currentIndex = nodes.indexWhere(
      (node) => identical(node, currentFocus) || node.hasFocus,
    );
    final targetIndex = switch (currentIndex) {
      -1 => backward ? nodes.length - 1 : 0,
      _ => backward
          ? (currentIndex - 1 + nodes.length) % nodes.length
          : (currentIndex + 1) % nodes.length,
    };
    nodes[targetIndex].requestFocus();
  }

  // ─── Helpers ──────────────────────────────────────────────────────
  String _currentLabel(List<int> allowedIndexes) {
    final current = allowedIndexes.contains(_selectedIndex)
        ? _selectedIndex
        : (allowedIndexes.isNotEmpty
            ? allowedIndexes.first
            : HomeNavIndex.home);
    if (current == HomeNavIndex.usageGuide) {
      return TransactionUiText.usageFlowHelperTitle;
    }
    return _slotItem(current)?.label ?? TransactionUiText.home;
  }

  int get _logoutIndex => HomeNavIndex.logout;

  List<_NavSection> _visibleSections(List<int> allowedIndexes) {
    return _menuService
        .visibleSections(snapshot: _menu, allowedIndexes: allowedIndexes)
        .map((section) =>
            _NavSection(title: section.title, indexes: section.navIndexes))
        .where((section) => section.indexes.isNotEmpty)
        .toList();
  }

  Future<void> _onDestinationSelected(
    int index,
    List<int> allowedIndexes,
  ) async {
    if (index == _logoutIndex) {
      _showLogoutDialog();
      return;
    }
    if (!allowedIndexes.contains(index)) return;
    if (index == _selectedIndex) return;
    final canLeave = await _confirmLeaveActiveFormIfNeeded();
    if (!canLeave || !mounted) return;
    setState(() {
      if (index != HomeNavIndex.register) {
        _registerInitialTabIndex = null;
      }
      _selectedIndex = index;
      _contentNavigatorKey = GlobalKey<NavigatorState>();
    });
    unawaited(_saveSelectedIndex(index));
  }

  Future<bool> _confirmLeaveActiveFormIfNeeded() async {
    final navigator = _contentNavigatorKey.currentState;
    if (navigator == null ||
        !SingleOpenNavigation.hasActiveForNavigator(navigator)) {
      return true;
    }
    final confirmed = await showFormLeaveConfirmDialog(context);
    if (confirmed) {
      SingleOpenNavigation.clearForNavigator(navigator);
    }
    return confirmed;
  }

  List<_MenuSearchEntry> _menuSearchEntries(List<int> allowedIndexes) {
    final entries = <_MenuSearchEntry>[];
    for (final section in _visibleSections(allowedIndexes)) {
      for (final navIndex in section.indexes) {
        final item = _slotItem(navIndex);
        if (item == null) continue;
        entries.add(
          _MenuSearchEntry(
            navIndex: navIndex,
            label: item.label,
            sectionTitle: section.title,
            icon: item.icon,
          ),
        );
      }
    }
    return entries;
  }

  List<_MenuSearchEntry> _filterMenuSearchEntries(
    List<_MenuSearchEntry> entries,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return entries;
    return entries
        .where(
          (entry) =>
              entry.label.toLowerCase().contains(q) ||
              entry.sectionTitle.toLowerCase().contains(q),
        )
        .toList();
  }

  _MenuSearchEntry? _firstMenuSearchResult(
    List<_MenuSearchEntry> entries,
    String query,
  ) {
    final filtered = _filterMenuSearchEntries(entries, query);
    return filtered.isEmpty ? null : filtered.first;
  }

  Future<void> _showMenuSearch(List<int> allowedIndexes) async {
    final entries = _menuSearchEntries(allowedIndexes);
    if (entries.isEmpty) return;
    final controller = TextEditingController();
    var query = '';

    final selectedIndex = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) {
        return SafeArea(
          child: AdaptiveContentSheet(
            titleWidget: Row(
              children: [
                Icon(Icons.search_rounded, color: AppColors.of(context).navy),
                const SizedBox(width: AppTheme.sp8),
                const Expanded(
                  child: Text(
                    'ค้นหาเมนู',
                    style: TextStyle(
                      fontFamily: 'Kanit',
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                final c = AppColors.of(context);
                final filtered = _filterMenuSearchEntries(entries, query);
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppTheme.sp16,
                    0,
                    AppTheme.sp16,
                    MediaQuery.viewInsetsOf(dialogContext).bottom +
                        AppTheme.sp16,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppInput(
                          controller: controller,
                          hint: 'พิมพ์ชื่อเมนูหรือหมวด เช่น รายรับ รายงาน',
                          prefixIcon: const Icon(Icons.search_rounded),
                          textInputAction: TextInputAction.search,
                          onChanged: (value) {
                            setDialogState(() => query = value);
                          },
                          onSubmitted: (value) {
                            final first =
                                _firstMenuSearchResult(entries, value);
                            if (first != null) {
                              Navigator.of(dialogContext).pop(first.navIndex);
                            }
                          },
                        ),
                        const SizedBox(height: AppTheme.sp12),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 360),
                          child: filtered.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppTheme.sp24,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.search_off_rounded,
                                        color: c.textHint,
                                        size: 36,
                                      ),
                                      const SizedBox(height: AppTheme.sp8),
                                      Text(
                                        'ไม่พบเมนูที่ตรงกับคำค้นหา',
                                        style: TextStyle(
                                          fontFamily: 'Kanit',
                                          color: c.textSecondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) =>
                                      Divider(height: 1, color: c.cardBorder),
                                  itemBuilder: (context, index) {
                                    final entry = filtered[index];
                                    final selected =
                                        entry.navIndex == _selectedIndex;
                                    return ListTile(
                                      dense: true,
                                      leading: Icon(
                                        entry.icon,
                                        color:
                                            selected ? c.navy : c.textSecondary,
                                      ),
                                      title: Text(
                                        entry.label,
                                        style: TextStyle(
                                          fontFamily: 'Kanit',
                                          color: c.textPrimary,
                                          fontWeight: selected
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text(
                                        entry.sectionTitle,
                                        style: TextStyle(
                                          fontFamily: 'Kanit',
                                          color: c.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                      trailing: selected
                                          ? Icon(
                                              Icons.check_circle_rounded,
                                              color: c.navy,
                                              size: 18,
                                            )
                                          : const Icon(
                                              Icons.keyboard_return_rounded,
                                              size: 18,
                                            ),
                                      onTap: () => Navigator.of(dialogContext)
                                          .pop(entry.navIndex),
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: AppTheme.sp12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: AppButton.outlined(
                            label: TransactionUiText.cancel,
                            fullWidth: false,
                            onPressed: () => Navigator.of(dialogContext).pop(),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
    controller.dispose();

    if (selectedIndex == null || !mounted) return;
    await _onDestinationSelected(selectedIndex, allowedIndexes);
  }

  // ─── Logout ───────────────────────────────────────────────────────
  void _showLogoutDialog() {
    final c = AppColors.of(context);
    showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.r16),
        ),
        icon: Icon(Icons.logout_rounded, color: c.expenseRed, size: 32),
        title: TransactionUiText.exitProgram,
        message: TransactionUiText.confirmExitProgram,
        cancelText: TransactionUiText.cancel,
        confirmText: TransactionUiText.confirm,
        confirmColor: c.expenseRed,
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        unawaited(_logout());
      }
    });
  }

  Future<void> _logout() async {
    final auth = context.read<SimpleAuthProvider>();
    await auth.logout();
    if (!mounted) return;
    if (auth.status == AuthStatus.error && auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error!)),
      );
      return;
    }
    await Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  // ─── Body shared ──────────────────────────────────────────────────
  Widget _buildBody(
    bool isWide,
    List<int> allowedIndexes, {
    required bool canOpenMenuConfiguration,
  }) {
    final content = _buildContentNavigator(
      allowedIndexes,
      canOpenMenuConfiguration: canOpenMenuConfiguration,
    );
    final visibleSections = _visibleSections(allowedIndexes);
    final sidebarNavIndexes = <int>[
      ...visibleSections.expand((section) => section.indexes),
    ];
    final c = AppColors.of(context);
    final sidebarBackground = c.cardWhite;
    final sectionTextColor = c.textSecondary;
    final sidebarWidth = _isSidebarCollapsed ? 84.0 : 252.0;

    if (isWide) {
      return Row(
        children: [
          Focus(
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.tab) {
                _cycleSidebarFocus(
                  sidebarNavIndexes,
                  backward: HardwareKeyboard.instance.isShiftPressed,
                );
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: sidebarWidth,
              decoration: BoxDecoration(
                color: sidebarBackground,
                border: Border(
                  right: BorderSide(color: c.cardBorder),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.symmetric(
                        horizontal: _isSidebarCollapsed ? 8 : 12,
                      ),
                      children: [
                        for (final section in visibleSections) ...[
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            child: _isSidebarCollapsed
                                ? const SizedBox.shrink()
                                : Padding(
                                    key: ValueKey(section.title),
                                    padding:
                                        const EdgeInsets.fromLTRB(8, 8, 8, 6),
                                    child: Text(
                                      section.title,
                                      style: TextStyle(
                                        color: sectionTextColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            alignment: Alignment.topCenter,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final navIndex in section.indexes)
                                  _buildSidebarItem(navIndex, allowedIndexes),
                              ],
                            ),
                          ),
                          SizedBox(height: _isSidebarCollapsed ? 6 : 10),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: content),
        ],
      );
    }

    return content;
  }

  Widget _buildContentNavigator(
    List<int> allowedIndexes, {
    required bool canOpenMenuConfiguration,
  }) {
    final auth = context.read<SimpleAuthProvider>();
    return Navigator(
      key: _contentNavigatorKey,
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (routeContext) => HomeRouter(
          screenIndex: _selectedIndex,
          registerInitialTabIndex: _registerInitialTabIndex,
          reportsInitialTabIndex: _reportsInitialTabIndex,
          onOpenReportsDailyClosing: () {
            if (allowedIndexes.contains(HomeNavIndex.reports)) {
              setState(() {
                _reportsInitialTabIndex = 9;
                _selectedIndex = HomeNavIndex.reports;
                _contentNavigatorKey = GlobalKey<NavigatorState>();
              });
              unawaited(_saveSelectedIndex(HomeNavIndex.reports));
            }
          },
          onOpenDepositRegister: () {
            if (allowedIndexes.contains(HomeNavIndex.register)) {
              setState(() {
                _registerInitialTabIndex = 6;
                _selectedIndex = HomeNavIndex.register;
                _contentNavigatorKey = GlobalKey<NavigatorState>();
              });
              unawaited(_saveSelectedIndex(HomeNavIndex.register));
            }
          },
          onOpenMenuConfiguration: canOpenMenuConfiguration
              ? () {
                  Navigator.of(routeContext).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const MenuConfigurationPage(),
                    ),
                  );
                }
              : null,
          onOpenSchoolProfile: () {
            Navigator.of(routeContext).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const SchoolProfilePage(),
              ),
            );
          },
          onOpenUserManagement: auth.can(PermissionKey.userAdminView)
              ? () {
                  Navigator.of(routeContext).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const UserManagementPage(),
                    ),
                  );
                }
              : null,
          onOpenBudgetSource: auth.can(PermissionKey.budgetSourceView)
              ? () {
                  Navigator.of(routeContext).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const BudgetSourcePage(),
                    ),
                  );
                }
              : null,
          onOpenIncomeTypeQuickAdd: () {
            Navigator.of(routeContext).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => ChangeNotifierProvider(
                  create: (_) => IncomeTypeProvider(
                    moneyType: const [],
                    sourceGroups: const [],
                  ),
                  child: const IncomeType(),
                ),
              ),
            );
          },
          onOpenExpenseType: () {
            Navigator.of(routeContext).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const ExpenseTypePage(),
              ),
            );
          },
          onOpenChequeAccount: () {
            Navigator.of(routeContext).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const ChequeAccountPage(),
              ),
            );
          },
          onOpenPartyManagement: () {
            Navigator.of(routeContext).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const PartyManagementPage(),
              ),
            );
          },
          onOpenMemberManagement: () {
            Navigator.of(routeContext).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => ChangeNotifierProvider(
                  create: (_) => MemberProvider(prefix: []),
                  child: const Member(),
                ),
              ),
            );
          },
          onOpenReceiptBookRegister:
              allowedIndexes.contains(HomeNavIndex.register)
                  ? () {
                      setState(() {
                        _registerInitialTabIndex = 5;
                        _selectedIndex = HomeNavIndex.register;
                        _contentNavigatorKey = GlobalKey<NavigatorState>();
                      });
                      unawaited(_saveSelectedIndex(HomeNavIndex.register));
                    }
                  : null,
          onOpenFiscalYearOpening: () {
            Navigator.of(routeContext).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const FiscalYearOpeningPage(),
              ),
            );
          },
          onOpenAppointmentOrder: () {
            Navigator.of(routeContext).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const AppointmentOrderPage(),
              ),
            );
          },
          onOpenDocGroupSettings: auth.can(PermissionKey.docGroupConfigure)
              ? () {
                  Navigator.of(routeContext).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const DocGroupSettingsPage(),
                    ),
                  );
                }
              : null,
          onOpenDatabaseMaintenance: () {
            Navigator.of(routeContext).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const DatabaseMaintenancePage(),
              ),
            );
          },
          onNavigateFromUsageGuide: (navIndex) {
            if (allowedIndexes.contains(navIndex)) {
              unawaited(_onDestinationSelected(navIndex, allowedIndexes));
            } else if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    TransactionUiText.usageFlowNavigateDenied,
                    style: TextStyle(fontFamily: 'Kanit'),
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildSidebarItem(int navIndex, List<int> allowedIndexes) {
    final item = _slotItem(navIndex);
    if (item == null) return const SizedBox.shrink();
    final selected = _selectedIndex == navIndex;
    final hovered = _hoveredIndex == navIndex;
    final focused = _focusedIndex == navIndex;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = AppColors.of(context);
    final baseTextColor = c.textPrimary;
    final mutedTextColor = c.textSecondary;
    final selectedBg = c.navy.withValues(alpha: isDark ? 0.18 : 0.12);
    final hoveredBg = c.navy.withValues(alpha: isDark ? 0.12 : 0.07);
    final selectedBorder = c.navy.withValues(alpha: isDark ? 0.42 : 0.26);
    final hoveredBorder = c.navy.withValues(alpha: isDark ? 0.30 : 0.14);
    final focusedBorder = c.navy.withValues(alpha: isDark ? 0.75 : 0.55);
    final activeIndicator = c.navy;
    void onTap() => unawaited(_onDestinationSelected(navIndex, allowedIndexes));
    final itemWidget = Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            left: 0,
            top: 8,
            bottom: 8,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 3,
              decoration: BoxDecoration(
                color: selected ? activeIndicator : Colors.transparent,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          MouseRegion(
            onEnter: (_) => setState(() => _hoveredIndex = navIndex),
            onExit: (_) => setState(() => _hoveredIndex = null),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.only(left: 6),
              decoration: BoxDecoration(
                color: selected
                    ? selectedBg
                    : (hovered ? hoveredBg : Colors.transparent),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: focused
                      ? focusedBorder
                      : (selected
                          ? selectedBorder
                          : (hovered ? hoveredBorder : Colors.transparent)),
                  width: focused ? 1.6 : 1,
                ),
                boxShadow: focused
                    ? [
                        BoxShadow(
                          color: activeIndicator.withValues(
                              alpha: isDark ? 0.14 : 0.16),
                          blurRadius: 8,
                          spreadRadius: 0.5,
                        ),
                      ]
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onTap,
                  focusNode: _focusNodeForSidebarIndex(navIndex),
                  onFocusChange: (hasFocus) {
                    setState(() => _focusedIndex = hasFocus ? navIndex : null);
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: _isSidebarCollapsed ? 8 : 12,
                      vertical: 12,
                    ),
                    // ใช้ความกว้างจริงจาก parent — อย่าพึ่งแค่ `_isSidebarCollapsed` เพราะ
                    // `AnimatedContainer` ยังขยายความกว้างช้ากว่า state ทำให้ Row ล้นระหว่าง animate
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // icon 24 + gap 12 + เผื่อตัวอักษรขั้นต่ำ — ต่ำกว่านี้แสดงแค่ไอคอน
                        const minWidthForLabelRow = 72;
                        final showFullRow = !_isSidebarCollapsed &&
                            constraints.maxWidth >= minWidthForLabelRow;
                        if (!showFullRow) {
                          return Center(
                            child: Icon(
                              item.icon,
                              color:
                                  selected ? activeIndicator : mutedTextColor,
                            ),
                          );
                        }
                        return Row(
                          children: [
                            Icon(
                              item.icon,
                              color:
                                  selected ? activeIndicator : mutedTextColor,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color:
                                      selected ? baseTextColor : mutedTextColor,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (_isSidebarCollapsed) {
      return Tooltip(message: item.label, child: itemWidget);
    }
    return itemWidget;
  }

  // ─── Build ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<SimpleAuthProvider>();
    final allowedIndexes = _menuService.allowedNavIndexes(
      snapshot: _menu,
      auth: auth,
    );
    if (!allowedIndexes.contains(_selectedIndex)) {
      final fallback =
          allowedIndexes.isNotEmpty ? allowedIndexes.first : HomeNavIndex.home;
      _selectedIndex = fallback;
      _contentNavigatorKey = GlobalKey<NavigatorState>();
      unawaited(_saveSelectedIndex(fallback));
    }
    final visibleItems =
        allowedIndexes.map((i) => _slotItem(i)).whereType<_NavItem>().toList();
    final isWide = MediaQuery.sizeOf(context).width >= 600;
    final c = AppColors.of(context);

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
          unawaited(_showMenuSearch(allowedIndexes));
        },
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () {
          unawaited(_showMenuSearch(allowedIndexes));
        },
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          leading: isWide
              ? IconButton(
                  tooltip: _isSidebarCollapsed ? 'ขยายเมนู' : 'ยุบเมนู',
                  icon: Icon(
                    _isSidebarCollapsed
                        ? Icons.keyboard_double_arrow_right_rounded
                        : Icons.keyboard_double_arrow_left_rounded,
                  ),
                  onPressed: _toggleSidebarCollapsed,
                )
              : null,
          title: desktopWindowChromeEnabled
              ? DragToMoveArea(
                  child: MouseRegion(
                    cursor: _draggingTitlebar
                        ? SystemMouseCursors.grabbing
                        : SystemMouseCursors.grab,
                    child: Listener(
                      onPointerDown: (_) {
                        if (!_draggingTitlebar) {
                          setState(() => _draggingTitlebar = true);
                        }
                      },
                      onPointerUp: (_) {
                        if (_draggingTitlebar) {
                          setState(() => _draggingTitlebar = false);
                        }
                      },
                      onPointerCancel: (_) {
                        if (_draggingTitlebar) {
                          setState(() => _draggingTitlebar = false);
                        }
                      },
                      child: SizedBox(
                        width: double.infinity,
                        height: kToolbarHeight,
                        child: Center(
                          child: Text(
                            _currentLabel(allowedIndexes),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: Theme.of(context).appBarTheme.titleTextStyle,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : Text(_currentLabel(allowedIndexes)),
          backgroundColor: c.cardWhite,
          elevation: 0,
          actionsPadding: EdgeInsets.only(
            right: desktopWindowChromeEnabled ? kDesktopCaptionWidth : 0,
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: c.cardBorder),
          ),
          actions: [
            IconButton(
              tooltip: 'ค้นหาเมนู (Ctrl+K)',
              visualDensity: VisualDensity.compact,
              onPressed: () => unawaited(_showMenuSearch(allowedIndexes)),
              icon: const Icon(Icons.search_rounded),
            ),
            const _ExpenseSyncWarningNavBadge(),
            const ReportSyncStatusBadge(),
            const AppBarNotificationBadge(),
            const PendingRequestsIndicator(),
            const SizedBox(width: 8),
            const OfflineStatusBadge(),
            const SizedBox(width: 12),
          ],
        ),
        drawer: isWide
            ? null
            : NavigationDrawer(
                selectedIndex: allowedIndexes.indexOf(_selectedIndex),
                onDestinationSelected: (i) {
                  Navigator.of(context).pop();
                  final visibleNavIndexes = <int>[
                    ..._visibleSections(allowedIndexes)
                        .expand((section) => section.indexes),
                  ];
                  unawaited(
                    _onDestinationSelected(
                        visibleNavIndexes[i], allowedIndexes),
                  );
                },
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(28, 16, 16, 10),
                    child: Text(TransactionUiText.menu,
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  ..._visibleSections(allowedIndexes).expand((section) sync* {
                    yield Padding(
                      padding: const EdgeInsets.fromLTRB(28, 10, 16, 6),
                      child: Text(
                        section.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                    for (final navIndex in section.indexes) {
                      final item = _slotItem(navIndex);
                      if (item == null) continue;
                      yield NavigationDrawerDestination(
                        icon: Icon(item.icon),
                        label: Text(item.label),
                        selectedIcon: Icon(item.icon),
                      );
                    }
                  }),
                ],
              ),
        body: Column(
          children: [
            Expanded(
              child: _buildBody(
                isWide,
                allowedIndexes,
                canOpenMenuConfiguration: auth.can(PermissionKey.menuConfigure),
              ),
            ),
            const _HomeFooter(),
          ],
        ),
        bottomNavigationBar: isWide || visibleItems.isEmpty
            ? null
            : NavigationBar(
                selectedIndex: allowedIndexes.indexOf(_selectedIndex).clamp(
                      0,
                      visibleItems.length - 1,
                    ),
                onDestinationSelected: (i) => unawaited(
                  _onDestinationSelected(allowedIndexes[i], allowedIndexes),
                ),
                destinations: visibleItems
                    .map((item) => NavigationDestination(
                          icon: Icon(item.icon),
                          label: item.label,
                          tooltip: item.label,
                        ))
                    .toList(),
              ),
      ),
    );
  }
}

class _HomeFooter extends StatefulWidget {
  const _HomeFooter();

  @override
  State<_HomeFooter> createState() => _HomeFooterState();
}

class _HomeFooterState extends State<_HomeFooter> {
  late final Future<PackageInfo> _packageInfoFuture;
  late final Future<SchoolProfile> _schoolProfileFuture;
  late final Future<LicenseSnapshot> _licenseSnapshotFuture;
  StreamSubscription<bool>? _networkSubscription;
  bool? _isApiOnline;

  @override
  void initState() {
    super.initState();
    _packageInfoFuture = PackageInfo.fromPlatform();
    _schoolProfileFuture = SchoolProfileLocalDataSourceImpl().load();
    _licenseSnapshotFuture = LicenseMode.snapshot().then((snapshot) {
      if (mounted &&
          snapshot.tier == ProductTier.online &&
          !snapshot.isLicenseExpired) {
        _startNetworkWatch();
      }
      return snapshot;
    });
  }

  void _startNetworkWatch() {
    if (_networkSubscription != null) return;

    final networkInfo = context.read<NetworkInfoService>();
    unawaited(networkInfo.isConnected.then((online) {
      if (!mounted) return;
      setState(() => _isApiOnline = online);
    }));
    _networkSubscription = networkInfo.onConnectivityChanged.listen((online) {
      if (!mounted) return;
      setState(() => _isApiOnline = online);
    });
  }

  @override
  void dispose() {
    unawaited(_networkSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<SimpleAuthProvider>();
    final c = AppColors.of(context);
    final fullName = _nonEmpty(auth.userFullName) ??
        _nonEmpty(auth.username) ??
        TransactionUiText.appFooterUnknownUser;
    final username = _nonEmpty(auth.username) ?? '-';
    final userGroup = _nonEmpty(auth.userGroupName) ??
        (auth.isAdmin
            ? TransactionUiText.appFooterAdminRole
            : TransactionUiText.appFooterOfficerRole);
    final email = _nonEmpty(auth.userEmail);
    final detailParts = [
      '${TransactionUiText.username}: $username / '
          '${TransactionUiText.appFooterFullNameLabel}: $fullName',
      '${TransactionUiText.userGroup}: $userGroup',
      if (email != null) '${TransactionUiText.email}: $email',
    ];

    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.cardWhite,
          border: Border(top: BorderSide(color: c.cardBorder)),
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.symmetric(
            horizontal: AppTheme.sp16,
            vertical: 6,
          ),
          child: FutureBuilder<PackageInfo>(
            future: _packageInfoFuture,
            builder: (context, snapshot) {
              final version = snapshot.hasData
                  ? '${snapshot.data!.version}+${snapshot.data!.buildNumber}'
                  : '-';
              return FutureBuilder<SchoolProfile>(
                future: _schoolProfileFuture,
                builder: (context, schoolSnapshot) {
                  final school = schoolSnapshot.data;
                  final schoolName = _nonEmpty(school?.name);
                  final schoolAddress = _nonEmpty(school?.address);
                  final schoolPhone = _nonEmpty(school?.phone);
                  final schoolExtra = _nonEmpty(school?.extra);
                  final schoolDetailParts = [
                    if (schoolAddress != null)
                      '${TransactionUiText.schoolProfileAddressLabel}: '
                          '$schoolAddress',
                    if (schoolPhone != null)
                      '${TransactionUiText.schoolProfilePhoneLabel}: '
                          '$schoolPhone',
                    if (schoolExtra != null) schoolExtra,
                  ];
                  final userBlock = _FooterPopupBlock(
                    icon: Icons.waving_hand_outlined,
                    title: '${TransactionUiText.appFooterWelcome} $fullName',
                    popupTitle: TransactionUiText.appFooterUserDetailTitle,
                    details: detailParts,
                  );
                  final schoolBlock = _FooterPopupBlock(
                    icon: Icons.school_outlined,
                    title:
                        schoolName ?? TransactionUiText.appFooterSchoolNotSet,
                    popupTitle: TransactionUiText.appFooterSchoolDetailTitle,
                    details: [
                      '${TransactionUiText.schoolProfileNameLabel}: '
                          '${schoolName ?? TransactionUiText.appFooterSchoolNotSet}',
                      if (schoolDetailParts.isEmpty)
                        TransactionUiText.schoolProfileTitle
                      else
                        ...schoolDetailParts,
                    ],
                  );
                  final versionChip = _FooterInfoChip(
                    icon: Icons.info_outline_rounded,
                    label:
                        '${TransactionUiText.appFooterVersionLabel} $version',
                    foreground: c.textSecondary,
                  );
                  return FutureBuilder<LicenseSnapshot>(
                    future: _licenseSnapshotFuture,
                    builder: (context, licenseSnapshot) {
                      final licenseChip = _buildLicenseChip(
                        context,
                        c,
                        licenseSnapshot.data,
                      );
                      final modeOnline = _isModeOnline(licenseSnapshot.data);
                      final apiChip = Tooltip(
                        message: _modeTooltip(licenseSnapshot.data, modeOnline),
                        child: _FooterInfoChip(
                          icon: modeOnline
                              ? Icons.cloud_done_outlined
                              : Icons.cloud_off_outlined,
                          label: modeOnline
                              ? TransactionUiText.appFooterApiOnline
                              : TransactionUiText.appFooterApiOffline,
                          foreground: modeOnline ? c.incomeGreen : c.loanAmber,
                        ),
                      );
                      final statusBlock = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          licenseChip,
                          const SizedBox(width: AppTheme.sp8),
                          versionChip,
                          const SizedBox(width: AppTheme.sp8),
                          apiChip,
                        ],
                      );

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth >= 720) {
                            return Row(
                              children: [
                                Expanded(
                                  child: Wrap(
                                    spacing: AppTheme.sp8,
                                    runSpacing: AppTheme.sp8,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      userBlock,
                                      schoolBlock,
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AppTheme.sp16),
                                statusBlock,
                              ],
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Wrap(
                                spacing: AppTheme.sp8,
                                runSpacing: AppTheme.sp8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  userBlock,
                                  schoolBlock,
                                ],
                              ),
                              const SizedBox(height: AppTheme.sp4),
                              Align(
                                alignment: Alignment.centerRight,
                                child: statusBlock,
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  bool _isModeOnline(LicenseSnapshot? snapshot) {
    return snapshot?.tier == ProductTier.online &&
        !(snapshot?.isLicenseExpired ?? true) &&
        _isApiOnline == true;
  }

  String _modeTooltip(LicenseSnapshot? snapshot, bool modeOnline) {
    if (snapshot == null || snapshot.tier == ProductTier.trial) {
      return TransactionUiText.appFooterModeTrialOfflineTooltip;
    }
    if (snapshot.isLicenseExpired) {
      return TransactionUiText.licenseExpiredBlockedMessage;
    }
    if (snapshot.tier == ProductTier.offline) {
      return TransactionUiText.appFooterModeOfflineLicenseTooltip;
    }
    return modeOnline
        ? TransactionUiText.appFooterModeOnlineLicenseOnlineTooltip
        : TransactionUiText.appFooterModeOnlineLicenseOfflineTooltip;
  }

  Widget _buildLicenseChip(
    BuildContext context,
    AppColors c,
    LicenseSnapshot? snapshot,
  ) {
    if (snapshot == null) {
      return _FooterInfoChip(
        icon: Icons.vpn_key_outlined,
        label: TransactionUiText.productTierCurrentBadge,
        foreground: c.textSecondary,
      );
    }

    switch (snapshot.tier) {
      case ProductTier.trial:
        final trial = snapshot.trial;
        final remaining = trial?.daysRemaining ?? 0;
        final total = trial?.daysTotal ?? 0;
        final expired = trial?.expired ?? false;
        return Tooltip(
          message: expired
              ? TransactionUiText.appFooterTrialExpired
              : TransactionUiText.appFooterTrialTooltip(remaining, total),
          child: _FooterInfoChip(
            icon: expired ? Icons.timer_off_outlined : Icons.timer_outlined,
            label: expired
                ? TransactionUiText.appFooterTrialExpired
                : TransactionUiText.appFooterTrialDaysRemaining(remaining),
            foreground: expired ? c.expenseRed : c.loanAmber,
          ),
        );
      case ProductTier.offline:
        return Tooltip(
          message: snapshot.isLicenseExpired
              ? TransactionUiText.licenseExpiredBlockedMessage
              : TransactionUiText.productTierOfflineSubtitle,
          child: _FooterInfoChip(
            icon: snapshot.isLicenseExpired
                ? Icons.vpn_key_off_outlined
                : Icons.verified_outlined,
            label: snapshot.isLicenseExpired
                ? TransactionUiText.appFooterLicenseExpired
                : TransactionUiText.appFooterActivatedOffline,
            foreground: snapshot.isLicenseExpired ? c.expenseRed : c.navy,
          ),
        );
      case ProductTier.online:
        return Tooltip(
          message: snapshot.isLicenseExpired
              ? TransactionUiText.licenseExpiredBlockedMessage
              : TransactionUiText.productTierOnlineSubtitle,
          child: _FooterInfoChip(
            icon: snapshot.isLicenseExpired
                ? Icons.vpn_key_off_outlined
                : Icons.verified_user_outlined,
            label: snapshot.isLicenseExpired
                ? TransactionUiText.appFooterLicenseExpired
                : TransactionUiText.appFooterActivatedOnline,
            foreground:
                snapshot.isLicenseExpired ? c.expenseRed : c.incomeGreen,
          ),
        );
    }
  }
}

class _FooterPopupBlock extends StatelessWidget {
  const _FooterPopupBlock({
    required this.icon,
    required this.title,
    required this.popupTitle,
    required this.details,
  });

  final IconData icon;
  final String title;
  final String popupTitle;
  final List<String> details;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return PopupMenuButton<void>(
      tooltip: TransactionUiText.appFooterClickForDetails,
      position: PopupMenuPosition.over,
      padding: EdgeInsets.zero,
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          enabled: false,
          child: SizedBox(
            width: 340,
            child: _FooterPopupContent(
              icon: icon,
              title: popupTitle,
              details: details,
            ),
          ),
        ),
      ],
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: c.textSecondary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.keyboard_arrow_up_rounded,
                  size: 15, color: c.textHint),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterPopupContent extends StatelessWidget {
  const _FooterPopupContent({
    required this.icon,
    required this.title,
    required this.details,
  });

  final IconData icon;
  final String title;
  final List<String> details;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.sp8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: c.navy),
              const SizedBox(width: AppTheme.sp8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.sp8),
          ...details.map(
            (detail) => Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.sp4),
              child: Text(
                detail,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterInfoChip extends StatelessWidget {
  const _FooterInfoChip({
    required this.icon,
    required this.label,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: foreground),
        const SizedBox(width: 5),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: foreground,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ExpenseSyncWarningNavBadge extends StatelessWidget {
  const _ExpenseSyncWarningNavBadge();

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseSyncWarningService>(
      builder: (context, service, _) {
        final message = service.message;
        if (message == null || message.isEmpty) {
          return const SizedBox.shrink();
        }

        final c = AppColors.of(context);
        return Padding(
          padding: const EdgeInsets.only(right: AppTheme.sp4),
          child: Tooltip(
            message: message,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: message,
              onPressed: () => _showExpenseSyncWarningDialog(context, message),
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(Icons.dns_outlined, color: c.loanAmber),
                  Positioned(
                    right: -1,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: c.loanAmber,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.cardWhite, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showExpenseSyncWarningDialog(BuildContext context, String message) {
    final c = AppColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: AdaptiveContentSheet(
          titleWidget: Row(
            children: [
              Icon(Icons.dns_outlined, color: c.loanAmber, size: 24),
              const SizedBox(width: AppTheme.sp8),
              Text(
                'ตรวจสอบการซิงก์รายจ่าย',
                style: TextStyle(
                  fontFamily: 'Kanit',
                  color: c.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.sp16,
              0,
              AppTheme.sp16,
              AppTheme.sp16,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      fontFamily: 'Kanit',
                      color: c.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppTheme.sp12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AppButton.primary(
                      label: 'รับทราบ',
                      fullWidth: false,
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
