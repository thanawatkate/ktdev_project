import 'dart:async';

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:saccm/core/window/desktop_window_chrome.dart';
import '../../../../../constants/app_theme.dart';
import '../../../../../constants/transaction_ui_text.dart';
import '../../../../../widgets/widgets.dart';
import '../widgets/auth_security_dialogs.dart';
import 'package:saccm/features/license/license_mode.dart';
import 'package:saccm/features/license/product_tier.dart';
import '../providers/simple_auth_provider.dart';

// ignore_for_file: use_build_context_synchronously

class SimpleLoginPage extends StatefulWidget {
  static const String routeName = '/login';

  const SimpleLoginPage({super.key});

  @override
  State<SimpleLoginPage> createState() => _SimpleLoginPageState();
}

class _SimpleLoginPageState extends State<SimpleLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pinController = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _pinFocus = FocusNode();
  bool _rememberPassword = false;
  bool _isShowingChangePasswordDialog = false;
  bool _isShowingPinSetupDialog = false;
  bool _authListenerAttached = false;
  AuthStatus? _lastHandledStatus;
  SimpleAuthProvider? _authProvider;
  LicenseSnapshot? _licenseSnap;

  // PIN inline state
  final _localAuth = LocalAuthentication();
  bool _biometricSupported = false;
  bool _pinSubmitting = false;
  String? _pinErrorText;
  Timer? _lockTimer;

  void _safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<SimpleAuthProvider>();
      _authProvider = authProvider;
      _attachAuthListener(authProvider);
      authProvider.initializeSession();
      if (authProvider.status == AuthStatus.pinRequired) {
        _focusPinInput(authProvider);
      }
      authProvider.loadSavedPassword().then((_) {
        if (authProvider.rememberPassword &&
            authProvider.savedPassword != null) {
          _safeSetState(() {
            _passwordController.text = authProvider.savedPassword!;
            _rememberPassword = true;
          });
        }
      });
      _loadBiometricSupport();
      _loadActivatedSchool();
    });
  }

  Future<void> _loadActivatedSchool() async {
    final snap = await LicenseMode.snapshot();
    if (!mounted) return;
    _safeSetState(() => _licenseSnap = snap);
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    if (_authListenerAttached && _authProvider != null) {
      _authProvider!.removeListener(_onAuthChanged);
    }
    _usernameController.dispose();
    _passwordController.dispose();
    _pinController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  void _attachAuthListener(SimpleAuthProvider authProvider) {
    if (_authListenerAttached) return;
    authProvider.addListener(_onAuthChanged);
    _authListenerAttached = true;
  }

  void _onAuthChanged() {
    if (!mounted) return;
    final authProvider = context.read<SimpleAuthProvider>();
    final status = authProvider.status;
    if (_lastHandledStatus == status && status != AuthStatus.authenticated) {
      return;
    }
    _lastHandledStatus = status;

    if (status == AuthStatus.passwordChangeRequired &&
        !_isShowingChangePasswordDialog) {
      _isShowingChangePasswordDialog = true;
      unawaited(_runForceChangePasswordFlow(authProvider));
      return;
    }

    if (status == AuthStatus.pinRequired) {
      // Start the lock-countdown timer so the PIN UI refreshes every second.
      _lockTimer?.cancel();
      _lockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        authProvider.refreshPinLockState();
      });
      authProvider.refreshPinLockState();
      _safeSetState(() {
        _pinErrorText = null;
        _pinSubmitting = false;
      });
      _focusPinInput(authProvider);
      return;
    }

    // PIN no longer required – stop the timer.
    _lockTimer?.cancel();
    _lockTimer = null;

    if (status == AuthStatus.authenticated &&
        !authProvider.mustChangePassword) {
      // ห้าม push /home ขณะไดอะล็อกบังคับเปลี่ยนรหัสยังเปิด — จะทำให้ stack Navigator เพี้ยน (หน้าขาว)
      if (_isShowingChangePasswordDialog) return;
      _handlePostLoginNavigation(authProvider);
    }
  }

  void _handlePostLoginNavigation(SimpleAuthProvider authProvider) {
    if (!mounted) return;
    if (authProvider.status != AuthStatus.authenticated ||
        authProvider.mustChangePassword) {
      return;
    }
    if (authProvider.requiresPinSetup) {
      if (_isShowingPinSetupDialog) return;
      authProvider.markPinSetupPromptHandled();
      _isShowingPinSetupDialog = true;
      _showMandatoryPinSetupDialog(authProvider).then((didSetup) {
        _isShowingPinSetupDialog = false;
        if (!mounted) return;
        if (didSetup == true) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      });
      return;
    }
    Navigator.of(context).pushReplacementNamed('/home');
  }

  Future<void> _runForceChangePasswordFlow(
      SimpleAuthProvider authProvider) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (_) => ForceChangePasswordDialog(
        authProvider: authProvider,
        currentPassword: _passwordController.text,
        rememberMe: _rememberPassword,
      ),
    );
    if (!mounted) return;
    _isShowingChangePasswordDialog = false;
    if (result == true) {
      _handlePostLoginNavigation(context.read<SimpleAuthProvider>());
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      body: Consumer<SimpleAuthProvider>(
        builder: (context, authProvider, child) {
          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.sp24,
                  vertical: AppTheme.sp32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(context),
                      const SizedBox(height: AppTheme.sp48),
                      _buildLoginCard(context, authProvider),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    if (!desktopWindowChromeEnabled) return scaffold;

    return Stack(
      children: [
        scaffold,
        Positioned(
          top: 0,
          left: 0,
          right: kDesktopCaptionWidth,
          height: kToolbarHeight,
          child: DragToMoveArea(
            child: const ColoredBox(
              color: Colors.transparent,
              child: SizedBox.expand(),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Header (logo + title) ────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        const AppLogo(size: 96),
        const SizedBox(height: AppTheme.sp16),
        Text(
          TransactionUiText.appThaiName,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppTheme.sp4),
        Text(
          TransactionUiText.appEnglishSubtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
        if (_licenseSnap != null) ...[
          const SizedBox(height: AppTheme.sp12),
          _buildLicenseChip(context),
        ],
      ],
    );
  }

  Widget _buildLicenseChip(BuildContext context) {
    final snap = _licenseSnap!;
    final scheme = Theme.of(context).colorScheme;
    IconData icon;
    String label;

    switch (snap.tier) {
      case ProductTier.trial:
        final t = snap.trial!;
        icon = Icons.schedule_rounded;
        label = t.expired
            ? TransactionUiText.embeddedTrialExpiredTitle
            : TransactionUiText.embeddedTrialLoginBanner(
                t.daysRemaining,
                t.daysTotal,
              );
        break;
      case ProductTier.offline:
        icon = Icons.storage_rounded;
        label = '${TransactionUiText.productTierOfflineTitle}'
            '${snap.schoolName != null ? ': ${snap.schoolName}' : ''}';
        break;
      case ProductTier.online:
        icon = Icons.cloud_done_rounded;
        label = '${TransactionUiText.productTierOnlineTitle}'
            '${snap.schoolName != null ? ': ${snap.schoolName}' : ''}';
        break;
    }

    return Chip(
      avatar: Icon(icon, size: 18, color: scheme.primary),
      label: Text(
        label,
        style: const TextStyle(fontFamily: 'Kanit', fontSize: 12),
      ),
    );
  }

  // ─── Login Card (switches between PIN and username/password) ─────────────
  Widget _buildLoginCard(
    BuildContext context,
    SimpleAuthProvider authProvider,
  ) {
    if (authProvider.status == AuthStatus.pinRequired) {
      return _buildPinUnlockCard(context, authProvider);
    }
    return _buildUsernamePasswordCard(context, authProvider);
  }

  // ─── PIN Unlock Card (inline) ─────────────────────────────────────────────
  Widget _buildPinUnlockCard(
    BuildContext context,
    SimpleAuthProvider authProvider,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final locked = authProvider.isPinLocked;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sp24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // User info
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(Icons.person_rounded,
                      color: scheme.onPrimaryContainer),
                ),
                const SizedBox(width: AppTheme.sp12),
                Expanded(
                  child: Text(
                    authProvider.username ?? '',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.sp16),
            Text(
              TransactionUiText.enterPinToContinue,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppTheme.sp4),
            Text(
              TransactionUiText.pinUnlockDescription,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppTheme.sp16),

            // Lock warning
            if (locked) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.sp12,
                  vertical: AppTheme.sp8,
                ),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(AppTheme.r8),
                ),
                child: Text(
                  '${TransactionUiText.pinTemporarilyLocked} ${authProvider.pinLockRemainingSeconds} ${TransactionUiText.seconds}',
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
              const SizedBox(height: AppTheme.sp12),
            ],

            AppInput(
              label: TransactionUiText.pinCode,
              controller: _pinController,
              enabled: !_pinSubmitting && !locked,
              focusNode: _pinFocus,
              maxLength: 6,
              action: const AppInputAction.number(obscure: true),
              onSubmitted: (_) => _submitPin(authProvider),
            ),

            if (_pinErrorText != null) ...[
              const SizedBox(height: AppTheme.sp8),
              Text(
                _pinErrorText!,
                style: TextStyle(color: scheme.error, fontSize: 13),
              ),
            ],

            const SizedBox(height: AppTheme.sp16),

            AppButton.primary(
              label: TransactionUiText.confirm,
              isLoading: _pinSubmitting,
              onPressed: (locked || _pinSubmitting)
                  ? null
                  : () => _submitPin(authProvider),
              icon: const Icon(Icons.lock_open_rounded, size: 20),
            ),

            if (authProvider.isBiometricEnabled && _biometricSupported) ...[
              const SizedBox(height: AppTheme.sp8),
              AppButton.secondary(
                label: TransactionUiText.useBiometricUnlock,
                onPressed: (locked || _pinSubmitting)
                    ? null
                    : () => _authenticateWithBiometric(authProvider),
                icon: const Icon(Icons.fingerprint_rounded),
              ),
            ],

            const SizedBox(height: AppTheme.sp8),
            AppButton.text(
              label: TransactionUiText.forgotPinUsePassword,
              onPressed:
                  _pinSubmitting ? null : () => _logoutToRelogin(authProvider),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Username / Password Card ─────────────────────────────────────────────
  Widget _buildUsernamePasswordCard(
    BuildContext context,
    SimpleAuthProvider authProvider,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final licenseCanSyncOnline = _licenseSnap?.canSyncOnline;
    final showOfflineMode =
        licenseCanSyncOnline == false || !authProvider.isOnlineMode;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sp24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── ชื่อผู้ใช้ ──
              AppInput(
                label: TransactionUiText.username,
                hint: TransactionUiText.usernameHint,
                required: true,
                controller: _usernameController,
                enabled: !authProvider.isLoading,
                focusNode: _usernameFocus,
                prefixIcon: const Icon(Icons.person_outline_rounded),
                textInputAction: TextInputAction.next,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                onChanged: (_) => setState(() {}),
                validator: (v) => (v == null || v.isEmpty)
                    ? TransactionUiText.fillUsername
                    : null,
              ),
              const SizedBox(height: AppTheme.sp16),

              // ── รหัสผ่าน ──
              AppInput(
                label: TransactionUiText.password,
                hint: TransactionUiText.passwordHint,
                required: true,
                controller: _passwordController,
                enabled: !authProvider.isLoading,
                focusNode: _passwordFocus,
                textInputAction: TextInputAction.done,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                action: const AppInputAction.password(),
                onSubmitted: (_) {
                  FocusScope.of(context).unfocus();
                  _handleLogin(authProvider);
                },
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return TransactionUiText.fillPassword;
                  }
                  if (v.length < 6) return TransactionUiText.passwordMinLength;
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.sp16),

              // ── Remember password checkbox ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text(TransactionUiText.rememberPassword),
                      value: _rememberPassword,
                      onChanged: authProvider.isLoading
                          ? null
                          : (bool? value) {
                              _safeSetState(() {
                                _rememberPassword = value ?? false;
                              });
                            },
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.sp12),

              // ── Local / offline indicator ──
              if (showOfflineMode)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.sp12,
                    vertical: AppTheme.sp8,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.tertiary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.r8),
                    border: Border.all(
                      color: scheme.tertiary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        color: scheme.tertiary,
                        size: 18,
                      ),
                      const SizedBox(width: AppTheme.sp8),
                      Expanded(
                        child: Text(
                          _licenseSnap?.tier == ProductTier.trial
                              ? TransactionUiText.localOnlyModeMessage
                              : TransactionUiText.offlineModeMessage,
                          style: const TextStyle(
                            fontFamily: 'Kanit',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: AppTheme.sp16),

              // ── Error banner ──
              if (authProvider.error != null) ...[
                _buildErrorBanner(context, authProvider.error!),
                const SizedBox(height: AppTheme.sp16),
              ],

              // ── ปุ่มเข้าสู่ระบบ ──
              AppButton.primary(
                label: TransactionUiText.login,
                isLoading: authProvider.isLoading,
                onPressed: () => _handleLogin(authProvider),
                icon: const Icon(Icons.login_rounded, size: 20),
              ),
              const SizedBox(height: AppTheme.sp12),
              Text(
                TransactionUiText.loginHelp,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Error banner ─────────────────────────────────────────────────────────
  Widget _buildErrorBanner(BuildContext context, String message) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.sp12,
        vertical: AppTheme.sp8,
      ),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(AppTheme.r8),
        border: Border.all(color: scheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: scheme.error, size: 20),
          const SizedBox(width: AppTheme.sp8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: scheme.onErrorContainer,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Login handler ────────────────────────────────────────────────────────
  void _handleLogin(SimpleAuthProvider authProvider) {
    FocusScope.of(context).unfocus();
    if (authProvider.isLoading) return;
    if (_formKey.currentState?.validate() ?? false) {
      authProvider.login(
        _usernameController.text.trim(),
        _passwordController.text,
        rememberMe: _rememberPassword,
      );
    }
  }

  // ─── PIN inline methods ───────────────────────────────────────────────────
  Future<void> _loadBiometricSupport() async {
    try {
      final deviceSupported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      final biometricTypes = await _localAuth.getAvailableBiometrics();
      if (!mounted) return;
      _safeSetState(() {
        _biometricSupported =
            deviceSupported && (canCheck || biometricTypes.isNotEmpty);
      });
    } catch (_) {
      if (!mounted) return;
      _safeSetState(() => _biometricSupported = false);
    }
  }

  void _focusPinInput(SimpleAuthProvider authProvider) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          authProvider.status != AuthStatus.pinRequired ||
          authProvider.isPinLocked) {
        return;
      }
      _pinFocus.requestFocus();
    });
  }

  Future<void> _submitPin(SimpleAuthProvider authProvider) async {
    if (_pinSubmitting || authProvider.isPinLocked) return;
    final pin = _pinController.text.trim();
    if (pin.length != 6) {
      _safeSetState(() => _pinErrorText = TransactionUiText.pinMustBe6Digits);
      return;
    }
    _safeSetState(() {
      _pinSubmitting = true;
      _pinErrorText = null;
    });
    final ok = await authProvider.verifyPin(pin);
    if (!mounted) return;
    _safeSetState(() => _pinSubmitting = false);
    if (ok) return; // _onAuthChanged will navigate
    if (authProvider.isPinLocked) {
      _safeSetState(() => _pinErrorText =
          '${TransactionUiText.pinTemporarilyLocked} ${authProvider.pinLockRemainingSeconds} ${TransactionUiText.seconds}');
    } else {
      _safeSetState(() => _pinErrorText =
          '${TransactionUiText.invalidPin} (${TransactionUiText.remainingAttempts}: ${authProvider.pinAttemptsLeft})');
    }
    _pinController.clear();
  }

  Future<void> _authenticateWithBiometric(
      SimpleAuthProvider authProvider) async {
    if (_pinSubmitting) return;
    _safeSetState(() {
      _pinSubmitting = true;
      _pinErrorText = null;
    });
    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: TransactionUiText.biometricAuthReason,
        biometricOnly: false,
      );
      if (!mounted) return;
      if (didAuthenticate) {
        final ok = await authProvider.unlockWithBiometric();
        if (!mounted) return;
        if (ok) return; // _onAuthChanged will navigate
      }
      _safeSetState(
          () => _pinErrorText = TransactionUiText.biometricAuthFailed);
    } catch (_) {
      if (!mounted) return;
      _safeSetState(
          () => _pinErrorText = TransactionUiText.biometricAuthFailed);
    } finally {
      if (mounted) _safeSetState(() => _pinSubmitting = false);
    }
  }

  Future<void> _logoutToRelogin(SimpleAuthProvider authProvider) async {
    _lockTimer?.cancel();
    _lockTimer = null;
    await authProvider.logout();
  }

  Future<bool?> _showMandatoryPinSetupDialog(
      SimpleAuthProvider authProvider) async {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (_) => MandatoryPinSetupDialog(authProvider: authProvider),
    );
  }
}
