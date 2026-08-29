import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/services/app_notification_service.dart';
import 'package:saccm/core/services/master_data_sync_service.dart';
import 'package:saccm/features/license/data/datasources/license_local_data_source.dart';
import 'package:saccm/features/license/license_mode.dart';
import 'package:saccm/features/license/presentation/pages/product_plan_page.dart';
import 'package:saccm/features/license/data/datasources/license_remote_data_source.dart';
import 'package:saccm/features/license/product_tier.dart';
import 'package:saccm/widgets/widgets.dart';

/// สถานะการลงทะเบียน (ออฟไลน์ / ออนไลน์)
class LicenseInfoPage extends StatefulWidget {
  const LicenseInfoPage({super.key});

  @override
  State<LicenseInfoPage> createState() => _LicenseInfoPageState();
}

class _LicenseInfoPageState extends State<LicenseInfoPage> {
  static const String _fontFamily = 'Kanit';
  static const double _maxResponsiveFormWidth = 1440;

  final _local = LicenseLocalDataSource();
  final _remote = LicenseRemoteDataSource();

  bool _loading = true;
  bool _syncing = false;
  String? _error;
  LicenseStatusResult? _status;
  LicenseInfo? _info;
  ProductTier? _tier;
  DateTime? _expiresAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _syncMaster() async {
    if (!await LicenseMode.canSyncOnline()) return;
    setState(() => _syncing = true);
    try {
      final ok = await MasterDataSyncService().run();
      if (!mounted) return;
      if (ok) {
        AppNotificationService.instance.showSuccess(
          TransactionUiText.masterDataSyncTitle,
          TransactionUiText.masterDataSyncSuccess,
        );
      } else {
        AppNotificationService.instance.showWarning(
          TransactionUiText.masterDataSyncTitle,
          TransactionUiText.masterDataSyncFailed,
        );
      }
      if (ok) await _load();
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!await LicenseMode.isLicensed()) {
        setState(() {
          _error = TransactionUiText.licenseNotActivated;
          _loading = false;
        });
        return;
      }

      _tier = await _local.getProductTier();
      _expiresAt = await _local.getExpiresAt();
      final info = await _local.loadLicenseInfo();
      if (info == null) {
        setState(() {
          _error = TransactionUiText.licenseNotActivated;
          _loading = false;
        });
        return;
      }
      _info = info;

      if (await LicenseMode.canSyncOnline()) {
        final status = await _remote.fetchStatus(
          schoolCode: info.schoolCode,
          deviceId: info.deviceId,
        );
        if (!mounted) return;
        setState(() {
          _status = status;
          _loading = false;
        });
      } else {
        if (!mounted) return;
        setState(() => _loading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  String _tierLabel(ProductTier? t) {
    switch (t) {
      case ProductTier.offline:
        return TransactionUiText.productTierOfflineTitle;
      case ProductTier.online:
        return TransactionUiText.productTierOnlineTitle;
      default:
        return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Scaffold(
        backgroundColor: c.background,
        appBar: _buildAppBar(c),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: scheme.primary))
            : _error != null
                ? _buildErrorState(c)
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(AppTheme.sp16),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: _maxResponsiveFormWidth,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TransactionFormHeader(
                              icon: Icons.verified_outlined,
                              iconColor: scheme.primary,
                              iconBgColor: c.iconBgIncome,
                              title: TransactionUiText.licenseInfoTitle,
                              subtitle: _tierLabel(_tier),
                              quickHint: TransactionUiText.licenseCanSync,
                              hintAccentColor: scheme.primary,
                              hintBorderColor: c.cardBorder,
                              textPrimaryColor: c.textPrimary,
                              showQuickHint: false,
                            ),
                            const SizedBox(height: AppTheme.sp16),
                            _buildInfoCard(c),
                            if (_status?.expired == true ||
                                (_expiresAt != null &&
                                    _expiresAt!.isBefore(DateTime.now()))) ...[
                              const SizedBox(height: AppTheme.sp16),
                              _buildExpiredBanner(c),
                            ],
                            if (_tier == ProductTier.online) ...[
                              const SizedBox(height: AppTheme.sp16),
                              _buildSyncCard(c),
                            ],
                            const SizedBox(height: AppTheme.sp24),
                          ],
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppColors c) {
    return AppBar(
      toolbarHeight: 52,
      backgroundColor: c.cardWhite,
      title: Text(
        TransactionUiText.licenseInfoTitle,
        style: TextStyle(
          fontFamily: _fontFamily,
          color: c.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      centerTitle: true,
      elevation: 0,
      actions: [
        IconButton(
          tooltip: TransactionUiText.retry,
          onPressed: _loading ? null : _load,
          icon: Icon(Icons.refresh_rounded, color: c.textSecondary),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: c.cardBorder),
      ),
    );
  }

  Widget _buildErrorState(AppColors c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sp24),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.sp16),
          decoration: BoxDecoration(
            color: c.cardWhite,
            borderRadius: BorderRadius.circular(AppTheme.r16),
            border: Border.all(color: c.cardBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: _fontFamily,
                  color: c.textSecondary,
                ),
              ),
              const SizedBox(height: AppTheme.sp16),
              AppButton.primary(
                label: TransactionUiText.productPlanTitle,
                fullWidth: false,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ProductPlanPage(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(AppColors c) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.sp16),
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r16),
        border: Border.all(color: c.cardBorder, width: 1),
      ),
      child: Column(
        children: [
          _row(TransactionUiText.licenseKindLabel, _tierLabel(_tier)),
          _row(TransactionUiText.licenseSchoolName, _info?.schoolName ?? ''),
          _row(TransactionUiText.licenseSchoolCode, _info?.schoolCode ?? ''),
          if (_expiresAt != null)
            _row(
              TransactionUiText.licenseExpiresLabel,
              _formatDate(_expiresAt!),
            ),
          if (_status != null) ...[
            _row(TransactionUiText.licenseStatusLabel, _status!.licenseStatus),
            _row(
              TransactionUiText.licenseDevices,
              '${_status!.devicesUsed} / ${_status!.maxDevices}',
            ),
            _row(
              TransactionUiText.licenseThisDevice,
              _status!.thisDeviceRegistered
                  ? TransactionUiText.labelYes
                  : TransactionUiText.labelNo,
            ),
            _row(
              TransactionUiText.licenseCanSync,
              _status!.canSync
                  ? TransactionUiText.labelYes
                  : TransactionUiText.labelNo,
            ),
          ] else ...[
            _row(TransactionUiText.licenseCanSync, TransactionUiText.labelNo),
          ],
        ],
      ),
    );
  }

  Widget _buildExpiredBanner(AppColors c) {
    final color = Theme.of(context).colorScheme.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.sp12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.r12),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        TransactionUiText.licenseExpiredWarning,
        style: TextStyle(
          fontFamily: _fontFamily,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSyncCard(AppColors c) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.sp16),
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r16),
        border: Border.all(color: c.cardBorder),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final button = AppButton.primary(
            label: TransactionUiText.masterDataSyncTitle,
            isLoading: _syncing,
            fullWidth: box.maxWidth < 560,
            onPressed: _syncing ? null : _syncMaster,
            icon: const Icon(Icons.cloud_download_outlined, size: 20),
          );
          if (box.maxWidth < 560) return button;
          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [SizedBox(width: 220, child: button)],
          );
        },
      ),
    );
  }

  String _formatDate(DateTime d) {
    return ThaiDateFormatter.format(d);
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                  fontFamily: 'Kanit', fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontFamily: 'Kanit')),
          ),
        ],
      ),
    );
  }
}
