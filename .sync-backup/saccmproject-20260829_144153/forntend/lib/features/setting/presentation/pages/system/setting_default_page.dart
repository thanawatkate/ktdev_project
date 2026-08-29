import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/features/auth/presentation/providers/simple_auth_provider.dart';
import 'package:saccm/features/license/license_mode.dart';
import 'package:saccm/features/license/presentation/pages/product_plan_page.dart';
import 'package:saccm/features/setting/presentation/providers/setting_config_provider.dart';
import 'package:saccm/features/setting/presentation/pages/system/doc_group_settings_page.dart';
import 'package:saccm/features/setting/presentation/pages/system/setting_api_db_page.dart';
import 'package:saccm/providers/theme_mode_provider.dart';
import 'package:saccm/widgets/widgets.dart';

class SettingDefault extends StatefulWidget {
  const SettingDefault({super.key});

  @override
  State<SettingDefault> createState() => _SettingDefaultState();
}

class _SettingDefaultState extends State<SettingDefault> {
  static const String _fontFamily = 'Kanit';
  static const double _maxResponsiveFormWidth = 1440;

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';
  bool? _canConfigureApi;

  @override
  void initState() {
    super.initState();
    _loadApiConfigAccess();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadApiConfigAccess() async {
    final canConfigure = await LicenseMode.canSyncOnline();
    if (!mounted) return;
    setState(() => _canConfigureApi = canConfigure);
  }

  Future<bool> _ensureCanConfigureApi(BuildContext context) async {
    final canConfigure = _canConfigureApi ?? await LicenseMode.canSyncOnline();
    if (mounted && _canConfigureApi != canConfigure) {
      setState(() => _canConfigureApi = canConfigure);
    }
    if (canConfigure) return true;

    if (context.mounted) {
      _showApiSettingLockedDialog(context);
    }
    return false;
  }

  void _showApiSettingLockedDialog(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => ConfirmDialog(
        isDestructive: false,
        title: TransactionUiText.apiSettingLockedTitle,
        message: TransactionUiText.apiSettingLockedMessage,
        cancelText: TransactionUiText.close,
        confirmText: TransactionUiText.apiSettingGoProductPlan,
        confirmColor: Theme.of(dialogContext).colorScheme.primary,
      ),
    ).then((goPlan) {
      if (goPlan == true && context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProductPlanPage()),
        );
      }
    });
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() => _searchQuery = value);
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  bool _matchesQuery(String value, {String? query}) {
    final q = (query ?? _searchQuery).trim().toLowerCase();
    if (q.isEmpty) return true;
    return value.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final configuredApiSubtitle = context.select<SettingProvider, String>(
      (setting) => 'API: ${setting.apiUrl}',
    );
    final canConfigureApi = _canConfigureApi == true;
    final apiSubtitle = canConfigureApi
        ? configuredApiSubtitle
        : TransactionUiText.apiSettingRequiresOnlineLicense;
    final themeSubtitle = context.select<ThemeModeProvider, String>(
      (theme) => _themeLabel(theme.mode),
    );
    final canConfigureDocGroup = context.select<SimpleAuthProvider, bool>(
      (auth) => auth.isAdmin && auth.can(PermissionKey.docGroupConfigure),
    );
    final settingMenus = <({String title, String subtitle})>[
      (
        title: TransactionUiText.systemConnection,
        subtitle: apiSubtitle,
      ),
      (
        title: TransactionUiText.appTheme,
        subtitle: themeSubtitle,
      ),
      if (canConfigureDocGroup)
        (
          title: TransactionUiText.docGroupSettingsTitle,
          subtitle: TransactionUiText.docGroupSettingsSubtitle,
        ),
    ];

    Future<void> openConnectionConfig() async {
      if (!await _ensureCanConfigureApi(context)) return;
      if (!context.mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: context.read<SettingProvider>(),
            child: const SettingApiDbPage(),
          ),
        ),
      );
    }

    void openDocGroupSettings() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const DocGroupSettingsPage(),
        ),
      );
    }

    return SafeArea(
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          toolbarHeight: 52,
          title: Text(
            TransactionUiText.defaults,
            style: TextStyle(
              fontFamily: _fontFamily,
              color: c.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
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
            final totalSettingsMenuCount = settingMenus.length;
            final showSearchAndQuickActions = totalSettingsMenuCount > 5;
            final isWide = constraints.maxWidth >= 900;
            final isSearching =
                showSearchAndQuickActions && _searchQuery.trim().isNotEmpty;
            final effectiveSearchQuery =
                showSearchAndQuickActions ? _searchQuery : '';
            final horizontalPadding = isWide ? AppTheme.sp24 : AppTheme.sp16;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                AppTheme.sp16,
                horizontalPadding,
                AppTheme.sp24,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: _maxResponsiveFormWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
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
                                borderRadius:
                                    BorderRadius.circular(AppTheme.r12),
                              ),
                              child: Icon(
                                Icons.tune_rounded,
                                color: colorScheme.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: AppTheme.sp12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    TransactionUiText.defaults,
                                    style: TextStyle(
                                      color: c.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    TransactionUiText.setDefaultSystem,
                                    style: TextStyle(
                                      color: c.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.sp16),
                      if (showSearchAndQuickActions) ...[
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: isSearching
                              ? const SizedBox.shrink()
                              : Column(
                                  key: const ValueKey('quick-actions-visible'),
                                  children: [
                                    _buildQuickActions(
                                      context: context,
                                      onConnectionTap: openConnectionConfig,
                                      onThemeTap: () =>
                                          _showThemePicker(context),
                                    ),
                                    const SizedBox(height: AppTheme.sp16),
                                  ],
                                ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(AppTheme.sp12),
                          decoration: BoxDecoration(
                            color: c.cardWhite,
                            borderRadius: BorderRadius.circular(AppTheme.r12),
                            border: Border.all(color: c.cardBorder),
                          ),
                          child: AppInput(
                            label: TransactionUiText.settingSearchLabel,
                            hint: TransactionUiText.settingSearchHint,
                            controller: _searchController,
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: c.textSecondary,
                              size: 20,
                            ),
                            onChanged: _onSearchChanged,
                            action: AppInputAction.text(
                              suffixIcon: _searchQuery.trim().isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: TransactionUiText.clearSearch,
                                      onPressed: _clearSearch,
                                      icon: Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                        color: c.textSecondary,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.sp16),
                      ],
                      _buildSectionLabel(
                        context: context,
                        title: TransactionUiText.allSettings,
                      ),
                      const SizedBox(height: AppTheme.sp8),
                      Builder(
                        builder: (context) {
                          final showConnection = _matchesQuery(
                            '${TransactionUiText.systemConnection} $apiSubtitle',
                            query: effectiveSearchQuery,
                          );
                          final showTheme = _matchesQuery(
                            '${TransactionUiText.appTheme} $themeSubtitle',
                            query: effectiveSearchQuery,
                          );
                          final showDocGroup = canConfigureDocGroup &&
                              _matchesQuery(
                                '${TransactionUiText.docGroupSettingsTitle} ${TransactionUiText.docGroupSettingsSubtitle}',
                                query: effectiveSearchQuery,
                              );
                          final hasAnyResult =
                              showConnection || showTheme || showDocGroup;

                          if (!hasAnyResult && showSearchAndQuickActions) {
                            return _buildNoResultState(
                              context: context,
                              onClearSearch: _clearSearch,
                            );
                          }

                          if (isWide) {
                            return Wrap(
                              spacing: AppTheme.sp12,
                              runSpacing: AppTheme.sp12,
                              children: [
                                if (showConnection)
                                  SizedBox(
                                    width: (constraints.maxWidth -
                                            (horizontalPadding * 2) -
                                            AppTheme.sp12) /
                                        2,
                                    child: _buildConfigCard(
                                      context: context,
                                      icon: Icons.settings_ethernet_rounded,
                                      iconBg: c.iconBgIncome,
                                      iconColor: colorScheme.primary,
                                      title: TransactionUiText.systemConnection,
                                      subtitle: apiSubtitle,
                                      searchQuery: effectiveSearchQuery,
                                      onTap: openConnectionConfig,
                                    ),
                                  ),
                                if (showTheme)
                                  SizedBox(
                                    width: (constraints.maxWidth -
                                            (horizontalPadding * 2) -
                                            AppTheme.sp12) /
                                        2,
                                    child: _buildConfigCard(
                                      context: context,
                                      icon: Icons.dark_mode_rounded,
                                      iconBg: c.iconBgLoan,
                                      iconColor: c.loanAmber,
                                      title: TransactionUiText.appTheme,
                                      subtitle: themeSubtitle,
                                      searchQuery: effectiveSearchQuery,
                                      onTap: () => _showThemePicker(context),
                                    ),
                                  ),
                                if (showDocGroup)
                                  SizedBox(
                                    width: (constraints.maxWidth -
                                            (horizontalPadding * 2) -
                                            AppTheme.sp12) /
                                        2,
                                    child: _buildConfigCard(
                                      context: context,
                                      icon: Icons.numbers_rounded,
                                      iconBg: c.iconBgLoan,
                                      iconColor: colorScheme.primary,
                                      title: TransactionUiText
                                          .docGroupSettingsTitle,
                                      subtitle: TransactionUiText
                                          .docGroupSettingsSubtitle,
                                      searchQuery: effectiveSearchQuery,
                                      onTap: openDocGroupSettings,
                                    ),
                                  ),
                              ],
                            );
                          }

                          final children = <Widget>[
                            if (showConnection)
                              _buildConfigItem(
                                context: context,
                                icon: Icons.settings_ethernet_rounded,
                                iconBg: c.iconBgIncome,
                                iconColor: colorScheme.primary,
                                title: TransactionUiText.systemConnection,
                                subtitle: apiSubtitle,
                                searchQuery: effectiveSearchQuery,
                                onTap: openConnectionConfig,
                              ),
                            if (showConnection && showTheme)
                              Divider(height: 1, color: c.dividerColor),
                            if (showTheme)
                              _buildConfigItem(
                                context: context,
                                icon: Icons.dark_mode_rounded,
                                iconBg: c.iconBgLoan,
                                iconColor: c.loanAmber,
                                title: TransactionUiText.appTheme,
                                subtitle: themeSubtitle,
                                searchQuery: effectiveSearchQuery,
                                onTap: () => _showThemePicker(context),
                              ),
                            if ((showConnection || showTheme) && showDocGroup)
                              Divider(height: 1, color: c.dividerColor),
                            if (showDocGroup)
                              _buildConfigItem(
                                context: context,
                                icon: Icons.numbers_rounded,
                                iconBg: c.iconBgLoan,
                                iconColor: colorScheme.primary,
                                title: TransactionUiText.docGroupSettingsTitle,
                                subtitle:
                                    TransactionUiText.docGroupSettingsSubtitle,
                                searchQuery: effectiveSearchQuery,
                                onTap: openDocGroupSettings,
                              ),
                          ];

                          return _buildMobileGroupedSection(
                            context: context,
                            title: TransactionUiText.systemSettings,
                            icon: Icons.tune_rounded,
                            children: children,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return TransactionUiText.lightTheme;
      case ThemeMode.dark:
        return TransactionUiText.darkTheme;
      case ThemeMode.system:
        return TransactionUiText.followSystem;
    }
  }

  static Future<void> _showThemePicker(BuildContext context) async {
    final themeProvider = context.read<ThemeModeProvider>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final sheetColors = AppColors.of(sheetContext);
        final sheetScheme = Theme.of(sheetContext).colorScheme;

        return AdaptiveContentSheet(
          titleWidget: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              TransactionUiText.selectTheme,
              style: TextStyle(
                color: sheetColors.textPrimary,
                fontFamily: 'Kanit',
              ),
            ),
            subtitle: Text(
              TransactionUiText.setDisplayTheme,
              style: TextStyle(
                color: sheetColors.textSecondary,
                fontFamily: 'Kanit',
              ),
            ),
            trailing: Icon(
              Icons.palette_rounded,
              color: sheetScheme.primary,
            ),
          ),
          child: Consumer<ThemeModeProvider>(
            builder: (context, theme, _) {
              return RadioGroup<ThemeMode>(
                groupValue: theme.mode,
                onChanged: (value) async {
                  if (value == null) return;
                  await themeProvider.setMode(value);
                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.system,
                      activeColor: sheetScheme.primary,
                      title: Text(
                        TransactionUiText.followSystem,
                        style: TextStyle(
                          color: sheetColors.textPrimary,
                          fontFamily: 'Kanit',
                        ),
                      ),
                    ),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.light,
                      activeColor: sheetScheme.primary,
                      title: Text(
                        TransactionUiText.lightTheme,
                        style: TextStyle(
                          color: sheetColors.textPrimary,
                          fontFamily: 'Kanit',
                        ),
                      ),
                    ),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.dark,
                      activeColor: sheetScheme.primary,
                      title: Text(
                        TransactionUiText.darkTheme,
                        style: TextStyle(
                          color: sheetColors.textPrimary,
                          fontFamily: 'Kanit',
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.sp8),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  static Widget _buildConfigItem({
    required BuildContext context,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String searchQuery,
    required VoidCallback onTap,
  }) {
    final c = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sp12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(AppTheme.r8),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: AppTheme.sp12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHighlightedText(
                    text: title,
                    query: searchQuery,
                    baseStyle: TextStyle(
                      color: c.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Kanit',
                    ),
                    highlightStyle: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Kanit',
                    ),
                  ),
                  const SizedBox(height: 2),
                  _buildHighlightedText(
                    text: subtitle,
                    query: searchQuery,
                    baseStyle: TextStyle(
                      color: c.textSecondary,
                      fontSize: 12,
                      fontFamily: 'Kanit',
                    ),
                    highlightStyle: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Kanit',
                    ),
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.textHint),
          ],
        ),
      ),
    );
  }

  static Widget _buildConfigCard({
    required BuildContext context,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String searchQuery,
    required VoidCallback onTap,
  }) {
    final c = AppColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r12),
        border: Border.all(color: c.cardBorder),
      ),
      child: _buildConfigItem(
        context: context,
        icon: icon,
        iconBg: iconBg,
        iconColor: iconColor,
        title: title,
        subtitle: subtitle,
        searchQuery: searchQuery,
        onTap: onTap,
      ),
    );
  }

  static Widget _buildHighlightedText({
    required String text,
    required String query,
    required TextStyle baseStyle,
    required TextStyle highlightStyle,
    int? maxLines,
  }) {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return Text(
        text,
        style: baseStyle,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = trimmedQuery.toLowerCase();
    final firstMatchIndex = lowerText.indexOf(lowerQuery);
    if (firstMatchIndex < 0) {
      return Text(
        text,
        style: baseStyle,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
      );
    }

    final spans = <TextSpan>[];
    var start = 0;
    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index < 0) {
        spans.add(TextSpan(text: text.substring(start), style: baseStyle));
        break;
      }

      if (index > start) {
        spans.add(
            TextSpan(text: text.substring(start, index), style: baseStyle));
      }

      final end = index + lowerQuery.length;
      spans.add(
          TextSpan(text: text.substring(index, end), style: highlightStyle));
      start = end;
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: maxLines == null ? TextOverflow.visible : TextOverflow.ellipsis,
    );
  }

  static Widget _buildQuickActions({
    required BuildContext context,
    required VoidCallback onConnectionTap,
    required VoidCallback onThemeTap,
  }) {
    final c = AppColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(
          context: context,
          title: TransactionUiText.quickActions,
        ),
        const SizedBox(height: AppTheme.sp8),
        Wrap(
          spacing: AppTheme.sp8,
          runSpacing: AppTheme.sp8,
          children: [
            _buildQuickActionChip(
              context: context,
              icon: Icons.settings_ethernet_rounded,
              label: TransactionUiText.systemConnection,
              iconColor: primary,
              borderColor: c.cardBorder,
              onTap: onConnectionTap,
            ),
            _buildQuickActionChip(
              context: context,
              icon: Icons.dark_mode_rounded,
              label: TransactionUiText.appTheme,
              iconColor: c.loanAmber,
              borderColor: c.cardBorder,
              onTap: onThemeTap,
            ),
          ],
        ),
      ],
    );
  }

  static Widget _buildQuickActionChip({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    final c = AppColors.of(context);

    return Material(
      color: c.cardWhite,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.sp12,
            vertical: AppTheme.sp8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: AppTheme.sp8),
              Text(
                label,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildSectionLabel({
    required BuildContext context,
    required String title,
  }) {
    final c = AppColors.of(context);

    return Text(
      title,
      style: TextStyle(
        color: c.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  static Widget _buildNoResultState({
    required BuildContext context,
    required VoidCallback onClearSearch,
  }) {
    final c = AppColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.sp16),
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r12),
        border: Border.all(color: c.cardBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.search_off_rounded, color: c.textHint),
          const SizedBox(width: AppTheme.sp12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  TransactionUiText.settingSearchNoResult,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontFamily: 'Kanit',
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: AppTheme.sp8),
                TextButton.icon(
                  onPressed: onClearSearch,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text(
                    TransactionUiText.clearSearch,
                    style: TextStyle(fontFamily: 'Kanit'),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.sp8,
                      vertical: AppTheme.sp4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildMobileGroupedSection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final c = AppColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r12),
        border: Border.all(color: c.cardBorder),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: c.iconBgIncome,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppTheme.sp12,
            vertical: AppTheme.sp4,
          ),
          childrenPadding: EdgeInsets.zero,
          iconColor: c.textSecondary,
          collapsedIconColor: c.textSecondary,
          leading: Icon(icon, color: primary, size: 20),
          title: Text(
            title,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFamily: 'Kanit',
            ),
          ),
          children: children,
        ),
      ),
    );
  }
}
