import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/local_data_source/audit_log_local_data_source.dart';
import 'package:saccm/core/di/service_locator.dart';
import 'package:saccm/core/error/party_tax_id_duplicate_exception.dart';
import 'package:saccm/core/local_data_source/income_local_data_source.dart';
import 'package:saccm/features/income/data/repositories/income_repository_offline.dart'
    as income_repo;
import 'package:saccm/features/party/presentation/pages/party_audit_page.dart';
import 'package:saccm/features/party/presentation/widgets/party_detail_dialog.dart';
import 'package:saccm/features/party/presentation/widgets/party_filter_sheet.dart';
import 'package:saccm/features/party/presentation/widgets/party_form_sheet.dart';
import 'package:saccm/features/party/presentation/widgets/party_list_item_card.dart';
import 'package:saccm/widgets/widgets.dart';

class PartyManagementPage extends StatefulWidget {
  const PartyManagementPage({super.key});

  @override
  State<PartyManagementPage> createState() => _PartyManagementPageState();
}

class _PartyManagementPageState extends State<PartyManagementPage> {
  static const String _fontFamily = 'Kanit';
  static const double _maxResponsiveFormWidth = 1440;

  final AuditLogLocalDataSource _auditLogLocalDataSource =
      AuditLogLocalDataSource();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _taxIdController = TextEditingController();
  final TextEditingController _remarkController = TextEditingController();

