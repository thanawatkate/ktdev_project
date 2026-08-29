import 'package:dio/dio.dart';
import 'package:saccm/config.dart';

abstract class ExpenseReqRemoteDataSource {
  Future<Map<String, dynamic>> create({
    required String token,
    required String docno,
    required String refmember,
    required String subdataJson,
    String? remark,
  });

  Future<Map<String, dynamic>> submitForApproval({
    required String serverId,
    required String token,
    String? note,
  });

  Future<Map<String, dynamic>> update({
    required String serverId,
    required String token,
    required Map<String, dynamic> body,
  });

  Future<Map<String, dynamic>> delete({
    required String serverId,
    required String token,
    String? docno,
  });
}

class ExpenseReqRemoteDataSourceImpl implements ExpenseReqRemoteDataSource {
  ExpenseReqRemoteDataSourceImpl({required this.dio});

  final Dio dio;

  static final Options _formUrlEncoded = Options(
    contentType: Headers.formUrlEncodedContentType,
  );

  @override
  Future<Map<String, dynamic>> create({
    required String token,
    required String docno,
    required String refmember,
    required String subdataJson,
    String? remark,
  }) async {
    final r = await dio.post(
      '${baseurl}expensereq',
      data: {
        'token': token,
        'docno': docno,
        'refmember': refmember,
        'subdata': subdataJson,
        if (remark != null && remark.isNotEmpty) 'remark': remark,
      },
      options: _formUrlEncoded,
    );
    return Map<String, dynamic>.from(r.data as Map? ?? {});
  }

  @override
  Future<Map<String, dynamic>> submitForApproval({
    required String serverId,
    required String token,
    String? note,
  }) async {
    final r = await dio.post(
      '${baseurl}approval/$serverId/submit',
      data: {
        'token': token,
        if (note != null && note.isNotEmpty) 'note': note,
      },
      options: _formUrlEncoded,
    );
    return Map<String, dynamic>.from(r.data as Map? ?? {});
  }

  @override
  Future<Map<String, dynamic>> update({
    required String serverId,
    required String token,
    required Map<String, dynamic> body,
  }) async {
    final r = await dio.patch(
      '${baseurl}expensereq/$serverId',
      data: {
        ...body,
        'token': token,
      },
      options: _formUrlEncoded,
    );
    return Map<String, dynamic>.from(r.data as Map? ?? {});
  }

  @override
  Future<Map<String, dynamic>> delete({
    required String serverId,
    required String token,
    String? docno,
  }) async {
    final r = await dio.delete(
      '${baseurl}expensereq/$serverId',
      data: {
        'token': token,
        if (docno != null && docno.isNotEmpty) 'docno': docno,
      },
      options: _formUrlEncoded,
    );
    return Map<String, dynamic>.from(r.data as Map? ?? {});
  }
}
