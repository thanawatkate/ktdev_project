import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/services/app_notification_service.dart';
import 'package:saccm/core/services/network_info_service.dart';
import 'package:saccm/core/services/report_sync_status_service.dart';
import 'package:saccm/core/services/sync_service.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/widgets/sync_status_badge.dart';

class AppBarNotificationBadge extends StatelessWidget {
  const AppBarNotificationBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppNotificationService>(
      builder: (context, service, _) {
        final message = service.current;
        final style = _appNotificationStyle(
          context,
          message?.level ?? AppNotificationLevel.info,
        );
        final hasMessage = message != null;
        final iconColor = hasMessage
            ? style.foreground
            : Theme.of(context).colorScheme.onSurfaceVariant;

        return Padding(
          padding: const EdgeInsets.only(right: AppTheme.sp4),
          child: IconButton(
            tooltip: hasMessage
                ? '${TransactionUiText.appBarNotificationTooltip}\n${message.title}: ${message.message}'
                : TransactionUiText.appBarNoNotificationTooltip,
            visualDensity: VisualDensity.compact,
            onPressed: hasMessage ? service.clear : null,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.notifications_none_rounded, color: iconColor),
                if (message?.busy == true)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: style.foreground,
                      ),
                    ),
                  )
                else if (hasMessage)
                  Positioned(
                    right: -1,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: style.foreground,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              Theme.of(context).appBarTheme.backgroundColor ??
                                  Theme.of(context).colorScheme.surface,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

({
  Color background,
  Color border,
  Color foreground,
  IconData icon,
}) _appNotificationStyle(
  BuildContext context,
  AppNotificationLevel level,
) {
  final scheme = Theme.of(context).colorScheme;
  switch (level) {
    case AppNotificationLevel.success:
      return (
        background: scheme.primaryContainer.withValues(alpha: 0.65),
        border: scheme.primary.withValues(alpha: 0.4),
        foreground: scheme.onPrimaryContainer,
        icon: Icons.check_circle_outline_rounded,
      );
    case AppNotificationLevel.warning:
      return (
        background: scheme.tertiaryContainer.withValues(alpha: 0.7),
        border: scheme.tertiary.withValues(alpha: 0.45),
        foreground: scheme.onTertiaryContainer,
        icon: Icons.warning_amber_rounded,
      );
    case AppNotificationLevel.error:
      return (
        background: scheme.errorContainer.withValues(alpha: 0.75),
        border: scheme.error.withValues(alpha: 0.45),
        foreground: scheme.onErrorContainer,
        icon: Icons.error_outline_rounded,
      );
    case AppNotificationLevel.info:
      return (
        background: scheme.surfaceContainerHighest,
        border: scheme.outline.withValues(alpha: 0.3),
        foreground: scheme.onSurface,
        icon: Icons.info_outline_rounded,
      );
  }
}

/// Offline Status Badge - แสดงสถานะ online/offline
class OfflineStatusBadge extends StatelessWidget {
  const OfflineStatusBadge({super.key});

  @override
  Widget build(BuildContext context) {
    if (!SyncUiRules.canShowServerSyncUi(context)) {
      final offlineColor = Colors.orange[800] ?? Colors.orange;
      return Padding(
        padding: const EdgeInsets.only(right: AppTheme.sp4),
        child: Tooltip(
          message: TransactionUiText.offlineLocalOnlyWorkingMessage,
          child: Icon(
            Icons.cloud_off_rounded,
            size: 22,
            color: offlineColor,
          ),
        ),
      );
    }

    return StreamBuilder<bool>(
      stream: context.read<NetworkInfoService>().onConnectivityChanged,
      initialData: true,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;

        if (isOnline) return const SizedBox.shrink();

        final offlineColor = Colors.orange[800] ?? Colors.orange;
        return Padding(
          padding: const EdgeInsets.only(right: AppTheme.sp4),
          child: Tooltip(
            message: TransactionUiText.offlineWorkingMessage,
            child: Icon(
              Icons.cloud_off_rounded,
              size: 22,
              color: offlineColor,
            ),
          ),
        );
      },
    );
  }
}

class ReportSyncStatusBadge extends StatelessWidget {
  const ReportSyncStatusBadge({super.key});

  @override
  Widget build(BuildContext context) {
    if (!SyncUiRules.canShowServerSyncUi(context)) {
      return const SizedBox.shrink();
    }

    return Consumer<ReportSyncStatusService>(
      builder: (context, service, _) {
        if (!service.isSyncing) return const SizedBox.shrink();

        final c = AppColors.of(context);
        return Padding(
          padding: const EdgeInsets.only(right: AppTheme.sp4),
          child: Tooltip(
            message: TransactionUiText.reportsRefreshingFromServer,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: c.navy,
                    ),
                  ),
                  Icon(Icons.cloud_sync_outlined, size: 16, color: c.navy),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Pending Requests Indicator - แสดงจำนวน pending requests
class PendingRequestsIndicator extends StatelessWidget {
  const PendingRequestsIndicator({super.key});

  Future<void> _manualSync(SyncService syncService) async {
    if (syncService.isSyncing) return;
    if (syncService.pendingCount == 0) {
      AppNotificationService.instance.showInfo(
        TransactionUiText.syncStatus,
        TransactionUiText.syncNoPendingMessage,
      );
      return;
    }
    AppNotificationService.instance.showBusy(
      TransactionUiText.syncSyncingNotification,
      TransactionUiText.syncInProgress,
    );
    unawaited(syncService.syncPendingRequests());
  }

  @override
  Widget build(BuildContext context) {
    if (!SyncUiRules.canShowServerSyncUi(context)) {
      return const SizedBox.shrink();
    }

    return Consumer<SyncService>(
      builder: (context, syncService, _) {
        final primary = Theme.of(context).colorScheme.primary;
        final pendingCount = syncService.pendingCount;
        final disabled = syncService.isSyncing;
        return Padding(
          padding: const EdgeInsets.only(right: AppTheme.sp4),
          child: IconButton(
            tooltip: pendingCount > 0
                ? '${TransactionUiText.syncManualTooltip}\n${TransactionUiText.syncPendingQueueCount}: $pendingCount'
                : TransactionUiText.syncManualTooltip,
            visualDensity: VisualDensity.compact,
            onPressed: disabled ? null : () => _manualSync(syncService),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                if (syncService.isSyncing)
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primary,
                    ),
                  )
                else
                  Icon(Icons.sync_rounded, color: primary),
                if (pendingCount > 0)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: _SmallCountBadge(count: pendingCount),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SmallCountBadge extends StatelessWidget {
  const _SmallCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : count.toString();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: scheme.error,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: Theme.of(context).appBarTheme.backgroundColor ??
              Theme.of(context).colorScheme.surface,
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: scheme.onError,
          fontFamily: 'Kanit',
          fontSize: 9,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}
