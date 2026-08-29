import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/widgets/widgets.dart';

class PartyFormSheet extends StatefulWidget {
  const PartyFormSheet({
    super.key,
    required this.isEdit,
    required this.initialRole,
    required this.nameController,
    required this.phoneController,
    required this.taxIdController,
    required this.remarkController,
    required this.duplicateMessageProvider,
  });

  final bool isEdit;
  final String initialRole;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController taxIdController;
  final TextEditingController remarkController;
  final String? Function(String name, String taxId) duplicateMessageProvider;

  @override
  State<PartyFormSheet> createState() => _PartyFormSheetState();
}

class _PartyFormSheetState extends State<PartyFormSheet> {
  late String _role;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _role = widget.initialRole;
  }

  void _submit() {
    final name = widget.nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _formError = 'กรุณาระบุชื่อ');
      return;
    }

    final duplicateError = widget.duplicateMessageProvider(
      name,
      widget.taxIdController.text.trim(),
    );
    if ((duplicateError ?? '').isNotEmpty) {
      setState(() => _formError = duplicateError);
      return;
    }

    Navigator.pop(context, _role);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SafeArea(
      child: AdaptiveContentSheet(
        title: widget.isEdit ? 'แก้ไขผู้เกี่ยวข้อง' : 'เพิ่มผู้เกี่ยวข้อง',
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppTheme.sp16,
            0,
            AppTheme.sp16,
            AppTheme.sp16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                AppInput(
                  label: 'ชื่อ',
                  controller: widget.nameController,
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
                const SizedBox(height: 8),
                AppDropdownField<String>(
                  label: 'บทบาท',
                  value: _role,
                  items: const [
                    AppDropdownItem(
                      value: 'payer',
                      label: 'ผู้จ่าย (รายรับ)',
                    ),
                    AppDropdownItem(
                      value: 'receiver',
                      label: 'ผู้รับ (รายจ่าย)',
                    ),
                    AppDropdownItem(
                      value: 'both',
                      label: 'ทั้งผู้จ่ายและผู้รับ',
                    ),
                  ],
                  onChanged: (v) => setState(() => _role = v ?? 'both'),
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                ),
                const SizedBox(height: 8),
                AppInput(
                  label: 'เบอร์โทรศัพท์',
                  controller: widget.phoneController,
                  action: const AppInputAction.number(),
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
                const SizedBox(height: 8),
                AppInput(
                  label: 'เลขผู้เสียภาษี',
                  controller: widget.taxIdController,
                  action: const AppInputAction.number(),
                  maxLength: 13,
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(Icons.receipt_long_outlined),
                  helperText:
                      'บุคคลธรรมดามักใช้เลขบัตรประชาชน 13 หลักเป็นทิน — กรอกในช่องนี้ได้ ไม่ต้องมีช่องเลขบัตรแยก',
                ),
                const SizedBox(height: 8),
                AppInput(
                  label: 'หมายเหตุ',
                  controller: widget.remarkController,
                  textInputAction: TextInputAction.done,
                  prefixIcon: const Icon(Icons.notes_outlined),
                ),
                if ((_formError ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _formError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontFamily: 'Kanit',
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'ยกเลิก',
                        style: TextStyle(
                          fontFamily: 'Kanit',
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _submit,
                      child: const Text(
                        'บันทึก',
                        style: TextStyle(fontFamily: 'Kanit'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
