import 'package:dio/dio.dart';
import 'package:saccm/config.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import '../../../../core/error/exceptions.dart';
import '../models/budget_source_model.dart';

abstract class BudgetSourceRemoteDataSource {
  Future<List<BudgetSourceModel>> getAll({String? fiscalYear});
  Future<void> create({
    required String token,
    required String code,
    required String name,
    required String fiscalYear,
    required double budgetAmount,
    double broughtForwardAmount = 0,
    required String budgetType,
    String? description,
    String? refMoneyGroup,
    String? refBankAccount,
  });
  Future<void> update({required String token, required String id, required Map<String, dynamic> fields});
  Future<void> delete({required String token, required String id});
}

class BudgetSourceRemoteDataSourceImpl implements BudgetSourceRemoteDataSource {
  final Dio dio;
  BudgetSourceRemoteDataSourceImpl({required this.dio});

  @override
  Future<List<BudgetSourceModel>> getAll({String? fiscalYear}) async {
    try {
      final response = await dio.get(
        '${baseurl}budgetsource',
        queryParameters: fiscalYear != null ? {'fiscal_year': fiscalYear} : null,
      );
      if (response.statusCode == 200) {
        final data = response.data['data'] as List? ?? [];
        return data.map((e) => BudgetSourceModel.fromJson(e)).toList();
      }
      throw const ServerException(message: TransactionUiText.loadBudgetSourceFailed);
    } on DioException catch (e) {
      final msg = (e.response?.data is Map ? e.response?.data['message'] : null) ?? 'Network error';
      throw ServerException(message: msg.toString());
    }
  }

  @override
  Future<void> create({
    required String token,
    required String code,
    required String name,
    required String fiscalYear,
    required double budgetAmount,
    double broughtForwardAmount = 0,
    required String budgetType,
    String? description,
    String? refMoneyGroup,
    String? refBankAccount,
  }) async {
    try {
      final response = await dio.post(
        '${baseurl}budgetsource',
        data: {
          'token': token,
          'code': code,
          'name': name,
          'fiscal_year': fiscalYear,
          'fiscalYear': fiscalYear,
          'budget_amount': budgetAmount,
          'budgetAmount': budgetAmount,
          'brought_forward_amount': broughtForwardAmount,
          'broughtForwardAmount': broughtForwardAmount,
          'budget_type': budgetType,
          'budgetType': budgetType,
          if (refMoneyGroup != null && refMoneyGroup.isNotEmpty)
            'refmoneygroup': refMoneyGroup,
          if (refBankAccount != null && refBankAccount.isNotEmpty)
            'refbankaccount': refBankAccount,
          if (description != null) 'description': description,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      if (response.data?['status'] != 'successfully') {
        throw ServerException(message: response.data?['message'] ?? TransactionUiText.createFailed);
      }
    } on DioException catch (e) {
      final msg = (e.response?.data is Map ? e.response?.data['message'] : null) ?? 'Network error';
      throw ServerException(message: msg.toString());
    }
  }

  @override
  Future<void> update({required String token, required String id, required Map<String, dynamic> fields}) async {
    try {
      final response = await dio.patch(
        '${baseurl}budgetsource/$id',
        data: {'token': token, ...fields},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      if (response.data?['status'] != 'successfully') {
        throw ServerException(message: response.data?['message'] ?? TransactionUiText.updateFailed);
      }
    } on DioException catch (e) {
      final msg = (e.response?.data is Map ? e.response?.data['message'] : null) ?? 'Network error';
      throw ServerException(message: msg.toString());
    }
  }

  @override
  Future<void> delete({required String token, required String id}) async {
    try {
      final response = await dio.delete(
        '${baseurl}budgetsource/$id',
        data: {'token': token},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      if (response.data?['status'] != 'successfully') {
        throw ServerException(message: response.data?['message'] ?? TransactionUiText.deleteFailed);
      }
    } on DioException catch (e) {
      final msg = (e.response?.data is Map ? e.response?.data['message'] : null) ?? 'Network error';
      throw ServerException(message: msg.toString());
    }
  }
}
