import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/local_data_source/user_local_data_source.dart';
import 'package:saccm/core/platform/runtime_platform.dart';
import 'package:saccm/core/services/app_notification_service.dart';
import 'package:saccm/features/auth/presentation/pages/simple_login_page.dart';
import 'package:saccm/core/services/master_data_sync_service.dart';
import 'package:saccm/features/license/data/datasources/license_local_data_source.dart';
import 'package:saccm/features/license/data/datasources/license_remote_data_source.dart';
import 'package:saccm/features/license/data/models/license_validate_preview.dart';
import 'package:saccm/features/license/product_tier.dart';
import 'package:saccm/features/setting/data/datasources/school_profile_local_data_source.dart';
import 'package:saccm/features/setting/domain/entities/school_profile.dart';
import 'package:saccm/widgets/widgets.dart';

class LicenseActivationPage extends StatefulWidget {
  static const String routeName = '/activate';

  const LicenseActivationPage({super.key});

  @override
  State<LicenseActivationPage> createState() => _LicenseActivationPageState();
}

class _ResponsiveFormField {
  const _ResponsiveFormField({
    required this.child,
    this.span = 1,
  });

  final Widget child;
  final int span;
}

class _LicenseActivationPageState extends State<LicenseActivationPage> {
  static const String _fontFamily = 'Kanit';
  static const double _maxResponsiveFormWidth = 1440;

  final _formKey = GlobalKey<FormState>();
  final _licenseKeyCtrl = TextEditingController();
  final _deviceLabelCtrl = TextEditingController();
  final _adminUserCtrl = TextEditingController();
  final _adminPassCtrl = TextEditingController();
  final _adminPassConfirmCtrl = TextEditingController();
  final _adminNameCtrl = TextEditingController();
  final _adminLastCtrl = TextEditingController();
  final _adminEmailCtrl = TextEditingController();

  final _licenseLocal = LicenseLocalDataSource();
  final _licenseRemote = LicenseRemoteDataSource();
  final _userLocal = UserLocalDataSource();
  final _schoolProfileDs = SchoolProfileLocalDataSourceImpl();

  bool _loading = false;
  String? _error;
  LicenseValidatePreview? _keyPreview;
  bool _validatingKey = false;

  @override
  void initState() {
    super.initState();
    _initDeviceLabel();
  }

  Future<void> _initDeviceLabel() async {
    _deviceLabelCtrl.text = defaultDeviceLabel;
  }

