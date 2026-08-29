// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/data_sources/menu_remote_data_source.dart';
import 'package:saccm/core/local_data_source/app_menu_local_data_source.dart';
import 'package:saccm/core/services/app_notification_service.dart';
import 'package:saccm/core/services/menu_refresh_bus.dart';
import 'package:saccm/features/auth/presentation/providers/simple_auth_provider.dart';
import 'package:saccm/widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MenuEditModel {
  _MenuEditModel({
    required this.id,
    required this.parentId,
    required this.slug,
    required this.nameTh,
    required this.sortOrder,
    required this.isActive,
    this.navIndex,
  });

  final int id;
  final int? parentId;
  final String slug;
  String nameTh;
  int sortOrder;
  int isActive;
  final int? navIndex;

  bool get isSection => parentId == null && navIndex == null;

  factory _MenuEditModel.fromRow(AppMenuRow r) {
    return _MenuEditModel(
      id: r.id,
      parentId: r.parentId,
      slug: r.slug,
      nameTh: r.nameTh,
      sortOrder: r.sortOrder,
      isActive: r.isActive,
      navIndex: r.navIndex,
    );
  }
}

/// ตั้งค่าเมนูหลักจากตาราง [app_menu] (local-first + อัปโหลดเซิร์ฟเวอร์เมื่อมี JWT)
class MenuConfigurationPage extends StatefulWidget {
  const MenuConfigurationPage({super.key});

  @override
  State<MenuConfigurationPage> createState() => _MenuConfigurationPageState();
}

class _MenuConfigurationPageState extends State<MenuConfigurationPage> {
  static const String _fontFamily = 'Kanit';
  static const double _maxResponsiveFormWidth = 1440;

  final AppMenuLocalDataSource _local = AppMenuLocalDataSource();
  final Dio _dio = Dio();
  final Map<int, TextEditingController> _nameCtrls = {};

