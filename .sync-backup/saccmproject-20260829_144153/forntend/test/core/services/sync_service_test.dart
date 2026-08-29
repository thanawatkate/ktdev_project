import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:saccm/core/local_data_source/base_local_data_source.dart';
import 'package:saccm/core/services/network_info_service.dart';
import 'package:saccm/core/services/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeNetworkInfoService implements NetworkInfoService {
  FakeNetworkInfoService(this._connected);

  bool _connected;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  @override
  Future<bool> get isConnected async => _connected;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  Future<void> setConnected(bool value) async {
    _connected = value;
    _controller.add(value);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

class FakePendingRequestsService extends PendingRequestsService {
  final List<PendingRequest> _items = [];

  @override
  Future<void> addPendingRequest({
    required String id,
    required String method,
    required String endpoint,
    String? payload,
  }) async {
    _items.add(
      PendingRequest(
        id: id,
        method: method,
        endpoint: endpoint,
        payload: payload,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<List<PendingRequest>> getPendingRequests() async {
    return List<PendingRequest>.from(_items);
  }

  @override
  Future<void> removePendingRequest(String id) async {
    _items.removeWhere((item) => item.id == id);
  }

  @override
  Future<void> updateAttempts(String id, int attempts) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index == -1) {
      return;
    }

    final current = _items[index];
    _items[index] = PendingRequest(
      id: current.id,
      method: current.method,
      endpoint: current.endpoint,
      payload: current.payload,
      createdAt: current.createdAt,
      attempts: attempts,
    );
  }

  @override
  Future<void> clearAllPending() async {
    _items.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'license_activated': true,
        'product_tier': 'online',
        'school_code': 'test-school',
        'school_name': 'Test School',
        'device_id': 'test-device',
      });
    });

    test('removes pending request and calls success handler after sync', () async {
      final network = FakeNetworkInfoService(true);
      final pending = FakePendingRequestsService();
      final syncedIds = <String>[];
      final executedIds = <String>[];

      final service = SyncService(
        networkInfo: network,
        pendingService: pending,
        requestExecutor: (request) async {
          executedIds.add(request.id);
        },
        onRequestSynced: (request, _) async {
          syncedIds.add(request.id);
        },
      );

      await service.addPendingRequest(
        id: 'income_create_1',
        method: 'POST',
        endpoint: 'income',
        payload: '{"docno":"A001"}',
      );
      await Future<void>.delayed(const Duration(milliseconds: 700));

      expect(executedIds, ['income_create_1']);
      expect(syncedIds, ['income_create_1']);
      expect(await pending.getPendingRequests(), isEmpty);
      expect(service.pendingCount, 0);

      service.dispose();
      await network.dispose();
    });

    test('increments attempts when sync fails', () async {
      final network = FakeNetworkInfoService(false);
      final pending = FakePendingRequestsService();

      final service = SyncService(
        networkInfo: network,
        pendingService: pending,
        requestExecutor: (request) async {
          throw Exception('sync failed');
        },
      );

      await service.addPendingRequest(
        id: 'expense_create_1',
        method: 'POST',
        endpoint: 'expense',
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await network.setConnected(true);
      await Future<void>.delayed(const Duration(milliseconds: 2200));

      final requests = await pending.getPendingRequests();
      expect(requests, hasLength(1));
      expect(requests.first.attempts, 1);
      expect(service.pendingCount, 1);

      service.dispose();
      await network.dispose();
    });
  });
}
