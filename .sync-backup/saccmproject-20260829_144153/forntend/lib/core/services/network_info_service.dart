import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:saccm/config.dart';
import 'package:saccm/features/license/license_mode.dart';

abstract class NetworkInfoService {
  Future<bool> get isConnected;
  Stream<bool> get onConnectivityChanged;
}

class NetworkInfoServiceImpl implements NetworkInfoService {
  final _connectivity = Connectivity();

  // Dedicated lightweight Dio instance for health-check pings only.
  final _pingDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
      sendTimeout: const Duration(seconds: 4),
    ),
  );

  /// Returns true only for online+offline licenses when BOTH a network
  /// interface exists AND the backend actually responds.
  @override
  Future<bool> get isConnected async {
    if (!await LicenseMode.canSyncOnline()) return false;
    final result = await _connectivity.checkConnectivity();
    if (!_hasNetworkInterface(result)) return false;
    return _isServerReachable();
  }

  /// Emits whenever connectivity changes. Trial/offline-only modes are always
  /// reported as offline and do not ping the backend.
  @override
  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.asyncMap((result) async {
      if (!await LicenseMode.canSyncOnline()) return false;
      if (!_hasNetworkInterface(result)) return false;
      return _isServerReachable();
    });
  }

  /// Pings the configured backend base URL.  Any HTTP response (even 4xx/5xx)
  /// means the server is reachable; only exceptions (timeout, DNS failure,
  /// connection refused) are treated as unreachable.
  Future<bool> _isServerReachable() async {
    try {
      final response = await _pingDio.get(
        baseurl,
        options: Options(validateStatus: (_) => true),
      );
      return (response.statusCode ?? 0) > 0;
    } catch (_) {
      return false;
    }
  }

  bool _hasNetworkInterface(dynamic result) {
    if (result is ConnectivityResult) {
      return result != ConnectivityResult.none;
    }
    if (result is List<ConnectivityResult>) {
      return result.isNotEmpty &&
          result.any((r) => r != ConnectivityResult.none);
    }
    return true;
  }
}