  List<Map<String, dynamic>> _parties = [];
  bool _isLoading = false;
  int _busyDepth = 0;
  String _busyMessage = 'กำลังประมวลผล...';
  String _searchQuery = '';
  String _roleFilter = 'all';
  String _statusFilter = 'all';
  String _sortBy = 'active_then_name';
  bool _auditReady = false;
  String? _token;
  String? _actorId;
  String? _actorName;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (!mounted) return;
      setState(
          () => _searchQuery = _searchController.text.trim().toLowerCase());
    });
    _initAndLoad();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _taxIdController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _initAndLoad() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    _actorId = prefs.getString('userId');
    final token = (_token ?? '').trim();
    final fromToken =
        token.startsWith('local_') ? token.substring('local_'.length) : '';
    _actorName = (prefs.getString('last_username') ?? '').trim();
    if ((_actorName ?? '').isEmpty && fromToken.isNotEmpty) {
      _actorName = fromToken;
    }
    await _ensureAuditReady();
    await _loadParties();
  }

  Future<void> _ensureAuditReady() async {
    if (_auditReady) return;
    await _auditLogLocalDataSource.init();
    _auditReady = true;
  }

  Future<T> _runWithBusy<T>({
    required String message,
    required Future<T> Function() action,
  }) async {
    if (mounted) {
      setState(() {
        _busyDepth += 1;
        _busyMessage = message;
      });
    }
    try {
      return await action();
    } finally {
      if (mounted) {
        setState(() {
          _busyDepth = _busyDepth > 0 ? _busyDepth - 1 : 0;
        });
      }
    }
  }

  Future<void> _safeAuditLog({
    required String module,
    required String action,
    required String entityId,
    Map<String, dynamic>? payload,
  }) async {
    try {
      await _ensureAuditReady();
      await _auditLogLocalDataSource.logEvent(
        module: module,
        action: action,
        entityId: entityId,
        payload: payload,
      );
    } catch (_) {
      // ไม่ให้ audit ล้มเหลวทำให้ผู้ใช้เข้าใจว่าบันทึก API ไม่สำเร็จ
    }
  }

  /// อัปเดตตาราง `party` ใน SQLite ให้หน้ารายรับ/รายจ่ายใช้รายชื่อล่าสุดหลังแก้ที่เซิร์ฟเวอร์
  Future<void> _syncIncomePartyMasterCache() async {
    try {
      await ServiceLocator.instance
          .get<income_repo.IncomeRepository>()
          .refreshPartyMasterCacheFromServer();
    } catch (_) {}
  }

  Map<String, dynamic> _partyRowFromSql(Map<String, dynamic> e) {
    final active = e['isactive'] == 1 ||
        e['isactive'] == true ||
        e['isactive']?.toString() == '1';
    return {
      'id': e['id'],
      'name': e['name'],
      'role': (e['role'] ?? 'both').toString(),
      'phone': e['phone'],
      'taxid': e['taxid'],
      'remark': e['remark'],
      'isactive': active,
    };
  }

  Future<void> _loadPartiesFromLocalDb() async {
    final ds = ServiceLocator.instance.get<IncomeLocalDataSource>();
    final rows = await ds.db.query('party', orderBy: 'name COLLATE NOCASE ASC');
    if (!mounted) return;
    setState(() {
      _parties = rows.map(_partyRowFromSql).toList();
    });
  }

  /// อ่านรายการจาก SQLite ก่อน — แล้วซิงก์จากเซิร์ฟเวอร์เบื้องหลัง
  Future<void> _loadParties(
      {String busyMessage = 'กำลังโหลดข้อมูลผู้เกี่ยวข้อง...'}) async {
    setState(() => _isLoading = true);
    await _runWithBusy(
      message: busyMessage,
      action: () async {
        try {
          await _loadPartiesFromLocalDb();
          unawaited(() async {
            await _syncIncomePartyMasterCache();
            if (mounted) await _loadPartiesFromLocalDb();
          }());
        } catch (_) {
          if (!mounted) return;
          _showSnack('ไม่สามารถโหลดรายชื่อผู้เกี่ยวข้องจากเครื่องได้');
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      },
    );
  }

  List<Map<String, dynamic>> get _filteredParties {
    final roleFiltered = _parties.where((p) {
      if (_roleFilter == 'all') return true;
      return (p['role'] ?? '').toString() == _roleFilter;
    }).toList();

    final statusFiltered = roleFiltered.where((p) {
      if (_statusFilter == 'all') return true;
      final isActive =
          p['isactive'] == true || p['isactive']?.toString() == '1';
      if (_statusFilter == 'active') return isActive;
      return !isActive;
    }).toList();

    final searched = _searchQuery.isEmpty
        ? statusFiltered
        : statusFiltered.where((p) {
            final name = (p['name'] ?? '').toString().toLowerCase();
            final role = (p['role'] ?? '').toString().toLowerCase();
            final phone = (p['phone'] ?? '').toString().toLowerCase();
            final taxid = (p['taxid'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery) ||
                role.contains(_searchQuery) ||
                phone.contains(_searchQuery) ||
                taxid.contains(_searchQuery);
          }).toList();

    final result = [...searched];
    int activeCompare(Map<String, dynamic> a, Map<String, dynamic> b) {
      final aActive = a['isactive'] == true || a['isactive']?.toString() == '1';
      final bActive = b['isactive'] == true || b['isactive']?.toString() == '1';
      if (aActive == bActive) return 0;
      return aActive ? -1 : 1;
    }

    int nameCompare(Map<String, dynamic> a, Map<String, dynamic> b) {
      final an = (a['name'] ?? '').toString().toLowerCase();
      final bn = (b['name'] ?? '').toString().toLowerCase();
      return an.compareTo(bn);
    }

    int idDescCompare(Map<String, dynamic> a, Map<String, dynamic> b) {
      final ai = int.tryParse((a['id'] ?? '0').toString()) ?? 0;
      final bi = int.tryParse((b['id'] ?? '0').toString()) ?? 0;
      return bi.compareTo(ai);
    }

    switch (_sortBy) {
      case 'name_asc':
        result.sort(nameCompare);
        break;
      case 'latest':
        result.sort(idDescCompare);
        break;
      default:
        result.sort((a, b) {
          final c = activeCompare(a, b);
          if (c != 0) return c;
          return nameCompare(a, b);
        });
        break;
    }
    return result;
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'payer':
        return 'ผู้จ่าย';
      case 'receiver':
        return 'ผู้รับ';
      default:
        return 'ทั้งสองฝั่ง';
    }
  }

  String _statusLabel(bool isActive) => isActive ? 'ใช้งาน' : 'ปิดใช้งาน';

  Map<String, dynamic>? _findDuplicateParty({
    required String name,
    required String taxId,
    String? excludeId,
  }) {
    final normalizedName = name.trim().toLowerCase();
    final normalizedTaxId = taxId.trim();
    if (normalizedName.isEmpty && normalizedTaxId.isEmpty) return null;
    for (final party in _parties) {
      final partyId = (party['id'] ?? '').toString();
      if (excludeId != null && partyId == excludeId) continue;
      final partyName = (party['name'] ?? '').toString().trim().toLowerCase();
      final partyTaxId = (party['taxid'] ?? '').toString().trim();
      final nameDuplicated =
          normalizedName.isNotEmpty && partyName == normalizedName;
      final taxIdDuplicated =
          normalizedTaxId.isNotEmpty && partyTaxId == normalizedTaxId;
      if (nameDuplicated || taxIdDuplicated) {
        return party;
      }
    }
    return null;
  }

  Future<void> _showPartyDetail(Map<String, dynamic> row) async {
    final isActive =
        row['isactive'] == true || row['isactive']?.toString() == '1';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PartyDetailDialog(
        row: row,
        roleLabel: _roleLabel((row['role'] ?? 'both').toString()),
        statusLabel: _statusLabel(isActive),
        onDelete: () {
          Navigator.pop(ctx);
          _confirmDeleteParty(row);
        },
        onOpenHistory: () {
          Navigator.pop(ctx);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PartyAuditPage(
                partyId: row['id']?.toString(),
                partyName: row['name']?.toString(),
              ),
            ),
          );
        },
        onEdit: () {
          Navigator.pop(ctx);
          _openPartyDialog(existing: row);
        },
      ),
    );
  }

  Future<void> _openPartyDialog({Map<String, dynamic>? existing}) async {
    _nameController.text = existing?['name']?.toString() ?? '';
    _phoneController.text = existing?['phone']?.toString() ?? '';
    _taxIdController.text = existing?['taxid']?.toString() ?? '';
    _remarkController.text = existing?['remark']?.toString() ?? '';
    final isEdit = existing != null;
    final role = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (_) => PartyFormSheet(
        isEdit: isEdit,
        initialRole: (existing?['role']?.toString() ?? 'both').toLowerCase(),
        nameController: _nameController,
        phoneController: _phoneController,
        taxIdController: _taxIdController,
        remarkController: _remarkController,
        duplicateMessageProvider: (name, taxId) {
          final excludeId = isEdit ? existing['id']?.toString() : null;
          final duplicated = _findDuplicateParty(
            name: name,
            taxId: taxId,
            excludeId: excludeId,
          );
          if (duplicated == null) return null;
          final duplicatedName = (duplicated['name'] ?? '').toString().trim();
          return 'พบข้อมูลซ้ำกับ "$duplicatedName" ในระบบ กรุณาตรวจสอบก่อนบันทึก';
        },
      ),
    );

    if (role == null || role.isEmpty) return;
    final selectedRole = role;
    if ((_token ?? '').isEmpty) {
      _showSnack('ไม่พบ token สำหรับบันทึกข้อมูล');
      return;
    }

    try {
      await _runWithBusy(
        message: isEdit
            ? 'กำลังบันทึกการแก้ไข...'
            : 'กำลังบันทึกข้อมูลผู้เกี่ยวข้อง...',
        action: () async {
          final repo =
              ServiceLocator.instance.get<income_repo.IncomeRepository>();
          final actorId = int.tryParse((_actorId ?? '').trim());
          final actorName =
              (_actorName ?? '').trim().isEmpty ? null : _actorName?.trim();
          if (isEdit) {
            await repo.updatePartyOfflineFirst(
              partyId: existing['id'].toString(),
              token: _token!,
              actorId: actorId,
              actorName: actorName,
              name: _nameController.text.trim(),
              role: selectedRole,
              phone: _phoneController.text.trim(),
              taxid: _taxIdController.text.trim(),
              remark: _remarkController.text.trim(),
            );
            await _safeAuditLog(
              module: 'party',
              action: 'update_party',
              entityId: existing['id'].toString(),
              payload: {
                'name': _nameController.text.trim(),
                'role': selectedRole,
                'phone': _phoneController.text.trim(),
                'taxid': _taxIdController.text.trim(),
              },
            );
          } else {
            final localId = await repo.createPartyOfflineFirst(
              token: _token!,
              actorId: actorId,
              actorName: actorName,
              name: _nameController.text.trim(),
              role: selectedRole,
              phone: _phoneController.text.trim(),
              taxid: _taxIdController.text.trim(),
              remark: _remarkController.text.trim(),
            );
            await _safeAuditLog(
              module: 'party',
              action: 'create_party',
              entityId: localId,
              payload: {
                'name': _nameController.text.trim(),
                'role': selectedRole,
                'phone': _phoneController.text.trim(),
                'taxid': _taxIdController.text.trim(),
              },
            );
          }
          _showSnack('บันทึกในเครื่องแล้ว จะส่งขึ้นเซิร์ฟเวอร์เมื่อออนไลน์');
          await _loadParties(busyMessage: 'กำลังรีเฟรชรายการ...');
        },
      );
    } on PartyTaxIdDuplicateException catch (e) {
      _showSnack(e.toString());
    } catch (_) {
      _showSnack('บันทึกข้อมูลไม่สำเร็จ');
    }
  }

  Future<void> _confirmDeleteParty(Map<String, dynamic> row) async {
    final name = (row['name'] ?? '').toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: 'ลบผู้เกี่ยวข้อง',
        message: 'ต้องการลบ "$name" ออกจากรายการหรือไม่\n'
            'รายการรับ/จ่ายเดิมจะคงชื่อในบันทึก แต่จะไม่ชี้ผู้เกี่ยวข้องนี้อีก',
        confirmText: 'ลบ',
      ),
    );
    if (ok != true || !mounted) return;
    await _deleteParty(row);
  }

  Future<void> _deleteParty(Map<String, dynamic> row) async {
    if ((_token ?? '').isEmpty) {
      _showSnack('ไม่พบ token สำหรับบันทึกข้อมูล');
      return;
    }
    try {
      await _runWithBusy(
        message: 'กำลังลบข้อมูลผู้เกี่ยวข้อง...',
        action: () async {
          final repo =
              ServiceLocator.instance.get<income_repo.IncomeRepository>();
          await repo.deletePartyOfflineFirst(
            partyId: row['id'].toString(),
            token: _token!,
            actorId: int.tryParse((_actorId ?? '').trim()),
            actorName:
                (_actorName ?? '').trim().isEmpty ? null : _actorName?.trim(),
          );
          await _safeAuditLog(
            module: 'party',
            action: 'delete_party',
            entityId: row['id'].toString(),
            payload: {'name': (row['name'] ?? '').toString()},
          );
          _showSnack(
              'ลบในเครื่องแล้ว จะส่งขึ้นเซิร์ฟเวอร์เมื่อออนไลน์ (ถ้ามีบนเซิร์ฟเวอร์)');
          await _loadParties(busyMessage: 'กำลังรีเฟรชรายการ...');
          unawaited(_syncIncomePartyMasterCache());
        },
      );
    } catch (_) {
      _showSnack('ลบข้อมูลไม่สำเร็จ');
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> row, bool isActive) async {
    if ((_token ?? '').isEmpty) {
      _showSnack('ไม่พบ token สำหรับบันทึกข้อมูล');
      return;
    }
    try {
      await _runWithBusy(
        message:
            isActive ? 'กำลังเปิดใช้งานรายการ...' : 'กำลังปิดใช้งานรายการ...',
        action: () async {
          final repo =
              ServiceLocator.instance.get<income_repo.IncomeRepository>();
          await repo.setPartyActiveOfflineFirst(
            partyId: row['id'].toString(),
            token: _token!,
            actorId: int.tryParse((_actorId ?? '').trim()),
            actorName:
                (_actorName ?? '').trim().isEmpty ? null : _actorName?.trim(),
            isActive: isActive,
          );
          await _safeAuditLog(
            module: 'party',
            action: isActive ? 'enable_party' : 'disable_party',
            entityId: row['id'].toString(),
            payload: {
              'name': (row['name'] ?? '').toString(),
              'isActive': isActive,
            },
          );
          await _loadParties(busyMessage: 'กำลังรีเฟรชรายการ...');
          unawaited(_syncIncomePartyMasterCache());
        },
      );
    } catch (_) {
      _showSnack('อัปเดตสถานะไม่สำเร็จ');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showFiltersModal() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PartyFilterSheet(
        roleFilter: _roleFilter,
        sortBy: _sortBy,
        statusFilter: _statusFilter,
        onRoleChanged: (value) => setState(() => _roleFilter = value),
        onSortChanged: (value) => setState(() => _sortBy = value),
        onStatusChanged: (value) => setState(() => _statusFilter = value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isBusy = _busyDepth > 0;

    return AppBusyBackdrop(
      isBusy: isBusy,
      message: _busyMessage,
      child: SafeArea(
        child: Scaffold(
          backgroundColor: c.background,
          appBar: AppBar(
            toolbarHeight: 52,
            title: Text(
              TransactionUiText.partyPayeePayerTitle,
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
                icon: Icon(Icons.tune_rounded, color: c.textSecondary),
                tooltip: TransactionUiText.partyManagementFilterTooltip,
                onPressed: isBusy ? null : _showFiltersModal,
              ),
              IconButton(
                icon: Icon(Icons.history_rounded, color: c.textSecondary),
                tooltip: TransactionUiText.partyManagementAuditTooltip,
                onPressed: isBusy
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PartyAuditPage(),
                          ),
                        );
                      },
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(height: 1, color: c.cardBorder),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: isBusy ? null : () => _openPartyDialog(),
            backgroundColor: c.navy,
            foregroundColor: Colors.white,
            elevation: 2,
            icon: const Icon(Icons.add, size: 20),
            label: const Text(
              TransactionUiText.partyManagementAddAction,
              style: TextStyle(
                fontFamily: _fontFamily,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: _maxResponsiveFormWidth),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppTheme.sp12),
                    child: AppInput(
                      hint: TransactionUiText.partyManagementSearchHint,
                      controller: _searchController,
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                  ),
                  Expanded(
                    child: _isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          )
                        : _filteredParties.isEmpty
                            ? Center(
                                child: Text(
                                  TransactionUiText.partyManagementEmpty,
                                  style: TextStyle(
                                    fontFamily: _fontFamily,
                                    color: c.textSecondary,
                                  ),
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _loadParties,
                                child: ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    4,
                                    12,
                                    12,
                                  ),
                                  itemCount: _filteredParties.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (_, index) {
                                    final row = _filteredParties[index];
                                    return PartyListItemCard(
                                      row: row,
                                      roleLabel: _roleLabel(
                                        (row['role'] ?? 'both').toString(),
                                      ),
                                      onTap: () => _showPartyDetail(row),
                                      onToggleActive: (v) =>
                                          _toggleActive(row, v),
                                      onEdit: () =>
                                          _openPartyDialog(existing: row),
                                      onDelete: () => _confirmDeleteParty(row),
                                    );
                                  },
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
