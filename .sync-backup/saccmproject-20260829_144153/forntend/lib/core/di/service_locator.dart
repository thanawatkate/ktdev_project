import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saccm/core/services/network_info_service.dart';
import 'package:saccm/core/services/sync_service.dart';
import 'package:saccm/core/local_data_source/approval_local_data_source.dart';
import 'package:saccm/core/local_data_source/app_database.dart';
import 'package:saccm/core/local_data_source/expense_req_local_data_source.dart';
import 'package:saccm/core/local_data_source/base_local_data_source.dart';
import 'package:saccm/core/local_data_source/audit_log_local_data_source.dart';
import 'package:saccm/core/local_data_source/income_local_data_source.dart';
import 'package:saccm/core/local_data_source/expense_local_data_source.dart';
import 'package:saccm/core/local_data_source/member_local_data_source.dart';
import 'package:saccm/core/local_data_source/loan_local_data_source.dart';
import 'package:saccm/core/local_data_source/repay_loan_local_data_source.dart';
import 'package:saccm/core/local_data_source/lookup_item_local_data_source.dart';
import 'package:saccm/core/local_data_source/bank_account_local_data_source.dart';
import 'package:saccm/core/local_data_source/doc_group_local_data_source.dart';
import 'package:saccm/features/income/data/datasources/income_remote_data_source.dart';
import 'package:saccm/features/expense/data/datasources/expense_remote_data_source.dart';
import 'package:saccm/features/income/data/repositories/income_repository_offline.dart';
import 'package:saccm/features/expense/data/repositories/expense_repository_offline.dart';
import 'package:saccm/features/member/data/datasources/member_remote_data_source.dart';
import 'package:saccm/features/member/data/repositories/member_repository_offline.dart';
import 'package:saccm/features/approval/data/datasources/approval_remote_data_source.dart';
import 'package:saccm/features/approval/data/repositories/approval_repository.dart';
import 'package:saccm/features/expense_req/data/datasources/expense_req_remote_data_source.dart';
import 'package:saccm/features/expense_req/data/repositories/expense_req_repository.dart';
import 'package:saccm/features/loan/data/repositories/loan_repository_offline.dart';
import 'package:saccm/features/loan/data/repositories/repay_loan_repository_offline.dart';
import 'package:saccm/features/income_type/data/repositories/lookup_item_repository_offline.dart';
import 'package:saccm/core/services/backup_restore_service.dart';
import 'package:saccm/features/register/data/datasources/register_local_data_source.dart';
import 'package:saccm/features/register/data/datasources/register_remote_data_source.dart';
import 'package:saccm/features/register/data/repositories/deposit_register_repository_offline.dart';
import 'package:saccm/features/register/data/repositories/receipt_book_register_repository_offline.dart';

// For now, we'll create a simple service locator without all dependencies
// This will be expanded as we migrate more features

class ServiceLocator {
  static ServiceLocator? _instance;
  static ServiceLocator get instance => _instance ??= ServiceLocator._();

  ServiceLocator._();

  final Map<Type, dynamic> _services = {};

