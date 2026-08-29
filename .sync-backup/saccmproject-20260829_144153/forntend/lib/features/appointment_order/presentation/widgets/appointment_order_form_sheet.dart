// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/utils/fiscal_year.dart';
import 'package:saccm/core/utils/single_open_navigation.dart';
import 'package:saccm/features/appointment_order/data/datasources/appointment_order_local_data_source.dart';
import 'package:saccm/widgets/widgets.dart';

String appointmentOrderTypeLabelUi(String code) {
  switch (code) {
    case 'finance_officer':
      return TransactionUiText.appointmentOrderTypeFinanceOfficer;
    case 'cash_committee':
      return TransactionUiText.appointmentOrderTypeCashCommittee;
    case 'daily_inspector':
      return TransactionUiText.appointmentOrderTypeDailyInspector;
    default:
      return code;
  }
}

String appointmentOrderRoleLabelUi(String code) {
  switch (code) {
    case 'chair':
      return TransactionUiText.appointmentOrderRoleChair;
    case 'secretary':
      return TransactionUiText.appointmentOrderRoleSecretary;
    case 'officer':
      return TransactionUiText.appointmentOrderRoleOfficer;
    case 'committee':
    default:
      return TransactionUiText.appointmentOrderRoleCommittee;
  }
}

Future<bool?> showAppointmentOrderFormSheet(
  BuildContext context, {
  String? editId,
}) {
  return SingleOpenNavigation.showSheet<bool>(
    context,
    key: 'appointment_order.form.${editId ?? 'add'}',
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (ctx) => AppointmentOrderFormSheet(editId: editId),
  );
}

class AppointmentOrderFormSheet extends StatefulWidget {
  const AppointmentOrderFormSheet({super.key, this.editId});

  final String? editId;

  @override
  State<AppointmentOrderFormSheet> createState() =>
      _AppointmentOrderFormSheetState();
}

class _MemberLine {
  _MemberLine({required this.name, required this.position, required this.role});
  final TextEditingController name;
  final TextEditingController position;
  String role;

  void dispose() {
    name.dispose();
    position.dispose();
  }
}

class _AppointmentOrderFormSheetState extends State<AppointmentOrderFormSheet> {
  final _ds = AppointmentOrderLocalDataSource();
  final _formKey = GlobalKey<FormState>();
  final _docno = TextEditingController();
  final _subject = TextEditingController();
  final _content = TextEditingController();
  final _fiscalYear = TextEditingController();
  DateTime? _docDate;
  String _orderType = 'cash_committee';
  String _status = 'active';
  final List<_MemberLine> _members = [];
  bool _loading = false;
  bool _bootLoading = true;

  @override
  void initState() {
    super.initState();
    _fiscalYear.text = FiscalYear.currentBuddhist().toString();
    _members.add(_MemberLine(
      name: TextEditingController(),
      position: TextEditingController(),
      role: 'committee',
    ));
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (widget.editId == null) {
      setState(() => _bootLoading = false);
      return;
    }
    try {
      final bundle = await _ds.getOrderWithMembers(widget.editId!);
      if (!mounted) return;
      if (bundle != null) {
        final o = bundle['order']! as Map<String, dynamic>;
        _docno.text = o['docno']?.toString() ?? '';
        _subject.text = o['subject']?.toString() ?? '';
        _content.text = o['content']?.toString() ?? '';
        _fiscalYear.text = o['fiscal_year']?.toString() ?? '';
        _orderType = o['order_type']?.toString() ?? 'cash_committee';
        _status = o['status']?.toString() ?? 'active';
        final raw = o['docdate']?.toString();
        if (raw != null && raw.isNotEmpty) {
          _docDate =
              DateTime.tryParse(raw) ?? DateFormat('yyyy-MM-dd').tryParse(raw);
        }
        for (final c in _members) {
          c.dispose();
        }
        _members.clear();
        final mlist = bundle['members']! as List<dynamic>;
        if (mlist.isEmpty) {
          _members.add(_MemberLine(
            name: TextEditingController(),
            position: TextEditingController(),
            role: 'committee',
          ));
        } else {
          for (final m in mlist) {
            final row = m as Map<String, dynamic>;
            _members.add(_MemberLine(
              name: TextEditingController(
                  text: row['member_name']?.toString() ?? ''),
              position: TextEditingController(
                  text: row['member_position']?.toString() ?? ''),
              role: row['role_in_order']?.toString() ?? 'committee',
            ));
          }
        }
      }
    } finally {
      if (mounted) setState(() => _bootLoading = false);
    }
  }

