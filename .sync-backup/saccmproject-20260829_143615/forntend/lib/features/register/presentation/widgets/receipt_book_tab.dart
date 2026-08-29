// ignore_for_file: use_build_context_synchronously
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/di/service_locator.dart';
import 'package:saccm/core/utils/fiscal_year.dart';
import 'package:saccm/features/register/data/repositories/receipt_book_register_repository_offline.dart';
import 'package:saccm/widgets/widgets.dart';
import '_simple_register_tab_base.dart';

@Deprecated('Use ReceiptBookRegisterTab instead.')
class ReceiptBookTab extends StatelessWidget {
  const ReceiptBookTab({super.key, required this.dio});

  final Dio dio;

  @override
  Widget build(BuildContext context) => ReceiptBookRegisterTab(dio: dio);
}

class ReceiptBookRegisterTab extends StatefulWidget {
  const ReceiptBookRegisterTab({super.key, required this.dio});

  final Dio dio;

  @override
  State<ReceiptBookRegisterTab> createState() => _ReceiptBookRegisterTabState();
}

class _ReceiptBookRegisterTabState extends State<ReceiptBookRegisterTab>
    with AutomaticKeepAliveClientMixin {
  late final ReceiptBookRegisterRepositoryOffline _repository =
      ServiceLocator.instance.get<ReceiptBookRegisterRepositoryOffline>();
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];
  int _fiscalYear = FiscalYear.currentBuddhist();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _repository.listReceiptBooks(
        fiscalYear: _fiscalYear.toString(),
      );
      _rows = rows;
    } catch (e) {
      _error = e.toString();
      _rows = const [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _popupActionButton({
    required String label,
    required VoidCallback onPressed,
    required AppColors colors,
    required bool primary,
  }) {
    final bg = primary ? colors.navy : colors.cardWhite;
    final fg = primary ? Colors.white : colors.textPrimary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        width: 96,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppTheme.r12),
          border: primary ? null : Border.all(color: colors.cardBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontFamily: 'Kanit',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _addReceiptBookButton(AppColors colors) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _showAddBookDialog,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.sp16),
        decoration: BoxDecoration(
          color: colors.navy,
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, color: Colors.white),
            SizedBox(width: AppTheme.sp8),
            Text(
              TransactionUiText.registerReceiptBookAddFab,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Kanit',
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _usedCount(Map<String, dynamic> row) {
    return int.tryParse(row['used_count']?.toString() ?? '') ?? 0;
  }

  String? _requiredReceiptNoRangeValidator({
    required String? value,
    required TextEditingController startCtrl,
    required TextEditingController endCtrl,
  }) {
    if (value == null || value.trim().isEmpty) {
      return TransactionUiText.registerFieldRequired;
    }
    if (startCtrl.text.trim().isEmpty || endCtrl.text.trim().isEmpty) {
      return null;
    }
    return ReceiptBookRegisterRepositoryOffline.validateReceiptRange(
      startNo: startCtrl.text.trim(),
      endNo: endCtrl.text.trim(),
    );
  }

  Future<void> _showAddBookDialog() async {
    final formKey = GlobalKey<FormState>();
    final startCtrl = TextEditingController();
    final endCtrl = TextEditingController();
    final fromCtrl = TextEditingController();
    final remarkCtrl = TextEditingController();
    final fyCtrl = TextEditingController(text: _fiscalYear.toString());
    String type = 'บร.';
    var autoBookNo = await _repository.suggestNextBookNo(
      fiscalYear: fyCtrl.text.trim(),
      receiptType: type,
    );
    final bookNoCtrl = TextEditingController(text: autoBookNo);

    Future<void> refreshAutoBookNo(
      StateSetter setDialogState, {
      bool force = false,
    }) async {
      final next = await _repository.suggestNextBookNo(
        fiscalYear: fyCtrl.text.trim(),
        receiptType: type,
      );
      final current = bookNoCtrl.text.trim();
      final shouldReplace = force || current.isEmpty || current == autoBookNo;
      autoBookNo = next;
      if (shouldReplace) {
        setDialogState(() {
          bookNoCtrl.text = next;
          bookNoCtrl.selection = TextSelection.collapsed(offset: next.length);
        });
      }
    }

    try {
      final ok = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: false,
        backgroundColor: Colors.transparent,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final c = AppColors.of(context);
              final maxHeight = MediaQuery.sizeOf(context).height - 32;
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.sp16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 460,
                        maxHeight: maxHeight > 360 ? maxHeight : 360,
                      ),
                      child: Material(
                        color: c.cardWhite,
                        elevation: 12,
                        shadowColor: Colors.black26,
                        borderRadius: BorderRadius.circular(AppTheme.r16),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                AppTheme.sp16,
                                AppTheme.sp8,
                                AppTheme.sp8,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      TransactionUiText
                                          .registerReceiptBookAddTitle,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontFamily: 'Kanit',
                                            fontWeight: FontWeight.w700,
                                            color: c.textPrimary,
                                          ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: TransactionUiText.cancel,
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, false),
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                                ],
                              ),
                            ),
                            Flexible(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  0,
                                  20,
                                  AppTheme.sp16,
                                ),
                                child: Form(
                                  key: formKey,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      AppInput(
                                        label: TransactionUiText
                                            .registerReceiptBookColBookNo,
                                        hint: TransactionUiText
                                            .registerReceiptBookBookNoHint,
                                        controller: bookNoCtrl,
                                        action: const AppInputAction.text(),
                                        required: true,
                                        validator: (v) =>
                                            _requiredReceiptNoRangeValidator(
                                          value: v,
                                          startCtrl: startCtrl,
                                          endCtrl: endCtrl,
                                        ),
                                      ),
                                      const SizedBox(height: AppTheme.sp12),
                                      BuddhistYearField.picker(
                                        controller: fyCtrl,
                                        required: true,
                                        maxYear: BuddhistYearField.toBuddhist(
                                            DateTime.now().year + 10),
                                        onChanged: (_) =>
                                            refreshAutoBookNo(setDialogState),
                                      ),
                                      const SizedBox(height: AppTheme.sp12),
                                      AppDropdownField<String>(
                                        label: TransactionUiText
                                            .registerReceiptBookDialogReceiptType,
                                        density: AppDropdownDensity.compact,
                                        value: type,
                                        items: const [
                                          AppDropdownItem(
                                            value: 'บร.',
                                            label: TransactionUiText
                                                .registerReceiptBookTypeBr,
                                          ),
                                          AppDropdownItem(
                                            value: 'บค.',
                                            label: TransactionUiText
                                                .registerReceiptBookTypeBk,
                                          ),
                                          AppDropdownItem(
                                            value: 'บฝ.',
                                            label: TransactionUiText
                                                .registerReceiptBookTypeBf,
                                          ),
                                        ],
                                        onChanged: (v) => setDialogState(() {
                                          type = v ?? type;
                                          refreshAutoBookNo(setDialogState);
                                        }),
                                      ),
                                      const SizedBox(height: AppTheme.sp12),
                                      AppInput(
                                        label: TransactionUiText
                                            .registerReceiptBookColStartNo,
                                        controller: startCtrl,
                                        action: const AppInputAction.text(),
                                        required: true,
                                        validator: (v) =>
                                            _requiredReceiptNoRangeValidator(
                                          value: v,
                                          startCtrl: startCtrl,
                                          endCtrl: endCtrl,
                                        ),
                                      ),
                                      const SizedBox(height: AppTheme.sp12),
                                      AppInput(
                                        label: TransactionUiText
                                            .registerReceiptBookColEndNo,
                                        controller: endCtrl,
                                        action: const AppInputAction.text(),
                                        required: true,
                                        validator: (v) =>
                                            _requiredReceiptNoRangeValidator(
                                          value: v,
                                          startCtrl: startCtrl,
                                          endCtrl: endCtrl,
                                        ),
                                      ),
                                      const SizedBox(height: AppTheme.sp12),
                                      AppInput(
                                        label: TransactionUiText
                                            .registerReceiptBookReceivedFrom,
                                        controller: fromCtrl,
                                        action: const AppInputAction.text(),
                                      ),
                                      const SizedBox(height: AppTheme.sp12),
                                      AppInput(
                                        label: TransactionUiText.remark,
                                        controller: remarkCtrl,
                                        action: const AppInputAction.text(),
                                        minLines: 2,
                                        maxLines: 4,
                                        textInputAction:
                                            TextInputAction.newline,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Divider(height: 1, color: c.cardBorder),
                            Padding(
                              padding: const EdgeInsets.all(AppTheme.sp16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  _popupActionButton(
                                    label: TransactionUiText.cancel,
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, false),
                                    colors: c,
                                    primary: false,
                                  ),
                                  const SizedBox(width: AppTheme.sp12),
                                  _popupActionButton(
                                    label: TransactionUiText.save,
                                    onPressed: () {
                                      if (formKey.currentState?.validate() ==
                                          true) {
                                        Navigator.pop(dialogContext, true);
                                      }
                                    },
                                    colors: c,
                                    primary: true,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

      if (ok != true) return;

      final body = {
        'book_no': bookNoCtrl.text.trim(),
        'receipt_type': type,
        'start_no': startCtrl.text.trim(),
        'end_no': endCtrl.text.trim(),
        'fiscal_year': fyCtrl.text.trim(),
        'received_from': fromCtrl.text.trim(),
        'remark': remarkCtrl.text.trim(),
      };
      final result = await _repository.createReceiptBook(body);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.synced
                ? TransactionUiText.saveSuccess
                : TransactionUiText.registerReceiptBookSavedLocal,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final errorText = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${TransactionUiText.createFailed}: $errorText')),
      );
    } finally {
      bookNoCtrl.dispose();
      startCtrl.dispose();
      endCtrl.dispose();
      fromCtrl.dispose();
      remarkCtrl.dispose();
      fyCtrl.dispose();
    }
  }

  Future<void> _showEditBookDialog(Map<String, dynamic> row) async {
    final id = row['id']?.toString() ?? '';
    if (id.isEmpty) return;

    final formKey = GlobalKey<FormState>();
    final bookNoCtrl = TextEditingController(
      text: row['book_no']?.toString() ?? '',
    );
    final startCtrl = TextEditingController(
      text: row['start_no']?.toString() ?? '',
    );
    final endCtrl = TextEditingController(
      text: row['end_no']?.toString() ?? '',
    );
    final fromCtrl = TextEditingController(
      text: row['received_from']?.toString() ?? '',
    );
    final remarkCtrl = TextEditingController(
      text: row['remark']?.toString() ?? '',
    );
    final fyCtrl = TextEditingController(
      text: row['fiscal_year']?.toString() ?? _fiscalYear.toString(),
    );
    String type = row['receipt_type']?.toString() ?? 'บร.';
    final locked = _usedCount(row) > 0;

    try {
      final ok = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: false,
        backgroundColor: Colors.transparent,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final c = AppColors.of(context);
              final maxHeight = MediaQuery.sizeOf(context).height - 32;
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.sp16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 460,
                        maxHeight: maxHeight > 360 ? maxHeight : 360,
                      ),
                      child: Material(
                        color: c.cardWhite,
                        elevation: 12,
                        shadowColor: Colors.black26,
                        borderRadius: BorderRadius.circular(AppTheme.r16),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                AppTheme.sp16,
                                AppTheme.sp8,
                                AppTheme.sp8,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      TransactionUiText
                                          .registerReceiptBookEditTitle,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontFamily: 'Kanit',
                                            fontWeight: FontWeight.w700,
                                            color: c.textPrimary,
                                          ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: TransactionUiText.cancel,
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, false),
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                                ],
                              ),
                            ),
                            Flexible(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  0,
                                  20,
                                  AppTheme.sp16,
                                ),
                                child: Form(
                                  key: formKey,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (locked) ...[
                                        Text(
                                          TransactionUiText
                                              .registerReceiptBookLockedUsed,
                                          style: TextStyle(
                                            color: c.textSecondary,
                                            fontFamily: 'Kanit',
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: AppTheme.sp12),
                                      ],
                                      AppInput(
                                        label: TransactionUiText
                                            .registerReceiptBookColBookNo,
                                        controller: bookNoCtrl,
                                        enabled: !locked,
                                        action: const AppInputAction.text(),
                                        required: true,
                                        validator: (v) =>
                                            _requiredReceiptNoRangeValidator(
                                          value: v,
                                          startCtrl: startCtrl,
                                          endCtrl: endCtrl,
                                        ),
                                      ),
                                      const SizedBox(height: AppTheme.sp12),
                                      BuddhistYearField.picker(
                                        controller: fyCtrl,
                                        required: true,
                                        enabled: !locked,
                                        maxYear: BuddhistYearField.toBuddhist(
                                            DateTime.now().year + 10),
                                      ),
                                      const SizedBox(height: AppTheme.sp12),
                                      AppDropdownField<String>(
                                        label: TransactionUiText
                                            .registerReceiptBookDialogReceiptType,
                                        density: AppDropdownDensity.compact,
                                        enabled: !locked,
                                        value: type,
                                        items: const [
                                          AppDropdownItem(
                                            value: 'บร.',
                                            label: TransactionUiText
                                                .registerReceiptBookTypeBr,
                                          ),
                                          AppDropdownItem(
                                            value: 'บค.',
                                            label: TransactionUiText
                                                .registerReceiptBookTypeBk,
                                          ),
                                          AppDropdownItem(
                                            value: 'บฝ.',
                                            label: TransactionUiText
                                                .registerReceiptBookTypeBf,
                                          ),
                                        ],
                                        onChanged: (v) => setDialogState(
                                          () => type = v ?? type,
                                        ),
                                      ),
                                      const SizedBox(height: AppTheme.sp12),
                                      AppInput(
                                        label: TransactionUiText
                                            .registerReceiptBookColStartNo,
                                        controller: startCtrl,
                                        enabled: !locked,
                                        action: const AppInputAction.text(),
                                        required: true,
                                        validator: (v) =>
                                            _requiredReceiptNoRangeValidator(
                                          value: v,
                                          startCtrl: startCtrl,
                                          endCtrl: endCtrl,
                                        ),
                                      ),
                                      const SizedBox(height: AppTheme.sp12),
                                      AppInput(
                                        label: TransactionUiText
                                            .registerReceiptBookColEndNo,
                                        controller: endCtrl,
                                        enabled: !locked,
                                        action: const AppInputAction.text(),
                                        required: true,
                                        validator: (v) =>
                                            _requiredReceiptNoRangeValidator(
                                          value: v,
                                          startCtrl: startCtrl,
                                          endCtrl: endCtrl,
                                        ),
                                      ),
                                      const SizedBox(height: AppTheme.sp12),
                                      AppInput(
                                        label: TransactionUiText
                                            .registerReceiptBookReceivedFrom,
                                        controller: fromCtrl,
                                        action: const AppInputAction.text(),
                                      ),
                                      const SizedBox(height: AppTheme.sp12),
                                      AppInput(
                                        label: TransactionUiText.remark,
                                        controller: remarkCtrl,
                                        action: const AppInputAction.text(),
                                        minLines: 2,
                                        maxLines: 4,
                                        textInputAction:
                                            TextInputAction.newline,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Divider(height: 1, color: c.cardBorder),
                            Padding(
                              padding: const EdgeInsets.all(AppTheme.sp16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  _popupActionButton(
                                    label: TransactionUiText.cancel,
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, false),
                                    colors: c,
                                    primary: false,
                                  ),
                                  const SizedBox(width: AppTheme.sp12),
                                  _popupActionButton(
                                    label: TransactionUiText.save,
                                    onPressed: () {
                                      if (formKey.currentState?.validate() ==
                                          true) {
                                        Navigator.pop(dialogContext, true);
                                      }
                                    },
                                    colors: c,
                                    primary: true,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

      if (ok != true) return;

      final body = {
        'book_no':
            locked ? row['book_no']?.toString() ?? '' : bookNoCtrl.text.trim(),
        'receipt_type':
            locked ? row['receipt_type']?.toString() ?? 'บร.' : type,
        'start_no':
            locked ? row['start_no']?.toString() ?? '' : startCtrl.text.trim(),
        'end_no':
            locked ? row['end_no']?.toString() ?? '' : endCtrl.text.trim(),
        'fiscal_year': locked
            ? row['fiscal_year']?.toString() ?? _fiscalYear.toString()
            : fyCtrl.text.trim(),
        'received_from': fromCtrl.text.trim(),
        'remark': remarkCtrl.text.trim(),
        'status': row['status']?.toString() ?? 'available',
      };
      final result = await _repository.updateReceiptBook(
        id: id,
        body: body,
        coreFieldsLocked: locked,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.synced
                ? TransactionUiText.saveSuccess
                : TransactionUiText.registerReceiptBookUpdatedLocal,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final errorText = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${TransactionUiText.updateFailed}: $errorText')),
      );
    } finally {
      bookNoCtrl.dispose();
      startCtrl.dispose();
      endCtrl.dispose();
      fromCtrl.dispose();
      remarkCtrl.dispose();
      fyCtrl.dispose();
    }
  }

  Future<void> _confirmDeleteBook(Map<String, dynamic> row) async {
    final id = row['id']?.toString() ?? '';
    if (id.isEmpty) return;

    if (_usedCount(row) > 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(TransactionUiText.registerReceiptBookDeleteBlocked),
        ),
      );
      return;
    }

    final bookNo = row['book_no']?.toString() ?? '-';
    final fiscalYear = row['fiscal_year']?.toString() ?? '-';
    final receiptType = row['receipt_type']?.toString() ?? '-';
    final c = AppColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: TransactionUiText.registerReceiptBookDeleteTitle,
        message:
            'ต้องการลบเล่ม "$bookNo" ปีงบประมาณ $fiscalYear ประเภท $receiptType หรือไม่?',
        cancelText: TransactionUiText.cancel,
        confirmText: TransactionUiText.delete,
        confirmColor: c.expenseRed,
        isDestructive: true,
      ),
    );
    if (ok != true) return;

    try {
      final result = await _repository.deleteReceiptBook(id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.synced
                ? TransactionUiText.deleteSuccess
                : TransactionUiText.registerReceiptBookDeletedLocal,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final errorText = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${TransactionUiText.deleteFailed}: $errorText')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = AppColors.of(context);
    return Stack(children: [
      Positioned.fill(
        child: SimpleRegisterTabBase(
          loading: _loading,
          error: _error,
          rows: _rows,
          headerInfo: TransactionUiText.registerReceiptBookListHeader,
          columnHeaders: const [
            TransactionUiText.registerReceiptBookColBookNo,
            TransactionUiText.registerReceiptBookColReceiptType,
            TransactionUiText.registerReceiptBookColStartNo,
            TransactionUiText.registerReceiptBookColEndNo,
            TransactionUiText.registerReceiptBookColUsed,
            TransactionUiText.registerReceiptBookColAmount,
            TransactionUiText.registerReceiptBookColStatus,
            TransactionUiText.registerReceiptBookColActions,
          ],
          cellBuilder: (r) => [
            DataCell(Text(r['book_no']?.toString() ?? '-')),
            DataCell(Text(r['receipt_type']?.toString() ?? '-')),
            DataCell(Text(r['start_no']?.toString() ?? '-')),
            DataCell(Text(r['end_no']?.toString() ?? '-')),
            DataCell(Text(r['used_count']?.toString() ?? '0')),
            DataCell(
                Text(SimpleRegisterTabBase.formatNumber(r['used_amount']))),
            DataCell(Text(r['status']?.toString() ?? '-')),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: TransactionUiText.edit,
                    icon: const Icon(Icons.edit_rounded),
                    onPressed: () => _showEditBookDialog(r),
                  ),
                  IconButton(
                    tooltip: TransactionUiText.delete,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: _usedCount(r) > 0 ? null : c.expenseRed,
                    ),
                    onPressed: () => _confirmDeleteBook(r),
                  ),
                ],
              ),
            ),
          ],
          csvFilePrefix: 'receipt_book_register',
          csvRowBuilder: (r) => [
            r['book_no']?.toString() ?? '',
            r['receipt_type']?.toString() ?? '',
            r['start_no']?.toString() ?? '',
            r['end_no']?.toString() ?? '',
            r['used_count']?.toString() ?? '0',
            SimpleRegisterTabBase.formatNumber(r['used_amount']),
            r['status']?.toString() ?? '',
            '',
          ],
          fiscalYear: _fiscalYear,
          onChangeFiscalYear: (v) {
            setState(() => _fiscalYear = v);
            _load();
          },
          onRefresh: _load,
        ),
      ),
      Positioned(
        right: 16,
        bottom: 16,
        child: _addReceiptBookButton(c),
      ),
    ]);
  }
}
