import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/utils/user_error_message.dart';
import 'package:saccm/features/license/license_mode.dart';
import 'package:saccm/features/license/presentation/pages/product_plan_page.dart';
import 'package:saccm/features/setting/presentation/providers/setting_config_provider.dart';
import 'package:saccm/widgets/widgets.dart';

class SettingApiDbPage extends StatefulWidget {
  const SettingApiDbPage({super.key});

  @override
  State<SettingApiDbPage> createState() => _SettingApiDbPageState();
}

class _SettingApiDbPageState extends State<SettingApiDbPage> {
  static const String _fontFamily = 'Kanit';
  static const double _maxResponsiveFormWidth = 1440;

  late TextEditingController _apiUrlCtrl;

  bool _isTestingApi = false;
  String? _testApiMessage;
  bool? _testApiSuccess;
  bool? _canConfigureApi;

  void _safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  @override
  void initState() {
    super.initState();
    final setting = context.read<SettingProvider>();
    _apiUrlCtrl = TextEditingController(text: setting.apiUrl);
    _loadApiConfigAccess();
  }

  @override
  void dispose() {
    _apiUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadApiConfigAccess() async {
    final canConfigure = await LicenseMode.canSyncOnline();
    if (!mounted) return;
    setState(() => _canConfigureApi = canConfigure);
  }

  bool _ensureCanConfigureApi() {
    if (_canConfigureApi == true) return true;
    _showMessage(TransactionUiText.apiSettingRequiresOnlineLicense,
        isError: true);
    return false;
  }

  Future<void> _testApi() async {
    if (!_ensureCanConfigureApi()) return;

    final url = _apiUrlCtrl.text.trim();
    if (url.isEmpty) {
      _safeSetState(() {
        _testApiSuccess = false;
        _testApiMessage = TransactionUiText.fillRequiredFields;
      });
      return;
    }

    _safeSetState(() {
      _isTestingApi = true;
      _testApiSuccess = null;
      _testApiMessage = TransactionUiText.testing;
    });

    try {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));
      final res = await dio.get<Map<String, dynamic>>(
        '$url/saccapi/setup/ping',
        options: Options(validateStatus: (_) => true),
      );

      if (res.data?['success'] == true) {
        _safeSetState(() {
          _testApiSuccess = true;
          _testApiMessage =
              res.data?['message'] as String? ?? TransactionUiText.apiReady;
        });
      } else {
        _safeSetState(() {
          _testApiSuccess = false;
          _testApiMessage = res.data?['message'] as String? ??
              TransactionUiText.apiInvalidResponse;
        });
      }
    } on DioException catch (e) {
      _safeSetState(() {
        _testApiSuccess = false;
        _testApiMessage = toUserErrorMessage(e);
      });
    } finally {
      _safeSetState(() => _isTestingApi = false);
    }
  }

  Future<void> _saveConfig() async {
    if (!_ensureCanConfigureApi()) return;

    FocusScope.of(context).unfocus();

    final apiUrl = _apiUrlCtrl.text.trim();

    if (apiUrl.isEmpty) {
      _showMessage(TransactionUiText.fillRequiredFields, isError: true);
      return;
    }

    try {
      final setting = context.read<SettingProvider>();
      await setting.setApiUrl(apiUrl);

      if (mounted) {
        _showMessage(TransactionUiText.saveConfigSuccess, isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showMessage(toUserErrorMessage(e), isError: true);
      }
    }
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final canConfigureApi = _canConfigureApi == true;

    return SafeArea(
      child: Scaffold(
        backgroundColor: c.background,
        appBar: _buildAppBar(c, canConfigureApi: canConfigureApi),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: _canConfigureApi == null
              ? Center(child: CircularProgressIndicator(color: scheme.primary))
              : SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(AppTheme.sp16),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: _maxResponsiveFormWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TransactionFormHeader(
                      icon: Icons.settings_rounded,
                      iconColor: scheme.primary,
                      iconBgColor: c.iconBgIncome,
                      title: TransactionUiText.apiDbSettingTitle,
                      subtitle: TransactionUiText.apiDbSettingSubtitle,
                      quickHint: TransactionUiText.apiUrlHint,
                      hintAccentColor: scheme.primary,
                      hintBorderColor: c.cardBorder,
                      textPrimaryColor: c.textPrimary,
                    ),
                    const SizedBox(height: AppTheme.sp16),
                    if (canConfigureApi) ...[
                      _buildConfigCard(c),
                      const SizedBox(height: AppTheme.sp16),
                      _buildActionCard(c),
                    ] else
                      _buildApiLockedCard(c, scheme),
                    const SizedBox(height: AppTheme.sp24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    AppColors c, {
    required bool canConfigureApi,
  }) {
    return AppBar(
      toolbarHeight: 52,
      title: Text(
        TransactionUiText.apiDbSettingTitle,
        style: TextStyle(
          color: c.textPrimary,
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
      centerTitle: true,
      backgroundColor: c.cardWhite,
      elevation: 0,
      actions: canConfigureApi
          ? [
              AppBarActionButton(
                label: TransactionUiText.save,
                onPressed: _saveConfig,
              ),
              const SizedBox(width: 4),
            ]
          : null,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: c.cardBorder),
      ),
    );
  }

  Widget _buildApiLockedCard(AppColors c, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.sp16),
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r16),
        border: Border.all(color: c.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: c.iconBgLoan,
                  borderRadius: BorderRadius.circular(AppTheme.r12),
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  color: scheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppTheme.sp12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TransactionUiText.apiSettingLockedTitle,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontFamily: _fontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      TransactionUiText.apiSettingLockedMessage,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontFamily: _fontFamily,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.sp16),
          AppButton.primary(
            label: TransactionUiText.apiSettingGoProductPlan,
            icon: const Icon(Icons.workspace_premium_outlined, size: 18),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProductPlanPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildConfigCard(AppColors c) {
    return Container(
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r16),
        border: Border.all(color: c.cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            c,
            icon: Icons.cloud_outlined,
            title: TransactionUiText.apiConfigSection,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.sp16,
              0,
              AppTheme.sp16,
              AppTheme.sp16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppInput(
                  label: TransactionUiText.apiUrl,
                  controller: _apiUrlCtrl,
                  hint: TransactionUiText.apiUrlHint,
                  action: const AppInputAction.text(),
                ),
                const SizedBox(height: AppTheme.sp12),
                AppButton.outlined(
                  label: _isTestingApi
                      ? TransactionUiText.testing
                      : TransactionUiText.testApi,
                  icon: _isTestingApi
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  onPressed: _isTestingApi ? null : _testApi,
                ),
                if (_testApiMessage != null) ...[
                  const SizedBox(height: AppTheme.sp12),
                  _buildTestMessage(c),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestMessage(AppColors c) {
    final success = _testApiSuccess == true;
    final color = success ? c.incomeGreen : Theme.of(context).colorScheme.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.sp12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.r12),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        _testApiMessage!,
        style: TextStyle(
          fontFamily: _fontFamily,
          color: color,
          fontSize: 13,
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
          final isWide = box.maxWidth >= 560;
          final saveButton = AppButton.primary(
            label: TransactionUiText.save,
            icon: const Icon(Icons.save_rounded, size: 18),
            fullWidth: !isWide,
            onPressed: _saveConfig,
          );
          final cancelButton = AppButton.outlined(
            label: TransactionUiText.cancel,
            fullWidth: !isWide,
            onPressed: () => Navigator.of(context).pop(),
          );
          if (!isWide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                cancelButton,
                const SizedBox(height: AppTheme.sp8),
                saveButton,
              ],
            );
          }
          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(width: 160, child: cancelButton),
              const SizedBox(width: AppTheme.sp8),
              SizedBox(width: 160, child: saveButton),
            ],
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
}
