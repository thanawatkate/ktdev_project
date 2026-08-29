# Offline Mode Implementation Guide

## 📦 What's Been Added

### 1. **Dependencies** (pubspec.yaml)
```
sqflite: ^2.3.0        # Local SQLite database
connectivity_plus: ^5.0.0  # Network monitoring
path_provider: ^2.1.0  # Database path handling
```

### 2. **Core Services**

#### `lib/core/services/network_info_service.dart`
- Detects online/offline status in real-time
- Provides stream for connectivity changes
- Abstract class for dependency injection

#### `lib/core/services/sync_service.dart`
- Manages pending requests queue
- Auto-syncs when connection is restored
- Tracks syncing state and pending count
- Extends ChangeNotifier for UI updates

### 3. **Local Data Layer**

#### `lib/core/local_data_source/app_database.dart`
- Initializes SQLite database
- Creates tables: income, expense, member, money_type, income_type, etc.
- Includes pending_requests table for offline queue
- Singleton pattern for database access

#### `lib/core/local_data_source/base_local_data_source.dart`
- Base class for all local data sources
- PendingRequestsService for queue management
- PendingRequest model

#### `lib/core/local_data_source/income_local_data_source.dart`
- Example implementation for income data
- Methods: saveIncome, getAllIncomes, getPendingIncomes, markAsSynced, etc.

### 4. **Repository Pattern**

#### `lib/features/income/data/repositories/income_repository_offline.dart`
- Offline-first pattern implementation
- Falls back to local data when offline
- Syncs automatically when online
- Example for income module (apply same pattern to others)

### 5. **UI Components**

#### `lib/widgets/offline_status_widgets.dart`
- **OfflineStatusBadge**: Compact offline indicator
- **PendingRequestsIndicator**: Shows pending sync count
- **OfflineStatusBar**: Full-width status bar
- **SyncStatusBottomSheet**: Detailed sync status

---

## 🚀 Integration Steps

### Step 1: Update Dependencies
```bash
cd forntend
flutter pub get
```

### Step 2: Register Services in ServiceLocator

Edit `lib/core/di/service_locator.dart`:

```dart
import 'package:saccm/core/services/network_info_service.dart';
import 'package:saccm/core/services/sync_service.dart';
import 'package:saccm/core/local_data_source/income_local_data_source.dart';
import 'package:saccm/core/local_data_source/base_local_data_source.dart';

class ServiceLocator {
  static final instance = ServiceLocator._internal();
  
  ServiceLocator._internal();
  
  Future<void> init() async {
    // ... existing code ...
    
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
}
```

### Step 3: Add SyncService to MultiProvider

Edit `lib/main.dart`:

```dart
return MultiProvider(
  providers: [
    ChangeNotifierProvider(
      create: (context) => SimpleAuthProvider(),
    ),
    ChangeNotifierProvider(
      create: (context) => getIt<SyncService>(),
    ),
    ChangeNotifierProvider(
      create: (context) => DisplayProvider(),
    ),
  ],
  child: MaterialApp(
    // ... rest of config ...
  ),
);
```

### Step 4: Create Local Data Sources for Other Modules

Copy pattern from `income_local_data_source.dart` for:
- ExpenseLocalDataSource
- MemberLocalDataSource
- MoneyTypeLocalDataSource
- IncomeTypeLocalDataSource
- etc.

### Step 5: Integrate Repository Pattern

For Income (already created as example):
- Use `income_repository_offline.dart` instead of direct `income_remote_data_source.dart`
- Follow the same pattern for other repositories

### Step 6: Add UI Indicators

In your pages (e.g., home_page.dart):

```dart
import 'package:saccm/widgets/offline_status_widgets.dart';

// In build():
Scaffold(
  appBar: AppBar(
    title: const Text('Home'),
    // ... other config ...
  ),
  body: Column(
    children: [
      const OfflineStatusBar(),
      const PendingRequestsIndicator(),
      Expanded(
        child: ListView(
          // Your content
        ),
      ),
    ],
  ),
);
```

---

## 💡 Usage Examples

### Reading Data (Offline-Safe)
```dart
class IncomeProvider extends ChangeNotifier {
  final IncomeRepository _repository;
  
  Future<void> loadIncomes() async {
    try {
      // This will:
      // - Fetch remote if online and cache locally
      // - Use cache if offline
      final incomes = await _repository.getIncomeList();
      _incomes = incomes;
      notifyListeners();
    } catch (e) {
      // Handle error
    }
  }
}
```

