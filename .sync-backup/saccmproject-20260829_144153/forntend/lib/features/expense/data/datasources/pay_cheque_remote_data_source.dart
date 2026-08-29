import 'package:dio/dio.dart';
import 'package:saccm/config.dart';

class PayChequeRemoteDataSource {
  PayChequeRemoteDataSource({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<Map<String, dynamic>> markCleared({
    required String id,
    required String token,
    DateTime? clearedAt,
  }) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '${baseurl}paycheque/$id',
      data: {
        'token': token,
        'cleared_at': (clearedAt ?? DateTime.now()).toIso8601String(),
      },
    );
    return Map<String, dynamic>.from(r.data ?? const {});
  }
}
