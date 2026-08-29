import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/di/service_locator.dart';
import 'package:saccm/core/local_data_source/member_local_data_source.dart';

class LoanBorrowerPickResult {
  const LoanBorrowerPickResult({required this.id, required this.label});

  final String id;
  final String label;
}

/// เลือกผู้ยืมจากตาราง member (สอดคล้อง FK loan.refMember)
class LoanBorrowerPickerSheet extends StatefulWidget {
  const LoanBorrowerPickerSheet({
    super.key,
    required this.onNavigateToRegisterMember,
  });

  final VoidCallback onNavigateToRegisterMember;

  static String formatLabel(MemberModel m) {
    final code = m.code.trim();
    final name = m.name.trim();
    if (name.isEmpty) return code;
    if (code.isNotEmpty) return '$code — $name';
    return name;
  }

  @override
  State<LoanBorrowerPickerSheet> createState() =>
      _LoanBorrowerPickerSheetState();
}

class _LoanBorrowerPickerSheetState extends State<LoanBorrowerPickerSheet> {
  static const _fontFamily = 'Kanit';

  bool _loading = true;
  List<MemberModel> _rows = [];
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController();
    _runLoad();
  }

  Future<void> _runLoad() async {
    final ds = ServiceLocator.instance.get<MemberLocalDataSource>();
    final rows = await ds.getAllMembers();
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _goRegisterAndClose() {
    Navigator.of(context).pop();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => widget.onNavigateToRegisterMember());
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;

    if (_loading) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                TransactionUiText.loanBorrowerPickerTitle,
                style: TextStyle(
                  fontFamily: _fontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                TransactionUiText.loanBorrowerPickerLoading,
                style: TextStyle(
                  fontFamily: _fontFamily,
                  fontSize: 13,
                  color: c.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 100,
                child: Center(
                  child: CircularProgressIndicator(color: scheme.primary),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_rows.isEmpty) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                TransactionUiText.loanBorrowerNoMembersTitle,
                style: TextStyle(
                  fontFamily: _fontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                TransactionUiText.loanBorrowerNoMembersBody,
                style: TextStyle(
                  fontFamily: _fontFamily,
                  fontSize: 13,
                  color: c.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        TransactionUiText.cancel,
                        style: TextStyle(
                          fontFamily: _fontFamily,
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.primary,
                      ),
                      onPressed: _goRegisterAndClose,
                      child: Text(
                        TransactionUiText.loanBorrowerGoRegister,
                        style: const TextStyle(fontFamily: _fontFamily),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final query = _search.text.trim().toLowerCase();
    final filtered = _rows.where((m) {
      if (query.isEmpty) return true;
      final name = m.name.toLowerCase();
      final code = m.code.toLowerCase();
      return name.contains(query) || code.contains(query);
    }).toList();

    final maxH = MediaQuery.sizeOf(context).height * 0.55;

    return SafeArea(
      child: SizedBox(
        height: maxH,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                TransactionUiText.loanBorrowerPickerTitle,
                style: TextStyle(
                  fontFamily: _fontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _search,
                style: TextStyle(color: c.textPrimary, fontFamily: _fontFamily),
                cursorColor: scheme.primary,
                decoration: InputDecoration(
                  hintText: TransactionUiText.loanBorrowerPickerSearchHint,
                  hintStyle:
                      TextStyle(color: c.textHint, fontFamily: _fontFamily),
                  prefixIcon:
                      Icon(Icons.search_rounded, color: c.textSecondary),
                  filled: true,
                  fillColor: c.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.sp16,
                    vertical: AppTheme.sp12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.r12),
                    borderSide: BorderSide(color: c.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.r12),
                    borderSide: BorderSide(color: c.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.r12),
                    borderSide: BorderSide(color: scheme.primary, width: 2),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: RepaintBoundary(
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: c.cardBorder),
                  itemBuilder: (_, i) {
                    final m = filtered[i];
                    final label = LoanBorrowerPickerSheet.formatLabel(m);
                    return ListTile(
                      title: Text(
                        label,
                        style: TextStyle(
                          fontFamily: _fontFamily,
                          color: c.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: c.textSecondary,
                      ),
                      onTap: () => Navigator.of(context).pop(
                        LoanBorrowerPickResult(id: m.id, label: label),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
