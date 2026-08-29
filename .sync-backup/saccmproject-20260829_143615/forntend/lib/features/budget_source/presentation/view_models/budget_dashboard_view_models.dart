import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/utils/fiscal_year.dart';
import 'package:saccm/features/budget_source/data/models/budget_source_model.dart';

/// แถวหนึ่งรายการ — อิงคอลัมน์จากตาราง `budget_source_budget` และ `budget_source_master`
/// ใน SQLite ตาม schema ใน `app_database.dart`
class BudgetDashboardSourceRow {
  const BudgetDashboardSourceRow({
    required this.budgetRowId,
    required this.masterId,
    required this.name,
    required this.code,
    required this.fiscalYear,
    required this.budgetAmount,
    required this.broughtForwardAmount,
    required this.usedAmount,
    required this.reservedAmount,
    this.budgetTypeLabel,
  });

  /// `budget_source_budget.id`
  final String budgetRowId;

  /// `budget_source_master.id`
  final String masterId;

  /// `budget_source_master.name`
  final String name;

  /// `budget_source_master.code`
  final String code;

  /// `budget_source_budget.fiscal_year`
  final String fiscalYear;

  /// `budget_source_budget.budget_amount`
  final double budgetAmount;

  /// `budget_source_budget.brought_forward_amount`
  final double broughtForwardAmount;

  /// `budget_source_budget.used_amount`
  final double usedAmount;

  /// `budget_source_budget.reserved_amount`
  final double reservedAmount;

  /// ป้ายประเภทงบ (จาก `budget_source_master.budget_type` แปลงเป็นข้อความที่อ่านง่าย)
  final String? budgetTypeLabel;

  /// วงเงินรวมที่ใช้เป็นฐาน (ยกมา + จัดสรรปีนี้) — สอดคล้อง [BudgetSourceEntity.totalAllocated]
  double get totalCap => budgetAmount + broughtForwardAmount;

  double get committed => usedAmount + reservedAmount;

  double get available => totalCap - usedAmount - reservedAmount;

  double get utilizationOfCap =>
      totalCap > 0 ? (committed / totalCap).clamp(0.0, double.infinity) : 0.0;

  factory BudgetDashboardSourceRow.fromBudgetSourceModel(BudgetSourceModel m) {
    return BudgetDashboardSourceRow(
      budgetRowId: m.id,
      masterId: m.masterId,
      name: m.name,
      code: m.code,
      fiscalYear: m.fiscalYear,
      budgetAmount: m.budgetAmount,
      broughtForwardAmount: m.broughtForwardAmount,
      usedAmount: m.usedAmount,
      reservedAmount: m.reservedAmount,
      budgetTypeLabel: m.budgetType,
    );
  }

  /// แปลงรายการแหล่งเงินจาก DB ให้เป็นแถวแดชบอร์ดสำหรับปีงบประมาณที่เลือก
  static List<BudgetDashboardSourceRow> listForFiscalYear(
    Iterable<BudgetSourceModel> items,
    String fiscalYear,
  ) {
    final fy = fiscalYear.trim();
    final out = items
        .where((m) => m.fiscalYear.trim() == fy)
        .map(BudgetDashboardSourceRow.fromBudgetSourceModel)
        .toList();
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }
}

/// สรุปรวมของปีงบประมาณที่เลือก
class BudgetDashboardTotals {
  const BudgetDashboardTotals({
    required this.fiscalYear,
    required this.totalBudget,
    required this.totalUsed,
    required this.totalReserved,
  });

  final String fiscalYear;
  final double totalBudget;
  final double totalUsed;
  final double totalReserved;

  double get available => totalBudget - totalUsed - totalReserved;

  /// รวมยอดจากแถวแดชบอร์ด (แต่ละแถวเป็นหนึ่ง budget_source_budget)
  static BudgetDashboardTotals fromRowsForYear(
    String fiscalYear,
    List<BudgetDashboardSourceRow> rows,
  ) {
    double tb = 0, tu = 0, tr = 0;
    for (final r in rows) {
      tb += r.totalCap;
      tu += r.usedAmount;
      tr += r.reservedAmount;
    }
    return BudgetDashboardTotals(
      fiscalYear: fiscalYear,
      totalBudget: tb,
      totalUsed: tu,
      totalReserved: tr,
    );
  }
}

/// ข้อมูลจำลอง — โครงสอดคล้องตารางใน SQLite ตาม schema ใน `app_database.dart`
class BudgetDashboardMock {
  BudgetDashboardMock._();

  static String currentFiscalYearString() =>
      FiscalYear.currentBuddhist().toString();

  /// รายการตัวอย่างสำหรับปีงบประมาณ [fiscalYear]
  static List<BudgetDashboardSourceRow> sampleRows(String fiscalYear) {
    return [
      BudgetDashboardSourceRow(
        budgetRowId: 'mock_bb_gov_$fiscalYear',
        masterId: 'mock_bm_gov',
        name: 'เงินงบประมาณแผ่นดิน',
        code: 'SRC-GOV-$fiscalYear-001',
        fiscalYear: fiscalYear,
        budgetAmount: 4500000,
        broughtForwardAmount: 120000,
        usedAmount: 2850000,
        reservedAmount: 180000,
        budgetTypeLabel: TransactionUiText.budgetTypeGov,
      ),
      BudgetDashboardSourceRow(
        budgetRowId: 'mock_bb_nongov_$fiscalYear',
        masterId: 'mock_bm_nongov',
        name: 'เงินนอกงบประมาณ',
        code: 'SRC-NONGOV-$fiscalYear-001',
        fiscalYear: fiscalYear,
        budgetAmount: 980000,
        broughtForwardAmount: 45000,
        usedAmount: 410000,
        reservedAmount: 95000,
        budgetTypeLabel: TransactionUiText.budgetTypeNonGov,
      ),
      BudgetDashboardSourceRow(
        budgetRowId: 'mock_bb_grant_$fiscalYear',
        masterId: 'mock_bm_grant',
        name: 'เงินอุดหนุนทั่วไป (ตัวอย่าง)',
        code: 'SRC-GEN-$fiscalYear-010',
        fiscalYear: fiscalYear,
        budgetAmount: 320000,
        broughtForwardAmount: 0,
        usedAmount: 62000,
        reservedAmount: 48000,
        budgetTypeLabel: TransactionUiText.budgetTypeGeneralGrant,
      ),
    ];
  }

  static BudgetDashboardTotals totalsFor(String fiscalYear, List<BudgetDashboardSourceRow> rows) {
    return BudgetDashboardTotals.fromRowsForYear(fiscalYear, rows);
  }
}
