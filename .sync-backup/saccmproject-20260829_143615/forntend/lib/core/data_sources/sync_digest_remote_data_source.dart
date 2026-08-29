import 'package:dio/dio.dart';
import 'package:saccm/config.dart';

/// ดึง digest จำนวนแถวจากเซิร์ฟเวอร์ — ใช้เทียบกับ [AppDatabase.getSyncDigestCounts]
class SyncDigestRemoteDataSource {
  SyncDigestRemoteDataSource({required this.dio});

  final Dio dio;

  Future<Map<String, int>> fetchDigest({required String token}) async {
    final response = await dio.get<dynamic>(
      '${baseurl}sync/digest',
      queryParameters: <String, dynamic>{
        'token': token,
      },
      options: Options(
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    if (response.statusCode != 200) {
      throw StateError('digest HTTP ${response.statusCode}');
    }
    final body = response.data;
    if (body is! Map) {
      throw StateError('digest: รูปแบบตอบกลับไม่ถูกต้อง');
    }
    final map = Map<String, dynamic>.from(body);
    if (map['success'] != true) {
      throw StateError(map['message']?.toString() ?? 'digest ไม่สำเร็จ');
    }
    final raw = map['counts'];
    if (raw is! Map) return {};
    final out = <String, int>{};
    for (final e in raw.entries) {
      final v = e.value;
      final n = v is int ? v : int.tryParse(v.toString()) ?? -1;
      out[e.key.toString()] = n;
    }
    return out;
  }
}
