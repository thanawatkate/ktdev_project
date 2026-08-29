import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:saccm/config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/core/di/service_locator.dart';
import 'package:saccm/core/local_data_source/app_database.dart';
import 'package:saccm/core/local_data_source/party_audit_materialized_store.dart';
import 'package:saccm/core/platform/local_file_ops.dart';
import 'package:saccm/core/utils/thai_date_formatter.dart';
import 'package:saccm/features/setting/data/datasources/school_profile_local_data_source.dart';
import 'package:saccm/features/setting/data/school_profile_csv_header.dart';
import 'package:saccm/features/setting/domain/entities/school_profile.dart';
import 'package:saccm/widgets/feedback/app_busy_backdrop.dart';
import 'package:saccm/widgets/dialog/confirm_dialog.dart';
import 'package:saccm/widgets/input/app_dropdown_field.dart';
import 'package:saccm/widgets/input/app_input.dart';
import 'package:saccm/widgets/sheet/adaptive_content_sheet.dart';

class PartyAuditPage extends StatefulWidget {
  const PartyAuditPage({super.key, this.partyId, this.partyName});

  final String? partyId;
  final String? partyName;

  @override
  State<PartyAuditPage> createState() => _PartyAuditPageState();
}

class _PartyAuditPageState extends State<PartyAuditPage> {
  static const int _pageSize = 50;
  final Dio _dio = ServiceLocator.instance.get<Dio>();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  String _busyMessage = 'กำลังโหลดประวัติการแก้ไข...';
  bool _isLoadingMore = false;
  int _page = 1;
  int _totalPages = 1;
  int _totalRecords = 0;
  final List<Map<String, dynamic>> _rows = [];
  String _actionFilter = 'all';
  final TextEditingController _userFilterCtrl = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;
  String? _lastExportPath;
  String _rangePreset = 'custom';
  String _changeFilter = 'all';
  bool _isExporting = false;
  bool _isExportingJson = false;
  String _lastExportScope = 'all';
  String _lastExportFormat = 'csv';
  bool _rememberExportPrefs = true;
  bool _didShowExportDefaultToast = false;
  String _presetAudience = 'all';
  String _activePresetLabel = 'กำหนดเอง';
  List<Map<String, dynamic>> _savedPresets = const [];

  static const String _prefExportScopeKey = 'party_audit_export_scope';
  static const String _prefExportFormatKey = 'party_audit_export_format';
  static const String _prefRememberExportKey = 'party_audit_remember_export';
  static const String _prefOnboardedKey = 'party_audit_onboarded';
  static const String _prefPresetAudienceKey = 'party_audit_preset_audience';
  static const String _prefSavedPresetsKey = 'party_audit_saved_presets';