  List<_MenuEditModel> _models = [];
  bool _loading = true;
  bool _saving = false;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    for (final c in _nameCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await _local.loadAllRowsForEdit();
      if (!mounted) return;
      for (final c in _nameCtrls.values) {
        c.dispose();
      }
      _nameCtrls.clear();
      _models = rows.map(_MenuEditModel.fromRow).toList();
      for (final m in _models) {
        _nameCtrls[m.id] = TextEditingController(text: m.nameTh);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_MenuEditModel> _rootsSorted() {
    final roots = _models.where((m) => m.parentId == null).toList();
    roots.sort((a, b) {
      final c = a.sortOrder.compareTo(b.sortOrder);
      if (c != 0) return c;
      return a.id.compareTo(b.id);
    });
    return roots;
  }

  List<_MenuEditModel> _childrenSorted(int parentId) {
    final ch = _models.where((m) => m.parentId == parentId).toList();
    ch.sort((a, b) {
      final c = a.sortOrder.compareTo(b.sortOrder);
      if (c != 0) return c;
      return a.id.compareTo(b.id);
    });
    return ch;
  }

  void _reindexSortOrders(List<_MenuEditModel> items) {
    for (var i = 0; i < items.length; i++) {
      items[i].sortOrder = i;
    }
  }

  void _moveRoot(int id, {required bool up}) {
    final roots = _rootsSorted();
    final i = roots.indexWhere((r) => r.id == id);
    if (i < 0) return;
    final j = up ? i - 1 : i + 1;
    if (j < 0 || j >= roots.length) return;
    final moved = roots.removeAt(i);
    roots.insert(j, moved);
    _reindexSortOrders(roots);
    setState(() {});
  }

  void _moveChild(int parentId, int id, {required bool up}) {
    final ch = _childrenSorted(parentId);
    final i = ch.indexWhere((r) => r.id == id);
    if (i < 0) return;
    final j = up ? i - 1 : i + 1;
    if (j < 0 || j >= ch.length) return;
    final moved = ch.removeAt(i);
    ch.insert(j, moved);
    _reindexSortOrders(ch);
    setState(() {});
  }

  Future<String?> _readServerToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  bool _isLikelyJwt(String? t) =>
      t != null && t.isNotEmpty && !t.startsWith('local_');

  Future<void> _save() async {
    final auth = context.read<SimpleAuthProvider>();
    if (!auth.can(PermissionKey.menuConfigure)) {
      AppNotificationService.instance.showWarning(
        TransactionUiText.warning,
        TransactionUiText.menuConfigurationNoPermission,
      );
      return;
    }

    for (final m in _models) {
      final c = _nameCtrls[m.id];
      if (c != null) m.nameTh = c.text.trim();
    }

    for (final m in _models) {
      if (m.nameTh.isEmpty) {
        AppNotificationService.instance.showWarning(
          TransactionUiText.warning,
          '${TransactionUiText.requiredName} (id ${m.id})',
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final patches = _models
          .map(
            (m) => (
              id: m.id,
              nameTh: m.nameTh,
              sortOrder: m.sortOrder,
              isActive: m.isActive,
            ),
          )
          .toList();
      await _local.applyBulkFieldUpdates(patches);

      final token = await _readServerToken();
      if (_isLikelyJwt(token)) {
        try {
          final remote = MenuRemoteDataSource(dio: _dio);
          final body = patches
              .map(
                (p) => <String, dynamic>{
                  'id': p.id,
                  'name_th': p.nameTh,
                  'sort_order': p.sortOrder,
                  'is_active': p.isActive,
                },
              )
              .toList();
          final serverRows = await remote.saveBulk(token!, body);
          await _local.replaceAllFromServerRows(serverRows);
          await _load();
        } catch (e) {
          if (mounted) {
            AppNotificationService.instance.showWarning(
              TransactionUiText.warning,
              TransactionUiText.menuConfigurationServerSyncFailed,
            );
          }
        }
      }

      MenuRefreshBus.notify();
      if (mounted) {
        AppNotificationService.instance.showSuccess(
          TransactionUiText.success,
          TransactionUiText.saveSuccess,
        );
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pullFromServer() async {
    final auth = context.read<SimpleAuthProvider>();
    if (!auth.can(PermissionKey.menuConfigure)) {
      AppNotificationService.instance.showWarning(
        TransactionUiText.warning,
        TransactionUiText.menuConfigurationNoPermission,
      );
      return;
    }
    final token = await _readServerToken();
    if (!_isLikelyJwt(token)) {
      AppNotificationService.instance.showWarning(
        TransactionUiText.warning,
        TransactionUiText.menuConfigurationNeedLogin,
      );
      return;
    }
    setState(() => _syncing = true);
    try {
      final remote = MenuRemoteDataSource(dio: _dio);
      final rows = await remote.fetchAllRows(token!);
      await _local.replaceAllFromServerRows(rows);
      await _load();
      MenuRefreshBus.notify();
      if (mounted) {
        AppNotificationService.instance.showSuccess(
          TransactionUiText.success,
          TransactionUiText.saveSuccess,
        );
      }
    } catch (e) {
      if (mounted) {
        AppNotificationService.instance.showError(
          TransactionUiText.error,
          e.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final auth = context.watch<SimpleAuthProvider>();
    final canEdit = auth.can(PermissionKey.menuConfigure);

    return SafeArea(
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          toolbarHeight: 52,
          title: Text(
            TransactionUiText.menuConfigurationTitle,
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
          actions: [
            if (canEdit)
              IconButton(
                tooltip: TransactionUiText.menuConfigurationSyncFromServer,
                onPressed: _syncing ? null : _pullFromServer,
                icon: _syncing
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                    : Icon(Icons.cloud_download_outlined, color: c.textPrimary),
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : !canEdit
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        TransactionUiText.menuConfigurationNoPermission,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 15,
                          fontFamily: 'Kanit',
                        ),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(AppTheme.sp16),
                    children: [
                      Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: _maxResponsiveFormWidth,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TransactionFormHeader(
                                icon: Icons.menu_open_rounded,
                                iconColor:
                                    Theme.of(context).colorScheme.primary,
                                iconBgColor: c.iconBgIncome,
                                title: TransactionUiText.menuConfigurationTitle,
                                subtitle:
                                    TransactionUiText.menuConfigurationSubtitle,
                                quickHint: TransactionUiText
                                    .menuConfigurationNeedLogin,
                                hintAccentColor:
                                    Theme.of(context).colorScheme.primary,
                                hintBorderColor: c.cardBorder,
                                textPrimaryColor: c.textPrimary,
                                showQuickHint: false,
                              ),
                              const SizedBox(height: AppTheme.sp16),
                              for (final root in _rootsSorted()) ...[
                                _buildSectionCard(context, root),
                                const SizedBox(height: AppTheme.sp12),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
        floatingActionButton: canEdit && !_loading
            ? FloatingActionButton.extended(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded),
                label: const Text(
                  TransactionUiText.menuConfigurationSave,
                  style: TextStyle(fontFamily: 'Kanit'),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildSectionCard(BuildContext context, _MenuEditModel root) {
    final c = AppColors.of(context);
    final roots = _rootsSorted();
    final ri = roots.indexWhere((r) => r.id == root.id);
    final children = _childrenSorted(root.id);

    return Card(
      color: c.cardWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.r16),
        side: BorderSide(color: c.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sp16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    root.isSection
                        ? TransactionUiText.menuConfigurationSectionHeader
                        : TransactionUiText.menuConfigurationLeafHeader,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      fontFamily: 'Kanit',
                    ),
                  ),
                ),
                IconButton(
                  tooltip: TransactionUiText.menuConfigurationMoveUp,
                  onPressed: ri > 0 ? () => _moveRoot(root.id, up: true) : null,
                  icon: Icon(Icons.arrow_upward_rounded, color: c.textPrimary),
                ),
                IconButton(
                  tooltip: TransactionUiText.menuConfigurationMoveDown,
                  onPressed: ri < roots.length - 1
                      ? () => _moveRoot(root.id, up: false)
                      : null,
                  icon:
                      Icon(Icons.arrow_downward_rounded, color: c.textPrimary),
                ),
              ],
            ),
            Text(
              '${TransactionUiText.menuConfigurationSlugHint}: ${root.slug}',
              style: TextStyle(
                color: c.textHint,
                fontSize: 12,
                fontFamily: 'Kanit',
              ),
            ),
            const SizedBox(height: AppTheme.sp8),
            AppInput(
              controller: _nameCtrls[root.id],
              label: TransactionUiText.menuConfigurationDisplayName,
              action: const AppInputAction.text(),
              onChanged: (v) => root.nameTh = v,
            ),
            const SizedBox(height: AppTheme.sp8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                TransactionUiText.menuConfigurationActive,
                style: TextStyle(
                  color: c.textPrimary,
                  fontFamily: 'Kanit',
                ),
              ),
              value: root.isActive == 1,
              onChanged: (v) => setState(() => root.isActive = v ? 1 : 0),
            ),
            if (children.isNotEmpty) ...[
              const Divider(height: 24),
              for (var ci = 0; ci < children.length; ci++) ...[
                if (ci > 0) const SizedBox(height: AppTheme.sp12),
                _buildLeafRow(
                    context, root.id, children[ci], ci, children.length),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLeafRow(
    BuildContext context,
    int parentId,
    _MenuEditModel leaf,
    int indexInParent,
    int childCount,
  ) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: AppTheme.sp8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: c.cardBorder, width: 2)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: AppTheme.sp12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      leaf.navIndex != null
                          ? 'nav ${leaf.navIndex}'
                          : leaf.slug,
                      style: TextStyle(
                        color: c.textHint,
                        fontSize: 12,
                        fontFamily: 'Kanit',
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: TransactionUiText.menuConfigurationMoveUp,
                    onPressed: indexInParent > 0
                        ? () => _moveChild(parentId, leaf.id, up: true)
                        : null,
                    icon: Icon(Icons.arrow_upward_rounded,
                        size: 20, color: c.textPrimary),
                  ),
                  IconButton(
                    tooltip: TransactionUiText.menuConfigurationMoveDown,
                    onPressed: indexInParent < childCount - 1
                        ? () => _moveChild(parentId, leaf.id, up: false)
                        : null,
                    icon: Icon(Icons.arrow_downward_rounded,
                        size: 20, color: c.textPrimary),
                  ),
                ],
              ),
              AppInput(
                controller: _nameCtrls[leaf.id],
                label: TransactionUiText.menuConfigurationDisplayName,
                action: const AppInputAction.text(),
                onChanged: (v) => leaf.nameTh = v,
              ),
              const SizedBox(height: AppTheme.sp4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  TransactionUiText.menuConfigurationActive,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 14,
                    fontFamily: 'Kanit',
                  ),
                ),
                value: leaf.isActive == 1,
                onChanged: (v) => setState(() => leaf.isActive = v ? 1 : 0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
