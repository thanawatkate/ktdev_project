import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/features/license/data/datasources/license_local_data_source.dart';
import 'package:saccm/features/license/data/datasources/license_remote_data_source.dart';
import 'package:saccm/features/license/product_tier.dart';
import 'package:saccm/widgets/widgets.dart';

/// หน้าผู้ให้บริการ — สร้าง/ยกเลิกรหัส (ต้องมี Admin Secret)
class LicenseAdminPage extends StatefulWidget {
  const LicenseAdminPage({super.key});

  @override
  State<LicenseAdminPage> createState() => _LicenseAdminPageState();
}

class _LicenseAdminPageState extends State<LicenseAdminPage> {
  static const String _fontFamily = 'Kanit';
  static const double _maxResponsiveFormWidth = 1440;

  final _local = LicenseLocalDataSource();
  final _remote = LicenseRemoteDataSource();
  final _secretCtrl = TextEditingController();
  final _schoolNameCtrl = TextEditingController();
  final _maxDevicesCtrl = TextEditingController(text: '5');
  final _daysCtrl = TextEditingController(text: '365');

  ProductTier _issueTier = ProductTier.offline;
  List<LicenseAdminRow> _rows = [];
  List<Map<String, dynamic>> _issueLogs = [];
  List<Map<String, dynamic>> _activationLogs = [];
  int _logTab = 0;
  String? _generatedKey;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSecret();
  }

  Future<void> _loadSecret() async {
    final s = await _local.getAdminSecret();
    if (s != null) {
      _secretCtrl.text = s;
      await _refreshList();
    }
  }

  @override
  void dispose() {
    _secretCtrl.dispose();
    _schoolNameCtrl.dispose();
    _maxDevicesCtrl.dispose();
    _daysCtrl.dispose();
    super.dispose();
  }

  String get _secret => _secretCtrl.text.trim();

  Future<void> _saveSecret() async {
    await _local.saveAdminSecret(_secret);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(TransactionUiText.saveConfigSuccess)),
      );
    }
  }

  Future<void> _refreshList() async {
    if (_secret.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _remote.listLicensesAdmin(_secret);
      final issueLogs = await _remote.listIssueLogsAdmin(_secret);
      final activationLogs = await _remote.listActivationLogsAdmin(_secret);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _issueLogs = issueLogs;
        _activationLogs = activationLogs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _generate() async {
    if (_secret.isEmpty || _schoolNameCtrl.text.trim().isEmpty) {
      setState(() => _error = TransactionUiText.fillRequiredFields);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _generatedKey = null;
    });
    try {
      final key = await _remote.generateLicenseAdmin(
        adminSecret: _secret,
        schoolName: _schoolNameCtrl.text.trim(),
        maxDevices: int.tryParse(_maxDevicesCtrl.text) ?? 5,
        expiresInDays: int.tryParse(_daysCtrl.text) ?? 365,
        productTier: _issueTier,
      );
      await _refreshList();
      if (!mounted) return;
      setState(() {
        _generatedKey = key;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _revoke(LicenseAdminRow row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmDialog(
        isDestructive: false,
        title: TransactionUiText.licenseAdminRevoke,
        message: '${row.schoolName}\n(${row.schoolCode})',
        confirmText: TransactionUiText.confirm,
        confirmColor: Theme.of(ctx).colorScheme.primary,
      ),
    );
    if (ok != true || _secret.isEmpty) return;

    setState(() => _loading = true);
    try {
      await _remote.revokeLicenseAdmin(
        adminSecret: _secret,
        schoolCode: row.schoolCode,
      );
      await _refreshList();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _kindLabel(String? kind) {
    switch (kind) {
      case 'online':
      case 'standard':
        return TransactionUiText.licenseAdminTierOnline;
      case 'offline':
        return TransactionUiText.licenseAdminTierOffline;
      default:
        return kind ?? '-';
    }
  }

  Widget _logList(List<Map<String, dynamic>> logs) {
    if (logs.isEmpty) {
      return const Center(
        child: Text('-', style: TextStyle(fontFamily: 'Kanit')),
      );
    }
    return ListView.builder(
      itemCount: logs.length,
      itemBuilder: (ctx, i) {
        final row = logs[i];
        final title = row['school_code']?.toString() ??
            row['school_name']?.toString() ??
            row['event']?.toString() ??
            '#${row['id']}';
        final sub = [
          row['event'],
          row['result'],
          row['platform'],
          ThaiDateFormatter.formatDateTime(row['created']),
        ].where((e) => e != null && '$e'.isNotEmpty).join(' · ');
        return ListTile(
          dense: true,
          title: Text(title,
              style: const TextStyle(fontFamily: 'Kanit', fontSize: 13)),
          subtitle: Text(sub,
              style: const TextStyle(fontFamily: 'Kanit', fontSize: 12)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          toolbarHeight: 52,
          title: Text(
            TransactionUiText.licenseAdminTitle,
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
          actions: [
            IconButton(
              onPressed: _loading ? null : _refreshList,
              icon: Icon(Icons.refresh_rounded, color: c.textSecondary),
              tooltip: TransactionUiText.retry,
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: c.cardBorder),
          ),
        ),
        body: SingleChildScrollView(
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
                    icon: Icons.admin_panel_settings_outlined,
                    iconColor: scheme.primary,
                    iconBgColor: c.iconBgIncome,
                    title: TransactionUiText.licenseAdminTitle,
                    subtitle: TransactionUiText.licenseAdminSubtitle,
                    quickHint: TransactionUiText.licenseAdminSecretHint,
                    hintAccentColor: scheme.primary,
                    hintBorderColor: c.cardBorder,
                    textPrimaryColor: c.textPrimary,
                    showQuickHint: false,
                  ),
                  const SizedBox(height: AppTheme.sp16),
                  AppInput(
                    label: TransactionUiText.licenseAdminSecretLabel,
                    controller: _secretCtrl,
                    hint: TransactionUiText.licenseAdminSecretHint,
                  ),
                  const SizedBox(height: 8),
                  AppButton.secondary(
                    label: TransactionUiText.save,
                    onPressed: _saveSecret,
                  ),
                  const Divider(height: 32),
                  AppInput(
                    label: TransactionUiText.licenseAdminSchoolName,
                    controller: _schoolNameCtrl,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AppInput(
                          label: TransactionUiText.licenseAdminMaxDevices,
                          controller: _maxDevicesCtrl,
                          action: const AppInputAction.number(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppInput(
                          label: TransactionUiText.licenseAdminDays,
                          controller: _daysCtrl,
                          action: const AppInputAction.number(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    TransactionUiText.licenseAdminProductTier,
                    style: const TextStyle(
                      fontFamily: 'Kanit',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text(
                            TransactionUiText.licenseAdminTierOffline),
                        selected: _issueTier == ProductTier.offline,
                        onSelected: (_) =>
                            setState(() => _issueTier = ProductTier.offline),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text(
                            TransactionUiText.licenseAdminTierOnline),
                        selected: _issueTier == ProductTier.online,
                        onSelected: (_) =>
                            setState(() => _issueTier = ProductTier.online),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppButton.primary(
                    label: TransactionUiText.licenseAdminGenerate,
                    isLoading: _loading,
                    onPressed: _generate,
                  ),
                  if (_generatedKey != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      TransactionUiText.licenseAdminGeneratedKey,
                      style: const TextStyle(
                        fontFamily: 'Kanit',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _generatedKey!,
                      style: const TextStyle(
                        fontFamily: 'Kanit',
                        fontSize: 18,
                        letterSpacing: 1.2,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _generatedKey!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('คัดลอกแล้ว')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('คัดลอก'),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        fontFamily: 'Kanit',
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'รายการ (${_rows.length})',
                    style: const TextStyle(
                      fontFamily: 'Kanit',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_loading && _rows.isEmpty)
                    const Center(child: CircularProgressIndicator())
                  else
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text(
                              TransactionUiText.licenseAdminIssueLogs),
                          selected: _logTab == 0,
                          onSelected: (_) => setState(() => _logTab = 0),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text(
                              TransactionUiText.licenseAdminActivationLogs),
                          selected: _logTab == 1,
                          onSelected: (_) => setState(() => _logTab = 1),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 220,
                    child: _logTab == 0
                        ? _logList(_issueLogs)
                        : _logList(_activationLogs),
                  ),
                  const SizedBox(height: 16),
                  ..._rows.map(
                    (r) => Card(
                      child: ListTile(
                        title: Text(r.schoolName),
                        subtitle: Text(
                          '${r.schoolCode} · ${_kindLabel(r.licenseKind)} · ${r.status} · ${r.devicesUsed}/${r.maxDevices} เครื่อง',
                          style: const TextStyle(fontFamily: 'Kanit'),
                        ),
                        trailing: r.status == 'revoked'
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.block_rounded),
                                tooltip: TransactionUiText.licenseAdminRevoke,
                                onPressed: () => _revoke(r),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
