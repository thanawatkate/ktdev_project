import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saccm/core/local_data_source/user_local_data_source.dart';
import 'package:saccm/core/services/secure_credential_store.dart';
import 'package:saccm/core/services/session_token_service.dart';
import 'package:saccm/features/license/license_mode.dart';
import '../../../../constants/transaction_ui_text.dart';

enum AuthStatus {
  initial,
  loading,
  passwordChangeRequired,
  pinRequired,
  authenticated,
  unauthenticated,
  error,
}

enum UserRole {
  admin,
  officer,
}

class PermissionKey {
  /// เมนูหลัก — รายการจาก [app_menu] + เมนูคงที่ในแอป (หน้าหลัก/ตั้งค่า/ออกจากระบบ) เช็คด้วย [SimpleAuthProvider.can]
  static const navHome = 'nav.home';
  static const navIncome = 'nav.income';
  static const navExpense = 'nav.expense';
  static const navExpenseReq = 'nav.expense_req';
  static const navLoan = 'nav.loan';
  static const navReports = 'nav.reports';
  static const navUsageGuide = 'nav.usage_guide';
  static const navLogout = 'nav.logout';
  static const navRegister = 'nav.register';
  static const navForms = 'nav.forms';

  static const approvalView = 'approval.view';
  static const approvalApprove = 'approval.approve';
  static const approvalReject = 'approval.reject';

  static const budgetSourceView = 'budget_source.view';
  static const budgetSourceCreate = 'budget_source.create';
  static const budgetSourceUpdate = 'budget_source.update';
  static const budgetSourceDelete = 'budget_source.delete';
  static const incomeDelete = 'income.delete';

  static const settingView = 'setting.view';
  static const userAdminView = 'user_admin.view';
  static const userAdminCreate = 'user_admin.create';
  static const userAdminResetPassword = 'user_admin.reset_password';
  static const userAdminUpdateRole = 'user_admin.update_role';
  static const userAdminToggleActive = 'user_admin.toggle_active';
  static const userAdminPermissionManage = 'user_admin.permission_manage';
  static const auditLogView = 'audit_log.view';
  static const formsDocNoManualEdit = 'forms.docno.manual_edit';
  static const docGroupConfigure = 'setting.doc_group.configure';

  /// แก้ไขชื่อ/ลำดับ/เปิดปิดรายการใน app_menu (หน้าตั้งค่าเมนูหลัก)
  static const menuConfigure = 'menu.configure';

  static const registerDepositView = 'register.deposit.view';
  static const registerDepositCreate = 'register.deposit.create';
  static const registerDepositUpdate = 'register.deposit.update';
  static const registerDepositSettle = 'register.deposit.settle';
  static const registerDepositDelete = 'register.deposit.delete';
}

class SimpleAuthProvider extends ChangeNotifier {
  static const String _lastUsernameKey = 'last_username';
  static const String _pinEnabledPrefix = 'pin_enabled_';
  static const String _pinHashPrefix = 'pin_hash_';
  static const String _biometricEnabledPrefix = 'biometric_enabled_';
  static const String _pinFailedAttemptsPrefix = 'pin_failed_attempts_';
  static const String _pinLockUntilPrefix = 'pin_lock_until_';
  static const String _pinSetupSkippedPrefix = 'pin_setup_skipped_';
  static const int _maxPinSetupSkips = 3;
  static const int _maxPinAttempts = 5;
  static const Duration _pinLockDuration = Duration(minutes: 5);

  AuthStatus _status = AuthStatus.initial;
  String? _error;
  String? _username;
  String? _userFullName;
  String? _userEmail;
  String? _userGroupName;
  String? _savedPassword;
  bool _rememberPassword = false;
  bool _isOnlineMode = true;
  bool _canShowServerSyncUi = false;
  UserRole _role = UserRole.officer;
  bool _mustChangePassword = false;
  Set<String> _permissions = <String>{};
  bool _isPinEnabled = false;
  bool _isBiometricEnabled = false;
  bool _requiresPinSetup = false;
  int _pinSetupSkippedCount = 0;
  int _pinFailedAttempts = 0;
  DateTime? _pinLockedUntil;
  final UserLocalDataSource _userLocalDataSource = UserLocalDataSource();

