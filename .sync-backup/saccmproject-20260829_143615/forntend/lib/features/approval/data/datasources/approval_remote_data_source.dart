import 'package:dio/dio.dart';
import 'package:saccm/config.dart';

abstract class ApprovalRemoteDataSource {
  Future<List<dynamic>> fetchByStatus(String status);

  Future<void> approve({
    required String id,
    required String? token,
    required String note,
  });

  Future<void> reject({
    required String id,
    required String? token,
    required String rejectReason,
  });

  Future<List<dynamic>> fetchLog({
    required String refTable,
    required String refId,
  });
}

class ApprovalRemoteDataSourceImpl implements ApprovalRemoteDataSource {
  ApprovalRemoteDataSourceImpl({required this.dio});

  final Dio dio;

  static final Options _formUrlEncoded = Options(
    contentType: Headers.formUrlEncodedContentType,
  );

  @override
  Future<List<dynamic>> fetchByStatus(String status) async {
    final r = await dio.get(
      '${baseurl}approval',
      queryParameters: {'status': status},
    );
    return (r.data['data'] as List? ?? []);
  }

  @override
  Future<void> approve({
    required String id,
    required String? token,
    required String note,
  }) async {
    await dio.post(
      '${baseurl}approval/$id/approve',
      data: {
        'token': token,
        'note': note,
      },
      options: _formUrlEncoded,
    );
  }

  @override
  Future<void> reject({
    required String id,
    required String? token,
    required String rejectReason,
  }) async {
    await dio.post(
      '${baseurl}approval/$id/reject',
      data: {
        'token': token,
        'reject_reason': rejectReason,
      },
      options: _formUrlEncoded,
    );
  }

  @override
  Future<List<dynamic>> fetchLog({
    required String refTable,
    required String refId,
  }) async {
    final r = await dio.get(
      '${baseurl}approval/log',
      queryParameters: {
        'ref_table': refTable,
        'ref_id': refId,
      },
    );
    return (r.data['data'] as List? ?? []);
  }
}
