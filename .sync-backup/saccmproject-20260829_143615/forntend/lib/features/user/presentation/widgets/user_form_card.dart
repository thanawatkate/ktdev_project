import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/features/user/presentation/models/user_form_lookup.dart';
import 'package:saccm/features/user/presentation/widgets/user_responsive_form_grid.dart';
import 'package:saccm/features/user/presentation/widgets/user_section_header.dart';
import 'package:saccm/widgets/widgets.dart';

class UserFormCard extends StatelessWidget {
  const UserFormCard({
    super.key,
    required this.codeController,
    required this.nameController,
    required this.lastNameController,
    required this.emailController,
    required this.contactNumberController,
    required this.usernameController,
    required this.passwordController,
    required this.codeFocusNode,
    required this.nameFocusNode,
    required this.lastNameFocusNode,
    required this.emailFocusNode,
    required this.contactNumberFocusNode,
    required this.usernameFocusNode,
    required this.passwordFocusNode,
    required this.prefixes,
    required this.userGroups,
    required this.selectedPrefixId,
    required this.selectedUserGroupId,
    required this.onPrefixChanged,
    required this.onUserGroupChanged,
    required this.onMissingPrefixTap,
    required this.onPasswordSubmitted,
    required this.requiredValidator,
    required this.emailValidator,
    required this.passwordValidator,
    this.isEditMode = false,
  });

  final TextEditingController codeController;
  final TextEditingController nameController;
  final TextEditingController lastNameController;
  final TextEditingController emailController;
  final TextEditingController contactNumberController;
  final TextEditingController usernameController;
  final TextEditingController passwordController;

  final FocusNode codeFocusNode;
  final FocusNode nameFocusNode;
  final FocusNode lastNameFocusNode;
  final FocusNode emailFocusNode;
  final FocusNode contactNumberFocusNode;
  final FocusNode usernameFocusNode;
  final FocusNode passwordFocusNode;

  final List<UserPrefixLookupItem> prefixes;
  final List<UserGroupLookupItem> userGroups;
  final String? selectedPrefixId;
  final int? selectedUserGroupId;

  final ValueChanged<String?> onPrefixChanged;
  final ValueChanged<int?> onUserGroupChanged;
  final VoidCallback onMissingPrefixTap;
  final VoidCallback onPasswordSubmitted;

