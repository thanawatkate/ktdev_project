import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:saccm/config.dart';
import 'package:saccm/core/di/service_locator.dart';
import 'package:saccm/core/local_data_source/app_database.dart';
import 'package:saccm/core/services/sync_service.dart';

class ExpenseTypeProvider extends ChangeNotifier {
  bool isLoading = false;
  String? error;
  bool _disposed = false;

  late final SyncService _syncService;

  ExpenseTypeProvider() {
    _syncService = ServiceLocator.instance.get<SyncService>();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<bool> saveExpenseType({
    required String token,
    required String name,
    required String code,
    required String refDefaultBudgetSource,
    String remark = '',
    int sort = 0,
  }) async {
    isLoading = true;
    error = null;
    _safeNotify();
    try {
      final bud = refDefaultBudgetSource.trim();
      if (bud.isEmpty) {
        error = 'ต้องเลือกแหล่งเงินเริ่มต้น';
        return false;
      }
      final budInt = int.tryParse(bud);
      if (budInt == null || budInt <= 0) {
        error = 'รหัสแหล่งเงินไม่ถูกต้อง';
        return false;
      }
      final db = await AppDatabase().database;
      final now = DateTime.now().toIso8601String();
      final localId =
          'expense_type_custom_${DateTime.now().millisecondsSinceEpoch}';
      await db.insert('expense_type', {
        'id': localId,
        'code': code.trim(),
        'name': name.trim(),
        'remark': remark.trim(),
        'sort': sort,
        'use': 'Y',
        'refDefaultBudgetSource': bud,
        'synced': 0,
        'lastModified': now,
      });
      await _syncService.addPendingRequest(
        id: 'expense_type_create_$localId',
        method: 'POST',
        endpoint: '${baseurl}expensetype',
        payload: jsonEncode({
          'token': token,
          'code': code.trim(),
          'name': name.trim(),
          'remark': remark.trim(),
          'sort': sort,
          'refdefaultbudgetsource': budInt,
        }),
      );
      error = null;
      return true;
    } catch (_) {
      error = 'บันทึกข้อมูลไม่สำเร็จ';
      return false;
    } finally {
      isLoading = false;
      _safeNotify();
    }
  }

  Future<bool> updateExpenseType({
    required String id,
    required String token,
    required String name,
    required String code,
    required String refDefaultBudgetSource,
    String remark = '',
    int sort = 0,
    String use = 'Y',
  }) async {
    isLoading = true;
    error = null;
    _safeNotify();
    try {
      final bud = refDefaultBudgetSource.trim();
      if (bud.isEmpty) {
        error = 'ต้องเลือกแหล่งเงินเริ่มต้น';
        return false;
      }
      final budInt = int.tryParse(bud);
      if (budInt == null || budInt <= 0) {
        error = 'รหัสแหล่งเงินไม่ถูกต้อง';
        return false;
      }
      final db = await AppDatabase().database;
      final now = DateTime.now().toIso8601String();
      await db.update(
        'expense_type',
        {
          'code': code.trim(),
          'name': name.trim(),
          'remark': remark.trim(),
          'sort': sort,
          'use': use,
          'refDefaultBudgetSource': bud,
          'synced': 0,
          'lastModified': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await _syncService.addPendingRequest(
        id: 'expense_type_update_$id',
        method: 'PUT',
        endpoint: '${baseurl}expensetype/$id',
        payload: jsonEncode({
          'token': token,
          'code': code.trim(),
          'name': name.trim(),
          'remark': remark.trim(),
          'sort': sort,
          'use': use,
          'refdefaultbudgetsource': budInt,
        }),
      );
      error = null;
      return true;
    } catch (_) {
      error = 'แก้ไขข้อมูลไม่สำเร็จ';
      return false;
    } finally {
      isLoading = false;
      _safeNotify();
    }
  }

  /// ลบประเภทรายจ่าย — ตรวจ FK ก่อนลบ
  Future<bool> deleteExpenseType({
    required String id,
    required String token,
  }) async {
    isLoading = true;
    error = null;
    _safeNotify();
    try {
      final db = await AppDatabase().database;
      // Guard: ตรวจสอบว่ามี expense_sub ที่อ้างอิงอยู่ไหม
      final inUse = await db.query(
        'expense_sub',
        columns: ['id'],
        where: 'refExpenseType = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (inUse.isNotEmpty) {
        error = 'ไม่สามารถลบได้ เพราะมีรายการเบิกจ่ายที่ใช้ประเภทนี้อยู่';
        return false;
      }
      await db.delete('expense_type', where: 'id = ?', whereArgs: [id]);
      await _syncService.addPendingRequest(
        id: 'expense_type_delete_$id',
        method: 'DELETE',
        endpoint: '${baseurl}expensetype/$id',
        payload: jsonEncode({'token': token}),
      );
      error = null;
      return true;
    } catch (_) {
      error = 'ลบข้อมูลไม่สำเร็จ';
      return false;
    } finally {
      isLoading = false;
      _safeNotify();
    }
  }
}
