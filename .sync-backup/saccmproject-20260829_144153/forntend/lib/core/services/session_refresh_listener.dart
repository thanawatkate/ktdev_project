import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saccm/features/auth/presentation/providers/simple_auth_provider.dart';
import 'package:saccm/features/license/data/datasources/license_local_data_source.dart';
import 'package:saccm/features/license/data/datasources/license_remote_data_source.dart';
import 'package:saccm/features/license/license_mode.dart';

/// รีเฟรช JWT ก่อนหมดอายุ (8 ชม.) เมื่อแอปทำงานอยู่ / กลับจากพื้นหลัง
class SessionRefreshListener extends StatefulWidget {
  const SessionRefreshListener({super.key, required this.child});

  final Widget child;

  @override
  State<SessionRefreshListener> createState() => _SessionRefreshListenerState();
}

class _SessionRefreshListenerState extends State<SessionRefreshListener>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => _tick(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _tick();
    }
  }

  Future<void> _tick() async {
    if (!mounted) return;
    final auth = context.read<SimpleAuthProvider>();
    if (!await LicenseMode.canSyncOnline()) return;

    if (auth.status != AuthStatus.authenticated) return;

    final username = auth.username;
    if (username == null || username.isEmpty) return;

    await auth.refreshServerTokenIfNeeded();

    try {
      if (!await LicenseMode.canSyncOnline()) return;
      final info = await LicenseLocalDataSource().loadLicenseInfo();
      if (info != null) {
        await LicenseRemoteDataSource().sendHeartbeat(
          schoolCode: info.schoolCode,
          deviceId: info.deviceId,
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
