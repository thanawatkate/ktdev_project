import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saccm/core/services/sync_service.dart';
import 'package:saccm/core/services/network_info_service.dart';
import 'package:saccm/constants/app_theme.dart';

/// Example page showing how to use offline features
class OfflineExamplePage extends StatelessWidget {
  const OfflineExamplePage({super.key});

  static const String _fontFamily = 'Kanit';
  static const double _maxResponsiveFormWidth = 1440;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SafeArea(
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          toolbarHeight: 52,
          title: Text(
            'Offline Support Example',
            style: TextStyle(
              fontFamily: _fontFamily,
              color: c.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
          backgroundColor: c.cardWhite,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: c.cardBorder),
          ),
        ),
        body: Column(
          children: [
            // Main content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.sp16),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _maxResponsiveFormWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Connection status section
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.sp16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Connection Status',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: AppTheme.sp12),
                                StreamBuilder<bool>(
                                  stream: context
                                      .read<NetworkInfoService>()
                                      .onConnectivityChanged,
                                  initialData: true,
                                  builder: (context, snapshot) {
                                    final isOnline = snapshot.data ?? true;
                                    return Row(
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isOnline
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                        ),
                                        const SizedBox(width: AppTheme.sp8),
                                        Text(
                                          isOnline ? 'Online' : 'Offline',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: isOnline
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.sp16),

                        // Sync status section
                        Consumer<SyncService>(
                          builder: (context, syncService, _) {
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(AppTheme.sp16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Sync Status',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const SizedBox(height: AppTheme.sp12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Pending Requests:',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                        ),
                                        Text(
                                          '${syncService.pendingCount}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AppTheme.sp12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Syncing:',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                        ),
                                        Text(
                                          syncService.isSyncing ? 'Yes' : 'No',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: syncService.isSyncing
                                                ? Colors.blue
                                                : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: AppTheme.sp16),

                        // Instructions
                        Card(
                          color: Colors.blue.withValues(alpha: 0.05),
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.sp16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Testing Offline Mode',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: AppTheme.sp8),
                                const Text(
                                  '1. Disable WiFi/Mobile data\n'
                                  '2. Try fetching data → uses local cache\n'
                                  '3. Try creating data → saved locally + queued\n'
                                  '4. Check pending count → shows queued items\n'
                                  '5. Enable WiFi/Mobile → auto-sync starts\n'
                                  '6. Check pending → count decreases as sync succeeds',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
