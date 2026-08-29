import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:saccm/config.dart';

/// ดาวน์โหลด PDF จาก backend ที่ /saccapi/forms/*
class FormRemoteDataSource {
  FormRemoteDataSource({Dio? dio}) : _dio = dio ?? Dio();
  final Dio _dio;

  Future<Uint8List> generate(String formKey, Map<String, dynamic> body) async {
    final response = await _dio.post<List<int>>(
      '${baseurl}forms/$formKey',
      data: body,
      options: Options(
        responseType: ResponseType.bytes,
        contentType: 'application/json',
      ),
    );
    final bytes = response.data;
    if (bytes == null) {
      throw Exception('ไม่ได้รับข้อมูลจากเซิร์ฟเวอร์');
    }
    return Uint8List.fromList(bytes);
  }

  Future<String> generateDocNo({
    required String tableName,
    required String docDate,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '${baseurl}docgroup/createdocno',
      queryParameters: {
        'tablename': tableName,
        'docdate': docDate,
      },
    );
    if (response.statusCode != 200) return '';
    return response.data?['docno']?.toString().trim() ?? '';
  }
}
