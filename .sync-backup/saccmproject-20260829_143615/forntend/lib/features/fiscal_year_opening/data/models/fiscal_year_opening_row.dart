/// FiscalYearOpeningRow — โมเดลข้อมูลยอดยกมา 1 slot (bucket × pocket)
class FiscalYearOpeningRow {
  final String? id;
  final String fiscalYear;
  final String bucket;
  final String pocket;
  final double openingAmount;
  final String? remark;
  final String source;
  final String use;

  const FiscalYearOpeningRow({
    this.id,
    required this.fiscalYear,
    required this.bucket,
    required this.pocket,
    required this.openingAmount,
    this.remark,
    this.source = 'manual',
    this.use = 'Y',
  });

  factory FiscalYearOpeningRow.fromJson(Map<String, dynamic> json) {
    return FiscalYearOpeningRow(
      id: json['id']?.toString(),
      fiscalYear: json['fiscal_year']?.toString() ?? '',
      bucket: json['bucket']?.toString() ?? '',
      pocket: json['pocket']?.toString() ?? '',
      openingAmount:
          double.tryParse(json['opening_amount']?.toString() ?? '0') ?? 0,
      remark: json['remark']?.toString(),
      source: json['source']?.toString() ?? 'manual',
      use: json['use']?.toString() ?? 'Y',
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'fiscal_year': fiscalYear,
        'bucket': bucket,
        'pocket': pocket,
        'opening_amount': openingAmount,
        'remark': remark,
        'source': source,
        'use': use,
      };

  FiscalYearOpeningRow copyWith({
    String? id,
    String? fiscalYear,
    String? bucket,
    String? pocket,
    double? openingAmount,
    String? remark,
    String? source,
    String? use,
  }) {
    return FiscalYearOpeningRow(
      id: id ?? this.id,
      fiscalYear: fiscalYear ?? this.fiscalYear,
      bucket: bucket ?? this.bucket,
      pocket: pocket ?? this.pocket,
      openingAmount: openingAmount ?? this.openingAmount,
      remark: remark ?? this.remark,
      source: source ?? this.source,
      use: use ?? this.use,
    );
  }
}

/// คงที่ของ bucket/pocket ตามคู่มือการเงินหน้า 34
/// แก้ฝั่ง backend ก็ต้องแก้ที่ `fiscal_year_opening.service.js` ด้วย
class FiscalYearOpeningConst {
  static const List<String> buckets = <String>[
    'budget',
    'state_revenue',
    'offbudget',
    'general_subsidy',
    'school_revenue',
    'withholding_tax',
    'contract_deposit',
  ];

  static const List<String> pockets = <String>['cash', 'bank', 'agency'];

  static const Map<String, String> bucketLabelTh = <String, String>{
    'budget': 'เงินงบประมาณ',
    'state_revenue': 'เงินรายได้แผ่นดิน',
    'offbudget': 'เงินนอกงบประมาณ',
    'general_subsidy': 'เงินอุดหนุนทั่วไป (OB-01/OB-02)',
    'school_revenue': 'เงินรายได้สถานศึกษา',
    'withholding_tax': 'เงินภาษีหัก ณ ที่จ่าย',
    'contract_deposit': 'เงินประกันสัญญา',
  };

  static const Map<String, String> pocketLabelTh = <String, String>{
    'cash': 'เงินสด',
    'bank': 'เงินฝากธนาคาร',
    'agency': 'ส่วนราชการผู้เบิก',
  };
}