  @override
  void dispose() {
    _licenseKeyCtrl.dispose();
    _deviceLabelCtrl.dispose();
    _adminUserCtrl.dispose();
    _adminPassCtrl.dispose();
    _adminPassConfirmCtrl.dispose();
    _adminNameCtrl.dispose();
    _adminLastCtrl.dispose();
    _adminEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _validateKeyPreview() async {
    final key = _licenseKeyCtrl.text.trim();
    if (key.length < 12) {
      setState(() => _keyPreview = null);
      return;
    }
    setState(() => _validatingKey = true);
    try {
      final preview = await _licenseRemote.validateKey(key);
      if (!mounted) return;
      setState(() {
        _keyPreview = preview;
        _validatingKey = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _keyPreview = null;
        _validatingKey = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final registryOk = await _licenseRemote.isRegistryReachable();
      if (!registryOk) {
        setState(() {
          _error = TransactionUiText.licenseActivateNeedsInternet;
          _loading = false;
        });
        return;
      }

      final deviceId = await _licenseLocal.getOrCreateDeviceId();
      final result = await _licenseRemote.activate(
        licenseKey: _licenseKeyCtrl.text,
        deviceId: deviceId,
        deviceLabel: _deviceLabelCtrl.text.trim(),
        adminUsername: _adminUserCtrl.text,
        adminPassword: _adminPassCtrl.text,
        adminName: _adminNameCtrl.text,
        adminLastname: _adminLastCtrl.text,
        adminEmail: _adminEmailCtrl.text,
      );

      await _userLocal.ensureActivationAdminUser(
        username: _adminUserCtrl.text.trim(),
        password: _adminPassCtrl.text,
        name: _adminNameCtrl.text.trim(),
        lastname: _adminLastCtrl.text.trim(),
        email: _adminEmailCtrl.text.trim(),
      );

      final tier = result.productTier ??
          ProductTierX.fromRegistryKind(result.licenseKind);

      await _licenseLocal.saveActivation(
        schoolCode: result.schoolCode,
        schoolName: result.schoolName,
        deviceId: deviceId,
        token: result.token,
        adminUsername: result.adminUsername,
        licenseKind: result.licenseKind,
        productTier: tier,
        expiresAt: result.expiresAt,
      );

      await _schoolProfileDs.save(
        SchoolProfile(
          name: result.schoolName,
          address: '',
          phone: '',
          extra: result.schoolCode,
        ),
      );

      if (!mounted) return;

      if (result.canSync) {
        AppNotificationService.instance.showBusy(
          TransactionUiText.masterDataSyncAfterActivate,
          TransactionUiText.masterDataSyncInProgress,
        );
        final synced = await MasterDataSyncService().run();
        if (!mounted) return;
        if (synced == false) {
          AppNotificationService.instance.showWarning(
            TransactionUiText.masterDataSyncTitle,
            TransactionUiText.masterDataSyncFailed,
          );
        } else {
          AppNotificationService.instance.showSuccess(
            TransactionUiText.masterDataSyncTitle,
            TransactionUiText.masterDataSyncSuccess,
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(TransactionUiText.productTierOfflineTitle),
          ),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(SimpleLoginPage.routeName);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
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
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(AppTheme.sp16),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: _maxResponsiveFormWidth),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TransactionFormHeader(
                        icon: Icons.verified_user_outlined,
                        iconColor: scheme.primary,
                        iconBgColor: c.iconBgIncome,
                        title: TransactionUiText.licenseActivationTitle,
                        subtitle: TransactionUiText.licenseActivationLead,
                        quickHint: TransactionUiText.licenseKeyHint,
                        hintAccentColor: scheme.primary,
                        hintBorderColor: c.cardBorder,
                        textPrimaryColor: c.textPrimary,
                      ),
                      const SizedBox(height: AppTheme.sp16),
                      _buildLicenseCard(c),
                      const SizedBox(height: AppTheme.sp16),
                      _buildAdminCard(c),
                      if (_error != null) ...[
                        const SizedBox(height: AppTheme.sp16),
                        _buildErrorBanner(c),
                      ],
                      const SizedBox(height: AppTheme.sp16),
                      _buildActionCard(c),
                      const SizedBox(height: AppTheme.sp24),
                    ],
                  ),
                ),
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
        TransactionUiText.licenseActivationTitle,
        style: TextStyle(
          fontFamily: _fontFamily,
          color: c.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      centerTitle: true,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: c.cardBorder),
      ),
    );
  }