  @override
  void dispose() {
    _docno.dispose();
    _subject.dispose();
    _content.dispose();
    _fiscalYear.dispose();
    for (final m in _members) {
      m.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final named = _members
        .map((m) => m.name.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (named.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(TransactionUiText.appointmentOrderMemberRequired)),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final docIso =
          _docDate != null ? DateFormat('yyyy-MM-dd').format(_docDate!) : null;
      var sort = 0;
      final memberPayload = _members
          .map((m) {
            if (m.name.text.trim().isEmpty) return null;
            sort++;
            return {
              'member_name': m.name.text.trim(),
              'member_position': m.position.text.trim(),
              'role_in_order': m.role,
              'sort': sort,
            };
          })
          .whereType<Map<String, dynamic>>()
          .toList();
      await _ds.upsertOrder(
        existingId: widget.editId,
        docno: _docno.text,
        docdateIso: docIso,
        orderType: _orderType,
        subject: _subject.text,
        content: _content.text.isEmpty ? null : _content.text,
        fiscalYear: _fiscalYear.text,
        status: _status,
        memberRows: memberPayload,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _addMember() {
    setState(() {
      _members.add(_MemberLine(
        name: TextEditingController(),
        position: TextEditingController(),
        role: 'committee',
      ));
    });
  }

  void _removeMember(int i) {
    if (_members.length <= 1) return;
    late final _MemberLine removed;
    setState(() {
      removed = _members.removeAt(i);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      removed.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    if (_bootLoading) {
      return Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: SizedBox(
          height: 200,
          child:
              Center(child: CircularProgressIndicator(color: scheme.primary)),
        ),
      );
    }

    return SafeArea(
      child: AdaptiveContentSheet(
        title: widget.editId == null
            ? TransactionUiText.addItem
            : TransactionUiText.edit,
        maxHeightFactor: 0.96,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: Form(
            key: _formKey,
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                AppInput(
                  label: TransactionUiText.appointmentOrderDocNoLabel,
                  controller: _docno,
                  action: const AppInputAction.text(),
                  required: true,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? TransactionUiText.fillRequiredFields
                      : null,
                ),
                const SizedBox(height: 12),
                AppDateInput(
                  label: TransactionUiText.appointmentOrderDocDateLabel,
                  initialValue: _docDate,
                  clearable: true,
                  onChanged: (d) => setState(() => _docDate = d),
                ),
                const SizedBox(height: 12),
                AppDropdownField<String>(
                  label: TransactionUiText.appointmentOrderTypeLabel,
                  value: _orderType,
                  items: const [
                    AppDropdownItem(
                      value: 'finance_officer',
                      label:
                          TransactionUiText.appointmentOrderTypeFinanceOfficer,
                    ),
                    AppDropdownItem(
                      value: 'cash_committee',
                      label:
                          TransactionUiText.appointmentOrderTypeCashCommittee,
                    ),
                    AppDropdownItem(
                      value: 'daily_inspector',
                      label:
                          TransactionUiText.appointmentOrderTypeDailyInspector,
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _orderType = v);
                  },
                  required: true,
                ),
                const SizedBox(height: 12),
                AppInput(
                  label: TransactionUiText.appointmentOrderSubjectLabel,
                  controller: _subject,
                  action: const AppInputAction.text(),
                  required: true,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? TransactionUiText.fillRequiredFields
                      : null,
                ),
                const SizedBox(height: 12),
                AppInput(
                  label: TransactionUiText.appointmentOrderContentLabel,
                  controller: _content,
                  action: const AppInputAction.text(),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                AppInput(
                  label: TransactionUiText.appointmentOrderFiscalYearLabel,
                  controller: _fiscalYear,
                  action: const AppInputAction.number(allowDecimal: false),
                  required: true,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? TransactionUiText.fillRequiredFields
                      : null,
                ),
                const SizedBox(height: 12),
                AppDropdownField<String>(
                  label: TransactionUiText.appointmentOrderStatusLabel,
                  value: _status,
                  items: const [
                    AppDropdownItem(
                      value: 'active',
                      label: TransactionUiText.appointmentOrderStatusActive,
                    ),
                    AppDropdownItem(
                      value: 'cancelled',
                      label: TransactionUiText.appointmentOrderStatusCancelled,
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _status = v);
                  },
                  required: true,
                ),
                const SizedBox(height: 16),
                Text(
                  TransactionUiText.appointmentOrderMembersSection,
                  style: TextStyle(
                    fontFamily: 'Kanit',
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                ...List.generate(_members.length, (i) {
                  final m = _members[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.cardWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: AppInput(
                                  label: TransactionUiText
                                      .appointmentOrderMemberNameLabel,
                                  controller: m.name,
                                  action: const AppInputAction.text(),
                                ),
                              ),
                              if (_members.length > 1)
                                IconButton(
                                  onPressed: () => _removeMember(i),
                                  icon: Icon(Icons.remove_circle_outline,
                                      color: c.expenseRed),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          AppInput(
                            label: TransactionUiText
                                .appointmentOrderMemberPositionLabel,
                            controller: m.position,
                            action: const AppInputAction.text(),
                          ),
                          const SizedBox(height: 8),
                          AppDropdownField<String>(
                            label: TransactionUiText
                                .appointmentOrderMemberRoleLabel,
                            value: m.role,
                            items: [
                              AppDropdownItem(
                                value: 'chair',
                                label: appointmentOrderRoleLabelUi('chair'),
                              ),
                              AppDropdownItem(
                                value: 'committee',
                                label: appointmentOrderRoleLabelUi('committee'),
                              ),
                              AppDropdownItem(
                                value: 'secretary',
                                label: appointmentOrderRoleLabelUi('secretary'),
                              ),
                              AppDropdownItem(
                                value: 'officer',
                                label: appointmentOrderRoleLabelUi('officer'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => m.role = v);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                OutlinedButton.icon(
                  onPressed: _addMember,
                  icon: const Icon(Icons.person_add_outlined, size: 18),
                  label: const Text(
                      TransactionUiText.appointmentOrderAddMemberRow),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _save,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(TransactionUiText.save),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
