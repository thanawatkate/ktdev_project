/// ข้อมูลตัวอย่างสำหรับ mockup หน้าจอรายงานการเงิน
///
/// โครงสร้างตรงกับ payload จาก `/saccapi/reports/*` และ local computer
/// ใช้ประกอบ UI design / widgetbook / การทดสอบแสดงผล โดยยังไม่ผูกเข้า runtime
///
/// ไฟล์: `forntend/lib/features/reports/mockup/reports_mockup_data.dart`
class ReportsMockupData {
  ReportsMockupData._();

  static const String schoolName = 'โรงเรียนบ้านตัวอย่าง';
  static const String fiscalYear = '2569';
  static const String reportDate = '2026-07-21';

  // ── Tab 0: ภาพรวม ───────────────────────────────────────────────
  static Map<String, dynamic> get summary => {
        'total_income': 1850000.00,
        'total_expense': 1423500.50,
        'balance': 426499.50,
        'total_loan': 85000.00,
        'total_repay': 32000.00,
      };

  // ── Tab 1: รายเดือน ─────────────────────────────────────────────
  static List<Map<String, dynamic>> get incomeByMonth => const [
        {'month': '2025-10', 'total': 420000, 'count': 8},
        {'month': '2025-11', 'total': 185000, 'count': 5},
        {'month': '2025-12', 'total': 210000, 'count': 6},
        {'month': '2026-01', 'total': 95000, 'count': 4},
        {'month': '2026-02', 'total': 120000, 'count': 5},
        {'month': '2026-03', 'total': 280000, 'count': 7},
        {'month': '2026-04', 'total': 150000, 'count': 4},
        {'month': '2026-05', 'total': 175000, 'count': 5},
        {'month': '2026-06', 'total': 110000, 'count': 3},
        {'month': '2026-07', 'total': 105000, 'count': 3},
      ];

  static List<Map<String, dynamic>> get expenseByMonth => const [
        {'month': '2025-10', 'total': 310000, 'count': 12},
        {'month': '2025-11', 'total': 165000, 'count': 9},
        {'month': '2025-12', 'total': 198000, 'count': 11},
        {'month': '2026-01', 'total': 88000, 'count': 7},
        {'month': '2026-02', 'total': 112000, 'count': 8},
        {'month': '2026-03', 'total': 245000, 'count': 14},
        {'month': '2026-04', 'total': 132000, 'count': 9},
        {'month': '2026-05', 'total': 98000, 'count': 6},
        {'month': '2026-06', 'total': 75500.50, 'count': 5},
      ];

  // ── Tab 2: แหล่งเงิน ────────────────────────────────────────────
  static List<Map<String, dynamic>> get budgetSource => const [
        {
          'id': 1,
          'code': 'OB-01',
          'name': 'ค่าจัดการเรียนการสอน',
          'budget_type': 'offbudget',
          'budget_amount': 450000,
          'brought_forward_amount': 25000,
          'fiscal_year': fiscalYear,
          'used_expense': 312000,
          'received_income': 450000,
          'income_amount': 450000,
          'remaining': 163000,
          'used_percent': '65.68',
        },
        {
          'id': 2,
          'code': 'OB-09',
          'name': 'เงินอุดหนุนโครงการอาหารกลางวัน',
          'budget_type': 'offbudget',
          'budget_amount': 680000,
          'brought_forward_amount': 0,
          'fiscal_year': fiscalYear,
          'used_expense': 510500.50,
          'received_income': 680000,
          'income_amount': 680000,
          'remaining': 169499.50,
          'used_percent': '75.07',
        },
        {
          'id': 3,
          'code': 'BG-01',
          'name': 'เงินงบประมาณ — ค่าวัสดุ',
          'budget_type': 'budget',
          'budget_amount': 120000,
          'brought_forward_amount': 10000,
          'fiscal_year': fiscalYear,
          'used_expense': 98000,
          'received_income': 130000,
          'income_amount': 130000,
          'remaining': 32000,
          'used_percent': '75.38',
        },
      ];

  // ── Tab 3: งบทดลอง ──────────────────────────────────────────────
  static Map<String, dynamic> get trialBalance => {
        'income': [
          {'type_name': 'เงินสด', 'total': 420000, 'count': 18},
          {'type_name': 'ฝากธนาคาร', 'total': 1280000, 'count': 24},
          {'type_name': 'ส่วนราชการผู้เบิก', 'total': 150000, 'count': 3},
        ],
        'expense': [
          {'type_name': 'เงินสด', 'total': 285000.50, 'count': 32},
          {'type_name': 'ฝากธนาคาร', 'total': 998500, 'count': 41},
          {'type_name': 'ส่วนราชการผู้เบิก', 'total': 140000, 'count': 4},
        ],
      };

