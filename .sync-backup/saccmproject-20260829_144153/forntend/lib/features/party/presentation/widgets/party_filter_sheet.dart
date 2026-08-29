import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/widgets/sheet/adaptive_content_sheet.dart';

class PartyFilterSheet extends StatelessWidget {
  const PartyFilterSheet({
    super.key,
    required this.roleFilter,
    required this.sortBy,
    required this.statusFilter,
    required this.onRoleChanged,
    required this.onSortChanged,
    required this.onStatusChanged,
  });

  final String roleFilter;
  final String sortBy;
  final String statusFilter;
  final ValueChanged<String> onRoleChanged;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<String> onStatusChanged;

  static const _fontFamily = 'Kanit';

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SafeArea(
      child: AdaptiveContentSheet(
        title: 'ตัวกรอง',
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.sp16,
            0,
            AppTheme.sp16,
            AppTheme.sp16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'บทบาท:',
                style: TextStyle(
                  fontFamily: _fontFamily,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('ทั้งหมด'),
                    selected: roleFilter == 'all',
                    onSelected: (_) => onRoleChanged('all'),
                  ),
                  ChoiceChip(
                    label: const Text('ผู้จ่าย'),
                    selected: roleFilter == 'payer',
                    onSelected: (_) => onRoleChanged('payer'),
                  ),
                  ChoiceChip(
                    label: const Text('ผู้รับ'),
                    selected: roleFilter == 'receiver',
                    onSelected: (_) => onRoleChanged('receiver'),
                  ),
                  ChoiceChip(
                    label: const Text('ทั้งสองฝั่ง'),
                    selected: roleFilter == 'both',
                    onSelected: (_) => onRoleChanged('both'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'เรียงลำดับ:',
                style: TextStyle(
                  fontFamily: _fontFamily,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Active ก่อน'),
                    selected: sortBy == 'active_then_name',
                    onSelected: (_) => onSortChanged('active_then_name'),
                  ),
                  ChoiceChip(
                    label: const Text('A-Z'),
                    selected: sortBy == 'name_asc',
                    onSelected: (_) => onSortChanged('name_asc'),
                  ),
                  ChoiceChip(
                    label: const Text('ล่าสุด'),
                    selected: sortBy == 'latest',
                    onSelected: (_) => onSortChanged('latest'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'สถานะ:',
                style: TextStyle(
                  fontFamily: _fontFamily,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('สถานะทั้งหมด'),
                    selected: statusFilter == 'all',
                    onSelected: (_) => onStatusChanged('all'),
                  ),
                  ChoiceChip(
                    label: const Text('ใช้งาน'),
                    selected: statusFilter == 'active',
                    onSelected: (_) => onStatusChanged('active'),
                  ),
                  ChoiceChip(
                    label: const Text('ปิดใช้งาน'),
                    selected: statusFilter == 'inactive',
                    onSelected: (_) => onStatusChanged('inactive'),
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
