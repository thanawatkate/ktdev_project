import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/local_data_source/app_menu_local_data_source.dart';
import 'package:saccm/core/services/menu_service.dart';
import 'package:saccm/features/home/presentation/pages/home_nav_index.dart';

/// แผนภาพลำดับการทำงานหลักของระบบ — โหนดที่มีเมนูจริงแตะแล้วสลับแท็บหลักได้
class SystemFlowDiagramTab extends StatefulWidget {
  const SystemFlowDiagramTab({
    super.key,
    this.onNavigateToNav,
  });

  final ValueChanged<int>? onNavigateToNav;

  @override
  State<SystemFlowDiagramTab> createState() => _SystemFlowDiagramTabState();
}

class _SystemFlowDiagramTabState extends State<SystemFlowDiagramTab> {
  late final Future<NavMenuSnapshot> _menuFuture =
      MenuService().loadMenuSnapshot();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;

    return FutureBuilder<NavMenuSnapshot>(
      future: _menuFuture,
      builder: (context, snap) {
        final menu = snap.data ?? NavMenuSnapshot.fallback();

        return LayoutBuilder(
          builder: (context, constraints) {
            // InteractiveViewer(constrained: false) passes unbounded max width;
            // clamp both min and max so Column/Row/Expanded get finite horizontal bounds.
            final viewportW =
                constraints.hasBoundedWidth && constraints.maxWidth > 0
                    ? constraints.maxWidth
                    : MediaQuery.sizeOf(context).width;

            return InteractiveViewer(
              constrained: false,
              boundaryMargin: const EdgeInsets.all(120),
              minScale: 0.65,
              maxScale: 2.75,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: viewportW,
                  maxWidth: viewportW,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.sp16,
                    AppTheme.sp12,
                    AppTheme.sp16,
                    AppTheme.sp24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        TransactionUiText.usageFlowDiagramIntro,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 14,
                          height: 1.45,
                          fontFamily: 'Kanit',
                        ),
                      ),
                      const SizedBox(height: AppTheme.sp16),
                      _FlowNodeCard(
                        c: c,
                        primary: primary,
                        leadingIcon: Icons.login_rounded,
                        title: TransactionUiText.usageFlowDiagramNodeLogin,
                        navigable: false,
                        onTap: null,
                      ),
                      _FlowArrow(c: c),
                      _FlowNodeCard(
                        c: c,
                        primary: primary,
                        leadingIcon: menu.iconForNavIndex(HomeNavIndex.setting),
                        title: TransactionUiText.usageFlowDiagramNodeSetup,
                        navigable: widget.onNavigateToNav != null,
                        onTap: widget.onNavigateToNav == null
                            ? null
                            : () =>
                                widget.onNavigateToNav!(HomeNavIndex.setting),
                      ),
                      _FlowArrow(c: c),
                      _FlowNodeCard(
                        c: c,
                        primary: primary,
                        leadingIcon: menu.iconForNavIndex(HomeNavIndex.home),
                        title: TransactionUiText.usageFlowDiagramNodeDashboard,
                        navigable: widget.onNavigateToNav != null,
                        onTap: widget.onNavigateToNav == null
                            ? null
                            : () => widget.onNavigateToNav!(HomeNavIndex.home),
                      ),
                      _FlowArrow(c: c),
                      Text(
                        TransactionUiText.usageFlowDiagramBranchLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: c.textHint,
                          fontSize: 12,
                          fontFamily: 'Kanit',
                        ),
                      ),
                      const SizedBox(height: AppTheme.sp8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _FlowNodeCard(
                              c: c,
                              primary: primary,
                              leadingIcon:
                                  menu.iconForNavIndex(HomeNavIndex.income),
                              title:
                                  TransactionUiText.usageFlowDiagramNodeIncome,
                              compact: true,
                              navigable: widget.onNavigateToNav != null,
                              onTap: widget.onNavigateToNav == null
                                  ? null
                                  : () => widget
                                      .onNavigateToNav!(HomeNavIndex.income),
                            ),
                          ),
                          const SizedBox(width: AppTheme.sp8),
                          Expanded(
                            child: _FlowNodeCard(
                              c: c,
                              primary: primary,
                              leadingIcon:
                                  menu.iconForNavIndex(HomeNavIndex.loan),
                              title:
                                  TransactionUiText.usageFlowDiagramNodeLoan,
                              compact: true,
                              navigable: widget.onNavigateToNav != null,
                              onTap: widget.onNavigateToNav == null
                                  ? null
                                  : () => widget
                                      .onNavigateToNav!(HomeNavIndex.loan),
                            ),
                          ),
                        ],
                      ),
                      _FlowArrow(c: c),
                      _FlowNodeCard(
                        c: c,
                        primary: primary,
                        leadingIcon:
                            menu.iconForNavIndex(HomeNavIndex.expenseReq),
                        title: TransactionUiText.usageFlowDiagramNodeExpenseReq,
                        navigable: widget.onNavigateToNav != null,
                        onTap: widget.onNavigateToNav == null
                            ? null
                            : () => widget
                                .onNavigateToNav!(HomeNavIndex.expenseReq),
                      ),
                      _FlowArrow(c: c),
                      _FlowNodeCard(
                        c: c,
                        primary: primary,
                        leadingIcon:
                            menu.iconForNavIndex(HomeNavIndex.approval),
                        title: TransactionUiText.usageFlowDiagramNodeApproval,
                        navigable: widget.onNavigateToNav != null,
                        onTap: widget.onNavigateToNav == null
                            ? null
                            : () =>
                                widget.onNavigateToNav!(HomeNavIndex.approval),
                      ),
                      _FlowArrow(c: c),
                      _FlowNodeCard(
                        c: c,
                        primary: primary,
                        leadingIcon:
                            menu.iconForNavIndex(HomeNavIndex.expense),
                        title: TransactionUiText.usageFlowDiagramNodeExpense,
                        navigable: widget.onNavigateToNav != null,
                        onTap: widget.onNavigateToNav == null
                            ? null
                            : () =>
                                widget.onNavigateToNav!(HomeNavIndex.expense),
                      ),
                      _FlowArrow(c: c),
                      _FlowNodeCard(
                        c: c,
                        primary: primary,
                        leadingIcon:
                            menu.iconForNavIndex(HomeNavIndex.reports),
                        title: TransactionUiText.usageFlowDiagramNodeReports,
                        navigable: widget.onNavigateToNav != null,
                        onTap: widget.onNavigateToNav == null
                            ? null
                            : () =>
                                widget.onNavigateToNav!(HomeNavIndex.reports),
                      ),
                      _FlowArrow(c: c),
                      _FlowNodeCard(
                        c: c,
                        primary: primary,
                        leadingIcon: Icons.cloud_sync_outlined,
                        title: TransactionUiText.usageFlowDiagramNodeSync,
                        navigable: false,
                        onTap: null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _FlowArrow extends StatelessWidget {
  const _FlowArrow({required this.c});

  final AppColors c;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Icon(
          Icons.arrow_downward_rounded,
          color: c.textHint,
          size: 22,
        ),
      ),
    );
  }
}

