import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/features/member/presentation/providers/member_provider.dart';
import 'package:saccm/features/prefix/presentation/pages/prefix_management_page.dart';
import 'package:saccm/widgets/dialog/alertDialog/custom_autodismiss_alert.dart';
import 'package:saccm/widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Member extends StatelessWidget {
  const Member({super.key, this.initialData});

  final Map<String, dynamic>? initialData;

  @override
  Widget build(BuildContext context) {
    final existingProvider =
        Provider.of<MemberProvider?>(context, listen: false);
    final child = _MemberView(initialData: initialData);
    if (existingProvider != null) return child;

    return ChangeNotifierProvider(
      create: (_) => MemberProvider(prefix: []),
      child: child,
    );
  }
}

class _MemberView extends StatefulWidget {
  const _MemberView({this.initialData});

  final Map<String, dynamic>? initialData;

  @override
  State<_MemberView> createState() => _ComponentsState();
}

class _ResponsiveFormField {
  const _ResponsiveFormField({
    required this.child,
    this.span = 1,
  });

  final Widget child;
  final int span;
}

class _ComponentsState extends State<_MemberView> {
  static const String _fontFamily = 'Kanit';
  static const double _maxResponsiveFormWidth = 1440;

  final _code = TextEditingController(),
      _name = TextEditingController(),
      _lastName = TextEditingController(),
      _email = TextEditingController(),
      _address = TextEditingController(),
      _contactnumber = TextEditingController();
// check focus input
  final FocusNode _emailFocusNode = FocusNode(),
      _codeFocusNode = FocusNode(),
      _nameFocusNode = FocusNode(),
      _contactnumberFocusNode = FocusNode(),
      _addressFocusNode = FocusNode(),
      _lastNameFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  late MemberProvider memberProvider;

  String? token;

  late String? refprefix;
  String? _editingLocalId;
  bool _didOpenInitialEditor = false;
  bool get _isEditMode => _editingLocalId != null;

  void checkOnChang(dynamic value) async {
    debugPrint(value);
  }

  @override
  void dispose() {
    for (final controller in _textControllers) {
      controller.removeListener(_onFormChanged);
    }
    _code.dispose();
    _name.dispose();
    _lastName.dispose();
    _email.dispose();
    _address.dispose();
    _contactnumber.dispose();
    _searchController.dispose();
    _emailFocusNode.dispose();
    _codeFocusNode.dispose();
    _nameFocusNode.dispose();
    _contactnumberFocusNode.dispose();
    _addressFocusNode.dispose();
    _lastNameFocusNode.dispose();
    super.dispose();
  }

  @override
  void deactivate() {
    // TODO: implement deactivate
    super.deactivate();
  }

  @override
  void didChangeDependencies() {
    // TODO: implement didChangeDependencies
    super.didChangeDependencies();
    // loadPrefix();
  }

  @override
  void initState() {
    super.initState();
    for (final controller in _textControllers) {
      controller.addListener(_onFormChanged);
    }
    SchedulerBinding.instance.addPostFrameCallback((_) => loadPage());

    // load prefix

// end check state focus node
  }

  List<TextEditingController> get _textControllers => [
        _code,
        _name,
        _lastName,
        _email,
        _address,
        _contactnumber,
      ];

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    memberProvider = Provider.of<MemberProvider>(context);
    final c = AppColors.of(context);

