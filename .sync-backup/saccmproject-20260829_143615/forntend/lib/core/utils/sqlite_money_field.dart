/// Helpers for SQLite monetary columns stored as [REAL] (or legacy TEXT / int).
double sqliteMoneyToDouble(Object? value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().trim()) ?? 0;
}

/// Normalizes DB / JSON values into a decimal string for UI models that use [String].
String sqliteMoneyToString(Object? value) {
  final d = sqliteMoneyToDouble(value);
  if (d == d.roundToDouble()) return d.toInt().toString();
  return d.toString();
}

/// True only for null or blank string — not for numeric zero (REAL default).
bool sqliteMoneyIsBlankStringOrNull(Object? value) {
  if (value == null) return true;
  if (value is String) return value.trim().isEmpty;
  return false;
}
