import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/services/app_notification_service.dart';
import 'package:saccm/core/services/session_token_service.dart';
import 'package:saccm/features/license/license_mode.dart';
import '../local_data_source/base_local_data_source.dart';
import '../services/network_info_service.dart';

typedef PendingRequestExecutor = Future<void> Function(PendingRequest request);
typedef PendingRequestSuccessHandler = Future<void> Function(
  PendingRequest request,
  Response<dynamic>? response,
);
typedef ExpenseReqPendingHandler = Future<void> Function(
    PendingRequest request);

/// Service สำหรับ auto-sync pending requests เมื่อ online กลับมา
class SyncService extends ChangeNotifier {
  final NetworkInfoService _networkInfo;
  final PendingRequestsService _pendingService;
  final Dio? _dio;
  final int _maxRetryAttempts;
  final PendingRequestExecutor? _requestExecutor;
  final PendingRequestSuccessHandler? _onRequestSynced;
  ExpenseReqPendingHandler? _expenseReqPendingHandler;

  /// Per-request HTTP timeout — prevents a single hung request from stalling
  /// the entire sync queue.
  static const _requestTimeout = Duration(seconds: 15);

  /// Debounce duration: waits this long after the last connectivity event
  /// before actually running sync.  Prevents sync storms when the network
  /// oscillates rapidly.
  static const _syncDebounce = Duration(seconds: 2);
  static const _queueSyncDebounce = Duration(milliseconds: 600);

  StreamSubscription<bool>? _connectivitySubscription;
  Timer? _debounceTimer;
  bool _disposed = false;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  int _pendingCount = 0;
  int get pendingCount => _pendingCount;

  SyncService({
    required NetworkInfoService networkInfo,
    required PendingRequestsService pendingService,
    Dio? dio,
    int maxRetryAttempts = 5,
    PendingRequestExecutor? requestExecutor,
    PendingRequestSuccessHandler? onRequestSynced,
  })  : _networkInfo = networkInfo,
        _pendingService = pendingService,
        _dio = dio,
        _maxRetryAttempts = maxRetryAttempts,
        _requestExecutor = requestExecutor,
        _onRequestSynced = onRequestSynced {
    _init();
  }

  void _init() {
    _connectivitySubscription =
        _networkInfo.onConnectivityChanged.listen((isConnected) {
      if (isConnected && !_isSyncing) {
        _scheduleSync(delay: _syncDebounce);
      }
    });

    unawaited(_loadPendingCount());
  }

  Future<void> _loadPendingCount() async {
    if (!await LicenseMode.canSyncOnline()) {
      _pendingCount = 0;
      if (!_disposed) notifyListeners();
      return;
    }
    final pending = await _pendingService.getPendingRequests();
    _pendingCount = pending.length;
    if (!_disposed) notifyListeners();
  }

  void registerExpenseReqPendingHandler(ExpenseReqPendingHandler handler) {
    _expenseReqPendingHandler = handler;
  }

  /// Add a pending request to queue
  Future<void> addPendingRequest({
    required String id,
    required String method,
    required String endpoint,
    String? payload,
    bool silent = false,
  }) async {
    if (!await LicenseMode.canSyncOnline()) {
      return;
    }

    await _pendingService.addPendingRequest(
      id: id,
      method: method,
      endpoint: endpoint,
      payload: payload,
    );
    unawaited(_loadPendingCount());
    if (!silent) {
      AppNotificationService.instance.showInfo(
        TransactionUiText.syncQueuedNotification,
        TransactionUiText.syncQueuedMessage,
      );
    }

    // Coalesce bursts (e.g. user saves multiple rows quickly) into one
    // background sync wave. Connectivity probing happens inside the worker.
    if (!_isSyncing) _scheduleSync(delay: _queueSyncDebounce);
  }

  /// ยกเลิกคิว POST/PATCH ที่ยังไม่ส่งสำหรับ party นี้ (ใช้ก่อนลบแถว party ในเครื่อง)
  Future<void> cancelPendingPartyWrites(String partyId) async {
    await _pendingService.removePendingRequestsForParty(partyId);
    unawaited(_loadPendingCount());
  }

  Future<void> cancelPendingRequest(String id) async {
    await _pendingService.removePendingRequest(id);
    unawaited(_loadPendingCount());
  }

