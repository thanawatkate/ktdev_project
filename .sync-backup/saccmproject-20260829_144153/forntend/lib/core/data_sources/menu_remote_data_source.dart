import 'package:dio/dio.dart';
import 'package:saccm/config.dart';

/// ดึง/บันทึกเมนูบนเซิร์ฟเวอร์ (ต้องมี JWT จริง — ไม่ใช่โทเคน local_)
class MenuRemoteDataSource {
  MenuRemoteDataSource({required this.dio});

  final Dio dio;

  Future<List<Map<String, dynamic>>> fetchAllRows(String token) async {
    final r = await dio.get<Map<String, dynamic>>(
      '${baseurl}menu/rows',
      queryParameters: <String, dynamic>{'token': token},
    );
    final body = r.data;
    if (body == null || body['success'] != true) {
      throw Exception(body?['message']?.toString() ?? 'โหลดเมนูจากเซิร์ฟเวอร์ไม่สำเร็จ');
    }
    final list = body['data'];
    if (list is! List) return <Map<String, dynamic>>[];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> saveBulk(
    String token,
    List<Map<String, dynamic>> rows,
  ) async {
    final r = await dio.put<Map<String, dynamic>>(
      '${baseurl}menu/bulk',
      data: <String, dynamic>{'token': token, 'rows': rows},
    );
    final body = r.data;
    if (body == null || body['success'] != true) {
      throw Exception(body?['message']?.toString() ?? 'บันทึกเมนูบนเซิร์ฟเวอร์ไม่สำเร็จ');
    }
    final list = body['data'];
    if (list is! List) return <Map<String, dynamic>>[];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
