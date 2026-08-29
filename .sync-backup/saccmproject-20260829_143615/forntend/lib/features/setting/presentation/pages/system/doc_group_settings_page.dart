// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/local_data_source/doc_group_local_data_source.dart';
import 'package:saccm/features/auth/presentation/providers/simple_auth_provider.dart';
import 'package:saccm/widgets/widgets.dart';

class DocGroupSettingsPage extends StatefulWidget {
  const DocGroupSettingsPage({super.key});

  @override
  State<DocGroupSettingsPage> createState() => _DocGroupSettingsPageState();
}

class _DocGroupSettingsPageState extends State<DocGroupSettingsPage> {
  final _local = DocGroupLocalDataSource();
  bool _loading = true;
  String? _error;
  List<DocGroupConfig> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final receiptBookConfig = await _local.getReceiptBookConfig();
      await _local.upsertDocGroup(receiptBookConfig);
      final rows = await _local.listDocGroups();
      if (!mounted) return;
      setState(() => _rows = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _normalizeRunGroupForComparison(String value) {
    return value.trim().toUpperCase();
  }

  bool _hasDuplicateRunGroup(String value, String currentId) {
    final normalized = _normalizeRunGroupForComparison(value);
    if (normalized.isEmpty) return false;
    return _rows.any((existing) {
      if (existing.id == currentId) return false;
      return _normalizeRunGroupForComparison(existing.runGroup) == normalized;
    });
  }

  Future<void> _edit(DocGroupConfig row) async {
    final tableNameCtrl = TextEditingController(text: row.tableName);
    final nameCtrl = TextEditingController(text: row.name);
    final runGroupCtrl = TextEditingController(text: row.runGroup);
    final formatCtrl = TextEditingController(text: row.docNoFormat);
    final formKey = GlobalKey<FormState>();

    try {
      final ok = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: false,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return SafeArea(
            child: AdaptiveContentSheet(
              title: TransactionUiText.docGroupEditTitle,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppTheme.sp16,
                  0,
                  AppTheme.sp16,
                  MediaQuery.viewInsetsOf(sheetContext).bottom + AppTheme.sp16,
                ),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppInput(
                          label: TransactionUiText.docGroupTableName,
                          controller: tableNameCtrl,
                          readOnly: true,
                          action: const AppInputAction.text(),
                        ),
                        const SizedBox(height: AppTheme.sp12),
                        AppInput(
                          label: TransactionUiText.docGroupName,
                          controller: nameCtrl,
                          required: true,
                          action: const AppInputAction.text(),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? TransactionUiText.registerFieldRequired
                              : null,
                        ),
                        const SizedBox(height: AppTheme.sp12),
                        AppInput(
                          label: TransactionUiText.docGroupRunGroup,
                          controller: runGroupCtrl,
                          helperText: TransactionUiText.docGroupRunGroupHint,
                          required: true,
                          action: const AppInputAction.text(),
                          validator: (v) {
                            final value = v?.trim() ?? '';
                            if (value.isEmpty) {
                              return TransactionUiText.docGroupRunGroupRequired;
                            }
                            if (RegExp(r'\s').hasMatch(value)) {
                              return TransactionUiText.docGroupRunGroupInvalid;
                            }
                            if (_hasDuplicateRunGroup(value, row.id)) {
                              return TransactionUiText
                                  .docGroupRunGroupDuplicate;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppTheme.sp12),
                        AppInput(
                          label: TransactionUiText.docGroupFormat,
                          hint: TransactionUiText.docGroupFormatHint,
                          helperText: TransactionUiText.docGroupFormatGuide,
                          controller: formatCtrl,
                          required: true,
                          action: const AppInputAction.text(),
                          validator: (v) {
                            final value = v?.trim() ?? '';
                            if (value.isEmpty) {
                              return TransactionUiText.registerFieldRequired;
                            }
                            if (!RegExp(r'\{RUN\d*\}').hasMatch(value)) {
                              return TransactionUiText
                                  .docGroupFormatRequiredRun;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppTheme.sp16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(sheetContext, false),
                              child: const Text(TransactionUiText.cancel),
                            ),
                            const SizedBox(width: AppTheme.sp8),
                            ElevatedButton(
                              onPressed: () {
                                if (formKey.currentState?.validate() != true) {
                                  return;
                                }
                                Navigator.pop(sheetContext, true);
                              },
                              child: const Text(TransactionUiText.save),
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
      );

      if (ok != true) return;
      final runGroup = runGroupCtrl.text.trim();
      final duplicateRunGroup =
          await _local.isRunGroupTaken(runGroup, excludeId: row.id);
      if (duplicateRunGroup) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(TransactionUiText.docGroupRunGroupDuplicate),
          ),
        );
        return;
      }
      await _local.upsertDocGroup(
        row.copyWith(
          name: nameCtrl.text.trim(),
          runGroup: runGroup,
          docNoFormat: formatCtrl.text.trim(),
        ),
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(TransactionUiText.docGroupSaveSuccess)),
      );
    } finally {
      tableNameCtrl.dispose();
      nameCtrl.dispose();
      runGroupCtrl.dispose();
      formatCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<SimpleAuthProvider>();
    final allowed = auth.isAdmin && auth.can(PermissionKey.docGroupConfigure);
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          toolbarHeight: 52,
          title: const Text(TransactionUiText.docGroupSettingsTitle),
          centerTitle: true,
          backgroundColor: c.cardWhite,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: c.cardBorder),
          ),
        ),
        body: !allowed
            ? _accessDenied(c)
            : _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _content(c, scheme),
      ),
    );
  }

  Widget _accessDenied(AppColors c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sp24),
        child: Text(
          TransactionUiText.docGroupSettingsAdminOnly,
          textAlign: TextAlign.center,
          style: TextStyle(color: c.textSecondary, fontFamily: 'Kanit'),
        ),
      ),
    );
  }

  Widget _content(AppColors c, ColorScheme scheme) {
    if (_rows.isEmpty) {
      return const Center(child: Text(TransactionUiText.docGroupEmpty));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.sp16),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.sp16),
                decoration: BoxDecoration(
                  color: c.cardWhite,
                  borderRadius: BorderRadius.circular(AppTheme.r12),
                  border: Border.all(color: c.cardBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.numbers_rounded, color: scheme.primary),
                    const SizedBox(width: AppTheme.sp12),
                    Expanded(
                      child: Text(
                        TransactionUiText.docGroupSettingsSubtitle,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontFamily: 'Kanit',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.sp12),
              ..._rows.map((row) => _rowCard(row, c, scheme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rowCard(DocGroupConfig row, AppColors c, ColorScheme scheme) {
    return Card(
      color: c.cardWhite,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.r12),
        side: BorderSide(color: c.cardBorder),
      ),
      child: ListTile(
        leading: Icon(Icons.tag_rounded, color: scheme.primary),
        title: Text(
          row.name,
          style: TextStyle(
            color: c.textPrimary,
            fontFamily: 'Kanit',
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '${row.tableName} • ${row.runGroup} • ${row.docNoFormat}',
          style: TextStyle(color: c.textSecondary, fontFamily: 'Kanit'),
        ),
        trailing: IconButton(
          tooltip: TransactionUiText.edit,
          icon: const Icon(Icons.edit_rounded),
          onPressed: () => _edit(row),
        ),
      ),
    );
  }
}
