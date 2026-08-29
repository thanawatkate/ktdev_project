import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/features/setting/data/datasources/school_profile_local_data_source.dart';
import 'package:saccm/features/setting/domain/entities/school_profile.dart';
import 'package:saccm/widgets/dialog/form_leave_confirm_dialog.dart';
import 'package:saccm/widgets/widgets.dart';

/// ตั้งค่าชื่อ ที่ตั้ง และข้อมูลอ้างอิงของโรงเรียน (เก็บบนเครื่อง)
class SchoolProfilePage extends StatefulWidget {
  const SchoolProfilePage({super.key});

  @override
  State<SchoolProfilePage> createState() => _SchoolProfilePageState();
}

class _ResponsiveFormField {
  const _ResponsiveFormField({
    required this.child,
    this.span = 1,
  });

  final Widget child;
  final int span;
}

class _SchoolProfilePageState extends State<SchoolProfilePage> {
  static const String _fontFamily = 'Kanit';
  static const double _maxResponsiveFormWidth = 1440;

  final SchoolProfileLocalDataSource _ds = SchoolProfileLocalDataSourceImpl();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _extraCtrl = TextEditingController();
  String _initialName = '';
  String _initialAddress = '';
  String _initialPhone = '';
  String _initialExtra = '';

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_onFieldChanged);
    _addressCtrl.addListener(_onFieldChanged);
    _phoneCtrl.addListener(_onFieldChanged);
    _extraCtrl.addListener(_onFieldChanged);
    _load();
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final p = await _ds.load();
      if (!mounted) return;
      _nameCtrl.text = p.name;
      _addressCtrl.text = p.address;
      _phoneCtrl.text = p.phone;
      _extraCtrl.text = p.extra;
      _captureInitialSnapshot();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onFieldChanged);
    _addressCtrl.removeListener(_onFieldChanged);
    _phoneCtrl.removeListener(_onFieldChanged);
    _extraCtrl.removeListener(_onFieldChanged);
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _extraCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_isFormReady) {
      _showSnack(_buildMissingRequiredText());
      return;
    }
    setState(() => _saving = true);
    try {
      await _ds.save(
        SchoolProfile(
          name: _nameCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          extra: _extraCtrl.text.trim(),
        ),
      );
      if (!mounted) return;
      _nameCtrl.text = _nameCtrl.text.trim();
      _addressCtrl.text = _addressCtrl.text.trim();
      _phoneCtrl.text = _phoneCtrl.text.trim();
      _extraCtrl.text = _extraCtrl.text.trim();
      _captureInitialSnapshot();
      _showSnack(TransactionUiText.schoolProfileSaveSuccess);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool get _isFormReady => _nameCtrl.text.trim().isNotEmpty;

  bool _hasUnsavedChanges() {
    return _nameCtrl.text.trim() != _initialName ||
        _addressCtrl.text.trim() != _initialAddress ||
        _phoneCtrl.text.trim() != _initialPhone ||
        _extraCtrl.text.trim() != _initialExtra;
  }

  void _captureInitialSnapshot() {
    _initialName = _nameCtrl.text.trim();
    _initialAddress = _addressCtrl.text.trim();
    _initialPhone = _phoneCtrl.text.trim();
    _initialExtra = _extraCtrl.text.trim();
  }

  String _buildMissingRequiredText() {
    return '${TransactionUiText.schoolProfileMissingRequiredPrefix}${TransactionUiText.schoolProfileNameLabel}';
  }

  Future<void> _handleBackNavigation() async {
    FocusScope.of(context).unfocus();
    if (!_hasUnsavedChanges()) {
      _popPageSafely();
      return;
    }
    final shouldLeave = await showFormLeaveConfirmDialog(
      context,
      title: TransactionUiText.schoolProfileUnsavedLeaveTitle,
      message: TransactionUiText.schoolProfileUnsavedLeaveBody,
      cancelText: TransactionUiText.formUnsavedStay,
      confirmText: TransactionUiText.formUnsavedLeaveWithoutSave,
    );
    if (shouldLeave && mounted) {
      _popPageSafely();
    }
  }

  void _popPageSafely() {
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, __) {
        if (!didPop) _handleBackNavigation();
      },
      child: SafeArea(
        child: Scaffold(
          backgroundColor: c.background,
          appBar: _buildAppBar(c),
          body: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(color: scheme.primary),
                  )
                : _buildContent(c),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppColors c) {
    return AppBar(
      toolbarHeight: 52,
      title: Text(
        TransactionUiText.schoolProfileTitle,
        style: TextStyle(
          color: c.textPrimary,
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
      centerTitle: true,
      backgroundColor: c.cardWhite,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: c.textPrimary,
        ),
        onPressed: _handleBackNavigation,
      ),
      actions: [
        Padding(
          padding: const EdgeInsetsDirectional.only(end: AppTheme.sp12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  Icons.help_outline_rounded,
                  size: 20,
                  color: c.textSecondary,
                ),
                tooltip: TransactionUiText.schoolProfileTitle,
                visualDensity: VisualDensity.compact,
                onPressed: _showPageGuideDialog,
              ),
              AppBarActionButton(
                label: TransactionUiText.save,
                isLoading: _saving,
                isEnabled: _isFormReady && !_saving,
                isPrimary: true,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: c.cardBorder),
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
              _buildFormCard(c),
              const SizedBox(height: AppTheme.sp24),
            ],
          ),
        ),
      ),
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
                icon: Icons.info_outline_rounded,
                title: TransactionUiText.schoolProfileMainSection,
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
                      span: columnCount,
                      child: AppInput(
                        label: TransactionUiText.schoolProfileNameLabel,
                        hint: TransactionUiText.schoolProfileNameHint,
                        controller: _nameCtrl,
                        required: true,
                        prefixIcon: const Icon(Icons.school_outlined),
                        textInputAction: TextInputAction.next,
                        action: const AppInputAction.text(),
                      ),
                    ),
                    _ResponsiveFormField(
                      span: columnCount,
                      child: AppInput(
                        label: TransactionUiText.schoolProfileAddressLabel,
                        hint: TransactionUiText.schoolProfileAddressHint,
                        controller: _addressCtrl,
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        maxLines: 4,
                        minLines: 2,
                        textInputAction: TextInputAction.newline,
                        action: const AppInputAction.text(),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: c.cardBorder),
              _buildSectionHeader(
                c,
                icon: Icons.contact_phone_outlined,
                title: TransactionUiText.schoolProfileContactSection,
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
                        label: TransactionUiText.schoolProfilePhoneLabel,
                        hint: TransactionUiText.schoolProfilePhoneHint,
                        controller: _phoneCtrl,
                        prefixIcon: const Icon(Icons.phone_outlined),
                        textInputAction: TextInputAction.next,
                        action: const AppInputAction.text(),
                      ),
                    ),
                    _ResponsiveFormField(
                      span: columnCount,
                      child: AppInput(
                        label: TransactionUiText.schoolProfileExtraLabel,
                        hint: TransactionUiText.schoolProfileExtraHint,
                        controller: _extraCtrl,
                        prefixIcon: const Icon(Icons.notes_rounded),
                        maxLines: 4,
                        minLines: 2,
                        textInputAction: TextInputAction.newline,
                        action: const AppInputAction.text(),
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

  Future<void> _showPageGuideDialog() async {
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    await PageGuideDialog.show(
      context: context,
      title: TransactionUiText.schoolProfileTitle,
      items: [
        PageGuideItem(
          icon: Icons.school_rounded,
          text: TransactionUiText.schoolProfileSubtitle,
          backgroundColor: scheme.primary.withValues(alpha: 0.08),
        ),
        PageGuideItem(
          icon: Icons.info_outline_rounded,
          text: TransactionUiText.schoolProfileRequiredBeforeSaveHint,
          backgroundColor: scheme.primary.withValues(alpha: 0.08),
        ),
        PageGuideItem(
          icon: Icons.storage_outlined,
          text: TransactionUiText.schoolProfileLocalNote,
          backgroundColor: c.cardWhite,
        ),
      ],
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
        AppTheme.sp12,
        AppTheme.sp16,
        AppTheme.sp8,
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
}