  AuthStatus get status => _status;
  String? get error => _error;
  String? get username => _username;
  String? get userFullName => _userFullName;
  String? get userEmail => _userEmail;
  String? get userGroupName => _userGroupName;
  String? get savedPassword => _savedPassword;
  bool get rememberPassword => _rememberPassword;
  bool get isOnlineMode => _isOnlineMode;
  bool get canShowServerSyncUi => _canShowServerSyncUi;
  UserRole get role => _role;
  bool get mustChangePassword => _mustChangePassword;
  bool get isPinEnabled => _isPinEnabled;
  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get requiresPinSetup => _requiresPinSetup;
  int get pinSetupSkippedCount => _pinSetupSkippedCount;
  int get maxPinSetupSkips => _maxPinSetupSkips;
  bool get canSkipPinSetup => _pinSetupSkippedCount < _maxPinSetupSkips;
  bool get isPinLocked =>
      _pinLockedUntil != null && DateTime.now().isBefore(_pinLockedUntil!);
  int get pinLockRemainingSeconds {
    if (!isPinLocked) return 0;
    return _pinLockedUntil!
        .difference(DateTime.now())
        .inSeconds
        .clamp(0, 99999);
  }

  int get pinAttemptsLeft =>
      (_maxPinAttempts - _pinFailedAttempts).clamp(0, _maxPinAttempts);
  bool get isAdmin => _role == UserRole.admin;
  bool get isOfficer => _role == UserRole.officer;
  Set<String> get permissions => Set<String>.unmodifiable(_permissions);

  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;

  bool can(String permission) {
    if (_role == UserRole.admin) return true;
    if (_permissions.isNotEmpty) return _permissions.contains(permission);
    switch (permission) {
      case PermissionKey.approvalView:
      case PermissionKey.approvalApprove:
      case PermissionKey.approvalReject:
      case PermissionKey.settingView:
      case PermissionKey.userAdminView:
      case PermissionKey.userAdminCreate:
      case PermissionKey.userAdminResetPassword:
      case PermissionKey.userAdminUpdateRole:
      case PermissionKey.userAdminToggleActive:
      case PermissionKey.userAdminPermissionManage:
      case PermissionKey.auditLogView:
      case PermissionKey.menuConfigure:
      case PermissionKey.docGroupConfigure:
      case PermissionKey.formsDocNoManualEdit:
      case PermissionKey.budgetSourceCreate:
      case PermissionKey.budgetSourceUpdate:
      case PermissionKey.budgetSourceDelete:
      case PermissionKey.incomeDelete:
      case PermissionKey.registerDepositCreate:
      case PermissionKey.registerDepositUpdate:
      case PermissionKey.registerDepositSettle:
      case PermissionKey.registerDepositDelete:
        return false;
      case PermissionKey.registerDepositView:
        return true;
      case PermissionKey.navHome:
      case PermissionKey.navIncome:
      case PermissionKey.navExpense:
      case PermissionKey.navExpenseReq:
      case PermissionKey.navLoan:
      case PermissionKey.navReports:
      case PermissionKey.navUsageGuide:
      case PermissionKey.navLogout:
      case PermissionKey.navRegister:
      case PermissionKey.navForms:
      case PermissionKey.budgetSourceView:
      default:
        return true;
    }
  }

  static bool isServerJwt(String? token) =>
      SessionTokenService.isServerJwt(token);

  Future<void> _persistLocalSessionToken(String username) async {
    await SessionTokenService.saveLocalToken(username);
    _isOnlineMode = false;
  }

  Future<void> _syncOnlineModeFromToken() async {
    final token = await SessionTokenService.readToken();
    _isOnlineMode = SessionTokenService.isServerJwt(token);
  }