### Creating Data (Offline Queue)
```dart
Future<void> createIncome() async {
  try {
    // This will:
    // - Send to remote if online
    // - Queue locally if offline
    // - Auto-sync when connection returns
    await _repository.createIncome(
      token: _token,
      docno: _docno,
      // ... other params ...
    );
  } catch (e) {
    // Handle error
  }
}
```

### Monitoring Offline Status
```dart
// In widget:
StreamBuilder<bool>(
  stream: context.read<NetworkInfoService>().onConnectivityChanged,
  builder: (context, snapshot) {
    final isOnline = snapshot.data ?? true;
    return Text(isOnline ? 'Online' : 'Offline');
  },
)
```

### Manual Sync
```dart
// In button onPressed:
Consumer<SyncService>(
  builder: (context, syncService, _) {
    return ElevatedButton(
      onPressed: syncService.syncPendingRequests,
      child: const Text('Sync Now'),
    );
  },
)
```

---

## 🗂️ File Structure

```
lib/
├── core/
│   ├── services/
│   │   ├── network_info_service.dart
│   │   └── sync_service.dart
│   ├── local_data_source/
│   │   ├── app_database.dart
│   │   ├── base_local_data_source.dart
│   │   ├── income_local_data_source.dart
│   │   ├── expense_local_data_source.dart  (to be created)
│   │   ├── member_local_data_source.dart   (to be created)
│   │   └── ...
│   └── di/
│       └── service_locator.dart (update)
├── features/
│   ├── income/
│   │   └── data/
│   │       ├── repositories/
│   │       │   └── income_repository_offline.dart
│   │       └── datasources/ (existing)
│   ├── expense/ (update similarly)
│   ├── member/ (update similarly)
│   └── ...
└── widgets/
    └── offline_status_widgets.dart
```

---

## 🔄 Data Flow

### Online Mode
```
User Action
  ↓
Repository (check isConnected)
  ↓
Remote API
  ↓
Local Database (cache)
  ↓
User sees data
```

### Offline Mode
```
User Action
  ↓
Repository (check isConnected)
  ↓
Local Database
  ↓
User sees cached data

(If CREATE/UPDATE/DELETE)
  ↓
Added to pending_requests queue
```

### Reconnection
```
Internet Restored
  ↓
SyncService detects connectivity
  ↓
Processes pending_requests
  ↓
Syncs with remote API
  ↓
Updates local database
  ↓
User sees latest data
```

---

## ⚙️ Components Checklist

- [x] Dependencies added (sqflite, connectivity_plus, path_provider)
- [x] NetworkInfoService
- [x] AppDatabase with schema
- [x] BaseLocalDataSource
- [x] IncomeLocalDataSource (example)
- [x] SyncService
- [x] IncomeRepository (offline-first)
- [x] Offline UI widgets
- [ ] ServiceLocator integration ← **Todo: Do this manually**
- [ ] Other modules local data sources ← **Todo: Create for expense, member, etc.**
- [ ] Update other repositories ← **Todo: Apply pattern to all repositories**
- [ ] Add UI indicators in pages ← **Todo: Add to home, income, expense pages**

---

## 🐛 Testing Offline Mode

1. **Turn off WiFi/Mobile data**
2. **Try fetching data** → Should display cached data
3. **Try creating data** → Should save locally in pending queue
4. **Check pending indicator** → Should show pending count
5. **Turn WiFi/Mobile back on** → Auto-sync should start
6. **Check indicator disappears** → All synced successfully

---

## 🎯 Next Steps

1. Run: `flutter pub get`
2. Follow "Integration Steps" above
3. Create local data sources for other modules
4. Update existing repositories with offline pattern
5. Add UI indicators to pages
6. Test offline functionality thoroughly
7. Handle edge cases (conflicts, network timeouts, etc.)

---

## 📚 References

- [SQLFlite Documentation](https://pub.dev/packages/sqflite)
- [Connectivity Plus](https://pub.dev/packages/connectivity_plus)
- [Offline-First Architecture](https://kuzzle.io/blog/offline-first-architecture/)