  // ── Tab 4: วงเงินคงเหลือรายปี ────────────────────────────────────
  static List<Map<String, dynamic>> get budgetRemaining => const [
        {
          'id': 1,
          'code': 'OB-01',
          'name': 'ค่าจัดการเรียนการสอน',
          'budget_type': 'offbudget',
          'fiscal_year': fiscalYear,
          'budget_amount': 450000,
          'brought_forward_amount': 25000,
          'used_amount': 312000,
          'remaining': 163000,
          'used_percent': 65.68,
        },
        {
          'id': 2,
          'code': 'OB-09',
          'name': 'เงินอุดหนุนโครงการอาหารกลางวัน',
          'budget_type': 'offbudget',
          'fiscal_year': fiscalYear,
          'budget_amount': 680000,
          'brought_forward_amount': 0,
          'used_amount': 510500.50,
          'remaining': 169499.50,
          'used_percent': 75.07,
        },
        {
          'id': 3,
          'code': 'BG-01',
          'name': 'เงินงบประมาณ — ค่าวัสดุ',
          'budget_type': 'budget',
          'fiscal_year': fiscalYear,
          'budget_amount': 120000,
          'brought_forward_amount': 10000,
          'used_amount': 135000,
          'remaining': -5000,
          'used_percent': 103.85,
        },
      ];

  // ── Tab 5: รับ-จ่ายประจำปี (ห.33) ────────────────────────────────
  static Map<String, dynamic> get annualSummary => {
        'fiscal_year': int.parse(fiscalYear),
        'income': [
          {
            'id': 1,
            'code': 'OB-01',
            'type_name': 'ค่าจัดการเรียนการสอน',
            'total': 450000,
            'count': 4,
          },
          {
            'id': 2,
            'code': 'OB-03',
            'type_name': 'ค่าหนังสือเรียน',
            'total': 185000,
            'count': 2,
          },
          {
            'id': 3,
            'code': 'OB-09',
            'type_name': 'เงินอุดหนุนโครงการอาหารกลางวัน',
            'total': 680000,
            'count': 6,
          },
          {
            'id': 4,
            'code': 'OB-11',
            'type_name': 'เงินกองทุนเพื่อความเสมอภาคทางการศึกษา (กสศ.)',
            'total': 120000,
            'count': 3,
          },
          {
            'id': 5,
            'code': 'OB-12',
            'type_name': 'ดอกเบี้ยบัญชีเงินอุดหนุนอื่น',
            'total': 8500,
            'count': 2,
          },
        ],
        'expense': [
          {
            'code': 'personnel',
            'type_name': 'งบบุคลากร',
            'total': 180000,
            'count': 8,
            'sort': 1,
            'lines': [
              {
                'code': '00',
                'type_name': 'งบบุคลากร — ค่าจ้างชั่วคราว',
                'total': 180000,
                'count': 8,
              },
            ],
          },
          {
            'code': 'operating',
            'type_name': 'งบดำเนินงาน',
            'total': 725500.50,
            'count': 42,
            'sort': 2,
            'lines': [
              {
                'code': '01',
                'type_name': 'ค่าตอบแทน',
                'total': 95000,
                'count': 10,
              },
              {
                'code': '02',
                'type_name': 'ค่าใช้สอย',
                'total': 210000,
                'count': 14,
              },
              {
                'code': '03',
                'type_name': 'ค่าวัสดุ',
                'total': 320500.50,
                'count': 12,
              },
              {
                'code': '04',
                'type_name': 'ค่าสาธารณูปโภค',
                'total': 100000,
                'count': 6,
              },
            ],
          },
          {
            'code': 'investment',
            'type_name': 'งบลงทุน',
            'total': 250000,
            'count': 3,
            'sort': 3,
            'lines': [
              {
                'code': '05',
                'type_name': 'ค่าครุภัณฑ์',
                'total': 250000,
                'count': 3,
              },
            ],
          },
          {
            'code': 'subsidy',
            'type_name': 'งบเงินอุดหนุน',
            'total': 268000,
            'count': 5,
            'sort': 4,
            'lines': [
              {
                'code': '07',
                'type_name': 'เงินอุดหนุน',
                'total': 268000,
                'count': 5,
              },
            ],
          },
        ],
        'expense_details': [
          {
            'code': '00',
            'type_name': 'งบบุคลากร — ค่าจ้างชั่วคราว',
            'total': 180000,
            'count': 8,
          },
          {
            'code': '01',
            'type_name': 'ค่าตอบแทน',
            'total': 95000,
            'count': 10,
          },
          {
            'code': '02',
            'type_name': 'ค่าใช้สอย',
            'total': 210000,
            'count': 14,
          },
          {
            'code': '03',
            'type_name': 'ค่าวัสดุ',
            'total': 320500.50,
            'count': 12,
          },
          {
            'code': '04',
            'type_name': 'ค่าสาธารณูปโภค',
            'total': 100000,
            'count': 6,
          },
          {
            'code': '05',
            'type_name': 'ค่าครุภัณฑ์',
            'total': 250000,
            'count': 3,
          },
          {
            'code': '07',
            'type_name': 'เงินอุดหนุน',
            'total': 268000,
            'count': 5,
          },
        ],
        'total_income': 1443500,
        'total_expense': 1423500.50,
        'balance': 19999.50,
        'opening_total': 350000,
        'ending_balance': 369999.50,
      };

