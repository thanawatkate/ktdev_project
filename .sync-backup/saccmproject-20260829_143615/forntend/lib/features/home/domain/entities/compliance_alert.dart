class ComplianceAlert {
  final String severity;
  final String code;
  final String title;
  final String message;
  final String? dueDate;

  const ComplianceAlert({
    required this.severity,
    required this.code,
    required this.title,
    required this.message,
    this.dueDate,
  });

  factory ComplianceAlert.fromJson(Map<String, dynamic> json) {
    return ComplianceAlert(
      severity: (json['severity'] ?? 'info').toString(),
      code: (json['code'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      dueDate: json['due_date']?.toString(),
    );
  }

  bool get isCritical => severity == 'critical';
  bool get isWarning => severity == 'warning';
}
