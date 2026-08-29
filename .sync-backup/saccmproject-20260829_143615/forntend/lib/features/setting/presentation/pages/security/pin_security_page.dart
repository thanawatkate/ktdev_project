import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/features/auth/presentation/providers/simple_auth_provider.dart';
import 'package:saccm/widgets/widgets.dart';

class PinSecurityPage extends StatefulWidget {
  const PinSecurityPage({super.key});

  @override
  State<PinSecurityPage> createState() => _PinSecurityPageState();
}

class _ResponsiveFormField {
  const _ResponsiveFormField({
    required this.child,
    this.span = 1,
  });

  final Widget child;
  final int span;
}

class _PinSecurityPageState extends State<PinSecurityPage> {
  static const String _fontFamily = 'Kanit';
  static const double _maxResponsiveFormWidth = 1440;

  final _localAuth = LocalAuthentication();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _currentPinController = TextEditingController();
  bool _submitting = false;
  bool _biometricSupported = false;

  @override
  void initState() {
    super.initState();
    _pinController.addListener(_onFieldChanged);
    _confirmPinController.addListener(_onFieldChanged);
    _currentPinController.addListener(_onFieldChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SimpleAuthProvider>().loadPinStatus();
      _loadBiometricSupport();
    });
  }

  @override
  void dispose() {
    _pinController.removeListener(_onFieldChanged);
    _confirmPinController.removeListener(_onFieldChanged);
    _currentPinController.removeListener(_onFieldChanged);
    _pinController.dispose();
    _confirmPinController.dispose();
    _currentPinController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  bool _isSixDigitPin(String value) {
    final pin = value.trim();
    return RegExp(r'^\d{6}$').hasMatch(pin);
  }

  bool _canSavePin(SimpleAuthProvider authProvider) {
    final pin = _pinController.text.trim();
    final confirm = _confirmPinController.text.trim();
    if (!_isSixDigitPin(pin) || pin != confirm) return false;
    if (authProvider.isPinEnabled &&
        !_isSixDigitPin(_currentPinController.text)) {
      return false;
    }
    return !_submitting;
  }

  bool _canDisablePin(SimpleAuthProvider authProvider) {
    return authProvider.isPinEnabled &&
        !_submitting &&
        _isSixDigitPin(_currentPinController.text);
  }

  Future<void> _savePin(SimpleAuthProvider authProvider) async {
    final pin = _pinController.text.trim();
    final confirm = _confirmPinController.text.trim();
    final currentPin = _currentPinController.text.trim();
    if (!_isSixDigitPin(pin)) {
      _showMessage(TransactionUiText.pinMustBe6Digits, isError: true);
      return;
    }
    if (pin != confirm) {
      _showMessage(TransactionUiText.pinMismatch, isError: true);
      return;
    }
    if (authProvider.isPinEnabled && !_isSixDigitPin(currentPin)) {
      _showMessage(TransactionUiText.enterCurrentPin, isError: true);
      return;
    }

    setState(() => _submitting = true);
    final ok = await authProvider.setPin(
      pin,
      currentPin: authProvider.isPinEnabled ? currentPin : null,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      _pinController.clear();
      _confirmPinController.clear();
      _currentPinController.clear();
      _showMessage(TransactionUiText.pinSavedSuccess);
      return;
    }
    _showMessage(
      authProvider.isPinEnabled
          ? TransactionUiText.invalidCurrentPin
          : TransactionUiText.pinSaveFailed,
      isError: true,
    );
  }

  Future<void> _disablePin(SimpleAuthProvider authProvider) async {
    final currentPin = _currentPinController.text.trim();
    if (!_isSixDigitPin(currentPin)) {
      _showMessage(TransactionUiText.enterCurrentPin, isError: true);
      return;
    }
    setState(() => _submitting = true);
    final ok = await authProvider.disablePin(currentPin: currentPin);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      _pinController.clear();
      _confirmPinController.clear();
      _currentPinController.clear();
      _showMessage(TransactionUiText.pinDisabledSuccess);
      return;
    }
    _showMessage(TransactionUiText.invalidPin, isError: true);
  }

  Future<void> _loadBiometricSupport() async {
    try {
      final deviceSupported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      final biometricTypes = await _localAuth.getAvailableBiometrics();
      if (!mounted) return;
      setState(() {
        _biometricSupported =
            deviceSupported && (canCheck || biometricTypes.isNotEmpty);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _biometricSupported = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            message,
            style: const TextStyle(fontFamily: _fontFamily),
          ),
          backgroundColor:
              isError ? Theme.of(context).colorScheme.error : Colors.green[700],
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SimpleAuthProvider>(
      builder: (context, authProvider, _) {
        final c = AppColors.of(context);
        return SafeArea(
          child: Scaffold(
            backgroundColor: c.background,
            appBar: _buildAppBar(c, authProvider),
            body: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: _buildContent(c, authProvider),
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    AppColors c,
    SimpleAuthProvider authProvider,
  ) {
    return AppBar(
      toolbarHeight: 52,
      title: Text(
        TransactionUiText.pinSecurityTitle,
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
                tooltip: TransactionUiText.pinSecurityTitle,
                visualDensity: VisualDensity.compact,
                onPressed: () => _showPageGuideDialog(authProvider),
              ),
              AppBarActionButton(
                label: authProvider.isPinEnabled
                    ? TransactionUiText.changePin
                    : TransactionUiText.enablePin,
                isLoading: _submitting,
                isEnabled: _canSavePin(authProvider),
                isPrimary: true,
                onPressed: () => _savePin(authProvider),
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

  Widget _buildContent(AppColors c, SimpleAuthProvider authProvider) {
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
              _buildPinFormCard(c, authProvider),
              if (authProvider.isPinEnabled) ...[
                const SizedBox(height: AppTheme.sp16),
                _buildDisablePinCard(c, authProvider),
              ],
              const SizedBox(height: AppTheme.sp24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinFormCard(AppColors c, SimpleAuthProvider authProvider) {
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
                icon: Icons.pin_outlined,
                title: TransactionUiText.pinCode,
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
                        label: TransactionUiText.newPin,
                        controller: _pinController,
                        maxLength: 6,
                        enabled: !_submitting,
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        textInputAction: TextInputAction.next,
                        action: const AppInputAction.number(obscure: true),
                      ),
                    ),
                    _ResponsiveFormField(
                      child: AppInput(
                        label: TransactionUiText.confirmNewPin,
                        controller: _confirmPinController,
                        maxLength: 6,
                        enabled: !_submitting,
                        prefixIcon: const Icon(Icons.lock_reset_rounded),
                        textInputAction: authProvider.isPinEnabled
                            ? TextInputAction.next
                            : TextInputAction.done,
                        action: const AppInputAction.number(obscure: true),
                      ),
                    ),
                    if (authProvider.isPinEnabled)
                      _ResponsiveFormField(
                        span: columnCount,
                        child: AppInput(
                          label: TransactionUiText.currentPinRequiredForChange,
                          controller: _currentPinController,
                          maxLength: 6,
                          enabled: !_submitting,
                          prefixIcon: const Icon(Icons.verified_user_outlined),
                          textInputAction: TextInputAction.done,
                          action: const AppInputAction.number(obscure: true),
                        ),
                      ),
                  ],
                ),
              ),
              if (authProvider.isPinEnabled) ...[
                Divider(height: 1, color: c.cardBorder),
                _buildBiometricSection(c, authProvider),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildDisablePinCard(AppColors c, SimpleAuthProvider authProvider) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.sp16),
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r16),
        border: Border.all(color: c.cardBorder),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final isWide = box.maxWidth >= 560;
          final disableButton = AppButton(
            label: TransactionUiText.disablePin,
            onPressed: _canDisablePin(authProvider)
                ? () => _disablePin(authProvider)
                : null,
            variant: AppButtonVariant.secondary,
            icon: const Icon(Icons.lock_open_rounded),
            fullWidth: !isWide,
          );
          if (!isWide) {
            return disableButton;
          }
          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(width: 180, child: disableButton),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBiometricSection(
    AppColors c,
    SimpleAuthProvider authProvider,
  ) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.fromLTRB(
        AppTheme.sp16,
        AppTheme.sp4,
        AppTheme.sp16,
        AppTheme.sp8,
      ),
      secondary: Icon(
        Icons.fingerprint_rounded,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(
        TransactionUiText.enableBiometricUnlock,
        style: TextStyle(
          fontFamily: _fontFamily,
          color: c.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        _biometricSupported
            ? TransactionUiText.biometricSupportedHint
            : TransactionUiText.biometricUnavailableHint,
        style: TextStyle(
          fontFamily: _fontFamily,
          color: c.textSecondary,
          fontSize: 12,
        ),
      ),
      value: authProvider.isBiometricEnabled,
      onChanged: (_biometricSupported && !_submitting)
          ? (v) => authProvider.setBiometricEnabled(v)
          : null,
    );
  }

  Future<void> _showPageGuideDialog(SimpleAuthProvider authProvider) async {
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    await PageGuideDialog.show(
      context: context,
      title: TransactionUiText.pinSecurityTitle,
      items: [
        PageGuideItem(
          icon: Icons.lock_outline_rounded,
          text: TransactionUiText.pinSecurityDescription,
          backgroundColor: scheme.primary.withValues(alpha: 0.08),
        ),
        PageGuideItem(
          icon: Icons.pin_outlined,
          text: authProvider.isPinEnabled
              ? TransactionUiText.currentPinRequiredForChange
              : TransactionUiText.pinMustBe6Digits,
          backgroundColor: scheme.primary.withValues(alpha: 0.08),
        ),
        PageGuideItem(
          icon: Icons.fingerprint_rounded,
          text: _biometricSupported
              ? TransactionUiText.biometricSupportedHint
              : TransactionUiText.biometricUnavailableHint,
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
}
