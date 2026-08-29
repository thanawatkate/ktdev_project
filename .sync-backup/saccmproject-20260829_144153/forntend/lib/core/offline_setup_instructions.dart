/// ServiceLocator offline initialization
/// เพิ่ม code นี้เข้าไป service_locator.dart
library;

/*
import 'package:get_it/get_it.dart';
import 'package:saccm/core/services/network_info_service.dart';
import 'package:saccm/core/services/sync_service.dart';
import 'package:saccm/core/local_data_source/income_local_data_source.dart';
import 'package:saccm/core/local_data_source/base_local_data_source.dart';

final getIt = GetIt.instance;

Future<void> initOfflineServices() async {
  // Network Info Service
  getIt.registerSingleton<NetworkInfoService>(
    NetworkInfoServiceImpl(),
  );

  // Pending Requests Service
  final pendingService = PendingRequestsService();
  await pendingService.init();
  getIt.registerSingleton<PendingRequestsService>(pendingService);

  // Sync Service
  getIt.registerSingleton<SyncService>(
    SyncService(
      networkInfo: getIt<NetworkInfoService>(),
      pendingService: getIt<PendingRequestsService>(),
    ),
  );

  // Income Local Data Source
  final incomeLocal = IncomeLocalDataSource();
  await incomeLocal.init();
  getIt.registerSingleton<IncomeLocalDataSource>(incomeLocal);
}
*/

// =====================================================
// คำแนะนำการใช้งาน:
// =====================================================
// 
// 1. เปิด lib/core/di/service_locator.dart
// 
// 2. เพิ่ม imports:
//    import 'package:saccm/core/services/network_info_service.dart';
//    import 'package:saccm/core/services/sync_service.dart';
//    import 'package:saccm/core/local_data_source/income_local_data_source.dart';
//    import 'package:saccm/core/local_data_source/base_local_data_source.dart';
//
// 3. ใน method init() ของ ServiceLocator เพิ่ม:
//    
//    // Network Info Service
//    getIt.registerSingleton<NetworkInfoService>(
//      NetworkInfoServiceImpl(),
//    );
//
//    // Pending Requests Service
//    final pendingService = PendingRequestsService();
//    await pendingService.init();
//    getIt.registerSingleton<PendingRequestsService>(pendingService);
//
//    // Sync Service
//    getIt.registerSingleton<SyncService>(
//      SyncService(
//        networkInfo: getIt<NetworkInfoService>(),
//        pendingService: getIt<PendingRequestsService>(),
//      ),
//    );
//
//    // Income Local Data Source
//    final incomeLocal = IncomeLocalDataSource();
//    await incomeLocal.init();
//    getIt.registerSingleton<IncomeLocalDataSource>(incomeLocal);
//
// 4. ใน providers ของ MultiProvider เพิ่ม:
//    
//    ChangeNotifierProvider(
//      create: (context) => getIt<SyncService>(),
//    ),
//
// 5. วิธีใช้ใน components:
//    
//    // ดึง data (จะใช้ local ถ้า offline)
//    final repository = IncomeRepository(
//      remoteDataSource: getIt<IncomeRemoteDataSource>(),
//      localDataSource: getIt<IncomeLocalDataSource>(),
//      networkInfo: getIt<NetworkInfoService>(),
//    );
//    
//    final incomes = await repository.getIncomeList();
//    
//    // Monitor offline status
//    Consumer<SyncService>(
//      builder: (context, syncService, _) {
//        return Text(
//          'Pending: ${syncService.pendingCount}',
//        );
//      },
//    )
