class FiscalYear {
  FiscalYear._();

  static int currentBuddhist({DateTime? now}) {
    final current = now ?? DateTime.now();
    // ปีงบประมาณไทย: ต.ค.-ธ.ค. จะเป็นปีงบของปีถัดไป
    if (current.month >= 10) {
      return current.year + 544;
    }
    return current.year + 543;
  }
}