  String _safeFilePart(String input) {
    final normalized = input.trim().replaceAll(RegExp(r'\\s+'), '_');
    final safe = normalized.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '');
    return safe.isEmpty ? 'all' : safe;
  }

  String _datePart(DateTime? d) {
    if (d == null) return 'all';
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}$mm$dd';
  }

  String _buildExportFileName(String extension) {
    final party = _safeFilePart(widget.partyId ?? 'all-party');
    final from = _datePart(_fromDate);
    final to = _datePart(_toDate);
    final action = _safeFilePart(_actionFilter);
    final change = _safeFilePart(_changeFilter);
    final user = _safeFilePart(
        _userFilterCtrl.text.isEmpty ? 'all-user' : _userFilterCtrl.text);
    return 'party_audit_${party}_$from-${to}_${action}_${change}_$user.$extension';
  }

  List<Map<String, dynamic>> _visibleRows() {
    return _changeFilter == 'isactive'
        ? _rows.where(_isIsActiveChange).toList()
        : _rows;
  }

  Future<void> _loadExportPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool(_prefRememberExportKey) ?? true;
    final loadedScope = prefs.getString(_prefExportScopeKey) ?? 'all';
    final loadedFormat = prefs.getString(_prefExportFormatKey) ?? 'csv';
    final loadedAudience = prefs.getString(_prefPresetAudienceKey) ?? 'all';
    if (!mounted) return;
    setState(() {
      _rememberExportPrefs = remember;
      _lastExportScope = remember ? loadedScope : 'all';
      _lastExportFormat = remember ? loadedFormat : 'csv';
      _presetAudience = loadedAudience;
    });

    if (_rememberExportPrefs && !_didShowExportDefaultToast && mounted) {
      _didShowExportDefaultToast = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final mode = _lastExportScope == 'all'
            ? 'ทั้งหมดตามตัวกรอง'
            : 'เฉพาะที่แสดงอยู่';
        final fmt = _lastExportFormat.toUpperCase();
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('ค่าเริ่มต้นส่งออก: $fmt/$mode')),
          );
      });
    }
  }

  Future<void> _savePresetAudience(String audience) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefPresetAudienceKey, audience);
    if (!mounted) return;
    setState(() => _presetAudience = audience);
  }

  Future<void> _loadSavedPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefSavedPresetsKey);
    if (raw == null || raw.trim().isEmpty) {
      if (!mounted) return;
      setState(() => _savedPresets = const []);
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final parsed = decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) => (e['name'] ?? '').toString().trim().isNotEmpty)
          .toList()
        ..sort(_sortSavedPresetByRecent);
      if (!mounted) return;
      setState(() => _savedPresets = parsed);
    } catch (_) {
      // Ignore corrupted local preset data and keep app usable.
    }
  }

  int _sortSavedPresetByRecent(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aLastUsed = DateTime.tryParse((a['lastUsedAt'] ?? '').toString());
    final bLastUsed = DateTime.tryParse((b['lastUsedAt'] ?? '').toString());
    if (aLastUsed != null && bLastUsed != null) {
      return bLastUsed.compareTo(aLastUsed);
    }
    if (aLastUsed != null) return -1;
    if (bLastUsed != null) return 1;

    final aUpdated = DateTime.tryParse((a['updatedAt'] ?? '').toString());
    final bUpdated = DateTime.tryParse((b['updatedAt'] ?? '').toString());
    if (aUpdated != null && bUpdated != null) {
      return bUpdated.compareTo(aUpdated);
    }
    if (aUpdated != null) return -1;
    if (bUpdated != null) return 1;
    return 0;
  }

  String _formatThaiDateTime(dynamic raw) {
    if (raw == null || raw.toString().trim().isEmpty) return '-';
    try {
      final dt = DateTime.tryParse(raw.toString());
      if (dt == null) return '-';
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dtDate = DateTime(dt.year, dt.month, dt.day);

      if (dtDate == today) {
        return 'วันนี้ ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      final yesterday = today.subtract(const Duration(days: 1));
      if (dtDate == yesterday) {
        return 'เมื่อวาน ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }

      final diff = today.difference(dtDate).inDays;
      if (diff < 7) {
        return '$diff วันที่แล้ว';
      }

      return ThaiDateFormatter.formatDateTime(dt);
    } catch (_) {
      return '-';
    }
  }

  Future<void> _persistSavedPresets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefSavedPresetsKey, jsonEncode(_savedPresets));
  }

  Map<String, dynamic> _buildCurrentPresetPayload(String name) {
    return {
      'name': name,
      'action': _actionFilter,
      'change': _changeFilter,
      'user': _userFilterCtrl.text.trim(),
      'range': _rangePreset,
      'from': _fromDate?.toIso8601String().substring(0, 10),
      'to': _toDate?.toIso8601String().substring(0, 10),
      'audience': _presetAudience,
      'exportScope': _lastExportScope,
      'exportFormat': _lastExportFormat,
      'updatedAt': DateTime.now().toIso8601String(),
      'lastUsedAt': DateTime.now().toIso8601String(),
    };
  }

  DateTime? _parseDateOnly(dynamic input) {
    if (input == null) return null;
    final text = input.toString().trim();
    if (text.isEmpty) return null;
    try {
      return DateTime.parse(text);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _promptTextSheet({
    required String title,
    required String label,
    String? hint,
    String? initialValue,
    IconData? prefixIcon,
    String confirmLabel = 'บันทึก',
    int minLines = 1,
    int maxLines = 1,
  }) async {
    final ctrl = TextEditingController(text: initialValue);
    try {
      return await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        showDragHandle: false,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => SafeArea(
          child: AdaptiveContentSheet(
            title: title,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                AppTheme.sp16,
                0,
                AppTheme.sp16,
                MediaQuery.viewInsetsOf(sheetContext).bottom + AppTheme.sp16,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppInput(
                      controller: ctrl,
                      label: label,
                      hint: hint,
                      minLines: minLines,
                      maxLines: maxLines,
                      prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
                      textInputAction: maxLines > 1
                          ? TextInputAction.newline
                          : TextInputAction.done,
                      onSubmitted: maxLines > 1
                          ? null
                          : (_) =>
                              Navigator.pop(sheetContext, ctrl.text.trim()),
                    ),
                    const SizedBox(height: AppTheme.sp12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text('ยกเลิก'),
                        ),
                        const SizedBox(width: AppTheme.sp8),
                        FilledButton(
                          onPressed: () =>
                              Navigator.pop(sheetContext, ctrl.text.trim()),
                          child: Text(confirmLabel),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } finally {
      ctrl.dispose();
    }
  }

  Future<void> _saveCurrentAsPreset() async {
    final name = await _promptTextSheet(
      title: 'บันทึก Preset ปัจจุบัน',
      label: 'ชื่อ Preset',
      hint: 'เช่น ตรวจย้อนหลังรายเดือน',
      prefixIcon: Icons.bookmark_add_rounded,
    );

    if (!mounted) return;
    final presetName = (name ?? '').trim();
    if (presetName.isEmpty) return;

    final payload = _buildCurrentPresetPayload(presetName);
    final idx = _savedPresets
        .indexWhere((p) => (p['name'] ?? '').toString() == presetName);
    final next = [..._savedPresets];
    if (idx >= 0) {
      next[idx] = payload;
    } else {
      next.insert(0, payload);
    }
    if (next.length > 20) {
      next.removeRange(20, next.length);
    }
    next.sort(_sortSavedPresetByRecent);

    setState(() {
      _savedPresets = next;
      _activePresetLabel = presetName;
    });
    await _persistSavedPresets();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('บันทึก Preset: $presetName')));
  }

  Future<void> _applySavedPreset(Map<String, dynamic> preset) async {
    final name = (preset['name'] ?? '').toString().trim();
    if (name.isEmpty) return;

    final from = _parseDateOnly(preset['from']);
    final to = _parseDateOnly(preset['to']);
    final range = (preset['range'] ?? 'custom').toString();

    setState(() {
      _actionFilter = (preset['action'] ?? 'all').toString();
      _changeFilter = (preset['change'] ?? 'all').toString();
      _userFilterCtrl.text = (preset['user'] ?? '').toString();
      _rangePreset = range;
      _fromDate = from;
      _toDate = to;
      _activePresetLabel = name;
    });

    final audience = (preset['audience'] ?? 'all').toString();
    if (audience == 'all' || audience == 'general' || audience == 'auditor') {
      await _savePresetAudience(audience);
    }

    final exportScope = (preset['exportScope'] ?? '').toString();
    final exportFormat = (preset['exportFormat'] ?? '').toString();
    if ((exportScope == 'all' || exportScope == 'visible') &&
        (exportFormat == 'csv' || exportFormat == 'json')) {
      await _saveExportPrefs(scope: exportScope, format: exportFormat);
    }

    await _loadFirstPage();

    final idx =
        _savedPresets.indexWhere((p) => (p['name'] ?? '').toString() == name);
    if (idx >= 0) {
      final updated = Map<String, dynamic>.from(_savedPresets[idx]);
      updated['lastUsedAt'] = DateTime.now().toIso8601String();
      final next = [..._savedPresets];
      next[idx] = updated;
      next.sort(_sortSavedPresetByRecent);
      setState(() => _savedPresets = next);
      await _persistSavedPresets();
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('ใช้งาน Preset: $name')));
  }

  Future<void> _renameSavedPreset(Map<String, dynamic> preset) async {
    final oldName = (preset['name'] ?? '').toString();
    if (oldName.isEmpty) return;
    final newName = await _promptTextSheet(
      title: 'เปลี่ยนชื่อ Preset',
      label: 'ชื่อใหม่',
      initialValue: oldName,
      prefixIcon: Icons.drive_file_rename_outline_rounded,
    );
    if (!mounted) return;
    final value = (newName ?? '').trim();
    if (value.isEmpty || value == oldName) return;

    final oldIdx = _savedPresets
        .indexWhere((p) => (p['name'] ?? '').toString() == oldName);
    if (oldIdx < 0) return;
    final next = [..._savedPresets];
    final updated = Map<String, dynamic>.from(next[oldIdx]);
    updated['name'] = value;
    updated['updatedAt'] = DateTime.now().toIso8601String();

    final conflictIdx =
        next.indexWhere((p) => (p['name'] ?? '').toString() == value);
    if (conflictIdx >= 0 && conflictIdx != oldIdx) {
      next.removeAt(conflictIdx);
      if (conflictIdx < oldIdx) {
        next[oldIdx - 1] = updated;
      } else {
        next[oldIdx] = updated;
      }
    } else {
      next[oldIdx] = updated;
    }
    next.sort(_sortSavedPresetByRecent);
    setState(() {
      _savedPresets = next;
      if (_activePresetLabel == oldName) {
        _activePresetLabel = value;
      }
    });
    await _persistSavedPresets();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text('เปลี่ยนชื่อ Preset เป็น: $value')));
  }

  Future<void> _duplicateSavedPreset(Map<String, dynamic> preset) async {
    final baseName = (preset['name'] ?? '').toString().trim();
    if (baseName.isEmpty) return;
    final dupName = await _promptTextSheet(
      title: 'คัดลอก Preset',
      label: 'ชื่อ Preset ใหม่',
      initialValue: '$baseName (copy)',
      prefixIcon: Icons.copy_rounded,
      confirmLabel: 'คัดลอก',
    );
    if (!mounted) return;
    final name = (dupName ?? '').trim();
    if (name.isEmpty) return;

    final copy = Map<String, dynamic>.from(preset);
    copy['name'] = name;
    copy['updatedAt'] = DateTime.now().toIso8601String();
    copy['lastUsedAt'] = DateTime.now().toIso8601String();

    final next = [..._savedPresets];
    final conflictIdx =
        next.indexWhere((p) => (p['name'] ?? '').toString() == name);
    if (conflictIdx >= 0) {
      next[conflictIdx] = copy;
    } else {
      next.insert(0, copy);
    }
    if (next.length > 20) {
      next.removeRange(20, next.length);
    }
    next.sort(_sortSavedPresetByRecent);
    setState(() => _savedPresets = next);
    await _persistSavedPresets();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('คัดลอก Preset เป็น: $name')));
  }

  Future<void> _exportSavedPresetsJson() async {
    final prettyJson =
        const JsonEncoder.withIndent('  ').convert(_savedPresets);
    if (kIsWeb) {
      await Clipboard.setData(ClipboardData(text: prettyJson));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('คัดลอก Preset JSON ลงคลิปบอร์ดแล้ว')));
      return;
    }

    final file = await writeTextFileToDocuments(
      filename:
          'party_audit_presets_${DateTime.now().millisecondsSinceEpoch}.json',
      content: prettyJson,
    );
    if (file == null) return;
    if (!mounted) return;
    setState(() => _lastExportPath = file.path);
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text('บันทึกไฟล์ Preset แล้ว: ${file.path}')));
  }

  Future<void> _importSavedPresetsJsonDialog() async {
    final raw = await _promptTextSheet(
      title: 'Import Preset JSON',
      label: 'วาง JSON ที่นี่',
      hint: '[{"name":"..."}]',
      confirmLabel: 'นำเข้า',
      minLines: 10,
      maxLines: 18,
    );
    if (!mounted) return;
    final jsonText = (raw ?? '').trim();
    if (jsonText.isEmpty) return;

    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is! List) {
        throw const FormatException('not list');
      }
      final imported = decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) => (e['name'] ?? '').toString().trim().isNotEmpty)
          .toList();

      final merged = <String, Map<String, dynamic>>{};
      for (final p in _savedPresets) {
        final name = (p['name'] ?? '').toString();
        if (name.isEmpty) continue;
        merged[name] = p;
      }
      for (final p in imported) {
        p['updatedAt'] = DateTime.now().toIso8601String();
        p['lastUsedAt'] = p['lastUsedAt'] ?? DateTime.now().toIso8601String();
        final name = (p['name'] ?? '').toString();
        if (name.isEmpty) continue;
        merged[name] = p;
      }

      final next = merged.values.toList()..sort(_sortSavedPresetByRecent);
      if (next.length > 20) {
        next.removeRange(20, next.length);
      }
      setState(() => _savedPresets = next);
      await _persistSavedPresets();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text('นำเข้า Preset แล้ว ${imported.length} รายการ')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('รูปแบบ JSON ไม่ถูกต้อง')));
    }
  }

  Future<void> _deleteSavedPreset(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: 'ยืนยันการลบ Preset',
        message: 'ต้องการลบ Preset "$name" หรือไม่',
        confirmText: 'ลบ',
      ),
    );
    if (confirmed != true) return;

    final next = _savedPresets
        .where((p) => (p['name'] ?? '').toString() != name)
        .toList();
    setState(() {
      _savedPresets = next;
      if (_activePresetLabel == name) {
        _activePresetLabel = 'กำหนดเอง';
      }
    });
    await _persistSavedPresets();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('ลบ Preset: $name')));
  }

  Future<void> _showSavedPresetManager() async {
    String searchQuery = '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AdaptiveContentSheet(
        child: StatefulBuilder(
          builder: (ctx, setModalState) => SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preset ที่บันทึก (${_savedPresets.length})',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _exportSavedPresetsJson,
                          icon: const Icon(Icons.ios_share_rounded),
                          label: const Text('Export JSON'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _importSavedPresetsJsonDialog,
                          icon: const Icon(Icons.upload_file_rounded),
                          label: const Text('Import JSON'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'ค้นหา Preset',
                        prefixIcon: Icon(Icons.search_rounded),
                        isDense: true,
                      ),
                      onChanged: (v) => setModalState(
                          () => searchQuery = v.trim().toLowerCase()),
                    ),
                    const SizedBox(height: 8),
                    if (_savedPresets.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8, bottom: 4),
                        child: Text('ยังไม่มี Preset ที่บันทึก'),
                      ),
                    if (_savedPresets.isNotEmpty)
                      ..._savedPresets.where((p) {
                        final name = (p['name'] ?? '').toString().toLowerCase();
                        final user = (p['user'] ?? '').toString().toLowerCase();
                        final action =
                            (p['action'] ?? '').toString().toLowerCase();
                        return name.contains(searchQuery) ||
                            user.contains(searchQuery) ||
                            action.contains(searchQuery);
                      }).map((p) {
                        final name = (p['name'] ?? '').toString();
                        final user = (p['user'] ?? '').toString();
                        final action = (p['action'] ?? 'all').toString();
                        final lastUsed = _formatThaiDateTime(p['lastUsedAt']);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.bookmark_rounded),
                          title: Text(name),
                          subtitle: Text(
                            'Action: $action • ผู้กระทำ: ${user.isEmpty ? 'ทั้งหมด' : user}${lastUsed == '-' ? '' : ' • ล่าสุด: $lastUsed'}',
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'rename') {
                                _renameSavedPreset(p);
                              } else if (value == 'duplicate') {
                                _duplicateSavedPreset(p);
                              } else if (value == 'delete') {
                                _deleteSavedPreset(name);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'rename',
                                child: Text('เปลี่ยนชื่อ'),
                              ),
                              PopupMenuItem(
                                value: 'duplicate',
                                child: Text('คัดลอก'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('ลบ'),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            _applySavedPreset(p);
                          },
                        );
                      }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveExportPrefs(
      {required String scope, required String format}) async {
    if (!_rememberExportPrefs) {
      if (!mounted) return;
      setState(() {
        _lastExportScope = scope;
        _lastExportFormat = format;
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefExportScopeKey, scope);
    await prefs.setString(_prefExportFormatKey, format);
    if (!mounted) return;
    setState(() {
      _lastExportScope = scope;
      _lastExportFormat = format;
    });
  }

  Future<void> _setRememberExportPrefs(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefRememberExportKey, value);
    if (!mounted) return;
    setState(() {
      _rememberExportPrefs = value;
      if (!value) {
        _lastExportScope = 'all';
        _lastExportFormat = 'csv';
      }
    });
    if (!value) {
      await prefs.remove(_prefExportScopeKey);
      await prefs.remove(_prefExportFormatKey);
    }
  }

  Future<bool?> _askExportAll(String formatLabel) async {
    final defaultAll = _lastExportScope == 'all';
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AdaptiveContentSheet(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ส่งออก $formatLabel',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  'เลือกขอบเขตข้อมูลที่ต้องการส่งออก',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.of(ctx).textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.visibility_rounded,
                    color: defaultAll ? null : Colors.green,
                  ),
                  title: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('เฉพาะที่แสดงอยู่'),
                      SizedBox(width: 6),
                      Tooltip(
                        message: 'ส่งออกเฉพาะข้อมูลที่โหลดอยู่ในหน้าปัจจุบัน',
                        child: Icon(Icons.help_outline_rounded, size: 16),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    defaultAll
                        ? 'ส่งออกเฉพาะรายการที่โหลดอยู่ในหน้าปัจจุบัน'
                        : 'ค่าเริ่มต้นล่าสุด',
                  ),
                  trailing: defaultAll
                      ? null
                      : const Icon(Icons.check_circle_rounded,
                          color: Colors.green),
                  onTap: () => Navigator.pop(ctx, false),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.all_inbox_rounded,
                    color: defaultAll ? Colors.green : null,
                  ),
                  title: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('ทั้งหมดตามตัวกรอง'),
                      SizedBox(width: 6),
                      Tooltip(
                        message:
                            'ดึงข้อมูลทุกหน้าจากเซิร์ฟเวอร์ตามตัวกรองที่ตั้งไว้',
                        child: Icon(Icons.help_outline_rounded, size: 16),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    defaultAll
                        ? 'ค่าเริ่มต้นล่าสุด'
                        : 'ดึงข้อมูลทุกหน้าจากเซิร์ฟเวอร์ตามตัวกรองปัจจุบัน',
                  ),
                  trailing: defaultAll
                      ? const Icon(Icons.check_circle_rounded,
                          color: Colors.green)
                      : null,
                  onTap: () => Navigator.pop(ctx, true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadExportPrefs();
    _loadSavedPresets();
    _loadFirstPage();
    _maybeShowOnboarding();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _userFilterCtrl.dispose();
    super.dispose();
  }

  Future<void> _maybeShowOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_prefOnboardedKey) ?? false;
    if (seen || !mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _showOnboardingDialog(mode: 'quick', allowDontShowAgain: true);
    });
  }

  Future<void> _showOnboardingDialog({
    required String mode,
    required bool allowDontShowAgain,
    String audience = 'general',
  }) async {
    final isDetailed = mode == 'detailed';
    final isAuditor = audience == 'auditor';
    final titlePrefix = isAuditor ? 'ผู้ตรวจสอบ/อนุมัติ' : 'เจ้าหน้าที่ทั่วไป';
    final steps = isDetailed
        ? (isAuditor
            ? const [
                '1. เริ่มจากช่วงเวลา + ผู้กระทำ + Action เพื่อจำกัดขอบเขตการตรวจสอบ',
                '2. งานติดตามการเปิด/ปิดสิทธิ์ ให้เปิดชิป "เฉพาะเปลี่ยนสถานะ"',
                '3. กด ดู JSON เพื่อเทียบ Old/New และดูสรุป ADD/DEL/CHG แบบอ่านเร็ว',
                '4. ถ้าต้องส่งหลักฐาน ให้ใช้ Export JSON แบบ "ทั้งหมดตามตัวกรอง"',
                '5. ใช้ปุ่ม Preset เพื่อเตรียมตัวกรองสำหรับเคสมาตรฐานทันที',
                'ตัวอย่างเคส A: ตรวจการเปิดใช้งานย้อนหลัง 7 วัน -> ใช้ Preset "ติดตามการเปิด/ปิด 7 วันล่าสุด"',
                'ตัวอย่างเคส B: ตรวจความถูกต้องรายเดือน -> ใช้ Preset "ทบทวนภาพรวมเดือนนี้"',
                'ตัวอย่างเคส C: ส่งหลักฐาน -> ใช้ Preset "เตรียมส่งหลักฐาน (JSON ทั้งหมด)"',
              ]
            : const [
                '1. ใช้ช่วงเวลา + Action เพื่อค้นหารายการที่เกี่ยวข้องให้เร็วที่สุด',
                '2. เปิด ดู JSON เพื่อเปรียบเทียบก่อน/หลัง เมื่อได้รับแจ้งแก้ไขข้อมูลผิด',
                '3. ถ้าหาเหตุจากการเปิด/ปิดใช้งาน ให้เปิดชิป "เฉพาะเปลี่ยนสถานะ"',
                '4. ใช้ Preset เพื่อตั้งค่าตัวกรองอัตโนมัติและลดขั้นตอนซ้ำ',
                '5. รีเซ็ตตัวกรองไม่ลบค่า export ที่จำไว้ แต่ รีเซ็ตหน้านี้ จะล้างทั้งหมด',
              ])
        : (isAuditor
            ? const [
                '1. ใช้ Preset เพื่อเริ่มเคสตรวจสอบได้ทันที',
                '2. ใช้ ดู JSON เพื่อยืนยัน Old/New ก่อนสรุปผล',
                '3. ส่งออก JSON ได้ทั้งเฉพาะที่แสดงหรือทั้งหมดตามตัวกรอง',
              ]
            : const [
                '1. ใช้ตัวกรองหรือ Preset เพื่อค้นหาให้เร็ว',
                '2. ใช้ ดู JSON เพื่อเทียบ Old/New',
                '3. ส่งออก CSV/JSON ได้ทั้งเฉพาะที่แสดงหรือทั้งหมดตามตัวกรอง',
              ]);

    final dontShow = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: AdaptiveContentSheet(
          title:
              '${isDetailed ? 'แนะนำแบบละเอียด' : 'แนะนำแบบสั้น'} • $titlePrefix',
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.sp16,
              0,
              AppTheme.sp16,
              AppTheme.sp16,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final step in steps) ...[
                    Text(step),
                    const SizedBox(height: 6),
                  ],
                  const SizedBox(height: AppTheme.sp12),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: AppTheme.sp8,
                    runSpacing: AppTheme.sp8,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(sheetContext, false);
                          _showOnboardingPresetChooser(
                            initialAudience: isAuditor ? 'auditor' : 'general',
                          );
                        },
                        child: const Text('ตั้งค่า Preset'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(sheetContext, false),
                        child: const Text('ปิด'),
                      ),
                      if (allowDontShowAgain)
                        FilledButton(
                          onPressed: () => Navigator.pop(sheetContext, true),
                          child: const Text('ไม่ต้องแสดงอีก'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (allowDontShowAgain && dontShow == true) {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_prefOnboardedKey, true);
    }
  }

  void _setRangeByPreset(String preset) {
    final now = DateTime.now();
    _rangePreset = preset;
    if (preset == 'today') {
      _fromDate = DateTime(now.year, now.month, now.day);
      _toDate = DateTime(now.year, now.month, now.day);
    } else if (preset == 'last7') {
      final from = now.subtract(const Duration(days: 6));
      _fromDate = DateTime(from.year, from.month, from.day);
      _toDate = DateTime(now.year, now.month, now.day);
    } else if (preset == 'last30') {
      final from = now.subtract(const Duration(days: 29));
      _fromDate = DateTime(from.year, from.month, from.day);
      _toDate = DateTime(now.year, now.month, now.day);
    } else if (preset == 'month') {
      _fromDate = DateTime(now.year, now.month, 1);
      _toDate = DateTime(now.year, now.month, now.day);
    }
  }

  Future<void> _applyAuditWorkflowPreset(String preset,
      {String? actorName}) async {
    if (preset == 'status7') {
      setState(() {
        _actionFilter = 'UPDATE';
        _changeFilter = 'isactive';
        _userFilterCtrl.clear();
        _setRangeByPreset('last7');
        _activePresetLabel = 'ติดตามการเปิด/ปิด 7 วันล่าสุด';
      });
      await _loadFirstPage();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('ตั้งค่า Preset: ติดตามการเปิด/ปิด 7 วันล่าสุด')));
      return;
    }

    if (preset == 'monthly') {
      setState(() {
        _actionFilter = 'all';
        _changeFilter = 'all';
        _userFilterCtrl.clear();
        _setRangeByPreset('month');
        _activePresetLabel = 'ทบทวนภาพรวมเดือนนี้';
      });
      await _loadFirstPage();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('ตั้งค่า Preset: ทบทวนภาพรวมเดือนนี้')));
      return;
    }

    if (preset == 'evidence') {
      setState(() {
        _actionFilter = 'all';
        _changeFilter = 'all';
        _userFilterCtrl.clear();
        _setRangeByPreset('month');
        _activePresetLabel = 'เตรียมส่งหลักฐาน (JSON ทั้งหมด)';
      });
      await _saveExportPrefs(scope: 'all', format: 'json');
      await _loadFirstPage();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('ตั้งค่า Preset: เตรียมส่งหลักฐาน (JSON ทั้งหมด)')));
      return;
    }

    if (preset == 'actor') {
      final actor = (actorName ?? '').trim();
      if (actor.isEmpty) return;
      setState(() {
        _actionFilter = 'all';
        _changeFilter = 'all';
        _userFilterCtrl.text = actor;
        _setRangeByPreset('last30');
        _activePresetLabel = 'เจาะผู้กระทำ: $actor';
      });
      await _loadFirstPage();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
            SnackBar(content: Text('ตั้งค่า Preset: เจาะผู้กระทำ $actor')));
    }
  }

  Future<void> _showActorPresetDialog() async {
    final actor = await _promptTextSheet(
      title: 'Preset: เจาะผู้กระทำคนเดียว',
      label: 'ชื่อผู้กระทำ',
      hint: 'เช่น admin หรือ Thanawat',
      initialValue: _userFilterCtrl.text.trim(),
      prefixIcon: Icons.person_search_rounded,
      confirmLabel: 'ใช้งาน Preset',
    );
    if (!mounted) return;
    final value = (actor ?? '').trim();
    if (value.isEmpty) return;
    await _applyAuditWorkflowPreset('actor', actorName: value);
  }

  Future<void> _showOnboardingPresetChooser({String? initialAudience}) async {
    String selectedAudience = initialAudience ?? _presetAudience;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AdaptiveContentSheet(
        child: StatefulBuilder(
          builder: (ctx, setModalState) => SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'เลือก Preset งานตรวจสอบ',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('ทั้งหมด'),
                          selected: selectedAudience == 'all',
                          onSelected: (_) =>
                              setModalState(() => selectedAudience = 'all'),
                        ),
                        ChoiceChip(
                          label: const Text('เจ้าหน้าที่ทั่วไป'),
                          selected: selectedAudience == 'general',
                          onSelected: (_) =>
                              setModalState(() => selectedAudience = 'general'),
                        ),
                        ChoiceChip(
                          label: const Text('ผู้ตรวจสอบ/อนุมัติ'),
                          selected: selectedAudience == 'auditor',
                          onSelected: (_) =>
                              setModalState(() => selectedAudience = 'auditor'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (selectedAudience != 'auditor')
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person_pin_rounded),
                        title: const Text('เจาะผู้กระทำคนเดียว'),
                        subtitle: const Text(
                            'ระบุชื่อผู้กระทำ + ตั้งช่วงเวลา 30 วันล่าสุดโดยอัตโนมัติ'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _showActorPresetDialog();
                        },
                      ),
                    if (selectedAudience != 'general')
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.toggle_on_rounded),
                        title: const Text('ติดตามการเปิด/ปิด 7 วันล่าสุด'),
                        subtitle: const Text(
                            'ตั้งค่า UPDATE + เฉพาะเปลี่ยนสถานะ + ช่วงเวลา 7 วัน'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _applyAuditWorkflowPreset('status7');
                        },
                      ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_month_rounded),
                      title: const Text('ทบทวนภาพรวมเดือนนี้'),
                      subtitle: const Text(
                          'ตั้งค่าเดือนนี้ + Action ทั้งหมด + แสดงทุกประเภทการเปลี่ยนแปลง'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _applyAuditWorkflowPreset('monthly');
                      },
                    ),
                    if (selectedAudience != 'general')
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.fact_check_rounded),
                        title: const Text('เตรียมส่งหลักฐาน (JSON ทั้งหมด)'),
                        subtitle: const Text(
                            'ตั้งค่าเดือนนี้ และค่า export เริ่มต้นเป็น JSON/ทั้งหมดตามตัวกรอง'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _applyAuditWorkflowPreset('evidence');
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    await _savePresetAudience(selectedAudience);
  }

  Future<void> _showOnboardingChooser() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AdaptiveContentSheet(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'แนะนำการใช้งาน',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  'เลือกตามบทบาทและระดับความละเอียด',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.of(ctx).textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.badge_rounded),
                  title: const Text('เจ้าหน้าที่ทั่วไป • โหมดสั้น'),
                  subtitle: const Text('สรุปขั้นตอนหลักสำหรับงานประจำวัน'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showOnboardingDialog(
                      mode: 'quick',
                      allowDontShowAgain: false,
                      audience: 'general',
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.menu_book_rounded),
                  title: const Text('เจ้าหน้าที่ทั่วไป • โหมดละเอียด'),
                  subtitle: const Text(
                      'แนวทางวิเคราะห์ย้อนหลังและลดงานซ้ำด้วย Preset'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showOnboardingDialog(
                      mode: 'detailed',
                      allowDontShowAgain: false,
                      audience: 'general',
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.shield_rounded),
                  title: const Text('ผู้ตรวจสอบ/อนุมัติ • โหมดสั้น'),
                  subtitle:
                      const Text('เช็คประเด็นสำคัญและเตรียมส่งหลักฐานได้ทันที'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showOnboardingDialog(
                      mode: 'quick',
                      allowDontShowAgain: false,
                      audience: 'auditor',
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.fact_check_rounded),
                  title: const Text('ผู้ตรวจสอบ/อนุมัติ • โหมดละเอียด'),
                  subtitle: const Text(
                      'อธิบายเคสมาตรฐานสำหรับตรวจสอบย้อนหลังและส่งหลักฐาน'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showOnboardingDialog(
                      mode: 'detailed',
                      allowDontShowAgain: false,
                      audience: 'auditor',
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _buildQuery(int page) {
    return {
      'page': page,
      'perPage': _pageSize,
      if (_actionFilter != 'all') 'action': _actionFilter,
      if (_changeFilter == 'isactive') 'changed_field': 'isactive',
      if (_userFilterCtrl.text.trim().isNotEmpty)
        'user_name': _userFilterCtrl.text.trim(),
      if (_fromDate != null)
        'date_from': DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day)
            .toIso8601String()
            .substring(0, 10),
      if (_toDate != null)
        'date_to': DateTime(_toDate!.year, _toDate!.month, _toDate!.day)
            .toIso8601String()
            .substring(0, 10),
    };
  }

  bool _partyAuditPage1Cacheable() {
    return _actionFilter == 'all' &&
        _changeFilter == 'all' &&
        _userFilterCtrl.text.trim().isEmpty &&
        _fromDate == null &&
        _toDate == null;
  }

  void _applyPartyAuditListBody(Map<String, dynamic> body) {
    final data = (body['data'] as List? ?? const [])
        .map((e) => (e is Map<String, dynamic>)
            ? e
            : Map<String, dynamic>.from(e as Map))
        .toList();
    final meta = (body['meta'] is Map<String, dynamic>)
        ? body['meta'] as Map<String, dynamic>
        : <String, dynamic>{};
    _rows
      ..clear()
      ..addAll(data);
    _page = (meta['page'] as num?)?.toInt() ?? 1;
    _totalPages = (meta['totalPages'] as num?)?.toInt() ?? 1;
    _totalRecords = (meta['total'] as num?)?.toInt() ?? data.length;
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: isFrom ? (_fromDate ?? now) : (_toDate ?? now),
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      locale: const Locale('th', 'TH'),
      currentDate: now,
      helpText: 'เลือกวันที่',
      cancelText: 'ยกเลิก',
      confirmText: 'ตกลง',
      fieldLabelText: 'วันที่',
      fieldHintText: 'วัน/เดือน/ปี พ.ศ.',
    );
    if (selected == null) return;
    setState(() {
      _rangePreset = 'custom';
      _activePresetLabel = 'กำหนดเอง';
      if (isFrom) {
        _fromDate = selected;
      } else {
        _toDate = selected;
      }
    });
    await _loadFirstPage();
  }

  Future<void> _clearFilters() async {
    setState(() {
      _actionFilter = 'all';
      _fromDate = null;
      _toDate = null;
      _userFilterCtrl.clear();
      _rangePreset = 'custom';
      _activePresetLabel = 'กำหนดเอง';
    });
    await _loadFirstPage();
  }

  Future<void> _applyPresetRange(String preset) async {
    setState(() {
      _setRangeByPreset(preset);
    });
    await _loadFirstPage();
  }

  String _csvEscape(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  String _buildCsv(List<Map<String, dynamic>> rows, SchoolProfile school) {
    final buffer = StringBuffer();
    for (final line in schoolProfileCsvCommentLines(school)) {
      buffer.writeln(line);
    }
    buffer.writeln('id,record_id,action,user_name,created,old_data,new_data');
    for (final row in rows) {
      buffer.writeln([
        _csvEscape((row['id'] ?? '').toString()),
        _csvEscape((row['record_id'] ?? '').toString()),
        _csvEscape((row['action'] ?? '').toString()),
        _csvEscape((row['user_name'] ?? '').toString()),
        _csvEscape((row['created'] ?? '').toString()),
        _csvEscape((row['old_data'] ?? '').toString()),
        _csvEscape((row['new_data'] ?? '').toString()),
      ].join(','));
    }
    return buffer.toString();
  }

  bool _toBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    final s = v.toString().trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'y' || s == 'yes';
  }

  bool _isIsActiveChange(Map<String, dynamic> row) {
    final oldMap = _decodeAsMap(row['old_data']);
    final newMap = _decodeAsMap(row['new_data']);
    if (oldMap == null || newMap == null) return false;
    if (!oldMap.containsKey('isactive') || !newMap.containsKey('isactive')) {
      return false;
    }
    return _toBool(oldMap['isactive']) != _toBool(newMap['isactive']);
  }

  Future<List<Map<String, dynamic>>> _fetchAllFilteredRows() async {
    const exportPageSize = 500;
    final all = <Map<String, dynamic>>[];
    var page = 1;
    var totalPages = 1;

    do {
      final response = await _dio.request(
        widget.partyId == null
            ? '${baseurl}party/audit-log'
            : '${baseurl}party/${widget.partyId}/audit-log',
        options: Options(method: 'GET'),
        queryParameters: {
          ..._buildQuery(page),
          'page': page,
          'perPage': exportPageSize,
        },
      );
      final body = (response.data is Map<String, dynamic>)
          ? response.data as Map<String, dynamic>
          : <String, dynamic>{};
      final data = (body['data'] as List? ?? const [])
          .map((e) => (e is Map<String, dynamic>)
              ? e
              : Map<String, dynamic>.from(e as Map))
          .toList();
      final meta = (body['meta'] is Map<String, dynamic>)
          ? body['meta'] as Map<String, dynamic>
          : <String, dynamic>{};
      all.addAll(data);
      totalPages = (meta['totalPages'] as num?)?.toInt() ?? totalPages;
      page += 1;
    } while (page <= totalPages);

    return all;
  }

  Future<void> _exportCsv() async {
    if (_isExporting) return;
    final exportAll = await _askExportAll('CSV');
    if (exportAll == null) return;
    await _saveExportPrefs(scope: exportAll ? 'all' : 'visible', format: 'csv');
    setState(() => _isExporting = true);
    try {
      final rows = exportAll
          ? () {
              return _fetchAllFilteredRows().then((allRows) =>
                  _changeFilter == 'isactive'
                      ? allRows.where(_isIsActiveChange).toList()
                      : allRows);
            }()
          : Future.value(_visibleRows());
      final resolvedRows = await rows;
      if (!mounted) return;

      if (resolvedRows.isEmpty) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
              const SnackBar(content: Text('ไม่มีข้อมูลสำหรับส่งออก')));
        return;
      }

      final school = await SchoolProfileLocalDataSourceImpl().load();
      if (!mounted) return;
      final csv = _buildCsv(resolvedRows, school);
      if (kIsWeb) {
        await Clipboard.setData(ClipboardData(text: csv));
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
              const SnackBar(content: Text('คัดลอก CSV ลงคลิปบอร์ดแล้ว')));
        return;
      }

      final file = await writeTextFileToDocuments(
        filename: _buildExportFileName('csv'),
        content: csv,
      );
      if (file == null) return;
      if (!mounted) return;
      setState(() => _lastExportPath = file.path);
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('บันทึกไฟล์แล้ว: ${file.path}')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('ส่งออกข้อมูลไม่สำเร็จ')));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportJson() async {
    if (_isExportingJson) return;
    final exportAll = await _askExportAll('JSON');
    if (exportAll == null) return;
    await _saveExportPrefs(
        scope: exportAll ? 'all' : 'visible', format: 'json');
    setState(() => _isExportingJson = true);
    try {
      final rows = exportAll
          ? () {
              return _fetchAllFilteredRows().then((allRows) =>
                  _changeFilter == 'isactive'
                      ? allRows.where(_isIsActiveChange).toList()
                      : allRows);
            }()
          : Future.value(_visibleRows());
      final resolvedRows = await rows;
      if (!mounted) return;

      if (resolvedRows.isEmpty) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
              const SnackBar(content: Text('ไม่มีข้อมูลสำหรับส่งออก')));
        return;
      }

      final prettyJson =
          const JsonEncoder.withIndent('  ').convert(resolvedRows);
      if (kIsWeb) {
        await Clipboard.setData(ClipboardData(text: prettyJson));
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
              const SnackBar(content: Text('คัดลอก JSON ลงคลิปบอร์ดแล้ว')));
        return;
      }

      final file = await writeTextFileToDocuments(
        filename: _buildExportFileName('json'),
        content: prettyJson,
      );
      if (file == null) return;
      if (!mounted) return;
      setState(() => _lastExportPath = file.path);
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('บันทึกไฟล์แล้ว: ${file.path}')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('ส่งออก JSON ไม่สำเร็จ')));
    } finally {
      if (mounted) setState(() => _isExportingJson = false);
    }
  }

  Future<void> _openExportFolder() async {
    final path = _lastExportPath;
    if (path == null || kIsWeb) return;
    await openFileLocation(path);
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _busyMessage = 'กำลังโหลดประวัติการแก้ไข...';
      _isLoading = true;
      _page = 1;
      _totalPages = 1;
      _rows.clear();
    });

    var showedCache = false;
    if (_partyAuditPage1Cacheable()) {
      try {
        final db = await AppDatabase().database;
        final cached =
            await PartyAuditMaterializedStore.loadPageOne(db, widget.partyId);
        if (cached != null && mounted) {
          setState(() {
            _applyPartyAuditListBody(cached);
            _isLoading = false;
          });
          showedCache = true;
        }
      } catch (_) {}
    }

    try {
      final response = await _dio.request(
        widget.partyId == null
            ? '${baseurl}party/audit-log'
            : '${baseurl}party/${widget.partyId}/audit-log',
        options: Options(method: 'GET'),
        queryParameters: _buildQuery(1),
      );
      final body = (response.data is Map<String, dynamic>)
          ? response.data as Map<String, dynamic>
          : <String, dynamic>{};
      if (_partyAuditPage1Cacheable()) {
        try {
          final db = await AppDatabase().database;
          await PartyAuditMaterializedStore.replacePageOne(
              db, widget.partyId, body);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _applyPartyAuditListBody(body);
      });
    } catch (_) {
      if (!mounted) return;
      if (!showedCache) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
              const SnackBar(content: Text('โหลดประวัติการแก้ไขไม่สำเร็จ')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _isLoading || _page >= _totalPages) return;
    setState(() => _isLoadingMore = true);
    final nextPage = _page + 1;
    try {
      final response = await _dio.request(
        widget.partyId == null
            ? '${baseurl}party/audit-log'
            : '${baseurl}party/${widget.partyId}/audit-log',
        options: Options(method: 'GET'),
        queryParameters: _buildQuery(nextPage),
      );
      final body = (response.data is Map<String, dynamic>)
          ? response.data as Map<String, dynamic>
          : <String, dynamic>{};
      final data = (body['data'] as List? ?? const [])
          .map((e) => (e is Map<String, dynamic>)
              ? e
              : Map<String, dynamic>.from(e as Map))
          .toList();
      final meta = (body['meta'] is Map<String, dynamic>)
          ? body['meta'] as Map<String, dynamic>
          : <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _rows.addAll(data);
        _page = (meta['page'] as num?)?.toInt() ?? nextPage;
        _totalPages = (meta['totalPages'] as num?)?.toInt() ?? _totalPages;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('โหลดข้อมูลเพิ่มเติมไม่สำเร็จ')));
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final p = _scrollController.position;
    if (p.pixels >= p.maxScrollExtent - 280) {
      _loadMore();
    }
  }

  String _formatJsonCell(dynamic raw) {
    if (raw == null) return '-';
    final s = raw.toString();
    if (s.trim().isEmpty) return '-';
    try {
      final decoded = jsonDecode(s);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return s;
    }
  }

  String _shortPreview(dynamic raw) {
    final formatted = _formatJsonCell(raw);
    if (formatted == '-') return formatted;
    final oneLine = formatted.replaceAll('\n', ' ');
    if (oneLine.length <= 120) return oneLine;
    return '${oneLine.substring(0, 120)}...';
  }

  Future<void> _copyText(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('คัดลอก $label แล้ว')));
  }

  Future<void> _showJsonDialog({
    required String title,
    required dynamic oldRaw,
    required dynamic newRaw,
  }) async {
    final oldData = _formatJsonCell(oldRaw);
    final newData = _formatJsonCell(newRaw);
    final oldMap = _decodeAsMap(oldRaw);
    final newMap = _decodeAsMap(newRaw);
    final diffRows = _buildTopLevelDiff(oldMap, newMap);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: AdaptiveContentSheet(
          title: title,
          maxHeightFactor: 0.92,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.sp16,
              0,
              AppTheme.sp16,
              AppTheme.sp16,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    fit: FlexFit.loose,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (diffRows.isNotEmpty) ...[
                            const Text(
                              'สรุปความต่าง (Top-level)',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            ...diffRows.map((r) {
                              final status = (r['status'] ?? '').toString();
                              final statusColor = status == 'ADD'
                                  ? Colors.green
                                  : status == 'DEL'
                                      ? Colors.red
                                      : Colors.amber.shade800;
                              final statusBg = status == 'ADD'
                                  ? Colors.green.withValues(alpha: 0.12)
                                  : status == 'DEL'
                                      ? Colors.red.withValues(alpha: 0.12)
                                      : Colors.amber.withValues(alpha: 0.16);
                              return Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: statusColor.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        '$status ${r['key']}',
                                        style: TextStyle(
                                          color: statusColor,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text('ก่อน: ${r['old']}'),
                                    Text('หลัง: ${r['new']}'),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 12),
                          ],
                          const Text(
                            'Old Data',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          SelectableText(oldData),
                          const SizedBox(height: 16),
                          const Text(
                            'New Data',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          SelectableText(newData),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.sp12),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: AppTheme.sp8,
                    runSpacing: AppTheme.sp8,
                    children: [
                      TextButton(
                        onPressed: () => _copyText(oldData, 'Old Data'),
                        child: const Text('คัดลอก Old'),
                      ),
                      TextButton(
                        onPressed: () => _copyText(newData, 'New Data'),
                        child: const Text('คัดลอก New'),
                      ),
                      TextButton(
                        onPressed: () => _copyText(
                          'Old:\n$oldData\n\nNew:\n$newData',
                          'Old/New',
                        ),
                        child: const Text('คัดลอกทั้งคู่'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('ปิด'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic>? _decodeAsMap(dynamic raw) {
    if (raw == null) return null;
    try {
      final v = raw is String ? jsonDecode(raw) : raw;
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
      return null;
    } catch (_) {
      return null;
    }
  }

  List<Map<String, String>> _buildTopLevelDiff(
    Map<String, dynamic>? oldMap,
    Map<String, dynamic>? newMap,
  ) {
    if (oldMap == null && newMap == null) return const [];
    final keys = <String>{...?(oldMap?.keys), ...?(newMap?.keys)}.toList()
      ..sort();
    final rows = <Map<String, String>>[];
    for (final key in keys) {
      final hasOld = oldMap?.containsKey(key) ?? false;
      final hasNew = newMap?.containsKey(key) ?? false;
      final oldValue = hasOld ? (oldMap![key]) : null;
      final newValue = hasNew ? (newMap![key]) : null;
      if (hasOld && hasNew && '$oldValue' == '$newValue') {
        continue;
      }
      rows.add({
        'key': key,
        'status': !hasOld
            ? 'ADD'
            : !hasNew
                ? 'DEL'
                : 'CHG',
        'old': hasOld ? '$oldValue' : '-',
        'new': hasNew ? '$newValue' : '-',
      });
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final title = widget.partyId == null
        ? 'ประวัติแก้ไขผู้รับ/ผู้จ่าย'
        : 'ประวัติ: ${widget.partyName ?? widget.partyId}';
    final visibleRows = _visibleRows();
    final shownCount = visibleRows.length;

    return AppBusyBackdrop(
      isBusy: _isLoading,
      message: _busyMessage,
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          title: Text(title),
          actions: [
            IconButton(
              onPressed: _showFiltersModal,
              icon: const Icon(Icons.tune_rounded),
              tooltip: 'ตัวกรอง',
            ),
            IconButton(
              onPressed: _isExporting ? null : _exportCsv,
              icon: _isExporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded),
              tooltip: 'Export CSV',
            ),
            IconButton(
              onPressed: _isExportingJson ? null : _exportJson,
              icon: _isExportingJson
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.data_object_rounded),
              tooltip: 'Export JSON',
            ),
            if (!kIsWeb && _lastExportPath != null)
              IconButton(
                onPressed: _openExportFolder,
                icon: const Icon(Icons.folder_open_rounded),
                tooltip: 'เปิดโฟลเดอร์ไฟล์',
              ),
            IconButton(
              onPressed: _loadFirstPage,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'รีเฟรช',
            ),
            IconButton(
              onPressed: _showOnboardingChooser,
              icon: const Icon(Icons.school_rounded),
              tooltip: 'แนะนำอีกครั้ง',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : visibleRows.isEmpty
                ? Column(
                    children: [
                      _buildFilters(c),
                      const Expanded(
                          child:
                              Center(child: Text('ยังไม่มีประวัติการแก้ไข'))),
                    ],
                  )
                : Column(
                    children: [
                      _buildFilters(c),
                      _buildSummaryBar(c, shownCount),
                      Expanded(
                        child: ListView.separated(
                          controller: _scrollController,
                          itemCount:
                              visibleRows.length + (_isLoadingMore ? 1 : 0),
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            if (i >= visibleRows.length) {
                              return const Padding(
                                padding: EdgeInsets.all(AppTheme.sp12),
                                child:
                                    Center(child: CircularProgressIndicator()),
                              );
                            }
                            final row = visibleRows[i];
                            final action = (row['action'] ?? '').toString();
                            final created = ThaiDateFormatter.formatDateTime(
                                row['created']);
                            final userName =
                                (row['user_name'] ?? '-').toString();
                            final oldData = _formatJsonCell(row['old_data']);
                            final newData = _formatJsonCell(row['new_data']);

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.sp12,
                                vertical: AppTheme.sp8,
                              ),
                              title: Text(
                                '$action • $created',
                                style: TextStyle(
                                  color: c.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text('ผู้กระทำ: $userName'),
                                  const SizedBox(height: 6),
                                  Text(
                                      'Old: ${_shortPreview(row['old_data'])}'),
                                  const SizedBox(height: 4),
                                  Text(
                                      'New: ${_shortPreview(row['new_data'])}'),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () => _showJsonDialog(
                                          title:
                                              'รายละเอียด Audit #${row['id'] ?? ''}',
                                          oldRaw: row['old_data'],
                                          newRaw: row['new_data'],
                                        ),
                                        icon: const Icon(Icons.code_rounded),
                                        label: const Text('ดู JSON'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            _copyText(oldData, 'Old Data'),
                                        child: const Text('คัดลอก Old'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            _copyText(newData, 'New Data'),
                                        child: const Text('คัดลอก New'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Future<void> _showFiltersModal() async {
    String formatDate(DateTime? d) {
      if (d == null) return '-';
      return ThaiDateFormatter.format(d);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: AdaptiveContentSheet(
            title: 'ตัวกรอง',
            maxHeightFactor: 0.92,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.sp16,
                0,
                AppTheme.sp16,
                AppTheme.sp16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Action Filter
                    const Text('Action:',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: AppDropdownField<String>(
                        label: 'เลือก Action',
                        value: _actionFilter,
                        items: const [
                          AppDropdownItem(value: 'all', label: 'ทั้งหมด'),
                          AppDropdownItem(value: 'INSERT', label: 'INSERT'),
                          AppDropdownItem(value: 'UPDATE', label: 'UPDATE'),
                          AppDropdownItem(value: 'DELETE', label: 'DELETE'),
                        ],
                        onChanged: (v) {
                          setModalState(() {
                            _actionFilter = v ?? 'all';
                            _activePresetLabel = 'กำหนดเอง';
                          });
                          setState(() {
                            _actionFilter = v ?? 'all';
                            _activePresetLabel = 'กำหนดเอง';
                          });
                          _loadFirstPage();
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    // User Filter
                    const Text('ผู้กระทำ:',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _userFilterCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ค้นหาชื่อผู้ใช้',
                        prefixIcon: Icon(Icons.person_search_rounded),
                      ),
                      onSubmitted: (_) {
                        setModalState(() => _activePresetLabel = 'กำหนดเอง');
                        setState(() => _activePresetLabel = 'กำหนดเอง');
                        _loadFirstPage();
                      },
                    ),
                    const SizedBox(height: 16),
                    // Date Range
                    const Text('ช่วงวันที่:',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDate(isFrom: true),
                            icon: const Icon(Icons.date_range_rounded),
                            label: Text('จาก ${formatDate(_fromDate)}'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDate(isFrom: false),
                            icon: const Icon(Icons.event_rounded),
                            label: Text('ถึง ${formatDate(_toDate)}'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Quick Range Presets
                    const Text('ช่วงเวลาด่วน:',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('วันนี้'),
                          selected: _rangePreset == 'today',
                          onSelected: (_) {
                            setModalState(
                                () => _activePresetLabel = 'กำหนดเอง');
                            setState(() => _activePresetLabel = 'กำหนดเอง');
                            _applyPresetRange('today');
                          },
                        ),
                        ChoiceChip(
                          label: const Text('7 วันล่าสุด'),
                          selected: _rangePreset == 'last7',
                          onSelected: (_) {
                            setModalState(
                                () => _activePresetLabel = 'กำหนดเอง');
                            setState(() => _activePresetLabel = 'กำหนดเอง');
                            _applyPresetRange('last7');
                          },
                        ),
                        ChoiceChip(
                          label: const Text('30 วันล่าสุด'),
                          selected: _rangePreset == 'last30',
                          onSelected: (_) {
                            setModalState(
                                () => _activePresetLabel = 'กำหนดเอง');
                            setState(() => _activePresetLabel = 'กำหนดเอง');
                            _applyPresetRange('last30');
                          },
                        ),
                        ChoiceChip(
                          label: const Text('เดือนนี้'),
                          selected: _rangePreset == 'month',
                          onSelected: (_) {
                            setModalState(
                                () => _activePresetLabel = 'กำหนดเอง');
                            setState(() => _activePresetLabel = 'กำหนดเอง');
                            _applyPresetRange('month');
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Other Filters
                    const Text('ตัวเลือกเพิ่มเติม:',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ChoiceChip(
                      label: const Text('เฉพาะเปลี่ยนสถานะ'),
                      selected: _changeFilter == 'isactive',
                      onSelected: (_) {
                        setModalState(() {
                          _changeFilter =
                              _changeFilter == 'isactive' ? 'all' : 'isactive';
                          _activePresetLabel = 'กำหนดเอง';
                        });
                        setState(() {
                          _changeFilter =
                              _changeFilter == 'isactive' ? 'all' : 'isactive';
                          _activePresetLabel = 'กำหนดเอง';
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    FilterChip(
                      label: Text(_rememberExportPrefs
                          ? 'จำค่า export: เปิด'
                          : 'จำค่า export: ปิด'),
                      selected: _rememberExportPrefs,
                      onSelected: (v) => _setRememberExportPrefs(v),
                    ),
                    const SizedBox(height: 16),
                    // Quick Actions
                    const Text('การกระทำด่วน:',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () => _applyAuditWorkflowPreset('status7'),
                          icon: const Icon(Icons.shield_rounded),
                          label: const Text('ด่วน: งานผู้ตรวจสอบ'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _showActorPresetDialog,
                          icon: const Icon(Icons.badge_rounded),
                          label: const Text('ด่วน: งานเจ้าหน้าที่'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Preset Audience
                    const Text('Preset แสดงให้:',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('ทั้งหมด'),
                          selected: _presetAudience == 'all',
                          onSelected: (_) => _savePresetAudience('all'),
                        ),
                        ChoiceChip(
                          label: const Text('เจ้าหน้าที่ทั่วไป'),
                          selected: _presetAudience == 'general',
                          onSelected: (_) => _savePresetAudience('general'),
                        ),
                        ChoiceChip(
                          label: const Text('ผู้ตรวจสอบ'),
                          selected: _presetAudience == 'auditor',
                          onSelected: (_) => _savePresetAudience('auditor'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Preset Management
                    const Text('Preset:',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () => _showOnboardingPresetChooser(
                            initialAudience: _presetAudience,
                          ),
                          icon: const Icon(Icons.bolt_rounded),
                          label: const Text('Preset งานตรวจสอบ'),
                        ),
                        TextButton.icon(
                          onPressed: _saveCurrentAsPreset,
                          icon: const Icon(Icons.bookmark_add_rounded),
                          label: const Text('บันทึก'),
                        ),
                        TextButton.icon(
                          onPressed: _showSavedPresetManager,
                          icon: const Icon(Icons.bookmarks_rounded),
                          label: const Text('จัดการ'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: _loadFirstPage,
                            child: const Text('ค้นหา'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _clearFilters,
                            icon: const Icon(Icons.restart_alt_rounded),
                            label: const Text('รีเซ็ต'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(AppColors c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppTheme.sp12,
        AppTheme.sp8,
        AppTheme.sp12,
        AppTheme.sp8,
      ),
      decoration: BoxDecoration(
        color: c.cardWhite,
        border: Border(bottom: BorderSide(color: c.cardBorder)),
      ),
      child: _buildSummaryBar(c, _rows.length),
    );
  }

  Widget _buildSummaryBar(AppColors c, int shownCount) {
    final summary = 'แสดง $shownCount รายการ';
    final totalText = _totalRecords > 0
        ? 'จากทั้งหมด $_totalRecords รายการ'
        : 'ยังไม่ทราบจำนวนรวม';
    final exportMode =
        _lastExportScope == 'all' ? 'ทั้งหมดตามตัวกรอง' : 'เฉพาะที่แสดงอยู่';
    final exportFmt = _lastExportFormat.toUpperCase();
    final remember = _rememberExportPrefs ? 'จำค่า ON' : 'จำค่า OFF';
    final audienceText = _presetAudience == 'auditor'
        ? 'ผู้ตรวจสอบ'
        : _presetAudience == 'general'
            ? 'เจ้าหน้าที่ทั่วไป'
            : 'ทั้งหมด';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      color: c.iconBgIncome,
      child: Text(
        '$summary • $totalText • preset: $_activePresetLabel ($audienceText) • export ล่าสุด: $exportFmt/$exportMode • $remember',
        style: TextStyle(
          color: c.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
