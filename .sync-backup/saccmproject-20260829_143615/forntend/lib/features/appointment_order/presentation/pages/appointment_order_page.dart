// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/utils/fiscal_year.dart';
import 'package:saccm/features/appointment_order/data/datasources/appointment_order_local_data_source.dart';
import 'package:saccm/features/appointment_order/presentation/widgets/appointment_order_form_sheet.dart';
import 'package:saccm/widgets/widgets.dart';

/// บันทึกคำสั่งแต่งตั้งกรรมการเก็บรักษาเงิน / เจ้าหน้าที่การเงิน — local-first (SQLite)
class AppointmentOrderPage extends StatefulWidget {
  const AppointmentOrderPage({super.key});

  @override
  State<AppointmentOrderPage> createState() => _AppointmentOrderPageState();
}

class _AppointmentOrderPageState extends State<AppointmentOrderPage> {
  static const String _fontFamily = 'Kanit';
  static const double _maxResponsiveFormWidth = 1440;

  final _ds = AppointmentOrderLocalDataSource();
  final _fyCtrl = TextEditingController();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];

  @override
  void initState() {
    super.initState();
    _fyCtrl.text = FiscalYear.currentBuddhist().toString();
    _load();
  }

  @override
  void dispose() {
    _fyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _rows = await _ds.listOrders(fiscalYear: _fyCtrl.text.trim());
    } catch (e) {
      _error = e.toString();
      _rows = const [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm({String? id}) async {
    final ok = await showAppointmentOrderFormSheet(context, editId: id);
    if (ok == true && mounted) await _load();
  }

  Future<void> _confirmDelete(Map<String, dynamic> row) async {
    final id = row['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final docno = row['docno']?.toString() ?? '';
    final c = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.r16),
        ),
        title: TransactionUiText.confirmDelete,
        message:
            '${TransactionUiText.appointmentOrderDocNoLabel}: $docno\n${TransactionUiText.confirmDeleteQuestion}',
        cancelText: TransactionUiText.cancel,
        confirmText: TransactionUiText.deleteItem,
        confirmColor: c.expenseRed,
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _ds.deleteOrder(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(TransactionUiText.deleteSuccess)),
        );
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty) return TransactionUiText.unspecified;
    return ThaiDateFormatter.format(raw, fallback: raw);
  }

  String _statusLabel(String? s) {
    switch (s) {
      case 'cancelled':
        return TransactionUiText.appointmentOrderStatusCancelled;
      case 'active':
      default:
        return TransactionUiText.appointmentOrderStatusActive;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Scaffold(
        backgroundColor: c.background,
        appBar: _buildAppBar(c),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppTheme.sp16),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: _maxResponsiveFormWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TransactionFormHeader(
                        icon: Icons.assignment_ind_outlined,
                        iconColor: scheme.primary,
                        iconBgColor: c.iconBgIncome,
                        title: TransactionUiText.appointmentOrderPageTitle,
                        subtitle:
                            TransactionUiText.appointmentOrderMenuSubtitle,
                        quickHint:
                            TransactionUiText.appointmentOrderMembersSection,
                        hintAccentColor: scheme.primary,
                        hintBorderColor: c.cardBorder,
                        textPrimaryColor: c.textPrimary,
                        showQuickHint: false,
                      ),
                      const SizedBox(height: AppTheme.sp16),
                      _buildFilterCard(c),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: _maxResponsiveFormWidth,
                  ),
                  child: _buildBody(c, scheme),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openForm(),
          backgroundColor: c.navy,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add, size: 20),
          label: const Text(
            TransactionUiText.addItem,
            style:
                TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppColors c) {
    return AppBar(
      toolbarHeight: 52,
      title: Text(
        TransactionUiText.appointmentOrderPageTitle,
        style: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: c.textPrimary,
        ),
      ),
      centerTitle: true,
      backgroundColor: c.cardWhite,
      foregroundColor: c.textPrimary,
      elevation: 0,
      actions: [
        IconButton(
          tooltip: TransactionUiText.retry,
          onPressed: _loading ? null : _load,
          icon: Icon(Icons.refresh_rounded, color: c.textSecondary),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: c.cardBorder),
      ),
    );
  }

  Widget _buildFilterCard(AppColors c) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.sp16),
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r16),
        border: Border.all(color: c.cardBorder),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final isWide = box.maxWidth >= 560;
          final yearField = AppInput(
            label: TransactionUiText.appointmentOrderFiscalYearLabel,
            controller: _fyCtrl,
            action: const AppInputAction.number(allowDecimal: false),
          );
          final viewButton = AppButton.primary(
            label: TransactionUiText.view,
            icon: const Icon(Icons.search_rounded, size: 18),
            fullWidth: !isWide,
            onPressed: _load,
          );
          if (!isWide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                yearField,
                const SizedBox(height: AppTheme.sp8),
                viewButton,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: yearField),
              const SizedBox(width: AppTheme.sp12),
              SizedBox(width: 160, child: viewButton),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(AppColors c, ColorScheme scheme) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: scheme.primary));
    }
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: TextStyle(color: c.expenseRed, fontFamily: _fontFamily),
        ),
      );
    }
    if (_rows.isEmpty) {
      return Center(
        child: Text(
          TransactionUiText.registerNoData,
          style: TextStyle(color: c.textSecondary, fontFamily: _fontFamily),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.sp16,
        0,
        AppTheme.sp16,
        88,
      ),
      itemCount: _rows.length,
      itemBuilder: (ctx, i) => _buildOrderCard(_rows[i], c),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> row, AppColors c) {
    final id = row['id']?.toString() ?? '';
    final type = row['order_type']?.toString() ?? '';
    final mc = row['member_count'];
    final count = mc is int ? mc : int.tryParse('$mc') ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.sp12),
      color: c.cardWhite,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.r16),
        side: BorderSide(color: c.cardBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.r16),
        onTap: () => _openForm(id: id),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.sp16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row['docno']?.toString() ?? '-',
                      style: TextStyle(
                        fontFamily: _fontFamily,
                        fontWeight: FontWeight.w700,
                        color: c.navy,
                      ),
                    ),
                  ),
                  Text(
                    _statusLabel(row['status']?.toString()),
                    style: TextStyle(
                      fontFamily: _fontFamily,
                      fontSize: 12,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.sp8),
              Text(
                appointmentOrderTypeLabelUi(type),
                style: TextStyle(
                  fontFamily: _fontFamily,
                  fontSize: 13,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: AppTheme.sp4),
              Text(
                row['subject']?.toString() ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: _fontFamily,
                  fontSize: 12,
                  color: c.textSecondary,
                ),
              ),
              const SizedBox(height: AppTheme.sp8),
              Row(
                children: [
                  Text(
                    '${TransactionUiText.date}: ${_fmtDate(row['docdate']?.toString())}',
                    style: TextStyle(
                      fontFamily: _fontFamily,
                      fontSize: 11,
                      color: c.textHint,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$count ${TransactionUiText.items}',
                    style: TextStyle(
                      fontFamily: _fontFamily,
                      fontSize: 11,
                      color: c.textHint,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: c.expenseRed,
                      size: 22,
                    ),
                    onPressed: () => _confirmDelete(row),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
