import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';

typedef IncomePayerSelection = ({String id, String name});

/// Bottom sheet เลือกผู้จ่าย — แสดงทันทีแล้วโหลดรายการใน sheet (ไม่บล็อกก่อนเปิด UI)
class IncomePayerPartyPickerSheet extends StatefulWidget {
  const IncomePayerPartyPickerSheet({
    super.key,
    required this.loadParties,
    required this.onNavigateToAddPartyWhenEmpty,
  });

  final Future<List<Map<String, dynamic>>> Function() loadParties;
  final VoidCallback onNavigateToAddPartyWhenEmpty;

  @override
  State<IncomePayerPartyPickerSheet> createState() =>
      _IncomePayerPartyPickerSheetState();
}

class _IncomePayerPartyPickerSheetState extends State<IncomePayerPartyPickerSheet> {
  static const _fontFamily = 'Kanit';

  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController();
    _runLoad();
  }

  Future<void> _runLoad() async {
    final rows = await widget.loadParties();
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

  void _goAddPartyAndCloseSheet() {
    Navigator.of(context).pop();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => widget.onNavigateToAddPartyWhenEmpty());
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
                TransactionUiText.incomePayerPickerTitle,
                style: TextStyle(
                  fontFamily: _fontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                TransactionUiText.incomePayerPickerLoading,
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
                TransactionUiText.receiveFromNoPayerDialogTitle,
                style: TextStyle(
                  fontFamily: _fontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                TransactionUiText.receiveFromNoPayerDialogBody,
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
                      onPressed: _goAddPartyAndCloseSheet,
                      child: const Text(
                        TransactionUiText.receiveFromGoAddParty,
                        style: TextStyle(fontFamily: _fontFamily),
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
    final filtered = _rows.where((row) {
      final name = (row['name'] ?? '').toString().toLowerCase();
      if (query.isEmpty) return true;
      return name.contains(query);
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
                TransactionUiText.incomePayerPickerTitle,
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
                  hintText: TransactionUiText.incomePayerPickerSearchHint,
                  hintStyle: TextStyle(color: c.textHint, fontFamily: _fontFamily),
                  prefixIcon: Icon(Icons.search_rounded, color: c.textSecondary),
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
                    final row = filtered[i];
                    final role =
                        (row['role'] ?? 'both').toString().toLowerCase();
                    final roleLabel = role == 'both'
                        ? 'ทั้งสองฝั่ง (จ่ายได้)'
                        : 'ผู้จ่าย';
                    return ListTile(
                      title: Text(
                        (row['name'] ?? '').toString(),
                        style: TextStyle(
                          fontFamily: _fontFamily,
                          color: c.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        roleLabel,
                        style: TextStyle(
                          fontFamily: _fontFamily,
                          color: c.textSecondary,
                          fontSize: 13,

                          height: 1.25,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: c.textSecondary,
                      ),
                      onTap: () => Navigator.of(context).pop((
                        id: (row['id'] ?? '').toString(),
                        name: (row['name'] ?? '').toString(),
                      )),
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
