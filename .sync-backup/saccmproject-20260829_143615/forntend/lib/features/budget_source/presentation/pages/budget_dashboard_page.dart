import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/local_data_source/budget_source_local_data_source.dart';
import 'package:saccm/core/utils/fiscal_year.dart';
import 'package:saccm/core/utils/user_error_message.dart';
import 'package:saccm/features/auth/presentation/providers/simple_auth_provider.dart';
import 'package:saccm/features/budget_source/data/models/budget_source_model.dart';
import 'package:saccm/widgets/widgets.dart';

import '../view_models/budget_dashboard_view_models.dart';
import '../widgets/budget_dashboard_overview_card.dart';
import '../widgets/budget_dashboard_source_card.dart';

/// ภาพรวมงบประมาณ — อ่านจาก SQLite (`budget_source_master` + `budget_source_budget`)
class BudgetDashboardPage extends StatefulWidget {
  const BudgetDashboardPage({super.key});

  @override
  State<BudgetDashboardPage> createState() => _BudgetDashboardPageState();
}

class _BudgetDashboardPageState extends State<BudgetDashboardPage> {
  static const String _fontFamily = 'Kanit';
  static const double _maxResponsiveFormWidth = 1440;

  final _localDs = BudgetSourceLocalDataSource();
  List<BudgetSourceModel> _items = [];
  String _selectedYear = FiscalYear.currentBuddhist().toString();
  int _busyDepth = 0;
  String _busyMessage = 'กำลังโหลด...';
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busyDepth += 1;
      _busyMessage = 'กำลังโหลดภาพรวมงบประมาณ...';
      _loadError = null;
    });
    try {
      await _localDs.init();
      final items = await _localDs.getAllBudgetSources();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loadError = null;
        _syncSelectedYearToData();
      });
    } catch (e) {
      if (!mounted) return;
      final msg = toUserErrorMessage(e);
      setState(() {
        if (_items.isEmpty) _loadError = msg;
      });
      if (_items.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          if (_busyDepth > 0) _busyDepth--;
        });
      }
    }
  }

  void _syncSelectedYearToData() {
    final choices = _yearChoices();
    if (choices.contains(_selectedYear)) return;
    if (choices.isNotEmpty) {
      _selectedYear = choices.first;
    } else {
      _selectedYear = FiscalYear.currentBuddhist().toString();
    }
  }

  List<String> _distinctYearsFromData() {
    final y = _items
        .map((e) => e.fiscalYear.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    y.sort((a, b) => b.compareTo(a));
    return y;
  }

  List<String> _yearChoices() {
    final set = _distinctYearsFromData().toSet();
    set.add(FiscalYear.currentBuddhist().toString());
    final list = set.toList();
    list.sort((a, b) => b.compareTo(a));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<SimpleAuthProvider>();
    final c = AppColors.of(context);
    if (!auth.can(PermissionKey.budgetSourceView)) {
      return SafeArea(
        child: Scaffold(
          backgroundColor: c.background,
          appBar: _buildAppBar(c),
          body: const Center(child: Text(TransactionUiText.noPermissionData)),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final usedColor = c.expenseRed;
    final reservedColor = Color.lerp(c.loanAmber, scheme.tertiary, 0.35)!;
    final availableColor = c.incomeGreen;

    final rows =
        BudgetDashboardSourceRow.listForFiscalYear(_items, _selectedYear);
    final totals = BudgetDashboardTotals.fromRowsForYear(_selectedYear, rows);
    final yearChoices = _yearChoices();

    return AppBusyBackdrop(
      isBusy: _busyDepth > 0,
      message: _busyMessage,
      child: Scaffold(
        backgroundColor: c.background,
        appBar: _buildAppBar(c),
        body: _loadError != null && _items.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.sp24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 40, color: scheme.error),
                      const SizedBox(height: AppTheme.sp12),
                      Text(
                        _loadError!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: c.textSecondary, fontFamily: 'Kanit'),
                      ),
                      const SizedBox(height: AppTheme.sp16),
                      AppButton.primary(
                        label: TransactionUiText.tryAgain,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        onPressed: _load,
                      ),
                    ],
                  ),
                ),
              )
            : RefreshIndicator(
                color: scheme.primary,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(AppTheme.sp16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: _maxResponsiveFormWidth,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer
                                    .withValues(alpha: 0.35),
                                borderRadius:
                                    BorderRadius.circular(AppTheme.r12),
                                border: Border.all(color: c.cardBorder),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.sp12,
                                  vertical: AppTheme.sp8,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.storage_rounded,
                                        size: 22, color: scheme.primary),
                                    const SizedBox(width: AppTheme.sp8),
                                    Expanded(
                                      child: Text(
                                        TransactionUiText
                                            .budgetDashboardLiveDataHint,
                                        style: TextStyle(
                                          color: c.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Kanit',
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: AppTheme.sp16),
                            AppDropdownField<String>(
                              label: TransactionUiText
                                  .budgetDashboardSelectFiscalYear,
                              value: _selectedYear,
                              items: yearChoices
                                  .map((y) => AppDropdownItem<String>(
                                      value: y, label: y))
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() => _selectedYear = v);
                              },
                            ),
                            const SizedBox(height: AppTheme.sp16),
                            if (rows.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: AppTheme.sp32),
                                child: Column(
                                  children: [
                                    Icon(Icons.inbox_outlined,
                                        size: 48, color: c.textHint),
                                    const SizedBox(height: AppTheme.sp12),
                                    Text(
                                      TransactionUiText
                                          .budgetDashboardEmptyForYear,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: c.textSecondary,
                                        fontSize: 14,
                                        fontFamily: 'Kanit',
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else ...[
                              BudgetDashboardOverviewCard(
                                totals: totals,
                                usedColor: usedColor,
                                reservedColor: reservedColor,
                                availableColor: availableColor,
                              ),
                              const SizedBox(height: AppTheme.sp24),
                              Text(
                                TransactionUiText.budgetDashboardSourcesSection,
                                style: TextStyle(
                                  color: c.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Kanit',
                                ),
                              ),
                              const SizedBox(height: AppTheme.sp12),
                              ...rows.map(
                                (r) => Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: AppTheme.sp12),
                                  child: BudgetDashboardSourceCard(
                                    row: r,
                                    usedColor: usedColor,
                                    reservedColor: reservedColor,
                                    availableColor: availableColor,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: AppTheme.sp32),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppColors c) {
    return AppBar(
      toolbarHeight: 52,
      title: Text(
        TransactionUiText.budgetDashboardTitle,
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
    );
  }
}
