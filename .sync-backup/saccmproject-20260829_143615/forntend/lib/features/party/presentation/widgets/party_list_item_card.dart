import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';

class PartyListItemCard extends StatelessWidget {
  const PartyListItemCard({
    super.key,
    required this.row,
    required this.roleLabel,
    required this.onTap,
    required this.onToggleActive,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> row;
  final String roleLabel;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static const _fontFamily = 'Kanit';

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isActive = row['isactive'] == true || row['isactive']?.toString() == '1';

    return Material(
      color: c.cardWhite,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.cardBorder),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
            title: Text(
              row['name']?.toString() ?? '',
              style: TextStyle(
                fontFamily: _fontFamily,
                color: c.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '$roleLabel'
              '${(row['phone'] ?? '').toString().isNotEmpty ? ' • ${row['phone']}' : ''}',
              style: TextStyle(
                fontFamily: _fontFamily,
                color: c.textSecondary,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isActive ? Icons.check_circle_rounded : Icons.remove_circle_rounded,
                  size: 18,
                  color: isActive ? c.incomeGreen : c.textHint,
                ),
                Switch(
                  value: isActive,
                  onChanged: onToggleActive,
                ),
                IconButton(
                  icon: Icon(
                    Icons.edit_rounded,
                    color: c.textSecondary,
                  ),
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  tooltip: 'ลบ',
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
