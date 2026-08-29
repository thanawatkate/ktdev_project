import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/local_data_source/audit_log_local_data_source.dart';
import 'package:saccm/core/local_data_source/user_local_data_source.dart';
import 'package:saccm/features/auth/presentation/providers/simple_auth_provider.dart';
import 'package:saccm/features/prefix/presentation/pages/prefix_management_page.dart';
import 'package:saccm/features/user/presentation/models/user_form_lookup.dart';
import 'package:saccm/features/user/presentation/widgets/user_group_permission_dialog.dart';
import 'package:saccm/features/user/presentation/widgets/user_management_dialogs.dart';
import 'package:saccm/features/user/presentation/widgets/user_form_card.dart';
import 'package:saccm/features/user/presentation/widgets/user_save_readiness_hint.dart';
import 'package:saccm/widgets/widgets.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  static const String _fontFamily = 'Kanit';
  static const double _maxResponsiveFormWidth = 1440;

  final UserLocalDataSource _userLocalDataSource = UserLocalDataSource();
  final AuditLogLocalDataSource _auditLogLocalDataSource =
      AuditLogLocalDataSource();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _codeFocusNode = FocusNode();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _lastNameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _contactNumberFocusNode = FocusNode();
  final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  bool _auditReady = false;
  bool _loading = true;
  bool _saving = false;
  int? _editingUserId;
  List<LocalUser> _users = <LocalUser>[];
  List<Map<String, dynamic>> _groups = <Map<String, dynamic>>[];
  List<UserPrefixLookupItem> _prefixes = <UserPrefixLookupItem>[];
  List<UserGroupLookupItem> _userGroupItems = <UserGroupLookupItem>[];
  String _searchQuery = '';
  String? _selectedPrefixId;
  int? _selectedUserGroupId;

  bool get _canView =>
      context.read<SimpleAuthProvider>().can(PermissionKey.userAdminView);
  bool get _canCreate =>
      context.read<SimpleAuthProvider>().can(PermissionKey.userAdminCreate);
  bool get _canResetPassword => context
      .read<SimpleAuthProvider>()
      .can(PermissionKey.userAdminResetPassword);
  bool get _canUpdateRole =>
      context.read<SimpleAuthProvider>().can(PermissionKey.userAdminUpdateRole);
  bool get _canToggleActive => context
      .read<SimpleAuthProvider>()
      .can(PermissionKey.userAdminToggleActive);
  bool get _canManagePermissions => context
      .read<SimpleAuthProvider>()
      .can(PermissionKey.userAdminPermissionManage);
  static const List<UserGroupPermissionItem> _permissionItems =
      <UserGroupPermissionItem>[
    UserGroupPermissionItem(
      PermissionKey.navHome,
      TransactionUiText.userAdminPermissionNavHome,
      TransactionUiText.userAdminPermissionCategoryMainMenu,
    ),
    UserGroupPermissionItem(
      PermissionKey.navIncome,
      TransactionUiText.userAdminPermissionNavIncome,
      TransactionUiText.userAdminPermissionCategoryMainMenu,
    ),
    UserGroupPermissionItem(
      PermissionKey.navExpenseReq,
      TransactionUiText.userAdminPermissionNavExpenseReq,
      TransactionUiText.userAdminPermissionCategoryMainMenu,
    ),
    UserGroupPermissionItem(
      PermissionKey.navExpense,
      TransactionUiText.userAdminPermissionNavExpense,
      TransactionUiText.userAdminPermissionCategoryMainMenu,
    ),
    UserGroupPermissionItem(
      PermissionKey.navLoan,
      TransactionUiText.userAdminPermissionNavLoan,
      TransactionUiText.userAdminPermissionCategoryMainMenu,
    ),
    UserGroupPermissionItem(
      PermissionKey.navReports,
      TransactionUiText.userAdminPermissionNavReports,
      TransactionUiText.userAdminPermissionCategoryMainMenu,
    ),
    UserGroupPermissionItem(
      PermissionKey.navUsageGuide,
      TransactionUiText.userAdminPermissionNavUsageGuide,
      TransactionUiText.userAdminPermissionCategoryMainMenu,
    ),
    UserGroupPermissionItem(
      PermissionKey.navLogout,
      TransactionUiText.userAdminPermissionNavLogout,
      TransactionUiText.userAdminPermissionCategoryMainMenu,
    ),
    UserGroupPermissionItem(
      PermissionKey.approvalView,
      TransactionUiText.userAdminPermissionApprovalView,
      TransactionUiText.userAdminPermissionCategoryApproval,
    ),
    UserGroupPermissionItem(
      PermissionKey.approvalApprove,
      TransactionUiText.userAdminPermissionApprovalApprove,
      TransactionUiText.userAdminPermissionCategoryApproval,
    ),
    UserGroupPermissionItem(
      PermissionKey.approvalReject,
      TransactionUiText.userAdminPermissionApprovalReject,
      TransactionUiText.userAdminPermissionCategoryApproval,
    ),
    UserGroupPermissionItem(
      PermissionKey.budgetSourceView,
      TransactionUiText.userAdminPermissionBudgetSourceView,
      TransactionUiText.userAdminPermissionCategoryBudgetSource,
    ),
    UserGroupPermissionItem(
      PermissionKey.budgetSourceCreate,
      TransactionUiText.userAdminPermissionBudgetSourceCreate,
      TransactionUiText.userAdminPermissionCategoryBudgetSource,
    ),
    UserGroupPermissionItem(
      PermissionKey.budgetSourceUpdate,
      TransactionUiText.userAdminPermissionBudgetSourceUpdate,
      TransactionUiText.userAdminPermissionCategoryBudgetSource,
    ),
    UserGroupPermissionItem(
      PermissionKey.budgetSourceDelete,
      TransactionUiText.userAdminPermissionBudgetSourceDelete,
      TransactionUiText.userAdminPermissionCategoryBudgetSource,
    ),
    UserGroupPermissionItem(
      PermissionKey.incomeDelete,
      TransactionUiText.userAdminPermissionIncomeDelete,
      TransactionUiText.userAdminPermissionCategoryIncome,
    ),
    UserGroupPermissionItem(
      PermissionKey.formsDocNoManualEdit,
      TransactionUiText.userAdminPermissionFormsDocNoManualEdit,
      TransactionUiText.userAdminPermissionCategoryForms,
    ),
    UserGroupPermissionItem(
      PermissionKey.settingView,
      TransactionUiText.userAdminPermissionSettingView,
      TransactionUiText.userAdminPermissionCategorySettings,
    ),
    UserGroupPermissionItem(
      PermissionKey.userAdminView,
      TransactionUiText.userAdminPermissionUserAdminView,
      TransactionUiText.userAdminPermissionCategoryUsers,
    ),
    UserGroupPermissionItem(
      PermissionKey.userAdminCreate,
      TransactionUiText.userAdminPermissionUserAdminCreate,
      TransactionUiText.userAdminPermissionCategoryUsers,
    ),
    UserGroupPermissionItem(
      PermissionKey.userAdminResetPassword,
      TransactionUiText.userAdminPermissionUserAdminResetPassword,
      TransactionUiText.userAdminPermissionCategoryUsers,
    ),
    UserGroupPermissionItem(
      PermissionKey.userAdminUpdateRole,
      TransactionUiText.userAdminPermissionUserAdminUpdateRole,
      TransactionUiText.userAdminPermissionCategoryUsers,
    ),
    UserGroupPermissionItem(
      PermissionKey.userAdminToggleActive,
      TransactionUiText.userAdminPermissionUserAdminToggleActive,
      TransactionUiText.userAdminPermissionCategoryUsers,
    ),
    UserGroupPermissionItem(
      PermissionKey.userAdminPermissionManage,
      TransactionUiText.userAdminPermissionUserAdminPermissionManage,
      TransactionUiText.userAdminPermissionCategoryUsers,
    ),
    UserGroupPermissionItem(
      PermissionKey.auditLogView,
      TransactionUiText.userAdminPermissionAuditLogView,
      TransactionUiText.userAdminPermissionCategoryUsers,
    ),
    UserGroupPermissionItem(
      PermissionKey.menuConfigure,
      TransactionUiText.userAdminPermissionMenuConfigure,
      TransactionUiText.userAdminPermissionCategorySettings,
    ),
  ];
  static const Map<String, Set<String>> _permissionTemplates =
      <String, Set<String>>{
    TransactionUiText.userAdminTemplateFinanceOfficer: <String>{
      PermissionKey.navHome,
      PermissionKey.navIncome,
      PermissionKey.navExpenseReq,
      PermissionKey.navExpense,
      PermissionKey.navLoan,
      PermissionKey.navReports,
      PermissionKey.navUsageGuide,
      PermissionKey.navLogout,
      PermissionKey.budgetSourceView,
      PermissionKey.budgetSourceCreate,
      PermissionKey.budgetSourceUpdate,
      PermissionKey.incomeDelete,
      PermissionKey.formsDocNoManualEdit,
    },
    TransactionUiText.userAdminTemplateApproverLead: <String>{
      PermissionKey.navHome,
      PermissionKey.navIncome,
      PermissionKey.navExpenseReq,
      PermissionKey.navExpense,
      PermissionKey.navLoan,
      PermissionKey.navReports,
      PermissionKey.navUsageGuide,
      PermissionKey.navLogout,
      PermissionKey.approvalView,
      PermissionKey.approvalApprove,
      PermissionKey.approvalReject,
      PermissionKey.budgetSourceView,
      PermissionKey.incomeDelete,
    },
    TransactionUiText.userAdminTemplateReportAuditor: <String>{
      PermissionKey.navHome,
      PermissionKey.navReports,
      PermissionKey.navUsageGuide,
      PermissionKey.navLogout,
      PermissionKey.budgetSourceView,
      PermissionKey.auditLogView,
    },
    TransactionUiText.userAdminTemplateAdmin: <String>{
      PermissionKey.navHome,
      PermissionKey.navIncome,
      PermissionKey.navExpenseReq,
      PermissionKey.navExpense,
      PermissionKey.navLoan,
      PermissionKey.navReports,
      PermissionKey.navUsageGuide,
      PermissionKey.navLogout,
      PermissionKey.approvalView,
      PermissionKey.approvalApprove,
      PermissionKey.approvalReject,
      PermissionKey.budgetSourceView,
      PermissionKey.budgetSourceCreate,
      PermissionKey.budgetSourceUpdate,
      PermissionKey.budgetSourceDelete,
      PermissionKey.incomeDelete,
      PermissionKey.formsDocNoManualEdit,
      PermissionKey.settingView,
      PermissionKey.userAdminView,
      PermissionKey.userAdminCreate,
      PermissionKey.userAdminResetPassword,
      PermissionKey.userAdminUpdateRole,
      PermissionKey.userAdminToggleActive,
      PermissionKey.userAdminPermissionManage,
      PermissionKey.auditLogView,
      PermissionKey.menuConfigure,
    },
  };

  @override
  void initState() {
    super.initState();
    for (final controller in _formControllers) {
      controller.addListener(_onFormChanged);
    }
    _searchController.addListener(() {
      if (!mounted) return;
      setState(() => _searchQuery = _searchController.text.trim());
    });
    _reload();
  }

  @override
  void dispose() {
    for (final controller in _formControllers) {
      controller.removeListener(_onFormChanged);
    }
    _searchController.dispose();
    _codeController.dispose();
    _nameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _contactNumberController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _codeFocusNode.dispose();
    _nameFocusNode.dispose();
    _lastNameFocusNode.dispose();
    _emailFocusNode.dispose();
    _contactNumberFocusNode.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  List<TextEditingController> get _formControllers => [
        _codeController,
        _nameController,
        _lastNameController,
        _emailController,
        _contactNumberController,
        _usernameController,
        _passwordController,
      ];

  bool get _isEditMode => _editingUserId != null;

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  List<LocalUser> get _filteredUsers {
    final query = _searchQuery.toLowerCase();
    if (query.isEmpty) return _users;
    return _users.where((user) {
      return user.fullName.toLowerCase().contains(query) ||
          user.username.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query) ||
          _displayUserGroup(user).toLowerCase().contains(query);
    }).toList();
  }

  TextStyle _pageBodyStyle(
    AppColors c, {
    required double fontSize,
    FontWeight? weight,
    Color? color,
    double? height,
  }) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: fontSize,
      fontWeight: weight ?? FontWeight.w600,
      color: color ?? c.textPrimary,
      height: height,
      letterSpacing: 0.2,
    );
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final users = await _userLocalDataSource.getAllUsers();
    final groups = await _userLocalDataSource.getUserGroups();
    final prefixes = await _userLocalDataSource.getPrefixes();
    final prefixItems = prefixes
        .map(UserPrefixLookupItem.fromRow)
        .where((item) => item.id.isNotEmpty)
        .toList();
    final userGroupItems = groups
        .map(UserGroupLookupItem.fromRow)
        .whereType<UserGroupLookupItem>()
        .toList();
    if (!mounted) return;
    setState(() {
      _users = users;
      _groups = groups;
      _prefixes = prefixItems;
      _userGroupItems = userGroupItems;
      final prefixIds = prefixItems.map((e) => e.id).toSet();
      _selectedPrefixId = prefixIds.contains(_selectedPrefixId)
          ? _selectedPrefixId
          : (prefixItems.isNotEmpty ? prefixItems.first.id : null);
      final groupIds = userGroupItems.map((e) => e.id).toSet();
      _selectedUserGroupId = groupIds.contains(_selectedUserGroupId)
          ? _selectedUserGroupId
          : (userGroupItems.isNotEmpty ? userGroupItems.first.id : null);
      _loading = false;
    });
  }

  Future<void> _ensureAuditReady() async {
    if (_auditReady) return;
    await _auditLogLocalDataSource.init();
    _auditReady = true;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (!_canView) {
      return SafeArea(
        child: Scaffold(
          backgroundColor: c.background,
          appBar: _buildAppBar(c),
          body: const Center(
            child: Text(TransactionUiText.noPermissionData),
          ),
        ),
      );
    }

    return SafeArea(
      child: Scaffold(
        backgroundColor: c.background,
        appBar: _buildAppBar(c),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: _loading
              ? Center(
                  child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              : _buildContent(c),
        ),
        floatingActionButton: _canCreate
            ? SizedBox(
                width: 56,
                height: 56,
                child: FloatingActionButton(
                  onPressed: _saving ? null : () => _showUserFormSheet(),
                  tooltip: TransactionUiText.addSystemUser,
                  backgroundColor: c.navy,
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.add_rounded),
                ),
              )
            : null,
      ),
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
              _buildUserListCard(c),
              const SizedBox(height: AppTheme.sp24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserListCard(AppColors c) {
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
            icon: Icons.manage_accounts_outlined,
            title: TransactionUiText.userAdminAccountListSection,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.sp16,
              0,
              AppTheme.sp16,
              AppTheme.sp16,
            ),
            child: AppInput(
              label: TransactionUiText.userAdminAccountListSection,
              controller: _searchController,
              hint: TransactionUiText.userAdminSearchHint,
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              textInputAction: TextInputAction.search,
            ),
          ),
          Divider(height: 1, color: c.cardBorder),
          Padding(
            padding: const EdgeInsets.all(AppTheme.sp8),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (_, __, ___) => _buildUserList(c),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList(AppColors c) {
    final users = _filteredUsers;
    if (users.isEmpty) {
      final message = _users.isEmpty
          ? TransactionUiText.userAdminEmpty
          : TransactionUiText.userAdminNoResult;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.sp12),
        child: Text(
          message,
          style: _pageBodyStyle(
            c,
            fontSize: 14,
            color: c.textSecondary,
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: users.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) => _buildUserListTile(c, users[index]),
    );
  }

  Widget _buildUserListTile(AppColors c, LocalUser user) {
    final groupLabel = _displayUserGroup(user);
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        backgroundColor: c.iconBgIncome,
        foregroundColor: Theme.of(context).colorScheme.primary,
        child: Text(
          _userInitial(user),
          style: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      title: Text(
        '${user.username} - ${user.fullName.trim().isEmpty ? user.username : user.fullName.trim()}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        [
          if (groupLabel.trim().isNotEmpty) groupLabel.trim(),
          if (user.email.trim().isNotEmpty) user.email.trim(),
          user.isActive
              ? TransactionUiText.userAdminActiveStatus
              : TransactionUiText.userAdminInactiveStatus,
          if (user.forcePasswordChange)
            TransactionUiText.userAdminForcePasswordChange,
        ].join(' • '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: _fontFamily,
          color: c.textSecondary,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildUserActionsMenu(c, user),
          if (_canCreate || _canUpdateRole)
            const Icon(Icons.edit_rounded, size: 18),
        ],
      ),
      onTap: (_canCreate || _canUpdateRole)
          ? () => _showUserFormSheet(existing: user)
          : null,
    );
  }

  Widget _buildFormCard() {
    return UserFormCard(
      codeController: _codeController,
      nameController: _nameController,
      lastNameController: _lastNameController,
      emailController: _emailController,
      contactNumberController: _contactNumberController,
      usernameController: _usernameController,
      passwordController: _passwordController,
      codeFocusNode: _codeFocusNode,
      nameFocusNode: _nameFocusNode,
      lastNameFocusNode: _lastNameFocusNode,
      emailFocusNode: _emailFocusNode,
      contactNumberFocusNode: _contactNumberFocusNode,
      usernameFocusNode: _usernameFocusNode,
      passwordFocusNode: _passwordFocusNode,
      prefixes: _prefixes,
      userGroups: _userGroupItems,
      selectedPrefixId: _selectedPrefixId,
      selectedUserGroupId: _selectedUserGroupId,
      isEditMode: _isEditMode,
      onPrefixChanged: (val) => setState(() => _selectedPrefixId = val),
      onUserGroupChanged: (val) => setState(() => _selectedUserGroupId = val),
      onMissingPrefixTap: _promptNavigateToManagePrefix,
      onPasswordSubmitted: () {
        if (_isReadyToSave && !_saving) {
          _saveUserForm();
        }
      },
      requiredValidator: _requiredValue,
      emailValidator: _validateEmail,
      passwordValidator: _validatePassword,
    );
  }

  Future<void> _showUserFormSheet({LocalUser? existing}) async {
    FocusScope.of(context).unfocus();
    _clearUserForm(requestFocus: false);
    if (existing != null) {
      _applyUserData(existing);
    }

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: AdaptiveContentSheet(
            title: existing == null
                ? TransactionUiText.addSystemUser
                : TransactionUiText.editSystemUser,
            child: ListenableBuilder(
              listenable: Listenable.merge(_formControllers),
              builder: (context, _) {
                final canSubmit = _isReadyToSave && !_saving;
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
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_saving) ...[
                              const LinearProgressIndicator(minHeight: 2),
                              const SizedBox(height: AppTheme.sp12),
                            ],
                            _buildFormCard(),
                            const SizedBox(height: AppTheme.sp12),
                            UserSaveReadinessHint(
                              isReadyToSave: _isReadyToSave,
                            ),
                            const SizedBox(height: AppTheme.sp12),
                            _buildSheetActionButtons(
                              sheetContext,
                              canSubmit: canSubmit,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    _clearUserForm(requestFocus: false);
  }

  Widget _buildSheetActionButtons(
    BuildContext sheetContext, {
    required bool canSubmit,
  }) {
    return LayoutBuilder(
      builder: (context, box) {
        final isWide = box.maxWidth >= 560;
        final cancelButton = AppButton.outlined(
          label: TransactionUiText.cancel,
          icon: const Icon(Icons.close_rounded, size: 18),
          fullWidth: !isWide,
          onPressed:
              _saving ? null : () => Navigator.of(sheetContext).pop(false),
        );
        final saveButton = AppButton.primary(
          label:
              _isEditMode ? TransactionUiText.saveEdit : TransactionUiText.save,
          icon: const Icon(Icons.save_rounded, size: 18),
          fullWidth: !isWide,
          isLoading: _saving,
          onPressed: canSubmit
              ? () async {
                  final success = await _saveUserForm();
                  if (success && sheetContext.mounted) {
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

  bool get _isReadyToSave {
    final hasSelectedPrefix =
        _prefixes.any((item) => item.id == _selectedPrefixId);
    final hasSelectedUserGroup =
        _userGroupItems.any((item) => item.id == _selectedUserGroupId);
    final passwordOk = _isEditMode
        ? (_passwordController.text.isEmpty ||
            _passwordController.text.length >= 6)
        : _passwordController.text.length >= 6;

    return _codeController.text.trim().isNotEmpty &&
        _nameController.text.trim().isNotEmpty &&
        _lastNameController.text.trim().isNotEmpty &&
        _usernameController.text.trim().isNotEmpty &&
        passwordOk &&
        hasSelectedPrefix &&
        hasSelectedUserGroup &&
        _validateEmail(_emailController.text) == null;
  }

  String? _requiredValue(String message, String? value) {
    return (value == null || value.trim().isEmpty) ? message : null;
  }

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);
    return valid ? null : TransactionUiText.invalidEmail;
  }

  String? _validatePassword(String? value) {
    final text = value ?? '';
    if (_isEditMode && text.isEmpty) return null;
    if (text.isEmpty) return TransactionUiText.passwordRequired;
    if (text.length < 6) return TransactionUiText.passwordMinLength;
    return null;
  }

  Future<bool> _saveUserForm() async {
    if (_saving) return false;
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showSnack(TransactionUiText.fillRequiredFields);
      return false;
    }
    if (_selectedPrefixId == null) {
      await _promptNavigateToManagePrefix();
      return false;
    }
    if (_selectedUserGroupId == null) {
      _showSnack(TransactionUiText.noUserGroupAvailable);
      return false;
    }

    final username = _usernameController.text.trim();
    final email = _emailController.text.trim().isEmpty
        ? '$username@saccm.local'
        : _emailController.text.trim();

    if (_isEditMode && !_canEditCurrentUserRole(username)) {
      _showSnack(TransactionUiText.cannotDowngradeCurrentAdmin);
      return false;
    }

    setState(() => _saving = true);
    try {
      final ok = _isEditMode
          ? await _userLocalDataSource.updateUser(
              userId: _editingUserId!,
              code: _codeController.text.trim(),
              email: email,
              username: username,
              name: _nameController.text.trim(),
              lastname: _lastNameController.text.trim(),
              contactNumber: _contactNumberController.text.trim(),
              refUserGroup: _selectedUserGroupId!,
              refPrefix: _selectedPrefixId,
              newPassword: _passwordController.text,
            )
          : await _userLocalDataSource.createUser(
              code: _codeController.text.trim(),
              email: email,
              username: username,
              password: _passwordController.text,
              name: _nameController.text.trim(),
              lastname: _lastNameController.text.trim(),
              contactNumber: _contactNumberController.text.trim(),
              refUserGroup: _selectedUserGroupId!,
              refPrefix: _selectedPrefixId,
            );
      if (!mounted) return false;
      if (!ok) {
        _showSnack(
          _isEditMode
              ? TransactionUiText.saveFailed
              : TransactionUiText.duplicateUsername,
        );
        return false;
      }

      await _ensureAuditReady();
      await _auditLogLocalDataSource.logEvent(
        module: 'user_admin',
        action: _isEditMode ? 'update_user' : 'create_user',
        entityId: _isEditMode ? _editingUserId.toString() : username,
        payload: {
          'username': username,
          'refUserGroup': _selectedUserGroupId,
        },
      );
      await _reload();
      if (!mounted) return false;
      _clearUserForm(requestFocus: false);
      _showSnack(
        _isEditMode
            ? TransactionUiText.editSuccess
            : TransactionUiText.saveSuccess,
      );
      return true;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _canEditCurrentUserRole(String username) {
    final currentUsername = context.read<SimpleAuthProvider>().username;
    if (currentUsername != username) return true;
    final selectedGroup = _groups.firstWhere(
      (g) => g['id'].toString() == _selectedUserGroupId.toString(),
      orElse: () => <String, dynamic>{'nameen': ''},
    );
    final selectedRoleEn =
        (selectedGroup['nameen'] ?? '').toString().toLowerCase();
    return selectedRoleEn == 'admin';
  }

  void _clearUserForm({bool requestFocus = true}) {
    _editingUserId = null;
    _codeController.clear();
    _nameController.clear();
    _lastNameController.clear();
    _emailController.clear();
    _contactNumberController.clear();
    _usernameController.clear();
    _passwordController.clear();
    _formKey.currentState?.reset();
    setState(() {
      _selectedPrefixId = _prefixes.isNotEmpty ? _prefixes.first.id : null;
      _selectedUserGroupId =
          _userGroupItems.isNotEmpty ? _userGroupItems.first.id : null;
    });
    if (requestFocus) _codeFocusNode.requestFocus();
  }

  void _applyUserData(LocalUser user) {
    _editingUserId = user.id;
    _codeController.text = user.code;
    _nameController.text = user.name;
    _lastNameController.text = user.lastname;
    _emailController.text = user.email;
    _contactNumberController.text = user.contactNumber;
    _usernameController.text = user.username;
    _passwordController.clear();
    setState(() {
      _selectedPrefixId = user.refPrefix;
      _selectedUserGroupId = user.refUserGroup;
    });
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
      if (mounted) _reload();
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            message,
            style: const TextStyle(fontFamily: _fontFamily),
          ),
        ),
      );
  }

  Widget _buildUserActionsMenu(AppColors c, LocalUser user) {
    if (!_canResetPassword && !_canUpdateRole && !_canToggleActive) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      tooltip: TransactionUiText.userAdminActionsTooltip,
      icon: Icon(Icons.more_vert_rounded, color: c.textSecondary),
      onSelected: (value) => _handleUserAction(value, user),
      itemBuilder: (context) => [
        if (_canResetPassword)
          const PopupMenuItem<String>(
            value: 'reset',
            child: Text(TransactionUiText.changePassword),
          ),
        if (_canUpdateRole)
          const PopupMenuItem<String>(
            value: 'role',
            child: Text(TransactionUiText.editUserRole),
          ),
        if (_canToggleActive)
          PopupMenuItem<String>(
            value: 'toggle',
            child: Text(
              user.isActive
                  ? TransactionUiText.disableUser
                  : TransactionUiText.enableUser,
            ),
          ),
      ],
    );
  }

  Future<void> _handleUserAction(String value, LocalUser user) async {
    if (value == 'reset') {
      if (!_canResetPassword) return;
      await _openResetPasswordDialog(user);
      return;
    }
    if (value == 'role') {
      if (!_canUpdateRole) return;
      await _openEditRoleDialog(user);
      return;
    }
    if (value != 'toggle' || !_canToggleActive) return;

    final currentUsername = context.read<SimpleAuthProvider>().username;
    if (currentUsername == user.username) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(TransactionUiText.cannotDisableCurrentUser),
        ),
      );
      return;
    }

    final ok = await _userLocalDataSource.setUserActive(
      userId: user.id,
      isActive: !user.isActive,
    );
    if (ok && mounted) {
      await _ensureAuditReady();
      await _auditLogLocalDataSource.logEvent(
        module: 'user_admin',
        action: user.isActive ? 'disable_user' : 'enable_user',
        entityId: user.id.toString(),
        payload: {
          'username': user.username,
          'isActive': !user.isActive,
        },
      );
      await _reload();
    }
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
            style: _pageBodyStyle(
              c,
              fontSize: 13,
              weight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _displayUserGroup(LocalUser user) {
    final nameTh = user.userGroupNameTh?.trim() ?? '';
    if (nameTh.isNotEmpty) return nameTh;
    final nameEn = user.userGroupNameEn?.trim() ?? '';
    if (nameEn.isNotEmpty) return nameEn;
    return TransactionUiText.unspecified;
  }

  String _userInitial(LocalUser user) {
    final source = user.name.trim().isNotEmpty ? user.name : user.username;
    final trimmed = source.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }

  PreferredSizeWidget _buildAppBar(AppColors c) {
    return AppBar(
      toolbarHeight: 52,
      title: Text(
        TransactionUiText.systemUsers,
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
        if (_canManagePermissions)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: AppTheme.sp12),
            child: AppBarActionButton(
              label: TransactionUiText.userAdminGroupPermissions,
              onPressed: _openGroupPermissionDialog,
            ),
          ),
      ],
    );
  }

  Future<void> _openResetPasswordDialog(LocalUser user) async {
    final newPassword = await showResetPasswordDialog(
      context: context,
      username: user.username,
    );
    if ((newPassword ?? '').isEmpty || !mounted) return;

    final ok = await _userLocalDataSource.resetPassword(
      userId: user.id,
      username: user.username,
      newPassword: newPassword!,
      forcePasswordChange: 1,
    );
    if (!mounted) return;
    if (ok) {
      await _ensureAuditReady();
      await _auditLogLocalDataSource.logEvent(
        module: 'user_admin',
        action: 'reset_password',
        entityId: user.id.toString(),
        payload: {'username': user.username},
      );
      await _reload();
    }
  }

  Future<void> _openEditRoleDialog(LocalUser user) async {
    final groupId = await showEditUserRoleDialog(
      context: context,
      username: user.username,
      groups: _groups,
      initialGroupId: user.refUserGroup?.toString(),
    );
    if (groupId == null || !mounted) return;

    final currentUsername = context.read<SimpleAuthProvider>().username;
    final selectedGroup = _groups.firstWhere(
      (g) => g['id'].toString() == groupId.toString(),
      orElse: () => <String, dynamic>{'nameen': ''},
    );
    final selectedRoleEn =
        (selectedGroup['nameen'] ?? '').toString().toLowerCase();
    if (currentUsername == user.username && selectedRoleEn != 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            TransactionUiText.cannotDowngradeCurrentAdmin,
          ),
        ),
      );
      return;
    }

    final ok = await _userLocalDataSource.updateUserGroup(
      userId: user.id,
      refUserGroup: groupId,
    );
    if (!mounted) return;
    if (ok) {
      await _ensureAuditReady();
      await _auditLogLocalDataSource.logEvent(
        module: 'user_admin',
        action: 'update_user_role',
        entityId: user.id.toString(),
        payload: {
          'username': user.username,
          'refUserGroup': groupId,
        },
      );
      await _reload();
    }
  }

  Future<void> _openGroupPermissionDialog() async {
    const baselinePermissions = <String>{
      PermissionKey.navHome,
      PermissionKey.navIncome,
      PermissionKey.navExpense,
      PermissionKey.navLoan,
      PermissionKey.navReports,
      PermissionKey.navUsageGuide,
      PermissionKey.navLogout,
      PermissionKey.budgetSourceView,
    };
    final saved = await showUserGroupPermissionDialog(
      context: context,
      groups: _groups,
      permissionItems: _permissionItems,
      permissionTemplates: _permissionTemplates,
      baselinePermissions: baselinePermissions,
      loadPermissionsByGroup: _userLocalDataSource.getPermissionsByUserGroup,
      onSave: (groupId, permissions) async {
        final auth = context.read<SimpleAuthProvider>();
        await _userLocalDataSource.replacePermissionsByUserGroup(
          userGroupId: groupId,
          permissions: permissions,
        );
        final currentUsername = auth.username;
        if (currentUsername != null && currentUsername.isNotEmpty) {
          final currentUser =
              await _userLocalDataSource.getUserByUsername(currentUsername);
          if (currentUser?.refUserGroup == groupId) {
            await auth.refreshCurrentUserPermissions();
          }
        }
        await _ensureAuditReady();
        await _auditLogLocalDataSource.logEvent(
          module: 'user_admin',
          action: 'update_group_permissions',
          entityId: groupId.toString(),
          payload: {
            'userGroupId': groupId,
            'permissions': permissions.toList()..sort(),
          },
        );
      },
    );
    if (saved == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(TransactionUiText.userAdminGroupPermissionsSaved),
        ),
      );
    }
  }
}
