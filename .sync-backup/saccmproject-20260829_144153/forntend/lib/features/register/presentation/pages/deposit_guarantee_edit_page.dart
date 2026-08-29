import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/di/service_locator.dart';
import 'package:saccm/features/auth/presentation/providers/simple_auth_provider.dart';
import 'package:saccm/features/register/data/repositories/deposit_register_repository_offline.dart';
import 'package:saccm/widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// แก้ไขรายการ holding (ไม่แก้ใบรับที่ผูกแล้ว)
class DepositGuaranteeEditPage extends StatefulWidget {
  const DepositGuaranteeEditPage({super.key, required this.deposit});

  final Map<String, dynamic> deposit;

  @override
  State<DepositGuaranteeEditPage> createState() =>
      _DepositGuaranteeEditPageState();
}

class _DepositGuaranteeEditPageState extends State<DepositGuaranteeEditPage> {
  static const _fontFamily = 'Kanit';
  static const double _maxResponsiveFormWidth = 1440;

  late final TextEditingController _docnoCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _partyCtrl;
  late final TextEditingController _contractCtrl;
  late final TextEditingController _detailCtrl;

  DateTime? _dueDate;
  bool _saving = false;

  DepositRegisterRepositoryOffline get _repo =>
      ServiceLocator.instance.get<DepositRegisterRepositoryOffline>();

  @override
  void initState() {
    super.initState();
    final d = widget.deposit;
    _docnoCtrl = TextEditingController(text: d['docno']?.toString() ?? '');
    _amountCtrl = TextEditingController(text: d['amount']?.toString() ?? '');
    _partyCtrl = TextEditingController(
      text: d['party_name']?.toString() ??
          d['party_name_snapshot']?.toString() ??
          '',
    );
    _contractCtrl =
        TextEditingController(text: d['contract_no']?.toString() ?? '');
    _detailCtrl = TextEditingController(text: d['detail']?.toString() ?? '');
    _dueDate = DateTime.tryParse(d['due_date']?.toString() ?? '');
  }

  @override
  void dispose() {
    _docnoCtrl.dispose();
    _amountCtrl.dispose();
    _partyCtrl.dispose();
    _contractCtrl.dispose();
    _detailCtrl.dispose();
    super.dispose();
  }

  int? get _serverId {
    final id = widget.deposit['id']?.toString() ?? '';
    if (id.startsWith('local_deposit_')) return null;
    return int.tryParse(id);
  }

  Future<void> _save() async {
    final auth = context.read<SimpleAuthProvider>();
    if (!auth.can(PermissionKey.registerDepositUpdate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(TransactionUiText.cannotDelete)),
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    if (token.isEmpty) return;

    setState(() => _saving = true);
    try {
      final res = await _repo.updateDeposit(
        serverOrLocalId: _serverId ?? 0,
        localIdHint: widget.deposit['id']?.toString() ?? '',
        token: token,
        body: {
          'docno': _docnoCtrl.text.trim(),
          'amount': _amountCtrl.text.trim(),
          'party_name_snapshot': _partyCtrl.text.trim(),
          'contract_no': _contractCtrl.text.trim(),
          'detail': _detailCtrl.text.trim(),
          if (_dueDate != null) 'due_date': _dueDate!.toIso8601String(),
        },
      );
      if (!mounted) return;
      if (res['status']?.toString() == 'successfully') {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? '')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
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
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(AppTheme.sp16),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: _maxResponsiveFormWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TransactionFormHeader(
                      icon: Icons.edit_note_rounded,
                      iconColor: scheme.primary,
                      iconBgColor: c.iconBgIncome,
                      title: TransactionUiText.registerDepositEditTitle,
                      subtitle: TransactionUiText.reviewBeforeSave,
                      quickHint:
                          TransactionUiText.registerDepositLinkedIncomeHint,
                      hintAccentColor: scheme.primary,
                      hintBorderColor: c.cardBorder,
                      textPrimaryColor: c.textPrimary,
                      showQuickHint: false,
                    ),
                    const SizedBox(height: AppTheme.sp16),
                    _buildFormCard(c),
                    const SizedBox(height: AppTheme.sp16),
                    _buildActionCard(c),
                    const SizedBox(height: AppTheme.sp24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppColors c) {
    return AppBar(
      toolbarHeight: 52,
      title: Text(
        TransactionUiText.registerDepositEditTitle,
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

  Widget _buildFormCard(AppColors c) {
    return Container(
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r16),
        border: Border.all(color: c.cardBorder, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sp16),
        child: LayoutBuilder(
          builder: (context, box) {
            final isWide = box.maxWidth >= 560;
            final fields = [
              AppInput(
                label: TransactionUiText.registerDepositColDocNo,
                controller: _docnoCtrl,
              ),
              AppInput(
                label: TransactionUiText.registerDepositColAmount,
                controller: _amountCtrl,
                action: const AppInputAction.number(allowDecimal: true),
                textAlign: TextAlign.right,
              ),
              AppInput(
                label: TransactionUiText.registerDepositPartyLabel,
                controller: _partyCtrl,
              ),
              AppInput(
                label: TransactionUiText.registerDepositContractNoLabel,
                controller: _contractCtrl,
              ),
              AppInput(
                label: TransactionUiText.registerDepositColDue,
                action: AppInputAction.date(
                  initialValue: _dueDate,
                  onChanged: (d) => setState(() => _dueDate = d),
                ),
              ),
              AppInput(
                label: TransactionUiText.detail,
                controller: _detailCtrl,
                minLines: 2,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
              ),
            ];
            if (!isWide) {
              return Column(
                children: [
                  for (final field in fields) ...[
                    field,
                    if (field != fields.last)
                      const SizedBox(height: AppTheme.sp12),
                  ],
                ],
              );
            }
            return Wrap(
              spacing: AppTheme.sp12,
              runSpacing: AppTheme.sp12,
              children: fields
                  .map(
                    (field) => SizedBox(
                      width: (box.maxWidth - AppTheme.sp12) / 2,
                      child: field,
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildActionCard(AppColors c) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.sp16),
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r16),
        border: Border.all(color: c.cardBorder),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final button = AppButton.primary(
            label: TransactionUiText.saveEdit,
            icon: const Icon(Icons.save_rounded, size: 18),
            fullWidth: box.maxWidth < 560,
            isLoading: _saving,
            onPressed: _saving ? null : _save,
          );
          if (box.maxWidth < 560) return button;
          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [SizedBox(width: 180, child: button)],
          );
        },
      ),
    );
  }
}