  // ── Tab 6: เงินคงเหลือประจำวัน (ห.34) ────────────────────────────
  static Map<String, dynamic> _pocketRow(
    String key,
    String label,
    String remark,
    double cash,
    double bank,
    double agency, [
    List<Map<String, dynamic>>? subRows,
  ]) {
    return {
      'key': key,
      'label': label,
      'remark': remark,
      'cash': cash,
      'bank': bank,
      'agency': agency,
      'total': cash + bank + agency,
      if (subRows != null) 'sub_rows': subRows,
    };
  }

  static Map<String, dynamic> get dailyBalance => {
        'date': reportDate,
        'fiscal_year': int.parse(fiscalYear),
        'rows': [
          _pocketRow('budget', 'เงินงบประมาณ', '', 5000, 85000, 12000),
          _pocketRow(
            'state_revenue',
            'เงินรายได้แผ่นดิน',
            'สุทธิ = เงินรายได้แผ่นดิน − OB-12',
            0,
            12500,
            0,
            [
              _pocketRow(
                'ob12',
                'ดอกเบี้ยบัญชีเงินอุดหนุนอื่น (OB-12)',
                '',
                0,
                8500,
                0,
              ),
            ],
          ),
          _pocketRow('offbudget', 'เงินนอกงบประมาณ', '', 18000, 420000, 0),
          _pocketRow(
            'general_subsidy',
            'เงินอุดหนุนทั่วไป',
            'หมวด OB-01 / OB-02',
            8000,
            210000,
            0,
            [
              _pocketRow(
                'general_subsidy_per_head',
                'ค่าจัดการเรียนการสอน (OB-01)',
                '',
                5000,
                155000,
                0,
              ),
              _pocketRow(
                'general_subsidy_poor',
                'ปัจจัยพื้นฐานนักเรียนยากจน (OB-02)',
                '',
                3000,
                55000,
                0,
              ),
            ],
          ),
          _pocketRow(
            'school_revenue',
            'เงินรายได้สถานศึกษา',
            '',
            4500,
            68000,
            0,
            [
              _pocketRow(
                'school_revenue_donation',
                'เงินบริจาค',
                '',
                2000,
                40000,
                0,
              ),
              _pocketRow(
                'school_revenue_other',
                'รายได้สถานศึกษาอื่น',
                '',
                2500,
                28000,
                0,
              ),
            ],
          ),
          _pocketRow('withholding_tax', 'เงินภาษีหัก ณ ที่จ่าย', '', 0, 15500, 0),
          _pocketRow('contract_deposit', 'เงินประกันสัญญา', '', 0, 50000, 0),
        ],
        'bank_opening_total': 250000,
        'opening_source': 'fiscal_year_opening',
        'cash': 35500,
        'bank': 861000,
        'agency': 12000,
        'total': 908500,
        'bank_breakdown': [
          {
            'id': 1,
            'accountnumber': '123-4-56789-0',
            'opening_balance': 180000,
            'bank_name': 'ธนาคารกรุงไทย',
          },
          {
            'id': 2,
            'accountnumber': '987-6-54321-0',
            'opening_balance': 70000,
            'bank_name': 'ธนาคารออมสิน',
          },
        ],
        'keeping_limits': [],
        'cash_over_limit': false,
        'cash_limit_used': 20000,
      };

  // ── Tab 7: สรุปเงินสดรายวัน ─────────────────────────────────────
  static Map<String, dynamic> get dailyCashSummary => {
        'date': reportDate,
        'opening_cash': 28500,
        'received_cash_today': 12500,
        'received_transfer_today': 45000,
        'paid_cash_today': 5500,
        'closing_cash': 35500,
      };

