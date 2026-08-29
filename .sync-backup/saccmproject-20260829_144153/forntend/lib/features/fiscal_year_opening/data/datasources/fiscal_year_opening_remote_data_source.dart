import 'package:dio/dio.dart';
import 'package:saccm/config.dart';
import 'package:saccm/core/error/exceptions.dart';
import '../models/fiscal_year_opening_row.dart';

/// Remote data source — เชื่อมกับ backend `/saccapi/fiscal-year-opening`
class FiscalYearOpeningRemoteDataSource {
  final Dio dio;
  FiscalYearOpeningRemoteDataSource({Dio? dio}) : dio = dio ?? Dio();

  /// GET ?fiscal_year=2569 → คืน 21 rows (7 buckets × 3 pockets)
  Future<List<FiscalYearOpeningRow>> getGrid(String fiscalYear) async {
    try {
      final response = await dio.get(
        '${baseurl}fiscal-year-opening',
        queryParameters: {'fiscal_year': fiscalYear},
      );
      if (response.statusCode == 200) {
        final data = response.data['data'];
        final rows = (data is Map ? data['rows'] : null) as List? ?? const [];
        return rows
            .map((e) =>
                FiscalYearOpeningRow.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      throw const ServerException(message: 'โหลดยอดยกมาไม่สำเร็จ');
    } on DioException catch (e) {
      final msg = (e.response?.data is Map
              ? e.response?.data['message']
              : null) ??
          'Network error';
      throw ServerException(message: msg.toString());
    }
  }

  /// GET /suggested — คำนวณยอด opening จากทรานแซคชันก่อน 1 ต.ค. ของปี-1
  Future<List<FiscalYearOpeningRow>> getSuggested(String fiscalYear) async {
    try {
      final response = await dio.get(
        '${baseurl}fiscal-year-opening/suggested',
        queryParameters: {'fiscal_year': fiscalYear},
      );
      if (response.statusCode == 200) {
        final data = response.data['data'];
        final rows = (data is Map ? data['rows'] : null) as List? ?? const [];
        return rows
            .map((e) =>
                FiscalYearOpeningRow.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      throw const ServerException(message: 'คำนวณยอดยกมาเสนอไม่สำเร็จ');
    } on DioException catch (e) {
      final msg = (e.response?.data is Map
              ? e.response?.data['message']
              : null) ??
          'Network error';
      throw ServerException(message: msg.toString());
    }
  }

  /// POST upsert grid
  Future<void> upsertGrid({
    required String token,
    required String fiscalYear,
    required List<FiscalYearOpeningRow> rows,
  }) async {
    try {
      final response = await dio.post(
        '${baseurl}fiscal-year-opening',
        data: {
          'token': token,
          'fiscal_year': fiscalYear,
          'rows': rows.map((r) => r.toJson()).toList(),
        },
      );
      if (response.data?['status'] != 'successfully') {
        throw ServerException(
            message: response.data?['message']?.toString() ??
                'บันทึกยอดยกมาไม่สำเร็จ');
      }
    } on DioException catch (e) {
      final msg = (e.response?.data is Map
              ? e.response?.data['message']
              : null) ??
          'Network error';
      throw ServerException(message: msg.toString());
    }
  }

  /// POST /copy-from-previous — คัดลอกยอดปลายปี N → ยอดยกมาปี N+1
  Future<void> copyFromPrevious({
    required String token,
    required String fiscalYear,
  }) async {
    try {
      final response = await dio.post(
        '${baseurl}fiscal-year-opening/copy-from-previous',
        data: {
          'token': token,
          'fiscal_year': fiscalYear,
        },
      );
      if (response.data?['status'] != 'successfully') {
        throw ServerException(
            message: response.data?['message']?.toString() ??
                'คัดลอกยอดยกมาไม่สำเร็จ');
      }
    } on DioException catch (e) {
      final msg = (e.response?.data is Map
              ? e.response?.data['message']
              : null) ??
          'Network error';
      throw ServerException(message: msg.toString());
    }
  }
}