  Future<bool> _syncServerSyncUiAvailability() async {
    _canShowServerSyncUi = await LicenseMode.canSyncOnline();
    return _canShowServerSyncUi;
  }

  /// ขอ JWT จาก server เมื่อเปิดใช้งาน license แล้ว (สำหรับ sync)
  Future<void> _tryRefreshServerToken(String username, String password) async {
    if (!await LicenseMode.canSyncOnline()) return;

    try {
      final fresh = await SessionTokenService.fetchFreshToken(
        username: username,
        password: password,
      );
      if (fresh != null && fresh.isNotEmpty) {
        await SessionTokenService.saveServerToken(fresh, username);
        _isOnlineMode = true;
      }
    } catch (_) {
      // ออฟไลน์ — ใช้ local token ต่อได้
    }
  }

  /// รีเฟรช JWT ก่อนหมดอายุ (เรียกจาก SessionRefreshListener / หลัง PIN)
  Future<void> refreshServerTokenIfNeeded({String? password}) async {
    if (!await _syncServerSyncUiAvailability()) {
      _isOnlineMode = false;
      notifyListeners();
      return;
    }

    final username = _username ?? await SessionTokenService.readLastUsername();
    if (username == null || username.isEmpty) return;

    final pwd = password ?? (_rememberPassword ? _savedPassword : null);
    await SessionTokenService.refreshIfNeeded(
      username: username,
      password: pwd,
    );
    await _syncOnlineModeFromToken();
    notifyListeners();
  }

  Future<void> _clearLocalSessionToken() async {
    await SessionTokenService.clearToken();
  }

  String _pinHash(String username, String pin) {
    final normalized = '$username:${pin.trim()}';
    return sha256.convert(normalized.codeUnits).toString();
  }

  String _resolveUsernameFromToken(String token) {
    if (token.startsWith('local_')) {
      return token.substring('local_'.length);
    }
    return '';
  }

  String _pinEnabledKey(String username) => '$_pinEnabledPrefix$username';
  String _pinHashKey(String username) => '$_pinHashPrefix$username';
  String _biometricEnabledKey(String username) =>
      '$_biometricEnabledPrefix$username';
  String _pinFailedAttemptsKey(String username) =>
      '$_pinFailedAttemptsPrefix$username';
  String _pinLockUntilKey(String username) => '$_pinLockUntilPrefix$username';
  String _pinSetupSkippedKey(String username) =>
      '$_pinSetupSkippedPrefix$username';

  Future<void> _loadPinGuardState(
      SharedPreferences prefs, String username) async {
    _pinFailedAttempts = prefs.getInt(_pinFailedAttemptsKey(username)) ?? 0;
    final lockUntilEpoch = prefs.getInt(_pinLockUntilKey(username));
    if (lockUntilEpoch == null) {
      _pinLockedUntil = null;
      return;
    }
    final lockUntil =
        DateTime.fromMillisecondsSinceEpoch(lockUntilEpoch, isUtc: false);
    if (DateTime.now().isAfter(lockUntil)) {
      _pinLockedUntil = null;
      _pinFailedAttempts = 0;
      await prefs.remove(_pinLockUntilKey(username));
      await prefs.setInt(_pinFailedAttemptsKey(username), 0);
    } else {
      _pinLockedUntil = lockUntil;
    }
  }

  Future<void> _clearPinGuardState(
      SharedPreferences prefs, String username) async {
    _pinFailedAttempts = 0;
    _pinLockedUntil = null;
    await prefs.setInt(_pinFailedAttemptsKey(username), 0);
    await prefs.remove(_pinLockUntilKey(username));
  }

  /// โหลด role และ permissions จาก database สำหรับ username ที่กำหนด
  Future<void> _loadUserProfile(String username) async {
    try {
      final user = await _userLocalDataSource.getUserByUsername(username);
      if (user == null) return;
      await _applyUserProfile(user);
    } catch (_) {
      // ถ้าโหลดไม่ได้ ให้คงค่าเดิมไว้
    }
  }

