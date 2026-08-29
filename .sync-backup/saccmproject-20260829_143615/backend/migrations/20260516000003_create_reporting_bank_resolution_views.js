/**
 * Views สำหรับรายงาน / จับคู่บัญชีธนาคาร — effective bank จากหัวเอกสาร + แหล่งเงิน + legacy incometype
 * ใช้ใน extra_reports (งบเทียบยอดธนาคาร) แทนการเขียน COALESCE ซ้ำใน query
 */
exports.up = async function (knex) {
  await knex.raw('DROP VIEW IF EXISTS v_report_income_bank_movement');
  await knex.raw(`
    CREATE VIEW v_report_income_bank_movement AS
    SELECT
      i.id AS income_id,
      isub.id AS incomesub_id,
      i.docdate AS docdate,
      i.refbudgetsource AS refbudgetsource,
      isub.amount AS amount,
      isub.refmoneytype AS refmoneytype,
      COALESCE(i.refbankaccount, bs.refbankaccount, it.refbankaccount) AS effective_refbankaccount
    FROM income i
    INNER JOIN incomesub isub ON isub.refincome = i.id
    LEFT JOIN incometype it ON it.id = isub.refincometype
    LEFT JOIN budgetsource bs ON bs.id = i.refbudgetsource
  `);

  await knex.raw('DROP VIEW IF EXISTS v_report_expense_bank_movement');
  await knex.raw(`
    CREATE VIEW v_report_expense_bank_movement AS
    SELECT
      e.id AS expense_id,
      es.id AS expensesub_id,
      COALESCE(e.docdate, e.created) AS doc_ts,
      e.refbudgetsource AS refbudgetsource,
      es.amount AS amount,
      es.refmoneytype AS refmoneytype,
      COALESCE(e.refbankaccount, bs.refbankaccount, it.refbankaccount) AS effective_refbankaccount
    FROM expense e
    INNER JOIN expensesub es ON es.refexpense = e.id
    LEFT JOIN incometype it ON it.id = es.refincometype
    LEFT JOIN budgetsource bs ON bs.id = e.refbudgetsource
  `);
};

exports.down = async function (knex) {
  await knex.raw('DROP VIEW IF EXISTS v_report_expense_bank_movement');
  await knex.raw('DROP VIEW IF EXISTS v_report_income_bank_movement');
};