  final String? Function(String message, String? value) requiredValidator;
  final FormFieldValidator<String> emailValidator;
  final FormFieldValidator<String> passwordValidator;
  final bool isEditMode;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r16),
        border: Border.all(color: c.cardBorder, width: 1),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final contentWidth = userCardContentWidth(box.maxWidth);
          final columnCount = userResponsiveColumnCount(contentWidth);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const UserSectionHeader(
                icon: Icons.badge_outlined,
                title: TransactionUiText.userProfileSection,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.sp16,
                  0,
                  AppTheme.sp16,
                  AppTheme.sp16,
                ),
                child: UserResponsiveFieldGrid(
                  maxWidth: contentWidth,
                  columnCount: columnCount,
                  fields: [
                    UserResponsiveFormField(
                      child: AppInput(
                        label: TransactionUiText.code,
                        required: true,
                        focusNode: codeFocusNode,
                        controller: codeController,
                        textInputAction: TextInputAction.next,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (value) => requiredValidator(
                          TransactionUiText.codeRequired,
                          value,
                        ),
                      ),
                    ),
                    UserResponsiveFormField(child: _buildPrefixField()),
                    UserResponsiveFormField(
                      child: AppInput(
                        label: TransactionUiText.firstName,
                        required: true,
                        focusNode: nameFocusNode,
                        controller: nameController,
                        textInputAction: TextInputAction.next,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (value) => requiredValidator(
                          TransactionUiText.firstNameRequired,
                          value,
                        ),
                      ),
                    ),
                    UserResponsiveFormField(
                      child: AppInput(
                        label: TransactionUiText.lastName,
                        required: true,
                        focusNode: lastNameFocusNode,
                        controller: lastNameController,
                        textInputAction: TextInputAction.next,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (value) => requiredValidator(
                          TransactionUiText.lastNameRequired,
                          value,
                        ),
                      ),
                    ),
                    UserResponsiveFormField(
                      span: columnCount >= 4 ? 2 : 1,
                      child: AppInput(
                        label: TransactionUiText.email,
                        focusNode: emailFocusNode,
                        controller: emailController,
                        textInputAction: TextInputAction.next,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: emailValidator,
                      ),
                    ),
                    UserResponsiveFormField(
                      child: AppInput(
                        label: TransactionUiText.contactNumber,
                        focusNode: contactNumberFocusNode,
                        controller: contactNumberController,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: c.cardBorder),
              const UserSectionHeader(
                icon: Icons.lock_person_outlined,
                title: TransactionUiText.userLoginSection,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.sp16,
                  0,
                  AppTheme.sp16,
                  AppTheme.sp16,
                ),
                child: UserResponsiveFieldGrid(
                  maxWidth: contentWidth,
                  columnCount: columnCount,
                  fields: [
                    UserResponsiveFormField(
                      child: AppInput(
                        label: TransactionUiText.username,
                        required: true,
                        enabled: !isEditMode,
                        readOnly: isEditMode,
                        focusNode: usernameFocusNode,
                        controller: usernameController,
                        textInputAction: TextInputAction.next,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (value) => requiredValidator(
                          TransactionUiText.usernameRequired,
                          value,
                        ),
                      ),
                    ),
                    UserResponsiveFormField(
                      child: AppInput(
                        action: const AppInputAction.password(),
                        label: TransactionUiText.password,
                        required: !isEditMode,
                        helperText: isEditMode
                            ? TransactionUiText.userPasswordEditHelper
                            : TransactionUiText.userPasswordHelper,
                        focusNode: passwordFocusNode,
                        controller: passwordController,
                        textInputAction: TextInputAction.done,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: passwordValidator,
                        onSubmitted: (_) => onPasswordSubmitted(),
                      ),
                    ),
                    UserResponsiveFormField(
                      span: columnCount >= 3 ? 2 : 1,
                      child: _buildUserGroupField(),
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

  Widget _buildPrefixField() {
    if (prefixes.isEmpty) {
      return AppInput(
        label: TransactionUiText.prefix,
        hint: TransactionUiText.selectPrefix,
        required: true,
        readOnly: true,
        prefixIcon: const Icon(Icons.badge_outlined),
        onTap: onMissingPrefixTap,
        action: const AppInputAction.text(
          suffixIcon: Icon(Icons.manage_search_rounded),
        ),
        helperText: TransactionUiText.prefixNoDataDialogBody,
      );
    }

    final prefixIds = prefixes.map((e) => e.id).toSet();
    final selected =
        prefixIds.contains(selectedPrefixId) ? selectedPrefixId : null;

    return AppLookupPickerField<String>(
      label: TransactionUiText.prefix,
      hint: TransactionUiText.selectPrefix,
      required: true,
      prefixIcon: const Icon(Icons.badge_outlined),
      clearable: false,
      items: prefixes
          .map(
            (e) => AppDropdownItem<String>(
              value: e.id,
              label: e.label,
            ),
          )
          .toList(),
      value: selected,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (value) =>
          value == null ? TransactionUiText.prefixNameRequired : null,
      onChanged: onPrefixChanged,
    );
  }

  Widget _buildUserGroupField() {
    final groupIds = userGroups.map((e) => e.id).toSet();
    final selected =
        groupIds.contains(selectedUserGroupId) ? selectedUserGroupId : null;

    return AppLookupPickerField<int>(
      label: TransactionUiText.userGroup,
      hint: TransactionUiText.selectUserGroup,
      required: true,
      clearable: false,
      items: userGroups
          .map(
            (e) => AppDropdownItem<int>(
              value: e.id,
              label: e.label,
            ),
          )
          .toList(),
      value: selected,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (value) =>
          value == null ? TransactionUiText.fillRequiredFields : null,
      onChanged: onUserGroupChanged,
    );
  }
}