class _FlowNodeCard extends StatelessWidget {
  const _FlowNodeCard({
    required this.c,
    required this.primary,
    required this.leadingIcon,
    required this.title,
    required this.navigable,
    required this.onTap,
    this.compact = false,
  });

  final AppColors c;
  final Color primary;
  final IconData leadingIcon;
  final String title;
  final bool navigable;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final border = Border.all(
      color: navigable ? primary.withValues(alpha: 0.45) : c.cardBorder,
      width: navigable ? 1.2 : 1,
    );
    final child = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : AppTheme.sp12,
        vertical: compact ? 10 : AppTheme.sp12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            leadingIcon,
            size: compact ? 22 : 26,
            color: navigable ? primary : c.textSecondary,
          ),
          SizedBox(height: compact ? 6 : 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: compact ? 12.5 : 14,
              fontWeight: FontWeight.w600,
              height: 1.25,
              fontFamily: 'Kanit',
            ),
          ),
          if (navigable) ...[
            SizedBox(height: compact ? 4 : 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.touch_app_outlined, size: 14, color: primary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    TransactionUiText.usageFlowDiagramTapHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: primary,
                      fontSize: compact ? 10.5 : 11.5,
                      fontFamily: 'Kanit',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    return Material(
      color: c.cardWhite,
      borderRadius: BorderRadius.circular(AppTheme.r12),
      child: navigable && onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppTheme.r12),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.r12),
                  border: border,
                ),
                child: child,
              ),
            )
          : Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.r12),
                border: border,
              ),
              child: child,
            ),
    );
  }
}