  Future<void> _applyUserProfile(LocalUser user) async {
    _username = user.username;
    _userFullName = user.fullName.trim();
    _userEmail = user.email.trim();
    _userGroupName = (user.userGroupNameTh?.trim().isNotEmpty ?? false)
        ? user.userGroupNameTh!.trim()
        : user.userGroupNameEn?.trim();
    _role = user.isAdmin ? UserRole.admin : UserRole.officer;
    _permissions =
        await _userLocalDataSource.getPermissionsByUserGroup(user.refUserGroup);
  }

  Future<void> refreshCurrentUserPermissions() async {
    final username = _username;
    if (username == null || username.isEmpty) return;
    await _loadUserProfile(username);
    notifyListeners();
  }

  Future<void> initializeSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = await SessionTokenService.readToken() ?? '';
      if (token.isEmpty) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      final fromToken = _resolveUsernameFromToken(token);
      final fallback = prefs.getString(_lastUsernameKey) ?? '';
      final username = fromToken.isNotEmpty ? fromToken : fallback;
      if (username.isEmpty) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      _username = username;
      await _loadUserProfile(username);
      _isPinEnabled = prefs.getBool(_pinEnabledKey(username)) ?? false;
      _isBiometricEnabled =
          prefs.getBool(_biometricEnabledKey(username)) ?? false;
      _pinSetupSkippedCount = prefs.getInt(_pinSetupSkippedKey(username)) ?? 0;
      await _loadPinGuardState(prefs, username);
      _status =
          _isPinEnabled ? AuthStatus.pinRequired : AuthStatus.authenticated;
      _requiresPinSetup = false;
      _error = null;
      if (await _syncServerSyncUiAvailability()) {
        await _syncOnlineModeFromToken();
        if (_rememberPassword && (_savedPassword?.isNotEmpty ?? false)) {
          await refreshServerTokenIfNeeded(password: _savedPassword);
        }
      } else {
        _isOnlineMode = false;
      }
      notifyListeners();
    } catch (_) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  Future<void> loadPinStatus() async {
    final username = _username;
    if (username == null || username.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    _isPinEnabled = prefs.getBool(_pinEnabledKey(username)) ?? false;
    _isBiometricEnabled =
        prefs.getBool(_biometricEnabledKey(username)) ?? false;
    _pinSetupSkippedCount = prefs.getInt(_pinSetupSkippedKey(username)) ?? 0;
    await _loadPinGuardState(prefs, username);
    notifyListeners();
  }

  Future<void> refreshPinLockState() async {
    final username = _username;
    if (username == null || username.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await _loadPinGuardState(prefs, username);
    notifyListeners();
  }

  Future<bool> setPin(String pin, {String? currentPin}) async {
    final username = _username;
    if (username == null || username.isEmpty) return false;
    final normalizedPin = pin.trim();
    if (normalizedPin.length != 6) return false;
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_pinEnabledKey(username)) ?? false;
    if (enabled) {
      final current = currentPin?.trim() ?? '';
      if (current.length != 6) return false;
      final storedHash = prefs.getString(_pinHashKey(username));
      if (storedHash == null || storedHash != _pinHash(username, current)) {
        return false;
      }
    }
    await prefs.setString(
        _pinHashKey(username), _pinHash(username, normalizedPin));
    await prefs.setBool(_pinEnabledKey(username), true);
    await prefs.setInt(_pinSetupSkippedKey(username), 0);
    await _clearPinGuardState(prefs, username);
    _isPinEnabled = true;
    _requiresPinSetup = false;
    _pinSetupSkippedCount = 0;
    notifyListeners();
    return true;
  }

  void markPinSetupPromptHandled() {
    if (!_requiresPinSetup) return;
    _requiresPinSetup = false;
    notifyListeners();
  }

  Future<void> recordPinSetupSkipped() async {
    final username = _username;
    if (username == null || username.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    _pinSetupSkippedCount += 1;
    await prefs.setInt(_pinSetupSkippedKey(username), _pinSetupSkippedCount);
    notifyListeners();
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final username = _username;
    if (username == null || username.isEmpty) return;
    if (!_isPinEnabled && enabled) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey(username), enabled);
    _isBiometricEnabled = enabled;
    notifyListeners();
  }

  Future<bool> verifyPin(String pin) async {
    final username = _username;
    if (username == null || username.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_pinEnabledKey(username)) ?? false;
    if (!enabled) return false;
    await _loadPinGuardState(prefs, username);
    if (isPinLocked) {
      return false;
    }
    final storedHash = prefs.getString(_pinHashKey(username));
    if (storedHash == null || storedHash.isEmpty) return false;
    final matches = _pinHash(username, pin) == storedHash;
    if (matches) {
      await _clearPinGuardState(prefs, username);
      await _loadUserProfile(username);
      _status = AuthStatus.authenticated;
      _error = null;
      notifyListeners();
      return true;
    }
    _pinFailedAttempts += 1;
    await prefs.setInt(_pinFailedAttemptsKey(username), _pinFailedAttempts);
    if (_pinFailedAttempts >= _maxPinAttempts) {
      _pinLockedUntil = DateTime.now().add(_pinLockDuration);
      await prefs.setInt(
        _pinLockUntilKey(username),
        _pinLockedUntil!.millisecondsSinceEpoch,
      );
      _pinFailedAttempts = 0;
      await prefs.setInt(_pinFailedAttemptsKey(username), 0);
    }
    notifyListeners();
    return false;
  }

  Future<bool> disablePin({String? currentPin}) async {
    final username = _username;
    if (username == null || username.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_pinEnabledKey(username)) ?? false;
    if (!enabled) return true;

    if (currentPin != null && currentPin.trim().isNotEmpty) {
      final storedHash = prefs.getString(_pinHashKey(username));
      if (storedHash == null || _pinHash(username, currentPin) != storedHash) {
        return false;
      }
    }

    await prefs.remove(_pinHashKey(username));
    await prefs.setBool(_pinEnabledKey(username), false);
    await prefs.setBool(_biometricEnabledKey(username), false);
    await _clearPinGuardState(prefs, username);
    _isPinEnabled = false;
    _isBiometricEnabled = false;
    notifyListeners();
    return true;
  }

  Future<bool> unlockWithBiometric() async {
    final username = _username;
    if (username == null || username.isEmpty) return false;
    if (!_isPinEnabled || !_isBiometricEnabled) return false;
    final prefs = await SharedPreferences.getInstance();
    await _clearPinGuardState(prefs, username);
    _status = AuthStatus.authenticated;
    _error = null;
    notifyListeners();
    return true;
  }

  /// Load saved password from local storage
  Future<void> loadSavedPassword() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _savedPassword = await SecureCredentialStore.read(
        'saved_password',
        legacyPrefs: prefs,
      );
      _rememberPassword = prefs.getBool('remember_password') ?? false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading saved password: $e');
    }
  }

  /// Save password locally when user checks "Remember password"
  Future<void> setSavePassword(bool save, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (save) {
        await SecureCredentialStore.write('saved_password', password);
        await prefs.setBool('remember_password', true);
        _savedPassword = password;
        _rememberPassword = true;
      } else {
        await SecureCredentialStore.delete('saved_password');
        await prefs.setBool('remember_password', false);
        _savedPassword = null;
        _rememberPassword = false;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving password: $e');
    }
  }

  Future<void> login(String username, String password,
      {bool rememberMe = false}) async {
    _setLoading();

    try {
      if (username.isEmpty || password.length < 6) {
        _status = AuthStatus.error;
        _error = TransactionUiText.invalidUsernameOrPassword;
        notifyListeners();
        return;
      }

      final localUser = await _userLocalDataSource.login(
        username: username,
        password: password,
      );

      if (localUser == null) {
        final existing = await _userLocalDataSource.getUserByUsername(username);
        if (existing != null && !existing.isActive) {
          _status = AuthStatus.error;
          _error = TransactionUiText.userDisabled;
          notifyListeners();
          return;
        }
        _status = AuthStatus.error;
        _error = TransactionUiText.invalidUsernameOrPassword;
        notifyListeners();
        return;
      }

      await _applyUserProfile(localUser);
      _mustChangePassword = localUser.forcePasswordChange;
      final prefs = await SharedPreferences.getInstance();
      _isPinEnabled =
          prefs.getBool(_pinEnabledKey(localUser.username)) ?? false;
      _isBiometricEnabled =
          prefs.getBool(_biometricEnabledKey(localUser.username)) ?? false;
      _pinSetupSkippedCount =
          prefs.getInt(_pinSetupSkippedKey(localUser.username)) ?? 0;
      await _loadPinGuardState(prefs, localUser.username);
      _status = _mustChangePassword
          ? AuthStatus.passwordChangeRequired
          : (_isPinEnabled ? AuthStatus.pinRequired : AuthStatus.authenticated);
      _requiresPinSetup = !_mustChangePassword && !_isPinEnabled;
      _error = null;
      await _persistLocalSessionToken(localUser.username);
      if (await _syncServerSyncUiAvailability()) {
        await _tryRefreshServerToken(username, password);
        await _syncOnlineModeFromToken();
      } else {
        _isOnlineMode = false;
      }

      // Save password if user checked "Remember password"
      if (rememberMe) {
        await setSavePassword(true, password);
      } else {
        await setSavePassword(false, '');
      }
    } catch (e) {
      _status = AuthStatus.error;
      _error = TransactionUiText.loginError;
    }

    notifyListeners();
  }

  Future<void> logout() async {
    _setLoading();

    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 1));

      _username = null;
      _userFullName = null;
      _userEmail = null;
      _userGroupName = null;
      _role = UserRole.officer;
      _mustChangePassword = false;
      _permissions = <String>{};
      _isPinEnabled = false;
      _isBiometricEnabled = false;
      _requiresPinSetup = false;
      _pinSetupSkippedCount = 0;
      _pinFailedAttempts = 0;
      _pinLockedUntil = null;
      _status = AuthStatus.unauthenticated;
      _error = null;
      _isOnlineMode = true;
      _canShowServerSyncUi = false;
      await _clearLocalSessionToken();
    } catch (e) {
      _status = AuthStatus.error;
      _error = TransactionUiText.logoutError;
    }

    notifyListeners();
  }

  void _setLoading() {
    _status = AuthStatus.loading;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<bool> changeInitialPassword({
    required String currentPassword,
    required String newPassword,
    required bool rememberMe,
  }) async {
    final username = _username;
    if (username == null || username.isEmpty) {
      _status = AuthStatus.error;
      _error = TransactionUiText.loginError;
      notifyListeners();
      return false;
    }
    if (newPassword.length < 6) {
      _status = AuthStatus.error;
      _error = TransactionUiText.passwordMinLength;
      notifyListeners();
      return false;
    }

    _setLoading();
    try {
      final changed = await _userLocalDataSource.changePasswordByCredentials(
        username: username,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      if (!changed) {
        _status = AuthStatus.error;
        _error = TransactionUiText.invalidUsernameOrPassword;
        notifyListeners();
        return false;
      }

      _mustChangePassword = false;
      _status = AuthStatus.authenticated;
      _requiresPinSetup = !_isPinEnabled;
      _error = null;
      await _persistLocalSessionToken(username);
      if (rememberMe) {
        await setSavePassword(true, newPassword);
      } else {
        await setSavePassword(false, '');
      }
      notifyListeners();
      return true;
    } catch (_) {
      _status = AuthStatus.error;
      _error = TransactionUiText.loginError;
      notifyListeners();
      return false;
    }
  }
}
