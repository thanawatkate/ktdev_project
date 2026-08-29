import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/features/auth/presentation/providers/simple_auth_provider.dart';
import 'package:saccm/widgets/widgets.dart';

class UserGroupPermissionItem {
  const UserGroupPermissionItem(this.key, this.label, this.category);

  final String key;
  final String label;
  final String category;
}

Future<bool?> showUserGroupPermissionDialog({
  required BuildContext context,
  required List<Map<String, dynamic>> groups,
  required List<UserGroupPermissionItem> permissionItems,
  required Map<String, Set<String>> permissionTemplates,
  required Set<String> baselinePermissions,
  required Future<Set<String>> Function(int groupId) loadPermissionsByGroup,
  required Future<void> Function(int groupId, Set<String> permissions) onSave,
}) async {
  if (groups.isEmpty) return false;

  String selectedGroupId = groups.first['id'].toString();
  String? sourceGroupId;
  final initialGroupId = int.tryParse(selectedGroupId);
  Set<String> selectedPermissions = initialGroupId == null
      ? <String>{}
      : await loadPermissionsByGroup(initialGroupId);
  bool saving = false;

  if (!context.mounted) return null;
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setLocalState) {
        final grouped = <String, List<UserGroupPermissionItem>>{};
        for (final item in permissionItems) {
          grouped
              .putIfAbsent(item.category, () => <UserGroupPermissionItem>[])
              .add(item);
        }
        final selectedCount = selectedPermissions.length;
        final hasSettingChildren = selectedPermissions.any(
          (p) => p.startsWith('user_admin.') || p == PermissionKey.auditLogView,
        );
        final missingSettingView = hasSettingChildren &&
            !selectedPermissions.contains(PermissionKey.settingView);

        Future<void> onGroupChanged(String? value) async {
          if (value == null) return;
          setLocalState(() {
            selectedGroupId = value;
            selectedPermissions = <String>{};
          });
          final groupId = int.tryParse(selectedGroupId);
          if (groupId == null) return;
          final permissions = await loadPermissionsByGroup(groupId);
          if (!dialogContext.mounted) return;
          setLocalState(() => selectedPermissions = {...permissions});
        }

        Future<void> copyFromSource({required bool merge}) async {
          final sourceId = int.tryParse(sourceGroupId ?? '');
          if (sourceId == null) return;
          final sourcePermissions = await loadPermissionsByGroup(sourceId);
          if (!dialogContext.mounted) return;
          setLocalState(() {
            selectedPermissions = merge
                ? {...selectedPermissions, ...sourcePermissions}
                : {...sourcePermissions};
          });
        }

        return SafeArea(
          child: AdaptiveContentSheet(
            title: 'จัดการสิทธิ์กลุ่มผู้ใช้',
            maxHeightFactor: 0.94,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppTheme.sp16,
                0,
                AppTheme.sp16,
                MediaQuery.viewInsetsOf(dialogContext).bottom + AppTheme.sp16,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Flexible(
                        fit: FlexFit.loose,
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppLookupPickerField<String>(
                                label: TransactionUiText.userGroup,
                                value: selectedGroupId,
                                clearable: false,
                                items: groups
                                    .map(
                                      (g) => AppDropdownItem<String>(
                                        value: g['id'].toString(),
                                        label: (g['nameen'] ?? '').toString(),
                                      ),
                                    )
                                    .toList(),
                                onChanged: onGroupChanged,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Theme.of(dialogContext)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child:
                                        Text('เลือกแล้ว $selectedCount สิทธิ์'),
                                  ),
                                ],
                              ),
                              if (missingSettingView) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.15),
                                    border: Border.all(
                                        color: Colors.amber.shade700
                                            .withValues(alpha: 0.5)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'คำเตือน: มีสิทธิ์ย่อยด้านตั้งค่า/ผู้ใช้ แต่ไม่มี setting.view ผู้ใช้อาจเข้าเมนูตั้งค่าไม่ได้',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: AppButton.outlined(
                                    label: 'แก้ให้ถูกอัตโนมัติ',
                                    fullWidth: false,
                                    onPressed: saving
                                        ? null
                                        : () => setLocalState(
                                              () => selectedPermissions = {
                                                ...selectedPermissions,
                                                PermissionKey.settingView,
                                              },
                                            ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  AppButton.outlined(
                                    label: 'พื้นฐาน',
                                    fullWidth: false,
                                    onPressed: saving
                                        ? null
                                        : () => setLocalState(
                                              () => selectedPermissions = {
                                                ...baselinePermissions
                                              },
                                            ),
                                  ),
                                  AppButton.outlined(
                                    label: 'เลือกทั้งหมด',
                                    fullWidth: false,
                                    onPressed: saving
                                        ? null
                                        : () => setLocalState(
                                              () => selectedPermissions = {
                                                ...permissionItems
                                                    .map((e) => e.key),
                                              },
                                            ),
                                  ),
                                  AppButton.outlined(
                                    label: 'ล้างทั้งหมด',
                                    fullWidth: false,
                                    onPressed: saving
                                        ? null
                                        : () => setLocalState(() =>
                                            selectedPermissions = <String>{}),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'เทมเพลตสำเร็จรูป',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: permissionTemplates.entries
                                    .map(
                                      (entry) => Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          AppButton.outlined(
                                            label: entry.key,
                                            fullWidth: false,
                                            onPressed: saving
                                                ? null
                                                : () => setLocalState(
                                                      () =>
                                                          selectedPermissions =
                                                              {...entry.value},
                                                    ),
                                          ),
                                          const SizedBox(width: 6),
                                          AppButton.outlined(
                                            label: '+',
                                            fullWidth: false,
                                            onPressed: saving
                                                ? null
                                                : () => setLocalState(
                                                      () =>
                                                          selectedPermissions =
                                                              {
                                                        ...selectedPermissions,
                                                        ...entry.value,
                                                      },
                                                    ),
                                          ),
                                        ],
                                      ),
                                    )
                                    .toList(),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'คัดลอกสิทธิ์จากกลุ่มอื่น',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: AppLookupPickerField<String>(
                                      label: 'กลุ่มต้นทาง',
                                      value: sourceGroupId,
                                      items: groups
                                          .where((g) =>
                                              g['id'].toString() !=
                                              selectedGroupId)
                                          .map(
                                            (g) => AppDropdownItem<String>(
                                              value: g['id'].toString(),
                                              label: (g['nameen'] ?? '')
                                                  .toString(),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: saving
                                          ? null
                                          : (v) => setLocalState(
                                              () => sourceGroupId = v),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  AppButton.outlined(
                                    label: 'แทนที่',
                                    fullWidth: false,
                                    onPressed: saving || sourceGroupId == null
                                        ? null
                                        : () => copyFromSource(merge: false),
                                  ),
                                  const SizedBox(width: 8),
                                  AppButton.outlined(
                                    label: 'ผสาน',
                                    fullWidth: false,
                                    onPressed: saving || sourceGroupId == null
                                        ? null
                                        : () => copyFromSource(merge: true),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ...grouped.entries.map(
                                (entry) => Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          top: 8, bottom: 4),
                                      child: Text(
                                        entry.key,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    ...entry.value.map(
                                      (item) => CheckboxListTile(
                                        value: selectedPermissions
                                            .contains(item.key),
                                        title: Text(item.label),
                                        subtitle: Text(item.key,
                                            style:
                                                const TextStyle(fontSize: 12)),
                                        contentPadding: EdgeInsets.zero,
                                        dense: true,
                                        onChanged: saving
                                            ? null
                                            : (checked) {
                                                setLocalState(() {
                                                  if (checked == true) {
                                                    selectedPermissions
                                                        .add(item.key);
                                                  } else {
                                                    selectedPermissions
                                                        .remove(item.key);
                                                  }
                                                  selectedPermissions = {
                                                    ...selectedPermissions
                                                  };
                                                });
                                              },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.sp12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AppButton.outlined(
                            label: TransactionUiText.cancel,
                            fullWidth: false,
                            onPressed: saving
                                ? null
                                : () => Navigator.pop(dialogContext, false),
                          ),
                          const SizedBox(width: AppTheme.sp8),
                          AppButton.primary(
                            label: TransactionUiText.save,
                            isLoading: saving,
                            fullWidth: false,
                            onPressed: () async {
                              final groupId = int.tryParse(selectedGroupId);
                              if (groupId == null) return;
                              setLocalState(() => saving = true);
                              await onSave(groupId, selectedPermissions);
                              if (!dialogContext.mounted) return;
                              Navigator.pop(dialogContext, true);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