    return SafeArea(
      child: Scaffold(
        backgroundColor: c.background,
        appBar: _buildAppBar(c),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: _buildContent(c),
        ),
        floatingActionButton: SizedBox(
          width: 56,
          height: 56,
          child: FloatingActionButton(
            onPressed: () => _showMemberFormSheet(),
            tooltip: TransactionUiText.addMember,
            backgroundColor: c.navy,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add_rounded),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppColors c) {
    return AppBar(
      toolbarHeight: 52,
      backgroundColor: c.cardWhite,
      title: Text(
        TransactionUiText.members,
        style: TextStyle(
          fontFamily: _fontFamily,
          color: c.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      centerTitle: true,
      elevation: 0,
      actions: [
        Padding(
          padding: const EdgeInsetsDirectional.only(end: AppTheme.sp12),
          child: IconButton(
            icon: Icon(
              Icons.help_outline_rounded,
              size: 20,
              color: c.textSecondary,
            ),
            tooltip: TransactionUiText.members,
            visualDensity: VisualDensity.compact,
            onPressed: _showPageGuideDialog,
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: c.cardBorder),
      ),
    );
  }

  Future<void> _showPageGuideDialog() async {
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    await PageGuideDialog.show(
      context: context,
      title: TransactionUiText.members,
      items: [
        PageGuideItem(
          icon: Icons.groups_rounded,
          text: TransactionUiText.memberFormHint,
          backgroundColor: scheme.primary.withValues(alpha: 0.08),
        ),
        PageGuideItem(
          icon: Icons.info_outline_rounded,
          text: TransactionUiText.memberRequiredBeforeSaveHint,
          backgroundColor: c.cardWhite,
        ),
        PageGuideItem(
          icon: Icons.list_alt_rounded,
          text: TransactionUiText.memberListTapToEdit,
          backgroundColor: c.cardWhite,
        ),
      ],
    );
  }

  Widget _buildContent(AppColors c) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(AppTheme.sp16),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxResponsiveFormWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMemberListCard(c),
              const SizedBox(height: AppTheme.sp24),
            ],
          ),
        ),
      ),
    );
  }

  double _cardContentWidth(double cardWidth) {
    final horizontalPadding = AppTheme.sp16 * 2;
    return cardWidth > horizontalPadding
        ? cardWidth - horizontalPadding
        : cardWidth;
  }

  int _responsiveColumnCount(double maxWidth) {
    if (maxWidth >= 1180) return 4;
    if (maxWidth >= 900) return 3;
    if (maxWidth >= 560) return 2;
    return 1;
  }

  Widget _responsiveFieldGrid(
    double maxWidth, {
    required int columnCount,
    required List<_ResponsiveFormField> fields,
    double spacing = AppTheme.sp12,
  }) {
    final columns = columnCount.clamp(1, 4).toInt();
    final columnWidth = (maxWidth - (spacing * (columns - 1))) / columns;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: fields.map((field) {
        final span = field.span.clamp(1, columns).toInt();
        final width = (columnWidth * span) + (spacing * (span - 1));
        return SizedBox(width: width, child: field.child);
      }).toList(),
    );
  }

  Widget _buildPrefixField() {
    final provider = context.watch<MemberProvider>();
    final rows = provider.prefix;
    if (rows.isEmpty) {
      return AppInput(
        label: TransactionUiText.prefix,
        hint: TransactionUiText.selectPrefix,
        required: true,
        readOnly: true,
        prefixIcon: const Icon(Icons.badge_outlined),
        onTap: _promptNavigateToManagePrefix,
        action: const AppInputAction.text(
          suffixIcon: Icon(Icons.manage_search_rounded),
        ),
        helperText: TransactionUiText.prefixNoDataDialogBody,
      );
    }

    final selected = rows.any((e) => e[0] == provider.valuePrefix)
        ? provider.valuePrefix
        : null;
    return AppLookupPickerField<String>(
      label: TransactionUiText.prefix,
      hint: TransactionUiText.selectPrefix,
      required: true,
      prefixIcon: const Icon(Icons.badge_outlined),
      clearable: false,
      items: rows
          .map(
            (e) => AppDropdownItem<String>(
              value: e[0],
              label: e[1],
            ),
          )
          .toList(),
      value: selected,
      onChanged: (val) {
        if (val != null) provider.addValuePrefix(val);
      },
    );
  }

  Widget _buildFormCard(AppColors c) {
    return Container(
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r16),
        border: Border.all(color: c.cardBorder, width: 1),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final contentWidth = _cardContentWidth(box.maxWidth);
          final columnCount = _responsiveColumnCount(contentWidth);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                c,
                icon: Icons.badge_outlined,
                title: TransactionUiText.memberProfileSection,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.sp16,
                  0,
                  AppTheme.sp16,
                  AppTheme.sp16,
                ),
                child: _responsiveFieldGrid(
                  contentWidth,
                  columnCount: columnCount,
                  fields: [
                    _ResponsiveFormField(
                      child: AppInput(
                        label: TransactionUiText.code,
                        required: true,
                        focusNode: _codeFocusNode,
                        controller: _code,
                        textInputAction: TextInputAction.next,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: _required(TransactionUiText.codeRequired),
                      ),
                    ),
                    _ResponsiveFormField(child: _buildPrefixField()),
                    _ResponsiveFormField(
                      child: AppInput(
                        label: TransactionUiText.firstName,
                        required: true,
                        focusNode: _nameFocusNode,
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator:
                            _required(TransactionUiText.firstNameRequired),
                      ),
                    ),
                    _ResponsiveFormField(
                      child: AppInput(
                        label: TransactionUiText.lastName,
                        required: true,
                        focusNode: _lastNameFocusNode,
                        controller: _lastName,
                        textInputAction: TextInputAction.next,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator:
                            _required(TransactionUiText.lastNameRequired),
                      ),
                    ),
                    _ResponsiveFormField(
                      span: columnCount >= 4 ? 2 : 1,
                      child: AppInput(
                        label: TransactionUiText.email,
                        focusNode: _emailFocusNode,
                        controller: _email,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    _ResponsiveFormField(
                      child: AppInput(
                        label: TransactionUiText.contactNumber,
                        focusNode: _contactnumberFocusNode,
                        controller: _contactnumber,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    _ResponsiveFormField(
                      span: columnCount,
                      child: AppInput(
                        label: TransactionUiText.address,
                        focusNode: _addressFocusNode,
                        controller: _address,
                        minLines: 2,
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showMemberFormSheet({
    Map<String, dynamic>? existing,
    bool popPageOnClose = false,
  }) async {
    FocusScope.of(context).unfocus();
    clearInput();
    if (existing != null) {
      _applyMemberData(existing);
    }
    final provider = context.read<MemberProvider>();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return ChangeNotifierProvider<MemberProvider>.value(
          value: provider,
          child: SafeArea(
            child: AdaptiveContentSheet(
              title: existing == null
                  ? TransactionUiText.addMember
                  : TransactionUiText.editMember,
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  ..._textControllers,
                  provider,
                ]),
                builder: (context, _) {
                  final c = AppColors.of(context);
                  final canSubmit = _isReadyToSave && !provider.isLoading;
                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      AppTheme.sp16,
                      0,
                      AppTheme.sp16,
                      MediaQuery.viewInsetsOf(sheetContext).bottom +
                          AppTheme.sp16,
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (provider.isLoading) ...[
                              const LinearProgressIndicator(minHeight: 2),
                              const SizedBox(height: AppTheme.sp12),
                            ],
                            _buildFormCard(c),
                            const SizedBox(height: AppTheme.sp12),
                            _buildSheetActionButtons(
                              sheetContext,
                              canSubmit: canSubmit,
                              isSaving: provider.isLoading,
                              popPageOnClose: popPageOnClose,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    clearInput();
    setState(() {});
    if (popPageOnClose && mounted) {
      Navigator.pop(context, result == true);
    }
  }

  Widget _buildSheetActionButtons(
    BuildContext sheetContext, {
    required bool canSubmit,
    required bool isSaving,
    required bool popPageOnClose,
  }) {
    return LayoutBuilder(
      builder: (context, box) {
        final isWide = box.maxWidth >= 560;
        final cancelButton = AppButton.outlined(
          label: TransactionUiText.cancel,
          icon: const Icon(Icons.close_rounded, size: 18),
          fullWidth: !isWide,
          onPressed:
              isSaving ? null : () => Navigator.of(sheetContext).pop(false),
        );
        final saveButton = AppButton.primary(
          label:
              _isEditMode ? TransactionUiText.saveEdit : TransactionUiText.save,
          icon: const Icon(Icons.save_rounded, size: 18),
          fullWidth: !isWide,
          isLoading: isSaving,
          onPressed: canSubmit
              ? () async {
                  final success = await _saveOnPressed();
                  if (!success) return;
                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop(true);
                  }
                }
              : null,
        );
        if (!isWide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cancelButton,
              const SizedBox(height: AppTheme.sp8),
              saveButton,
            ],
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(width: 160, child: cancelButton),
            const SizedBox(width: AppTheme.sp8),
            SizedBox(width: 180, child: saveButton),
          ],
        );
      },
    );
  }

  Widget _buildMemberListCard(AppColors c) {
    return Container(
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r16),
        border: Border.all(color: c.cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            c,
            icon: Icons.list_alt_rounded,
            title: TransactionUiText.memberListSection,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.sp16,
              0,
              AppTheme.sp16,
              AppTheme.sp16,
            ),
            child: AppInput(
              label: TransactionUiText.memberListTapToEdit,
              hint: TransactionUiText.memberSearchHint,
              controller: _searchController,
              prefixIcon: const Icon(Icons.search_rounded),
              textInputAction: TextInputAction.search,
            ),
          ),
          Divider(height: 1, color: c.cardBorder),
          Padding(
            padding: const EdgeInsets.all(AppTheme.sp8),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (_, __, ___) => _buildMemberList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    AppColors c, {
    required IconData icon,
    required String title,
  }) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.sp16,
        AppTheme.sp16,
        AppTheme.sp16,
        AppTheme.sp12,
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: AppTheme.sp8),
          Text(
            title,
            style: TextStyle(
              fontFamily: _fontFamily,
              color: c.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  bool get _isReadyToSave =>
      _code.text.trim().isNotEmpty &&
      memberProvider.prefix.any((e) => e[0] == memberProvider.valuePrefix) &&
      _name.text.trim().isNotEmpty &&
      _lastName.text.trim().isNotEmpty;

  String? Function(String?) _required(String message) {
    return (value) => (value == null || value.trim().isEmpty) ? message : null;
  }

  Widget _buildMemberList() {
    final query = _searchController.text.trim().toLowerCase();
    final members = context.watch<MemberProvider>().members.where((row) {
      if (query.isEmpty) return true;
      final code = row['code']?.toString().toLowerCase() ?? '';
      final name = row['name']?.toString().toLowerCase() ?? '';
      final contact = row['contactnumber']?.toString().toLowerCase() ?? '';
      return code.contains(query) ||
          name.contains(query) ||
          contact.contains(query);
    }).toList();
    if (members.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(query.isEmpty
            ? TransactionUiText.emptyMember
            : TransactionUiText.notFound),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: members.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final row = members[index];
        return ListTile(
          dense: true,
          title: Text('${row['code'] ?? ''} - ${row['name'] ?? ''}'),
          subtitle: Text(row['contactnumber']?.toString() ?? ''),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ServerSyncStatusBadge(
                synced: row['synced'] == true,
                borderRadius: 10,
                showBorder: false,
                margin: const EdgeInsets.only(right: 6),
              ),
              const Icon(Icons.edit_rounded, size: 18),
            ],
          ),
          onTap: () => _showMemberFormSheet(existing: row),
        );
      },
    );
  }

  void loadPrefix() async {
    context.read<MemberProvider>().loadPrefixes();
  }

  Future<void> _promptNavigateToManagePrefix() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => NoPrefixPromptDialog(
        onGoManagePrefix: _openPrefixManagementPage,
      ),
    );
  }

  void _openPrefixManagementPage() {
    if (!mounted) return;
    Navigator.of(context)
        .push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const PrefixManagementPage(),
      ),
    )
        .then((_) {
      if (mounted) {
        context.read<MemberProvider>().loadPrefixes();
      }
    });
  }

  Future<void> loadPage() async {
    SharedPreferences prefsData = await SharedPreferences.getInstance();
    if (!mounted) return;
    token = prefsData.getString("token");
    loadPrefix();
    await context.read<MemberProvider>().loadMemberList();
    if (!mounted) return;

    if (widget.initialData != null && !_didOpenInitialEditor) {
      _didOpenInitialEditor = true;
      await _showMemberFormSheet(
        existing: widget.initialData,
        popPageOnClose: true,
      );
    }
  }

  Future<bool> _saveOnPressed() async {
    if (!mounted) return false;
    final memberProvider = context.read<MemberProvider>();
    if (!memberProvider.prefix.any((e) => e[0] == memberProvider.valuePrefix)) {
      await _promptNavigateToManagePrefix();
      return false;
    }
    final success = _isEditMode
        ? await memberProvider.updateMember(
            localId: _editingLocalId ?? '',
            token: token ?? '',
            memberCode: _code.text,
            name: _name.text,
            lastName: _lastName.text,
            email: _email.text,
            contactNumber: _contactnumber.text,
            address: _address.text,
          )
        : await memberProvider.saveMember(
            token: token ?? '',
            memberCode: _code.text,
            name: _name.text,
            lastName: _lastName.text,
            email: _email.text,
            contactNumber: _contactnumber.text,
            address: _address.text,
          );
    if (!mounted) return false;
    if (success) {
      showAutoDismissAlert(
        context,
        TransactionUiText.warning,
        _isEditMode
            ? TransactionUiText.editSuccess
            : TransactionUiText.saveSuccess,
        null,
      );
      await memberProvider.loadMemberList();
      if (!mounted) return false;
      setState(() {});
      return true;
    } else {
      final err = memberProvider.error ?? TransactionUiText.saveFailed;
      showAutoDismissAlert(context, TransactionUiText.warning, err, null);
      return false;
    }
  }

  void clearInput() {
    _name.text = "";
    _code.text = '';
    _lastName.text = '';
    _email.text = '';
    _contactnumber.text = '';
    memberProvider.addValuePrefix('0');
    _address.text = '';
    _editingLocalId = null;
  }

  void _applyMemberData(Map<String, dynamic> data) {
    _editingLocalId = data['id']?.toString();
    _code.text = data['code']?.toString() ?? '';
    _name.text = data['name']?.toString() ?? '';
    _lastName.text = data['lastname']?.toString() ?? '';
    _email.text = data['email']?.toString() ?? '';
    _contactnumber.text = data['contactnumber']?.toString() ?? '';
    _address.text = data['address']?.toString() ?? '';
    final prefix = data['refprefix']?.toString();
    if (prefix != null && prefix.isNotEmpty) {
      memberProvider.addValuePrefix(prefix);
    }
    setState(() {});
  }
}
