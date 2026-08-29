import 'package:dio/dio.dart';
import 'package:saccm/config.dart';

class ChequeAccountRemoteDataSource {
  ChequeAccountRemoteDataSource({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<Map<String, dynamic>> create({
    required String token,
    required String chequeno,
    required String chequename,
    required String refBank,
    int sort = 0,
    String use = 'Y',
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '${baseurl}chequeaccount',
      data: {
        'token': token,
        'chequeno': chequeno,
        'chequemame': chequename,
        'chequename': chequename,
        'refbank': refBank,
        'sort': sort,
        'use': use,
      },
    );
    return Map<String, dynamic>.from(r.data ?? const {});
  }

  Future<Map<String, dynamic>> update({
    required String id,
    required String token,
    String? chequeno,
    String? chequename,
    String? refBank,
    int? sort,
    String? use,
  }) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '${baseurl}chequeaccount/$id',
      data: {
        'token': token,
        if (chequeno != null) 'chequeno': chequeno,
        if (chequename != null) ...{
          'chequemame': chequename,
          'chequename': chequename,
        },
        if (refBank != null) 'refbank': refBank,
        if (sort != null) 'sort': sort,
        if (use != null) 'use': use,
      },
    );
    return Map<String, dynamic>.from(r.data ?? const {});
  }

  Future<Map<String, dynamic>> remove({
    required String id,
    required String token,
  }) async {
    final r = await _dio.delete<Map<String, dynamic>>(
      '${baseurl}chequeaccount/$id',
      data: {'token': token},
    );
    return Map<String, dynamic>.from(r.data ?? const {});
  }
}