  // ── Tab 8: งบเทียบยอดธนาคาร (ห.32) ──────────────────────────────
  static Map<String, dynamic> get bankReconciliation => {
        'as_of': reportDate,
        'accounts': [
          {
            'id': 1,
            'accountnumber': '123-4-56789-0',
            'opening_balance': 180000,
            'bank_name': 'ธนาคารกรุงไทย',
            'total_in_bank': 520000,
            'total_out_bank': 385000,
            'book_balance': 315000,
          },
          {
            'id': 2,
            'accountnumber': '987-6-54321-0',
            'opening_balance': 70000,
            'bank_name': 'ธนาคารออมสิน',
            'total_in_bank': 210000,
            'total_out_bank': 95000,
            'book_balance': 185000,
          },
        ],
        'unallocated_bank_movements': {
          'total_in_bank': 0,
          'total_out_bank': 15000,
          'net_movement': -15000,
        },
        'total_opening': 250000,
        'total_in_bank': 730000,
        'total_out_bank': 480000,
        'book_balance': 500000,
        'outstanding_cheque_total': 42500,
        'reconciled_statement_balance': 542500,
        'adjustment_policy': 'notes_only',
        'adjustment_notes': [
          {
            'id': 1,
            'as_of_date': reportDate,
            'note': 'รอ Statement ประจำเดือน ก.ค. จากธนาคาร',
          },
        ],
      };

  // ── Tab 9: ปิดวัน (ตัวอย่างสถานะ) ────────────────────────────────
  static Map<String, dynamic> get dailyClosingPreview => {
        'date': reportDate,
        'is_closed': false,
        'balance_snapshot': dailyBalance,
        'history': [
          {
            'close_date': '2026-07-20',
            'closed_at': '2026-07-20T16:45:00',
            'note': 'ปิดวันปกติ',
            'cash_total': 28500,
          },
          {
            'close_date': '2026-07-19',
            'closed_at': '2026-07-19T16:30:00',
            'note': '',
            'cash_total': 31200,
          },
        ],
      };

  // ── Tab 10: สรุปหนี้ยืมค้าง ───────────────────────────────────────
  static List<Map<String, dynamic>> get loanOutstanding => const [
        {
          'id': 11,
          'docno': 'YM-2569-0003',
          'borrower': 'นายสมชาย ใจดี',
          'outstanding': 25000,
          'due_date': '2026-06-30',
          'is_overdue': true,
        },
        {
          'id': 12,
          'docno': 'YM-2569-0007',
          'borrower': 'นางสาวมาลี รักเรียน',
          'outstanding': 15000,
          'due_date': '2026-08-15',
          'is_overdue': false,
        },
        {
          'id': 13,
          'docno': 'YM-2569-0010',
          'borrower': 'นายวิชัย พากเพียร',
          'outstanding': 45000,
          'due_date': '2026-07-10',
          'is_overdue': true,
        },
      ];

  // ── Tab 11: เช็คค้างตัดบัญชี ────────────────────────────────────
  static Map<String, dynamic> get outstandingCheques => {
        'as_of': reportDate,
        'fiscal_year': int.parse(fiscalYear),
        'total_outstanding': 42500,
        'count': 3,
        'rows': [
          {
            'pay_cheque_id': 101,
            'chequeno': '784512',
            'chequeamount': 18500,
            'docdate': '2026-07-05',
            'bank_name': 'ธนาคารกรุงไทย',
            'cheque_account_no': '123-4-56789-0',
            'expense_docno': 'EX-2569-0042',
            'expense_detail': 'ค่าวัสดุสำนักงาน',
          },
          {
            'pay_cheque_id': 102,
            'chequeno': '784520',
            'chequeamount': 12000,
            'docdate': '2026-07-12',
            'bank_name': 'ธนาคารกรุงไทย',
            'cheque_account_no': '123-4-56789-0',
            'expense_docno': 'EX-2569-0051',
            'expense_detail': 'ค่าจ้างชั่วคราว',
          },
          {
            'pay_cheque_id': 103,
            'chequeno': '331008',
            'chequeamount': 12000,
            'docdate': '2026-07-18',
            'bank_name': 'ธนาคารออมสิน',
            'cheque_account_no': '987-6-54321-0',
            'expense_docno': 'EX-2569-0058',
            'expense_detail': 'ค่าซ่อมบำรุงอาคาร',
          },
        ],
      };

  /// Bundle ปีงบ — ตรงกับ cache bundle ของ ReportsRepository
  static Map<String, dynamic> get fiscalYearBundle => {
        'fiscal_year': fiscalYear,
        'summary': summary,
        'incomeByMonth': incomeByMonth,
        'expenseByMonth': expenseByMonth,
        'budgetData': budgetSource,
        'trialBalance': trialBalance,
        'budgetRemaining': budgetRemaining,
        'annualSummary': annualSummary,
      };
}
