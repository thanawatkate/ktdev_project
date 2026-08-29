class AppDateFormat {
  /// "พุธ 6 พฤษภาคม 2569"
  static const String thaiBuddhist = 'thai_buddhist';

  /// "6 พ.ค. 2569"
  static const String thaiBuddhistShort = 'thai_buddhist_short';

  /// "6/5/2569"
  static const String numericBuddhist = 'numeric_buddhist';

  /// "06/05/2026" (Gregorian) — สำหรับ legacy หรือกรณีที่ต้องแสดง ค.ศ. จริง ๆ เท่านั้น
  static const String numeric = 'dd/MM/yyyy';
}

class ThaiDateFormatter {
  static const List<String> _thaiWeekdays = [
    'จันทร์',
    'อังคาร',
    'พุธ',
    'พฤหัสบดี',
    'ศุกร์',
    'เสาร์',
    'อาทิตย์',
  ];

  static const List<String> _thaiMonths = [
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม',
  ];

  static const List<String> _thaiMonthsShort = [
    'ม.ค.',
    'ก.พ.',
    'มี.ค.',
    'เม.ย.',
    'พ.ค.',
    'มิ.ย.',
    'ก.ค.',
    'ส.ค.',
    'ก.ย.',
    'ต.ค.',
    'พ.ย.',
    'ธ.ค.',
  ];

  static int toBuddhistYear(int gregorianYear) => gregorianYear + 543;

  static DateTime? parse(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    final text = raw.toString().trim();
    if (text.isEmpty) return null;

    final parsed = DateTime.tryParse(text);
    if (parsed != null) return parsed;

    final slash = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{2,4})$').firstMatch(text);
    if (slash == null) return null;

    final day = int.tryParse(slash.group(1)!);
    final month = int.tryParse(slash.group(2)!);
    var year = int.tryParse(slash.group(3)!);
    if (day == null || month == null || year == null) return null;

    if (year < 100) year += 2500;
    if (year > 2400) year -= 543;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime(year, month, day);
  }

  /// ค่า ISO สำหรับเก็บ/query เท่านั้น ไม่ใช้เป็นข้อความแสดงผลต่อผู้ใช้
  static String toIsoDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String format(dynamic raw, {String fallback = '-'}) {
    final date = parse(raw);
    if (date == null) return fallback;
    return short(date);
  }

  static String formatFull(dynamic raw, {String fallback = '-'}) {
    final date = parse(raw);
    if (date == null) return fallback;
    return full(date);
  }

  static String formatDateTime(dynamic raw, {String fallback = '-'}) {
    final date = parse(raw);
    if (date == null) return fallback;
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '${short(date)} $hh:$mm น.';
  }

  static String formatByPattern(
    DateTime date,
    String pattern, {
    bool fallbackToThai = true,
  }) {
    switch (pattern) {
      case AppDateFormat.thaiBuddhist:
        return full(date);
      case AppDateFormat.thaiBuddhistShort:
        return short(date);
      case AppDateFormat.numericBuddhist:
        return numeric(date);
      case AppDateFormat.numeric:
        return _gregorianNumeric(date);
      default:
        return fallbackToThai ? full(date) : _gregorianNumeric(date);
    }
  }

  /// "พุธ 6 พฤษภาคม 2569"
  static String full(DateTime date) {
    final weekday = _thaiWeekdays[date.weekday - 1];
    final month = _thaiMonths[date.month - 1];
    final year = toBuddhistYear(date.year);
    return '$weekday ${date.day} $month $year';
  }

  /// "6 พ.ค. 2569"
  static String short(DateTime date) {
    final month = _thaiMonthsShort[date.month - 1];
    final year = toBuddhistYear(date.year);
    return '${date.day} $month $year';
  }

  /// "6/5/2569"
  static String numeric(DateTime date) {
    final year = toBuddhistYear(date.year);
    return '${date.day}/${date.month}/$year';
  }

  static String _gregorianNumeric(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString().padLeft(4, '0');
    return '$d/$m/$y';
  }
}
