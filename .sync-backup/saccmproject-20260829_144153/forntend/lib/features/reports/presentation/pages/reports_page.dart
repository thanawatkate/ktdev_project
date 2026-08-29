// ignore_for_file: use_build_context_synchronously
import 'dart:async';

import 'package:saccm/features/setting/data/datasources/school_profile_local_data_source.dart';
import 'package:saccm/features/setting/domain/entities/school_profile.dart';
import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/services/app_notification_service.dart';
import 'package:saccm/core/services/report_sync_status_service.dart';
import 'package:saccm/core/utils/fiscal_year.dart';
import 'package:saccm/core/utils/pdf_print.dart';
import 'package:saccm/core/utils/user_error_message.dart';
import 'package:saccm/features/license/license_mode.dart';
import 'package:saccm/features/reports/data/repositories/reports_repository_offline.dart';
import 'package:saccm/features/reports/presentation/services/reports_csv_export_service.dart';
import 'package:saccm/features/reports/presentation/services/reports_excel_export_service.dart';
import 'package:saccm/features/reports/presentation/services/reports_pdf_export_service.dart';
import 'package:saccm/features/reports/presentation/widgets/annual_summary_tab.dart';
import 'package:saccm/features/reports/presentation/widgets/bank_reconciliation_tab.dart';
import 'package:saccm/features/reports/presentation/widgets/daily_balance_tab.dart';
import 'package:saccm/features/reports/presentation/widgets/daily_closing_tab.dart';
import 'package:saccm/features/reports/presentation/widgets/daily_cash_summary_tab.dart';
import 'package:saccm/features/reports/presentation/widgets/loan_outstanding_tab.dart';
import 'package:saccm/features/reports/presentation/widgets/outstanding_cheques_tab.dart';
import 'package:saccm/features/reports/presentation/widgets/reports_filter_bar.dart';
import 'package:saccm/features/reports/presentation/widgets/reports_lazy_tab.dart';
import 'package:saccm/features/reports/presentation/widgets/reports_paper_canvas.dart';
import 'package:saccm/features/reports/presentation/widgets/reports_primary_tabs.dart';
import 'package:saccm/features/reports/presentation/widgets/reports_tab_actions.dart';
import 'package:saccm/features/reports/presentation/widgets/reports_tab_selector.dart';
import 'package:saccm/widgets/feedback/app_busy_backdrop.dart';
import 'package:saccm/widgets/layout/embedded_home_scaffold.dart';
import 'package:saccm/widgets/offline_status_widgets.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({
    super.key,
    this.embeddedInHome = false,
    this.initialTabIndex,
  });
  final bool embeddedInHome;

  /// แท็บเริ่มต้น (0-11) — 9 = ปิดวัน
  final int? initialTabIndex;
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage>
    with SingleTickerProviderStateMixin {
  static const String _fontFamily = 'Kanit';

  final SchoolProfileLocalDataSource _schoolProfileDs =
      SchoolProfileLocalDataSourceImpl();
  final ReportsRepository _reportsRepository = ReportsRepository();
  final ReportsCsvExportService _csvExportService = ReportsCsvExportService();
  final ReportsExcelExportService _excelExportService =
      ReportsExcelExportService();
  final ReportsPdfExportService _pdfExportService = ReportsPdfExportService();
  late TabController _tabController;

  final _yearCtrl = TextEditingController();

  bool _isLoading = false;
  String _busyMessage = TransactionUiText.reportsBusyLoading;
  bool _exportingCsv = false;
  bool _exportingExcel = false;
  bool _printingPdf = false;
  bool _isSyncingBundle = false;
  bool _isRefreshingLocal = false;
  int _loadRequestId = 0;
  String? _loadedFiscalYear;
  SchoolProfile _schoolProfile = const SchoolProfile();

  // Summary
  Map<String, dynamic>? _summary;

  // Monthly charts data
  List _incomeByMonth = [], _expenseByMonth = [];

  // Budget source
  List _budgetData = [];

  // Trial balance
  Map<String, dynamic>? _trialBalance;

  // Budget remaining
  List _budgetRemaining = [];

  // Annual summary
  Map<String, dynamic>? _annualSummary;

  void _safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  Map<String, dynamic>? _mapFromJson(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  void _applyReportBundle(Map<String, dynamic> bundle) {
    _summary = _mapFromJson(bundle['summary']);
    _incomeByMonth = List.from(bundle['incomeByMonth'] as List? ?? const []);
    _expenseByMonth = List.from(bundle['expenseByMonth'] as List? ?? const []);
    _budgetData = List.from(bundle['budgetData'] as List? ?? const []);
    _trialBalance = _mapFromJson(bundle['trialBalance']);
    _budgetRemaining =
        List.from(bundle['budgetRemaining'] as List? ?? const []);
    _annualSummary = _mapFromJson(bundle['annualSummary']);
  }

  Future<void> _exportBudgetSourceCsv() async {
    if (_exportingCsv || _budgetData.isEmpty) return;
    _safeSetState(() => _exportingCsv = true);
    try {
      final outcome = await _csvExportService.exportBudgetSourceCsv(
        schoolProfile: _schoolProfile,
        fiscalYearText: _yearCtrl.text.trim(),
        budgetData: _budgetData,
      );
      if (mounted) {
        AppNotificationService.instance.showSuccess(
          TransactionUiText.success,
          outcome.userMessage,
          duration: Duration(seconds: outcome.displaySeconds),
        );
      }
    } catch (e) {
      if (mounted) {
        AppNotificationService.instance.showError(
          TransactionUiText.error,
          toUserErrorMessage(e),
        );
      }
    } finally {
      _safeSetState(() => _exportingCsv = false);
    }
  }

  Future<void> _exportBudgetSourceExcel() async {
    if (_exportingExcel || _budgetData.isEmpty) return;
    _safeSetState(() => _exportingExcel = true);
    try {
      final outcome = await _excelExportService.exportBudgetSourceExcel(
        schoolProfile: _schoolProfile,
        fiscalYearText: _yearCtrl.text.trim(),
        budgetData: _budgetData,
      );
      if (mounted) {
        AppNotificationService.instance.showSuccess(
          TransactionUiText.success,
          outcome.userMessage,
          duration: Duration(seconds: outcome.displaySeconds),
        );
      }
    } catch (e) {
      if (mounted) {
        AppNotificationService.instance.showError(
          TransactionUiText.error,
          toUserErrorMessage(e),
        );
      }
    } finally {
      _safeSetState(() => _exportingExcel = false);
    }
  }

  @override
  void initState() {
    super.initState();
    final initial = (widget.initialTabIndex ?? 0).clamp(0, reportTabCount - 1);
    _tabController = TabController(
        length: reportTabCount, vsync: this, initialIndex: initial);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _safeSetState(() {});
        _prefetchAdjacentTabs();
      }
    });
    _yearCtrl.text = FiscalYear.currentBuddhist().toString();
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _yearCtrl.dispose();
    _reportsRepository.dispose();
    super.dispose();
  }

  Future<void> _loadAll({bool forceRecompute = false}) async {
    final fy = _yearCtrl.text.trim();
    if (_isLoading && fy == _loadedFiscalYear && !forceRecompute) return;
    final requestId = ++_loadRequestId;
    final hadDataBefore = _loadedFiscalYear == fy && _summary != null;
    if (!hadDataBefore) {
      _safeSetState(() {
        _isLoading = true;
        _busyMessage = TransactionUiText.reportsBusyLoadingLocal;
      });
    }
    if (fy.isEmpty) {
      _safeSetState(() => _isLoading = false);
      return;
    }

    late final SchoolProfile profile;
    Map<String, dynamic>? cached;
    try {
      final results = await Future.wait<Object?>([
        _schoolProfileDs.load(),
        _reportsRepository.loadDisplayBundle(fy),
      ]);
      if (!mounted || requestId != _loadRequestId) return;
      profile = results[0]! as SchoolProfile;
      cached = results[1] as Map<String, dynamic>?;
    } catch (_) {
      if (!mounted || requestId != _loadRequestId) return;
      _safeSetState(() => _isLoading = false);
      return;
    }

    _schoolProfile = profile;
    var hadCached = false;
    if (cached != null) {
      hadCached = true;
      _safeSetState(() {
        _applyReportBundle(cached!);
        _loadedFiscalYear = fy;
        _isLoading = false;
      });
    }

    if (!hadCached || forceRecompute) {
      _safeSetState(() => _isRefreshingLocal = true);
      try {
        final local = await _reportsRepository.loadLocalBundle(fy);
        if (mounted && requestId == _loadRequestId) {
          _safeSetState(() {
            _applyReportBundle(local);
            _loadedFiscalYear = fy;
            _isLoading = false;
          });
        }
      } catch (_) {
        if (!hadCached && mounted && requestId == _loadRequestId) {
          AppNotificationService.instance.showError(
            TransactionUiText.error,
            TransactionUiText.reportsLoadFailedPrefix,
          );
        }
      } finally {
        if (mounted && requestId == _loadRequestId) {
          _safeSetState(() => _isRefreshingLocal = false);
        }
      }
    }

    if (!mounted || requestId != _loadRequestId) return;
    _safeSetState(() => _isLoading = false);

    unawaited(
      _syncBundleInBackground(
        fy,
        hadCached: hadCached,
        requestId: requestId,
      ),
    );
  }

  Future<void> _syncBundleInBackground(
    String fy, {
    required bool hadCached,
    required int requestId,
  }) async {
    if (_isSyncingBundle) return;
    if (!await LicenseMode.canSyncOnline()) return;
    _isSyncingBundle = true;
    ReportSyncStatusService.instance.beginSync();
    try {
      await _reportsRepository.syncAndLoadBundle(fy);
      if (!mounted || requestId != _loadRequestId) return;
      final bundle = await _reportsRepository.loadCachedBundle(fy);
      if (bundle == null) return;
      if (!mounted || requestId != _loadRequestId) return;
      _safeSetState(() {
        _applyReportBundle(bundle);
        _loadedFiscalYear = fy;
      });
    } catch (e) {
      if (mounted && !hadCached) {
        AppNotificationService.instance.showError(
          TransactionUiText.error,
          toUserErrorMessage(e),
        );
      }
    } finally {
      _isSyncingBundle = false;
      ReportSyncStatusService.instance.endSync();
    }
  }

  bool _shouldMaterializeTab(int index) {
    final current = _tabController.index;
    return index == current ||
        index == current - 1 ||
        index == current + 1;
  }

  void _prefetchAdjacentTabs() {
    _safeSetState(() {});
  }

  bool get _showInitialLoader =>
      _isLoading && _loadedFiscalYear == null && _summary == null;

  Widget _buildLazyTab({
    required int index,
    required WidgetBuilder builder,
  }) {
    return ReportsLazyTab(
      key: ValueKey('report-tab-$index'),
      shouldMaterialize: _shouldMaterializeTab(index),
      builder: builder,
    );
  }

  Future<void> _exportAnnualSummaryCsv() async {
    if (_exportingCsv || _annualSummary == null) return;
    _safeSetState(() => _exportingCsv = true);
    try {
      final outcome = await _csvExportService.exportAnnualSummaryCsv(
        schoolProfile: _schoolProfile,
        data: _annualSummary!,
        fiscalYearText: _yearCtrl.text.trim(),
      );
      if (mounted) {
        AppNotificationService.instance.showSuccess(
          TransactionUiText.success,
          outcome.userMessage,
          duration: Duration(seconds: outcome.displaySeconds),
        );
      }
    } catch (e) {
      if (mounted) {
        AppNotificationService.instance.showError(
          TransactionUiText.error,
          toUserErrorMessage(e),
        );
      }
    } finally {
      _safeSetState(() => _exportingCsv = false);
    }
  }

  Future<void> _exportAnnualSummaryExcel() async {
    if (_exportingExcel || _annualSummary == null) return;
    _safeSetState(() => _exportingExcel = true);
    try {
      final outcome = await _excelExportService.exportAnnualSummaryExcel(
        schoolProfile: _schoolProfile,
        data: _annualSummary!,
        fiscalYearText: _yearCtrl.text.trim(),
      );
      if (mounted) {
        AppNotificationService.instance.showSuccess(
          TransactionUiText.success,
          outcome.userMessage,
          duration: Duration(seconds: outcome.displaySeconds),
        );
      }
    } catch (e) {
      if (mounted) {
        AppNotificationService.instance.showError(
          TransactionUiText.error,
          toUserErrorMessage(e),
        );
      }
    } finally {
      _safeSetState(() => _exportingExcel = false);
    }
  }

  Future<void> _printAnnualSummaryPdf() async {
    if (_printingPdf || _annualSummary == null) return;
    _safeSetState(() => _printingPdf = true);
    try {
      final doc = await _pdfExportService.buildAnnualSummaryPdf(
        schoolProfile: _schoolProfile,
        data: _annualSummary!,
        fiscalYearText: _yearCtrl.text.trim(),
      );
      if (!mounted) return;
      final outcome = await printPdfBytes(
        context: context,
        bytes: doc.bytes,
        filename: doc.filename,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(pdfPrintOutcomeMessage(outcome))),
      );
    } catch (e) {
      if (mounted) {
        AppNotificationService.instance.showError(
          TransactionUiText.error,
          toUserErrorMessage(e),
        );
      }
    } finally {
      _safeSetState(() => _printingPdf = false);
    }
  }

  Widget _appBarExportMenu({
    required bool enabled,
    required VoidCallback onCsv,
    required VoidCallback onExcel,
  }) {
    final exporting = _exportingCsv || _exportingExcel;
    if (exporting) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return PopupMenuButton<ReportsExportFormat>(
      tooltip: TransactionUiText.reportsExportTooltip,
      enabled: enabled && !exporting,
      onSelected: (format) {
        switch (format) {
          case ReportsExportFormat.csv:
            onCsv();
          case ReportsExportFormat.excel:
            onExcel();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: ReportsExportFormat.csv,
          child: Text(TransactionUiText.exportCsv),
        ),
        PopupMenuItem(
          value: ReportsExportFormat.excel,
          child: Text(TransactionUiText.exportExcel),
        ),
      ],
      icon: const Icon(Icons.download_outlined),
    );
  }

  List<Widget> _reportAppBarActions() {
    final idx = _tabController.index;
    final actions = <Widget>[];

    if (idx == 2) {
      actions.add(
        _appBarExportMenu(
          enabled: _budgetData.isNotEmpty,
          onCsv: _exportBudgetSourceCsv,
          onExcel: _exportBudgetSourceExcel,
        ),
      );
    }

    if (idx == 5) {
      actions.add(
        IconButton(
          onPressed: _printingPdf || _annualSummary == null
              ? null
              : _printAnnualSummaryPdf,
          tooltip: TransactionUiText.reportsPrintPdfTooltip,
          icon: _printingPdf
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.print_outlined),
        ),
      );
      actions.add(
        _appBarExportMenu(
          enabled: _annualSummary != null,
          onCsv: _exportAnnualSummaryCsv,
          onExcel: _exportAnnualSummaryExcel,
        ),
      );
    }

    actions.add(
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: IconButton(
          onPressed: () => _loadAll(forceRecompute: true),
          icon: const Icon(Icons.refresh),
        ),
      ),
    );
    return actions;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final useWideReportHeader = screenWidth >= 900;
    final reportHeaderHeight =
        useWideReportHeader ? 152.0 : (screenWidth < 520 ? 320.0 : 232.0);
    final reportsTitle = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          TransactionUiText.financeReport,
          style: TextStyle(
            color: c.textPrimary,
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        if (_schoolProfile.name.isNotEmpty)
          Text(
            _schoolProfile.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: c.textSecondary,
              fontFamily: _fontFamily,
              fontSize: 12,
            ),
          ),
      ],
    );

    final reportsTabsAndFilters = useWideReportHeader
        ? Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: ReportsYearFilterBar(
                      controller: _yearCtrl,
                      onSubmit: _loadAll,
                    ),
                  ),
                  SizedBox(
                    width: 620,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 16, 8),
                      child: ReportsTabSelector(
                        currentIndex: _tabController.index,
                        onChanged: _tabController.animateTo,
                        showHint: false,
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: ReportsSelectedReportHint(
                  currentIndex: _tabController.index,
                ),
              ),
            ],
          )
        : Column(
            children: [
              ReportsYearFilterBar(
                controller: _yearCtrl,
                onSubmit: _loadAll,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: ReportsTabSelector(
                  currentIndex: _tabController.index,
                  onChanged: _tabController.animateTo,
                ),
              ),
            ],
          );

    return AppBusyBackdrop(
      isBusy: _isLoading,
      message: _busyMessage,
      child: EmbeddedHomeScaffold(
        embeddedInHome: widget.embeddedInHome,
        backgroundColor: c.background,
        standaloneAppBar: AppBar(
          toolbarHeight: 52,
          title: reportsTitle,
          centerTitle: true,
          backgroundColor: c.cardWhite,
          elevation: 0,
          actions: [
            if (!widget.embeddedInHome) const ReportSyncStatusBadge(),
            ..._reportAppBarActions(),
          ],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(reportHeaderHeight),
            child: reportsTabsAndFilters,
          ),
        ),
        embeddedAppBar: AppBar(
          toolbarHeight: 44,
          backgroundColor: c.cardWhite,
          elevation: 0,
          actions: _reportAppBarActions(),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(reportHeaderHeight),
            child: reportsTabsAndFilters,
          ),
        ),
        body: _showInitialLoader
            ? Center(child: CircularProgressIndicator(color: scheme.primary))
            : Column(
                children: [
                  if (_isRefreshingLocal)
                    LinearProgressIndicator(
                      minHeight: 2,
                      color: scheme.primary,
                      backgroundColor: c.cardBorder,
                    ),
                  Expanded(
                    child: ReportsPaperCanvas(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildLazyTab(
                            index: 0,
                            builder: (_) =>
                                ReportsOverviewTab(summary: _summary),
                          ),
                          _buildLazyTab(
                            index: 1,
                            builder: (_) => ReportsMonthlyTab(
                              incomeByMonth: _incomeByMonth,
                              expenseByMonth: _expenseByMonth,
                              fiscalYearText: _yearCtrl.text.trim(),
                            ),
                          ),
                          _buildLazyTab(
                            index: 2,
                            builder: (_) => ReportsBudgetSourceTab(
                              budgetData: _budgetData,
                            ),
                          ),
                          _buildLazyTab(
                            index: 3,
                            builder: (_) => ReportsTrialBalanceTab(
                              trialBalance: _trialBalance,
                            ),
                          ),
                          _buildLazyTab(
                            index: 4,
                            builder: (_) => ReportsBudgetRemainingTab(
                              budgetRemaining: _budgetRemaining,
                            ),
                          ),
                          _buildLazyTab(
                            index: 5,
                            builder: (_) => AnnualSummaryTab(
                              data: _annualSummary,
                              fiscalYearText: _yearCtrl.text.trim(),
                            ),
                          ),
                          _buildLazyTab(
                            index: 6,
                            builder: (_) => DailyBalanceTab(
                              repository: _reportsRepository,
                            ),
                          ),
                          _buildLazyTab(
                            index: 7,
                            builder: (_) => DailyCashSummaryTab(
                              repository: _reportsRepository,
                            ),
                          ),
                          _buildLazyTab(
                            index: 8,
                            builder: (_) => BankReconciliationTab(
                              repository: _reportsRepository,
                            ),
                          ),
                          _buildLazyTab(
                            index: 9,
                            builder: (_) => DailyClosingTab(
                              repository: _reportsRepository,
                            ),
                          ),
                          _buildLazyTab(
                            index: 10,
                            builder: (_) => const LoanOutstandingTab(),
                          ),
                          _buildLazyTab(
                            index: 11,
                            builder: (_) => OutstandingChequesTab(
                              repository: _reportsRepository,
                              fiscalYearText: _yearCtrl.text.trim(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
