import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/widgets/sheet/adaptive_content_sheet.dart';

class PartyDetailDialog extends StatelessWidget {
  const PartyDetailDialog({
    super.key,
    required this.row,
    required this.roleLabel,
    required this.statusLabel,
    required this.onDelete,
    required this.onOpenHistory,
    required this.onEdit,
  });

  final Map<String, dynamic> row;
  final String roleLabel;
  final String statusLabel;
  final VoidCallback onDelete;
  final VoidCallback onOpenHistory;
  final VoidCallback onEdit;

  static const _fontFamily = 'Kanit';

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final detailStyle = TextStyle(
      fontFamily: _fontFamily,
      color: c.textPrimary,
    );

    return SafeArea(
      child: AdaptiveContentSheet(
        title: 'รายละเอียดผู้เกี่ยวข้อง',
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppTheme.sp16,
            0,
            AppTheme.sp16,
            AppTheme.sp16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('ชื่อ: ${(row['name'] ?? '').toString()}',
                    style: detailStyle),
                const SizedBox(height: 6),
                Text('บทบาท: $roleLabel', style: detailStyle),
                const SizedBox(height: 6),
                Text('สถานะ: $statusLabel', style: detailStyle),
                const SizedBox(height: 6),
                Text(
                  'เบอร์โทร: ${(row['phone'] ?? '-').toString().isEmpty ? '-' : row['phone']}',
                  style: detailStyle,
                ),
                const SizedBox(height: 6),
                Text(
                  'เลขผู้เสียภาษี: ${(row['taxid'] ?? '-').toString().isEmpty ? '-' : row['taxid']}',
                  style: detailStyle,
                ),
                const SizedBox(height: 6),
                Text(
                  'หมายเหตุ: ${(row['remark'] ?? '-').toString().isEmpty ? '-' : row['remark']}',
                  style: detailStyle,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'ปิด',
                        style: TextStyle(
                          fontFamily: _fontFamily,
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onDelete,
                      child: Text(
                        'ลบ',
                        style: TextStyle(
                          fontFamily: _fontFamily,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onOpenHistory,
                      child: Text(
                        'ประวัติ',
                        style: TextStyle(
                          fontFamily: _fontFamily,
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: onEdit,
                      child: const Text(
                        'แก้ไข',
                        style: TextStyle(fontFamily: _fontFamily),
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
