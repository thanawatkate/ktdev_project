/// ข้อมูลการตั้งค่า API
class AppConfig {
  final String apiUrl;

  AppConfig({
    required this.apiUrl,
  });

  AppConfig copyWith({
    String? apiUrl,
  }) {
    return AppConfig(
      apiUrl: apiUrl ?? this.apiUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppConfig &&
          runtimeType == other.runtimeType &&
          apiUrl == other.apiUrl;

  @override
  int get hashCode => apiUrl.hashCode;
}
