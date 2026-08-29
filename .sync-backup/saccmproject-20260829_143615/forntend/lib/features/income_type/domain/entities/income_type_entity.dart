class IncomeTypeEntity {
  final int? id;
  final String name;
  final String remark;
  final int? sourceGroupCode;

  const IncomeTypeEntity({
    this.id,
    required this.name,
    this.remark = '',
    this.sourceGroupCode,
  });
}
