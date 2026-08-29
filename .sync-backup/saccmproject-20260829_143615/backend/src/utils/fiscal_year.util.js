function getCurrentFiscalYearBuddhist(date = new Date()) {
  const adYear = date.getFullYear();
  const month = date.getMonth() + 1;
  // ปีงบประมาณไทย: ต.ค.-ธ.ค. นับเป็นปีงบของปีถัดไป
  return month >= 10 ? adYear + 544 : adYear + 543;
}

function fiscalYearRangeFromBuddhist(buddhistYear) {
  const parsed = Number.parseInt(buddhistYear, 10);
  if (!Number.isFinite(parsed)) return null;
  const adYear = parsed - 543;
  return {
    startDate: `${adYear - 1}-10-01`,
    endDate: `${adYear}-09-30`,
  };
}

module.exports = {
  getCurrentFiscalYearBuddhist,
  fiscalYearRangeFromBuddhist,
};
