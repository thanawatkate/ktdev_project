import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/school_profile.dart';

/// อ่าน/เขียนข้อมูลโรงเรียนลง SharedPreferences (ไม่ผูก FK — ข้อมูลอ้างอิงบนเครื่อง)
abstract class SchoolProfileLocalDataSource {
  Future<SchoolProfile> load();
  Future<void> save(SchoolProfile profile);
}

class SchoolProfileLocalDataSourceImpl implements SchoolProfileLocalDataSource {
  static const String _nameKey = 'school_profile_name';
  static const String _addressKey = 'school_profile_address';
  static const String _phoneKey = 'school_profile_phone';
  static const String _extraKey = 'school_profile_extra';

  late SharedPreferences _prefs;
  bool _initialized = false;

  Future<void> _ensure() async {
    if (!_initialized) {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
    }
  }

  @override
  Future<SchoolProfile> load() async {
    await _ensure();
    return SchoolProfile(
      name: _prefs.getString(_nameKey) ?? '',
      address: _prefs.getString(_addressKey) ?? '',
      phone: _prefs.getString(_phoneKey) ?? '',
      extra: _prefs.getString(_extraKey) ?? '',
    );
  }

  @override
  Future<void> save(SchoolProfile profile) async {
    await _ensure();
    await _prefs.setString(_nameKey, profile.name.trim());
    await _prefs.setString(_addressKey, profile.address.trim());
    await _prefs.setString(_phoneKey, profile.phone.trim());
    await _prefs.setString(_extraKey, profile.extra.trim());
  }
}