  void _scheduleSync({required Duration delay}) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, () => unawaited(syncPendingRequests()));
  }

  /// Sync all pending requests.
  /// Uses exponential backoff per request based on its attempt count:
  ///   backoff = 2^attempts seconds (capped at 64 s).
  /// Requests that exceed [_maxRetryAttempts] are still kept and retried; local
  /// data is never treated as safely synced until the server accepts it.
  Future<void> syncPendingRequests() async {
    if (_isSyncing ||
        !await LicenseMode.canSyncOnline() ||
        !await _networkInfo.isConnected) {
      return;
    }

    _isSyncing = true;
    if (!_disposed) notifyListeners();

    try {
      final pendingRequests = await _pendingService.getPendingRequests();
      if (pendingRequests.isNotEmpty) {
        AppNotificationService.instance.showBusy(
          TransactionUiText.syncSyncingNotification,
          TransactionUiText.syncInProgress,
        );
      }
      var syncedCount = 0;
      var failedCount = 0;

      for (final request in pendingRequests) {
        if (request.attempts >= _maxRetryAttempts) {
          debugPrint('SyncService: retrying ${request.id} after '
              '${request.attempts} attempts; kept in queue until accepted');
        }

        // Exponential backoff: skip this cycle if the minimum wait hasn't
        // elapsed since the request was created / last attempted.
        final backoffExponent = math.min(6, request.attempts);
        final backoffSeconds = 1 << backoffExponent; // 1,2,4,8,…64
        final earliestRetry =
            request.createdAt.add(Duration(seconds: backoffSeconds));
        if (request.attempts > 0 && DateTime.now().isBefore(earliestRetry)) {
          debugPrint('SyncService: skipping ${request.id} (backoff '
              '${backoffSeconds}s not elapsed)');
          continue;
        }

        try {
          final response = await _executePendingRequest(request);
          await _onRequestSynced?.call(request, response);
          await _pendingService.removePendingRequest(request.id);
          syncedCount++;
          debugPrint('SyncService: synced ${request.id}');
        } catch (e) {
          failedCount++;
          await _pendingService.updateAttempts(
              request.id, request.attempts + 1);
          debugPrint('SyncService: failed to sync ${request.id} '
              '(attempt ${request.attempts + 1}): $e');
        }
      }

      unawaited(_loadPendingCount());
      if (pendingRequests.isNotEmpty) {
        if (failedCount > 0) {
          AppNotificationService.instance.showWarning(
            TransactionUiText.syncWarningNotification,
            TransactionUiText.syncPartialFailedMessage(
                failedCount, _pendingCount),
          );
        } else if (syncedCount > 0) {
          AppNotificationService.instance.showSuccess(
            TransactionUiText.syncSuccessNotification,
            TransactionUiText.syncCompletedMessage(syncedCount),
          );
        } else {
          AppNotificationService.instance.clear();
        }
      }
    } finally {
      _isSyncing = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Clear all pending requests
  Future<void> clearAllPending() async {
    await _pendingService.clearAllPending();
    unawaited(_loadPendingCount());
  }

  /// Get current connectivity status
  Future<bool> get isConnected => _networkInfo.isConnected;

  /// Stream of connectivity changes
  Stream<bool> get onConnectivityChanged => _networkInfo.onConnectivityChanged;

  void _throwIfMutationBodyFailed(
      PendingRequest request, Response<dynamic> resp) {
    final code = resp.statusCode ?? 0;
    if (code < 200 || code >= 300) {
      throw Exception('Sync HTTP $code');
    }
    final raw = resp.data;
    if (raw is! Map) return;
    final status = (raw['status'] ?? '').toString().toLowerCase().trim();
    final ok = raw['success'];
    if (ok == false) {
      final msg = raw['message']?.toString().trim();
      throw Exception(
        msg != null && msg.isNotEmpty ? msg : 'Sync rejected: ${request.id}',
      );
    }
    if (status.isEmpty) {
      return;
    }
    const successStatuses = {
      'successfully',
      'success',
      'ok',
      'true',
      'completed',
    };
    if (successStatuses.contains(status)) return;
    final msg = raw['message']?.toString().trim();
    throw Exception(
      msg != null && msg.isNotEmpty ? msg : 'Sync rejected: $status',
    );
  }

  Future<Response<dynamic>?> _executePendingRequest(
      PendingRequest request) async {
    if (request.id.startsWith('expense_req_')) {
      final handler = _expenseReqPendingHandler;
      if (handler != null) {
        await handler(request);
        return null;
      }
    }

    final requestExecutor = _requestExecutor;
    if (requestExecutor != null) {
      await requestExecutor(request);
      return null;
    }

    if (_dio == null) {
      throw StateError('Dio client is not configured for SyncService');
    }

    dynamic data;
    final rawPayload = request.payload;
    if (rawPayload != null && rawPayload.isNotEmpty) {
      try {
        data = jsonDecode(rawPayload);
      } catch (_) {
        data = rawPayload;
      }
    }
    final token = await SessionTokenService.readToken();
    if (data is Map<String, dynamic> &&
        token != null &&
        token.isNotEmpty &&
        !data.containsKey('token')) {
      data = <String, dynamic>{...data, 'token': token};
    }

    // Apply per-request timeout to prevent a single hung request from
    // blocking the rest of the sync queue indefinitely.
    final resp = await _dio!.request<dynamic>(
      request.endpoint,
      options: Options(
        method: request.method,
        sendTimeout: _requestTimeout,
        receiveTimeout: _requestTimeout,
        headers: token != null && token.isNotEmpty
            ? {'Authorization': 'Bearer $token'}
            : null,
      ),
      data: data,
    );
    _throwIfMutationBodyFailed(request, resp);
    return resp;
  }

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
