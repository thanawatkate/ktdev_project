import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

// Core imports
import 'core/diagnostics/startup_log.dart';
import 'core/window/desktop_window_chrome.dart';
import 'core/di/service_locator.dart';
import 'core/local_data_source/app_database_startup.dart';
import 'core/platform/runtime_platform.dart';
import 'core/security/app_guard.dart';
import 'core/security/app_guard_gate.dart';
import 'core/services/app_notification_service.dart';
import 'core/services/expense_sync_warning_service.dart';
import 'core/services/network_info_service.dart';
import 'core/services/report_sync_status_service.dart';
import 'core/services/session_refresh_listener.dart';
import 'core/services/sync_service.dart';
import 'config.dart';

// Theme
import 'constants/app_theme.dart';
import 'constants/transaction_ui_text.dart';
import 'providers/theme_mode_provider.dart';

// Feature imports
import 'features/auth/presentation/providers/simple_auth_provider.dart';
import 'features/auth/presentation/pages/simple_login_page.dart';
import 'features/license/embedded_trial_license.dart';
import 'features/license/presentation/pages/license_activation_page.dart'; // route /activate
import 'features/license/presentation/pages/product_plan_page.dart';
import 'features/license/presentation/widgets/license_gate.dart';
import 'features/setting/presentation/providers/setting_config_provider.dart';

import 'features/home/presentation/pages/home_page.dart';
import 'features/reports/presentation/services/reports_pdf_fonts.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await StartupLog.init();
      StartupLog.step('binding ready');

      FlutterError.onError = (details) {
        StartupLog.step('FlutterError: ${details.exceptionAsString()}');
        if (kDebugMode) {
          FlutterError.presentError(details);
        }
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        StartupLog.step('platform error: $error\n$stack');
        return false;
      };

      runApp(const SaccmBootstrap());
    },
    (error, stack) {
      StartupLog.step('zone error: $error\n$stack');
      runApp(
        StartupErrorApp(
          message: error.toString(),
          logPath: StartupLog.logFilePath,
        ),
      );
    },
  );
}

/// Shows UI immediately, then loads heavy services (helps low-RAM PCs).
class SaccmBootstrap extends StatefulWidget {
  const SaccmBootstrap({super.key});

  @override
  State<SaccmBootstrap> createState() => _SaccmBootstrapState();
}

class _SaccmBootstrapState extends State<SaccmBootstrap> {
  GuardVerdict _guardVerdict = GuardVerdict.ok;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      StartupLog.step('AppGuard.run');
      _guardVerdict = await AppGuard.run();

      StartupLog.step('initDesktopWindowManager');
      await initDesktopWindowManager();

      StartupLog.step('offline support');
      await _initializeOfflineSupport();

      StartupLog.step('RuntimeConfig');
      await RuntimeConfig.loadFromPreferences();

      StartupLog.step('EmbeddedTrialLicense');
      await EmbeddedTrialLicense.ensureStarted();

      StartupLog.step('pending db restore');
      await applyPendingSaccmDbRestoreIfAny();

      StartupLog.step('ServiceLocator.init');
      await ServiceLocator.instance.init();

      StartupLog.step('date formatting (th)');
      Intl.defaultLocale = 'th';
      await initializeDateFormatting('th');

      StartupLog.step('reports pdf fonts preload');
      unawaited(ReportsPdfFonts.preload());

      StartupLog.step('bootstrap complete');
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (e, st) {
      StartupLog.step('bootstrap failed: $e\n$st');
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return StartupErrorApp(
        message: _error!,
        logPath: StartupLog.logFilePath,
      );
    }
    if (_ready) {
      return MyApp(guardVerdict: _guardVerdict);
    }
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                TransactionUiText.appThaiName,
                style: const TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'กำลังเริ่มระบบ...',
                style: TextStyle(
                  fontFamily: 'Kanit',
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Initialize offline support (database, services)
Future<void> _initializeOfflineSupport() async {
  if (kIsWeb) {
    // Requires `web/sqlite3.wasm` + `web/sqflite_sw.js` from:
    // dart run sqflite_common_ffi_web:setup
    databaseFactory = createDatabaseFactoryFfiWeb(
      options: SqfliteFfiWebOptions(
        sqlite3WasmUri: Uri.base.resolve('sqlite3.wasm'),
        sharedWorkerUri: Uri.base.resolve('sqflite_sw.js'),
        indexedDbName: 'saccm_databases',
      ),
    );
  } else if (isDesktopRuntime) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}

/// Minimal UI when bootstrap throws before [MyApp] can start.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({
    super.key,
    required this.message,
    this.logPath,
  });

  final String message;
  final String? logPath;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SACCM startup error',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(message),
                  ),
                ),
                if (logPath != null) ...[
                  const SizedBox(height: 12),
                  SelectableText(
                    'Log: $logPath',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.guardVerdict});

  final GuardVerdict guardVerdict;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<NetworkInfoService>.value(
          value: ServiceLocator.instance.get<NetworkInfoService>(),
        ),

        // Clean Architecture Providers
        ChangeNotifierProvider(
          create: (context) => SimpleAuthProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeModeProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingProvider()..loadConfig(),
        ),
        ChangeNotifierProvider.value(
          value: AppNotificationService.instance,
        ),
        ChangeNotifierProvider.value(
          value: ExpenseSyncWarningService.instance,
        ),
        ChangeNotifierProvider.value(
          value: ReportSyncStatusService.instance,
        ),

        // Offline Support
        ChangeNotifierProvider(
          create: (context) => ServiceLocator.instance.get<SyncService>(),
        ),
      ],
      // LicenseGate อยู่นอก Consumer — กัน state ถูกรีเซ็ตเมื่อ ThemeModeProvider โหลด
      // (ซึ่งเคยทำให้ FlutterSecureStorage บน Windows ค้างคู่กัน → spinner ไม่หาย)
      child: LicenseGate(
        child: Consumer<ThemeModeProvider>(
          builder: (context, themeProvider, _) => MaterialApp(
            title: TransactionUiText.appThaiName,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeProvider.mode,
            builder: (context, child) => AppGuardGate(
              initialVerdict: guardVerdict,
              child: SessionRefreshListener(
                child: desktopAppShellBuilder(context, child),
              ),
            ),
            locale: const Locale('th', 'TH'),
            supportedLocales: const [
              Locale('th', 'TH'),
              Locale('en', 'US'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            initialRoute: '/login',
            routes: {
              '/login': (context) => const SimpleLoginPage(),
              '/activate': (context) => const LicenseActivationPage(),
              '/product-plan': (context) => const ProductPlanPage(),
              '/home': (context) => const HomeScreen(),
            },
            onUnknownRoute: (settings) {
              return MaterialPageRoute(
                builder: (context) => const SimpleLoginPage(),
              );
            },
            debugShowCheckedModeBanner: false,
          ),
        ),
      ),
    );
  }
}