  // Register services
  Future<void> init() async {
    // External dependencies
    final sharedPreferences = await SharedPreferences.getInstance();
    _services[SharedPreferences] = sharedPreferences;

    final dio = Dio();
    // Do NOT set baseUrl here — remote data sources build absolute URLs from
    // config.dart's `baseurl`, and SyncService also stores absolute URLs in
    // the pending queue.  Setting a baseUrl would corrupt those absolute URLs.
    dio.options.connectTimeout = const Duration(seconds: 5);
    dio.options.receiveTimeout = const Duration(seconds: 10);
    _services[Dio] = dio;

    final approvalLocalDataSource = ApprovalLocalDataSource();
    _services[ApprovalLocalDataSource] = approvalLocalDataSource;

    final approvalRemoteDataSource = ApprovalRemoteDataSourceImpl(dio: dio);
    _services[ApprovalRemoteDataSource] = approvalRemoteDataSource;

    _services[ApprovalRepository] = ApprovalRepository(
      remoteDataSource: approvalRemoteDataSource,
      localDataSource: approvalLocalDataSource,
    );

    final expenseReqLocalDataSource = ExpenseReqLocalDataSource();
    await expenseReqLocalDataSource.init();
    _services[ExpenseReqLocalDataSource] = expenseReqLocalDataSource;

    final expenseReqRemoteDataSource = ExpenseReqRemoteDataSourceImpl(dio: dio);
    _services[ExpenseReqRemoteDataSource] = expenseReqRemoteDataSource;

    // ─── Offline Support Services ───────────────────────────────────────

    // Network Info Service
    final networkInfo = NetworkInfoServiceImpl();
    _services[NetworkInfoService] = networkInfo;

    // Pending Requests Service
    final pendingService = PendingRequestsService();
    await pendingService.init();
    _services[PendingRequestsService] = pendingService;

    // Offline Data Sources
    final incomeLocalDataSource = IncomeLocalDataSource();
    await incomeLocalDataSource.init();
    _services[IncomeLocalDataSource] = incomeLocalDataSource;

    final auditLogLocalDataSource = AuditLogLocalDataSource();
    await auditLogLocalDataSource.init();
    _services[AuditLogLocalDataSource] = auditLogLocalDataSource;

    // Remote Data Sources
    final incomeRemoteDataSource = IncomeRemoteDataSourceImpl(dio: dio);
    _services[IncomeRemoteDataSource] = incomeRemoteDataSource;
    final expenseRemoteDataSource = ExpenseRemoteDataSourceImpl(dio: dio);
    _services[ExpenseRemoteDataSource] = expenseRemoteDataSource;
    final memberRemoteDataSource = MemberRemoteDataSourceImpl(dio: dio);
    _services[MemberRemoteDataSource] = memberRemoteDataSource;

    // Expense Local Data Source
    final expenseLocalDataSource = ExpenseLocalDataSource();
    await expenseLocalDataSource.init();
    _services[ExpenseLocalDataSource] = expenseLocalDataSource;

    // Member Local Data Source
    final memberLocalDataSource = MemberLocalDataSource();
    await memberLocalDataSource.init();
    _services[MemberLocalDataSource] = memberLocalDataSource;

    // Loan Local Data Source
    final loanLocalDataSource = LoanLocalDataSource();
    await loanLocalDataSource.init();
    _services[LoanLocalDataSource] = loanLocalDataSource;

    // Repay Loan Local Data Source
    final repayLoanLocalDataSource = RepayLoanLocalDataSource();
    await repayLoanLocalDataSource.init();
    _services[RepayLoanLocalDataSource] = repayLoanLocalDataSource;

    // Lookup Item Local Data Sources
    final moneyTypeLocalDataSource = MoneyTypeLocalDataSource();
    await moneyTypeLocalDataSource.init();
    _services[MoneyTypeLocalDataSource] = moneyTypeLocalDataSource;

    final incomeTypeLocalDataSource = IncomeTypeLocalDataSource();
    await incomeTypeLocalDataSource.init();
    _services[IncomeTypeLocalDataSource] = incomeTypeLocalDataSource;

    final bankAccountLocalDataSource = BankAccountLocalDataSource();
    await bankAccountLocalDataSource.init();
    _services[BankAccountLocalDataSource] = bankAccountLocalDataSource;

    late final IncomeRepository incomeRepository;
    late final LoanRepository loanRepository;
    late final RepayLoanRepository repayLoanRepository;

    String? tokenFromPartyPendingPayload(String? payload) {
      if (payload == null || payload.isEmpty) return null;
      try {
        final m = jsonDecode(payload);
        if (m is Map<String, dynamic>) return m['token']?.toString();
        if (m is Map) return m['token']?.toString();
      } catch (_) {}
      return null;
    }

    // Sync Service
    late final SyncService syncService;
    syncService = SyncService(
      networkInfo: networkInfo,
      pendingService: pendingService,
      dio: dio,
      onRequestSynced: (request, response) async {
        if (request.id.startsWith('party_create_')) {
          final localId = request.id.substring('party_create_'.length);
          Map<String, dynamic> body = {};
          final d = response?.data;
          if (d is Map) body = Map<String, dynamic>.from(d);
          await incomeRepository.applyPartyCreateSyncSuccess(
            localId,
            body,
            queueToken: tokenFromPartyPendingPayload(request.payload),
          );
          return;
        }
        if (request.id.startsWith('party_patch:')) {
          final tail = request.id.substring('party_patch:'.length);
          final serverPartyId = tail.split(':').first;
          await incomeRepository.applyPartyPatchSyncSuccess(serverPartyId);
          return;
        }
        if (request.id.startsWith('party_delete:')) {
          // แถว party ลบในเครื่องไปแล้วตอนคิว — ไม่ต้องทำเพิ่ม
          return;
        }

        if (request.id.startsWith('income_create_') ||
            request.id.startsWith('income_upsert_')) {
          final entityId = request.id
              .replaceFirst('income_create_', '')
              .replaceFirst('income_upsert_', '');
          await incomeLocalDataSource.markAsSynced(entityId);
          return;
        }

        if (request.id.startsWith('expense_create_') ||
            request.id.startsWith('expense_upsert_')) {
          final entityId = request.id
              .replaceFirst('expense_create_', '')
              .replaceFirst('expense_upsert_', '');
          await expenseLocalDataSource.markAsSynced(entityId);
          return;
        }

        if (request.id.startsWith('member_create_') ||
            request.id.startsWith('member_upsert_')) {
          final entityId = request.id
              .replaceFirst('member_create_', '')
              .replaceFirst('member_upsert_', '');
          await memberLocalDataSource.markAsSynced(entityId);
          return;
        }

        if (request.id.startsWith('loan_create_')) {
          final localId = request.id.replaceFirst('loan_create_', '');
          Map<String, dynamic> body = {};
          final d = response?.data;
          if (d is Map) body = Map<String, dynamic>.from(d);
          await loanRepository.applyCreateSyncSuccess(localId, body);
          return;
        }
        if (request.id.startsWith('loan_update_') ||
            request.id.startsWith('loan_upsert_')) {
          final entityId = request.id
              .replaceFirst('loan_update_', '')
              .replaceFirst('loan_upsert_', '');
          await loanRepository.applyUpdateSyncSuccess(entityId);
          return;
        }

        if (request.id.startsWith('repay_loan_create_')) {
          final localId = request.id.replaceFirst('repay_loan_create_', '');
          Map<String, dynamic> body = {};
          final d = response?.data;
          if (d is Map) body = Map<String, dynamic>.from(d);
          await repayLoanRepository.applyCreateSyncSuccess(localId, body);
          return;
        }
        if (request.id.startsWith('repay_loan_update_') ||
            request.id.startsWith('repay_loan_upsert_')) {
          final entityId = request.id
              .replaceFirst('repay_loan_update_', '')
              .replaceFirst('repay_loan_upsert_', '');
          await repayLoanRepository.applyUpdateSyncSuccess(entityId);
          return;
        }

        if (request.id.startsWith('bank_account_create_')) {
          final entityId = request.id.replaceFirst('bank_account_create_', '');
          await bankAccountLocalDataSource.markAsSynced(entityId);
          return;
        }

        if (request.id.startsWith('deposit_receive_')) {
          final localId = request.id.replaceFirst('deposit_receive_', '');
          Map<String, dynamic> body = {};
          final d = response?.data;
          if (d is Map) body = Map<String, dynamic>.from(d);
          final depositRepo = DepositRegisterRepositoryOffline(
            remote: RegisterRemoteDataSource(dio: dio),
            local: RegisterLocalDataSource(),
            networkInfo: networkInfo,
            syncService: syncService,
          );
          await depositRepo.applyReceiveSyncSuccess(localId, body);
          return;
        }

        if (request.id.startsWith('receipt_book_create_')) {
          final localId = request.id.replaceFirst('receipt_book_create_', '');
          Map<String, dynamic> body = {};
          final d = response?.data;
          if (d is Map) body = Map<String, dynamic>.from(d);
          final receiptBookRepo = ReceiptBookRegisterRepositoryOffline(
            remote: RegisterRemoteDataSource(dio: dio),
            local: RegisterLocalDataSource(),
            docGroupLocal: DocGroupLocalDataSource(),
            networkInfo: networkInfo,
            syncService: syncService,
          );
          await receiptBookRepo.applyCreateSyncSuccess(localId, body);
          return;
        }

        if (request.id.startsWith('receipt_book_patch_')) {
          final receiptBookId =
              request.id.replaceFirst('receipt_book_patch_', '');
          await RegisterLocalDataSource().markReceiptBookSynced(
            receiptBookId,
          );
          return;
        }

        if (request.id.startsWith('deposit_return_')) {
          Map<String, dynamic> body = {};
          final d = response?.data;
          if (d is Map) body = Map<String, dynamic>.from(d);
          final depositRepo = DepositRegisterRepositoryOffline(
            remote: RegisterRemoteDataSource(dio: dio),
            local: RegisterLocalDataSource(),
            networkInfo: networkInfo,
            syncService: syncService,
          );
          await depositRepo.applyReturnSyncSuccess(body);
          return;
        }

        if (request.id.startsWith('deposit_patch_')) {
          final depositId = request.id.replaceFirst('deposit_patch_', '');
          final depositRepo = DepositRegisterRepositoryOffline(
            remote: RegisterRemoteDataSource(dio: dio),
            local: RegisterLocalDataSource(),
            networkInfo: networkInfo,
            syncService: syncService,
          );
          await depositRepo.applyPatchSyncSuccess(depositId);
          return;
        }

        if (request.id.startsWith('deposit_delete_')) {
          // ลบ local ไปแล้วตอน enqueue; sync สำเร็จไม่ต้องทำอะไรเพิ่ม
          return;
        }

        if (request.id.startsWith('finance_daily_close_')) {
          final closeDate = request.id.replaceFirst('finance_daily_close_', '');
          final db = await AppDatabase().database;
          await db.update(
            'daily_closing',
            {'synced': 1},
            where: 'close_date = ?',
            whereArgs: [closeDate],
          );
          return;
        }

        if (request.id.startsWith('bank_recon_note_')) {
          final localId = request.id.replaceFirst('bank_recon_note_', '');
          final db = await AppDatabase().database;
          await db.update(
            'bank_reconciliation_adjustment',
            {'synced': 1},
            where: 'id = ?',
            whereArgs: [localId],
          );
          return;
        }
      },
    );
    _services[SyncService] = syncService;

    _services[ApprovalRepository] = ApprovalRepository(
      remoteDataSource: approvalRemoteDataSource,
      localDataSource: approvalLocalDataSource,
      syncService: syncService,
    );

    _services[DepositRegisterRepositoryOffline] =
        DepositRegisterRepositoryOffline(
      remote: RegisterRemoteDataSource(dio: dio),
      local: RegisterLocalDataSource(),
      networkInfo: networkInfo,
      syncService: syncService,
    );
    _services[ReceiptBookRegisterRepositoryOffline] =
        ReceiptBookRegisterRepositoryOffline(
      remote: RegisterRemoteDataSource(dio: dio),
      local: RegisterLocalDataSource(),
      docGroupLocal: DocGroupLocalDataSource(),
      networkInfo: networkInfo,
      syncService: syncService,
    );

    final expenseReqRepository = ExpenseReqRepository(
      localDataSource: expenseReqLocalDataSource,
      remoteDataSource: expenseReqRemoteDataSource,
      networkInfo: networkInfo,
      syncService: syncService,
      auditLogLocalDataSource: auditLogLocalDataSource,
    );
    _services[ExpenseReqRepository] = expenseReqRepository;

    syncService.registerExpenseReqPendingHandler((request) async {
      if (request.id.startsWith('expense_req_submit_')) {
        final localId = request.id.replaceFirst('expense_req_submit_', '');
        final row = await expenseReqLocalDataSource.getById(localId);
        final serverId = row?.serverId?.trim();
        if (serverId == null || serverId.isEmpty) {
          throw Exception('รอ sync ใบขอเบิกก่อนส่งขออนุมัติ');
        }
        Map<String, dynamic> body = {};
        if (request.payload != null && request.payload!.isNotEmpty) {
          body = Map<String, dynamic>.from(jsonDecode(request.payload!) as Map);
        }
        final res = await expenseReqRemoteDataSource.submitForApproval(
          serverId: serverId,
          token: body['token']?.toString() ?? '',
          note: body['note']?.toString(),
        );
        if (res['status']?.toString() != 'successfully') {
          throw Exception(
              res['message']?.toString() ?? 'ส่งขออนุมัติไม่สำเร็จ');
        }
        await expenseReqRepository.applySubmitSyncSuccess(localId);
        return;
      }
      if (request.id.startsWith('expense_req_create_')) {
        Map<String, dynamic> body = {};
        if (request.payload != null && request.payload!.isNotEmpty) {
          body = Map<String, dynamic>.from(jsonDecode(request.payload!) as Map);
        }
        final localId = body['_localId']?.toString() ??
            request.id.replaceFirst('expense_req_create_', '');
        final res = await expenseReqRemoteDataSource.create(
          token: body['token']?.toString() ?? '',
          docno: body['docno']?.toString() ?? '',
          refmember: body['refmember']?.toString() ?? '',
          subdataJson: body['subdata']?.toString() ?? '[]',
          remark: body['remark']?.toString(),
        );
        if (res['status']?.toString() != 'successfully') {
          throw Exception(
              res['message']?.toString() ?? 'สร้างใบขอเบิกไม่สำเร็จ');
        }
        await expenseReqRepository.applyCreateSyncSuccess(localId, res);
        return;
      }
      if (request.id.startsWith('expense_req_update_')) {
        final localId = request.id.replaceFirst('expense_req_update_', '');
        final row = await expenseReqLocalDataSource.getById(localId);
        final serverId = row?.serverId?.trim();
        if (serverId == null || serverId.isEmpty) {
          throw Exception('รอ sync ใบขอเบิกก่อนอัปเดต');
        }
        Map<String, dynamic> body = {};
        if (request.payload != null && request.payload!.isNotEmpty) {
          body = Map<String, dynamic>.from(jsonDecode(request.payload!) as Map);
        }
        final res = await expenseReqRemoteDataSource.update(
          serverId: serverId,
          token: body['token']?.toString() ?? '',
          body: body..remove('_localId'),
        );
        if (res['status']?.toString() != 'successfully') {
          throw Exception(
              res['message']?.toString() ?? 'อัปเดตใบขอเบิกไม่สำเร็จ');
        }
        await expenseReqRepository.applyUpdateSyncSuccess(localId);
        return;
      }
      if (request.id.startsWith('expense_req_delete_')) {
        Map<String, dynamic> body = {};
        if (request.payload != null && request.payload!.isNotEmpty) {
          body = Map<String, dynamic>.from(jsonDecode(request.payload!) as Map);
        }
        final res = await expenseReqRemoteDataSource.delete(
          serverId: request.endpoint.split('/').last,
          token: body['token']?.toString() ?? '',
          docno: body['docno']?.toString(),
        );
        if (res['status']?.toString() != 'successfully') {
          throw Exception(res['message']?.toString() ?? 'ลบใบขอเบิกไม่สำเร็จ');
        }
      }
    });

    // ─── Repositories with Offline Support ──────────────────────────────

    // Income Repository
    incomeRepository = IncomeRepository(
      remoteDataSource: incomeRemoteDataSource,
      localDataSource: incomeLocalDataSource,
      auditLogLocalDataSource: auditLogLocalDataSource,
      networkInfo: networkInfo,
      syncService: syncService,
    );
    _services[IncomeRepository] = incomeRepository;

    // Expense Repository
    final expenseRepository = ExpenseRepository(
      localDataSource: expenseLocalDataSource,
      auditLogLocalDataSource: auditLogLocalDataSource,
      networkInfo: networkInfo,
      syncService: syncService,
      remoteDataSource: expenseRemoteDataSource,
    );
    _services[ExpenseRepository] = expenseRepository;

    // Member Repository
    final memberRepository = MemberRepository(
      localDataSource: memberLocalDataSource,
      networkInfo: networkInfo,
      syncService: syncService,
      remoteDataSource: memberRemoteDataSource,
    );
    _services[MemberRepository] = memberRepository;

    // Lookup Item Repository
    final lookupItemRepository = LookupItemRepository(
      moneyTypeLocalDataSource: moneyTypeLocalDataSource,
      incomeTypeLocalDataSource: incomeTypeLocalDataSource,
      networkInfo: networkInfo,
      remoteDataSource: incomeRemoteDataSource,
    );
    _services[LookupItemRepository] = lookupItemRepository;

    // Loan Repository
    loanRepository = LoanRepository(
      localDataSource: loanLocalDataSource,
      auditLogLocalDataSource: auditLogLocalDataSource,
      syncService: syncService,
    );
    _services[LoanRepository] = loanRepository;

    repayLoanRepository = RepayLoanRepository(
      localDataSource: repayLoanLocalDataSource,
      auditLogLocalDataSource: auditLogLocalDataSource,
      syncService: syncService,
    );
    _services[RepayLoanRepository] = repayLoanRepository;

    _services[BackupRestoreService] = BackupRestoreService(
      networkInfo: networkInfo,
      syncService: syncService,
      pendingService: pendingService,
      prefs: sharedPreferences,
      dio: dio,
    );
  }

  // Get service
  T get<T>() {
    final service = _services[T];
    if (service == null) {
      throw Exception('Service of type $T is not registered');
    }
    return service as T;
  }

  // Register service
  void register<T>(T service) {
    _services[T] = service;
  }

  // Remove service
  void unregister<T>() {
    _services.remove(T);
  }

  // Clear all services
  void clear() {
    _services.clear();
  }
}
