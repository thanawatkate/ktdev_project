import '../domain/entities/school_profile.dart';

/// บรรทัดนำ (# comment) สำหรับไฟล์ CSV — โปรแกรมสเปรดชีตมักยังอ่านได้
List<String> schoolProfileCsvCommentLines(SchoolProfile p) {
  String oneLine(String s) =>
      s.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();

  final out = <String>[];
  if (p.name.isNotEmpty) {
    out.add('# school_name: ${oneLine(p.name)}');
  }
  if (p.address.isNotEmpty) {
    out.add('# school_address: ${oneLine(p.address)}');
  }
  if (p.phone.isNotEmpty) {
    out.add('# school_phone: ${oneLine(p.phone)}');
  }
  if (p.extra.isNotEmpty) {
    out.add('# school_extra: ${oneLine(p.extra)}');
  }
  return out;
}
