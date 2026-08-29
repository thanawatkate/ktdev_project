import 'dart:async';

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/features/auth/presentation/providers/simple_auth_provider.dart';
import 'package:saccm/widgets/widgets.dart';

class ForceChangePasswordDialog extends StatefulWidget {
  const ForceChangePasswordDialog({
    super.key,
    required this.authProvider,
    required this.currentPassword,
    required this.rememberMe,
  });

  final SimpleAuthProvider authProvider;
  final String currentPassword;
  final bool rememberMe;

  @override
  State<ForceChangePasswordDialog> createState() =>
      _ForceChangePasswordDialogState();
}

class _ForceChangePasswordDialogState extends State<ForceChangePasswordDialog> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;
    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(TransactionUiText.passwordMinLength)),
      );
      return;
    }
    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(TransactionUiText.passwordMismatch)),
      );
      return;
    }

    setState(() => _submitting = true);
    final ok = await widget.authProvider.changeInitialPassword(
      currentPassword: widget.currentPassword,
      newPassword: newPassword,
      rememberMe: widget.rememberMe,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AdaptiveContentSheet(
        title: TransactionUiText.changeInitialPasswordTitle,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            AppTheme.sp16,
            0,
            AppTheme.sp16,
            MediaQuery.viewInsetsOf(context).bottom + AppTheme.sp16,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(TransactionUiText.changeInitialPasswordMessage),
                const SizedBox(height: AppTheme.sp12),
                AppInput(
                  label: TransactionUiText.newPassword,
                  controller: _newPasswordController,
                  enabled: !_submitting,
                  action: const AppInputAction.password(),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppTheme.sp12),
                AppInput(
                  label: TransactionUiText.confirmPassword,
                  controller: _confirmPasswordController,
                  enabled: !_submitting,
                  action: const AppInputAction.password(),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppTheme.sp12),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 180,
                    child: AppButton.primary(
                      label: TransactionUiText.changePassword,
                      isLoading: _submitting,
                      onPressed: _submit,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PinUnlockDialog extends StatefulWidget {
  const PinUnlockDialog({
    super.key,
    required this.authProvider,
  });

  final SimpleAuthProvider authProvider;

  @override
  State<PinUnlockDialog> createState() => _PinUnlockDialogState();
}

class _PinUnlockDialogState extends State<PinUnlockDialog> {
  final _localAuth = LocalAuthentication();
  final _pinController = TextEditingController();
  final _pinFocusNode = FocusNode();
  Timer? _lockTimer;
  bool _submitting = false;
  bool _biometricSupported = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    widget.authProvider.refreshPinLockState();
    _loadBiometricSupport();
    _focusPinInput();
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      widget.authProvider.refreshPinLockState();
    });
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (widget.authProvider.isPinLocked) {
      setState(() => _errorText = _lockMessage(widget.authProvider));
      return;
    }
    final pin = _pinController.text.trim();
    if (pin.length != 6) {
      setState(() => _errorText = TransactionUiText.pinMustBe6Digits);
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });
    final ok = await widget.authProvider.verifyPin(pin);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    if (widget.authProvider.isPinLocked) {
      setState(() => _errorText = _lockMessage(widget.authProvider));
    } else {
      setState(() {
        _errorText =
            '${TransactionUiText.invalidPin} (${TransactionUiText.remainingAttempts}: ${widget.authProvider.pinAttemptsLeft})';
      });
    }
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

  void _focusPinInput() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.authProvider.isPinLocked) return;
      _pinFocusNode.requestFocus();
    });
  }

  Future<void> _authenticateWithBiometric() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: TransactionUiText.biometricAuthReason,
        biometricOnly: false,
      );
      if (!mounted) return;
      if (didAuthenticate) {
        final ok = await widget.authProvider.unlockWithBiometric();
        if (!mounted) return;
        if (ok) {
          Navigator.of(context).pop(true);
          return;
        }
      }
      setState(() => _errorText = TransactionUiText.biometricAuthFailed);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorText = TransactionUiText.biometricAuthFailed);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _logoutToRelogin() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    await widget.authProvider.logout();
    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.of(context).pop(false);
  }

  String _lockMessage(SimpleAuthProvider authProvider) {
    return '${TransactionUiText.pinTemporarilyLocked} ${authProvider.pinLockRemainingSeconds} ${TransactionUiText.seconds}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AdaptiveContentSheet(
        title: TransactionUiText.enterPinToContinue,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            AppTheme.sp16,
            0,
            AppTheme.sp16,
            MediaQuery.viewInsetsOf(context).bottom + AppTheme.sp16,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(TransactionUiText.pinUnlockDescription),
                const SizedBox(height: AppTheme.sp12),
                if (widget.authProvider.isPinLocked) ...[
                  Text(
                    _lockMessage(widget.authProvider),
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  const SizedBox(height: AppTheme.sp8),
                ],
                AppInput(
                  label: TransactionUiText.pinCode,
                  controller: _pinController,
                  enabled: !_submitting && !widget.authProvider.isPinLocked,
                  focusNode: _pinFocusNode,
                  maxLength: 6,
                  action: const AppInputAction.number(obscure: true),
                  onSubmitted: (_) => _submit(),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: AppTheme.sp8),
                  Text(
                    _errorText!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                if (widget.authProvider.isBiometricEnabled &&
                    _biometricSupported) ...[
                  const SizedBox(height: AppTheme.sp8),
                  AppButton.secondary(
                    label: TransactionUiText.useBiometricUnlock,
                    onPressed: (_submitting || widget.authProvider.isPinLocked)
                        ? null
                        : _authenticateWithBiometric,
                    icon: const Icon(Icons.fingerprint_rounded),
                  ),
                ],
                const SizedBox(height: AppTheme.sp12),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppTheme.sp8,
                  runSpacing: AppTheme.sp8,
                  children: [
                    SizedBox(
                      width: 180,
                      child: AppButton.text(
                        label: TransactionUiText.forgotPinUsePassword,
                        onPressed: _logoutToRelogin,
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: AppButton.primary(
                        label: TransactionUiText.confirm,
                        isLoading: _submitting,
                        onPressed:
                            widget.authProvider.isPinLocked ? null : _submit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MandatoryPinSetupDialog extends StatefulWidget {
  const MandatoryPinSetupDialog({
    super.key,
    required this.authProvider,
  });

  final SimpleAuthProvider authProvider;

  @override
  State<MandatoryPinSetupDialog> createState() =>
      _MandatoryPinSetupDialogState();
}

class _MandatoryPinSetupDialogState extends State<MandatoryPinSetupDialog> {
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _pinFocusNode = FocusNode();
  bool _submitting = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _focusPinInput();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final pin = _pinController.text.trim();
    final confirm = _confirmPinController.text.trim();
    if (pin.length != 6 || int.tryParse(pin) == null) {
      setState(() => _errorText = TransactionUiText.pinMustBe6Digits);
      return;
    }
    if (pin != confirm) {
      setState(() => _errorText = TransactionUiText.pinMismatch);
      return;
    }
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    final ok = await widget.authProvider.setPin(pin);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _errorText = TransactionUiText.pinSaveFailed);
  }

  Future<void> _logout() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    await widget.authProvider.recordPinSetupSkipped();
    await widget.authProvider.logout();
    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.of(context).pop(false);
  }

  void _focusPinInput() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pinFocusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AdaptiveContentSheet(
        title: TransactionUiText.setupPinNowTitle,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            AppTheme.sp16,
            0,
            AppTheme.sp16,
            MediaQuery.viewInsetsOf(context).bottom + AppTheme.sp16,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(TransactionUiText.setupPinNowDescription),
                if (widget.authProvider.pinSetupSkippedCount > 0) ...[
                  const SizedBox(height: AppTheme.sp8),
                  Text(
                    '${TransactionUiText.pinSetupSkippedWarningPrefix} ${widget.authProvider.pinSetupSkippedCount} ${TransactionUiText.timesSuffix}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (!widget.authProvider.canSkipPinSetup) ...[
                  const SizedBox(height: AppTheme.sp8),
                  Text(
                    TransactionUiText.pinSetupSkipLimitReached,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: AppTheme.sp12),
                AppInput(
                  label: TransactionUiText.newPin,
                  controller: _pinController,
                  enabled: !_submitting,
                  focusNode: _pinFocusNode,
                  maxLength: 6,
                  action: const AppInputAction.number(obscure: true),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppTheme.sp12),
                AppInput(
                  label: TransactionUiText.confirmNewPin,
                  controller: _confirmPinController,
                  enabled: !_submitting,
                  maxLength: 6,
                  action: const AppInputAction.number(obscure: true),
                  onSubmitted: (_) => _submit(),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: AppTheme.sp8),
                  Text(
                    _errorText!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: AppTheme.sp12),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppTheme.sp8,
                  runSpacing: AppTheme.sp8,
                  children: [
                    SizedBox(
                      width: 140,
                      child: AppButton.text(
                        label: TransactionUiText.logoutForNow,
                        onPressed: widget.authProvider.canSkipPinSetup
                            ? _logout
                            : null,
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: AppButton.primary(
                        label: TransactionUiText.setupPinNowAction,
                        isLoading: _submitting,
                        onPressed: _submit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