  Widget _buildLicenseCard(AppColors c) {
    return Container(
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r16),
        border: Border.all(color: c.cardBorder, width: 1),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final contentWidth = _cardContentWidth(box.maxWidth);
          final columnCount = _responsiveColumnCount(contentWidth);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                c,
                icon: Icons.vpn_key_rounded,
                title: TransactionUiText.licenseKeyLabel,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.sp16,
                  0,
                  AppTheme.sp16,
                  AppTheme.sp16,
                ),
                child: _responsiveFieldGrid(
                  contentWidth,
                  columnCount: columnCount,
                  fields: [
                    _ResponsiveFormField(
                      span: columnCount >= 3 ? 2 : 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppInput(
                            label: TransactionUiText.licenseKeyLabel,
                            controller: _licenseKeyCtrl,
                            hint: TransactionUiText.licenseKeyHint,
                            textCapitalization: TextCapitalization.characters,
                            onChanged: (_) => _validateKeyPreview(),
                          ),
                          if (_validatingKey)
                            const Padding(
                              padding: EdgeInsets.only(top: AppTheme.sp8),
                              child: LinearProgressIndicator(),
                            )
                          else if (_keyPreview != null) ...[
                            const SizedBox(height: AppTheme.sp8),
                            _KeyPreviewBanner(preview: _keyPreview!),
                            if (_keyPreview!.productTier == ProductTier.offline)
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: AppTheme.sp8),
                                child: Text(
                                  TransactionUiText
                                      .licenseOfflineAfterActivateHint,
                                  style: TextStyle(
                                    fontFamily: _fontFamily,
                                    fontSize: 12,
                                    color: c.textSecondary,
                                  ),
                                ),
                              ),
                          ] else if (_licenseKeyCtrl.text.trim().length >=
                              12) ...[
                            const SizedBox(height: AppTheme.sp8),
                            Text(
                              TransactionUiText.licenseKeyPreviewInvalid,
                              style: TextStyle(
                                fontFamily: _fontFamily,
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    _ResponsiveFormField(
                      child: AppInput(
                        label: TransactionUiText.licenseDeviceLabel,
                        controller: _deviceLabelCtrl,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAdminCard(AppColors c) {
    return Container(
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r16),
        border: Border.all(color: c.cardBorder, width: 1),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final contentWidth = _cardContentWidth(box.maxWidth);
          final columnCount = _responsiveColumnCount(contentWidth);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                c,
                icon: Icons.admin_panel_settings_outlined,
                title: TransactionUiText.licenseAdminSection,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.sp16,
                  0,
                  AppTheme.sp16,
                  AppTheme.sp16,
                ),
                child: _responsiveFieldGrid(
                  contentWidth,
                  columnCount: columnCount,
                  fields: [
                    _ResponsiveFormField(
                      child: AppInput(
                        label: TransactionUiText.username,
                        controller: _adminUserCtrl,
                      ),
                    ),
                    _ResponsiveFormField(
                      child: AppInput(
                        label: TransactionUiText.password,
                        controller: _adminPassCtrl,
                        action: const AppInputAction.password(),
                        validator: (v) {
                          if (v == null || v.length < 6) {
                            return TransactionUiText.passwordMinLength;
                          }
                          return null;
                        },
                      ),
                    ),
                    _ResponsiveFormField(
                      child: AppInput(
                        label: TransactionUiText.confirmPassword,
                        controller: _adminPassConfirmCtrl,
                        action: const AppInputAction.password(),
                        validator: (v) {
                          if (v != _adminPassCtrl.text) {
                            return TransactionUiText.passwordMismatch;
                          }
                          return null;
                        },
                      ),
                    ),
                    _ResponsiveFormField(
                      child: AppInput(
                        label: TransactionUiText.licenseAdminName,
                        controller: _adminNameCtrl,
                      ),
                    ),
                    _ResponsiveFormField(
                      child: AppInput(
                        label: TransactionUiText.licenseAdminLastname,
                        controller: _adminLastCtrl,
                      ),
                    ),
                    _ResponsiveFormField(
                      span: columnCount >= 3 ? 2 : 1,
                      child: AppInput(
                        label: TransactionUiText.licenseAdminEmail,
                        controller: _adminEmailCtrl,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildErrorBanner(AppColors c) {
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
        _error!,
        style: TextStyle(
          fontFamily: _fontFamily,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildActionCard(AppColors c) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.sp16),
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r16),
        border: Border.all(color: c.cardBorder),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final button = AppButton(
            label: TransactionUiText.licenseActivateButton,
            onPressed: _loading ? null : _submit,
            isLoading: _loading,
            fullWidth: box.maxWidth < 560,
            icon: const Icon(Icons.verified_user_outlined, size: 20),
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

  Widget _buildSectionHeader(
    AppColors c, {
    required IconData icon,
    required String title,
  }) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.sp16,
        AppTheme.sp16,
        AppTheme.sp16,
        AppTheme.sp12,
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: AppTheme.sp8),
          Text(
            title,
            style: TextStyle(
              fontFamily: _fontFamily,
              color: c.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  double _cardContentWidth(double cardWidth) {
    final horizontalPadding = AppTheme.sp16 * 2;
    return cardWidth > horizontalPadding
        ? cardWidth - horizontalPadding
        : cardWidth;
  }

  int _responsiveColumnCount(double maxWidth) {
    if (maxWidth >= 1180) return 4;
    if (maxWidth >= 900) return 3;
    if (maxWidth >= 560) return 2;
    return 1;
  }

  Widget _responsiveFieldGrid(
    double maxWidth, {
    required int columnCount,
    required List<_ResponsiveFormField> fields,
    double spacing = AppTheme.sp12,
  }) {
    final columns = columnCount.clamp(1, 4).toInt();
    final columnWidth = (maxWidth - (spacing * (columns - 1))) / columns;
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: fields.map((field) {
        final span = field.span.clamp(1, columns).toInt();
        final width = (columnWidth * span) + (spacing * (span - 1));
        return SizedBox(width: width, child: field.child);
      }).toList(),
    );
  }
}

class _KeyPreviewBanner extends StatelessWidget {
  const _KeyPreviewBanner({required this.preview});

  final LicenseValidatePreview preview;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tier = preview.productTier;
    final label = preview.expired
        ? TransactionUiText.licenseKeyPreviewInvalid
        : tier == ProductTier.online
            ? TransactionUiText.licenseKeyPreviewOnline
            : tier == ProductTier.offline
                ? TransactionUiText.licenseKeyPreviewOffline
                : TransactionUiText.licenseKeyPreviewInvalid;

    return Material(
      color: scheme.secondaryContainer.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.vpn_key_rounded, color: scheme.onSecondaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Kanit',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (preview.schoolName.isNotEmpty)
                    Text(
                      preview.schoolName,
                      style: TextStyle(
                        fontFamily: 'Kanit',
                        fontSize: 12,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
