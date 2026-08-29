/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = async function (knex) {
  const hasExpense = await knex.schema.hasTable('expense');
  if (hasExpense) {
    const hasDocStatus = await knex.schema.hasColumn('expense', 'doc_status');
    if (!hasDocStatus) {
      await knex.schema.alterTable('expense', function (table) {
        table.string('doc_status', 24).notNullable().defaultTo('posted');
      });
    }

    const hasMoneyDomain = await knex.schema.hasColumn('expense', 'money_domain');
    if (!hasMoneyDomain) {
      await knex.schema.alterTable('expense', function (table) {
        table.string('money_domain', 24).nullable();
      });
    }

    const hasApprovedBy = await knex.schema.hasColumn('expense', 'approved_by');
    if (!hasApprovedBy) {
      await knex.schema.alterTable('expense', function (table) {
        table.integer('approved_by').unsigned().nullable();
      });
    }

    const hasApprovedAt = await knex.schema.hasColumn('expense', 'approved_at');
    if (!hasApprovedAt) {
      await knex.schema.alterTable('expense', function (table) {
        table.timestamp('approved_at').nullable();
      });
    }

    const hasPostedAt = await knex.schema.hasColumn('expense', 'posted_at');
    if (!hasPostedAt) {
      await knex.schema.alterTable('expense', function (table) {
        table.timestamp('posted_at').nullable();
      });
    }

    const hasChangeReason = await knex.schema.hasColumn('expense', 'change_reason');
    if (!hasChangeReason) {
      await knex.schema.alterTable('expense', function (table) {
        table.string('change_reason', 255).nullable();
      });
    }
  }

  const hasPayCheque = await knex.schema.hasTable('paycheque');
  if (hasPayCheque) {
    const hasChequeNo = await knex.schema.hasColumn('paycheque', 'chequeno');
    if (!hasChequeNo) {
      await knex.schema.alterTable('paycheque', function (table) {
        table.string('chequeno', 128).nullable();
      });
    }
  }
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = async function (knex) {
  const hasExpense = await knex.schema.hasTable('expense');
  if (hasExpense) {
    const hasChangeReason = await knex.schema.hasColumn('expense', 'change_reason');
    if (hasChangeReason) {
      await knex.schema.alterTable('expense', function (table) {
        table.dropColumn('change_reason');
      });
    }
    const hasPostedAt = await knex.schema.hasColumn('expense', 'posted_at');
    if (hasPostedAt) {
      await knex.schema.alterTable('expense', function (table) {
        table.dropColumn('posted_at');
      });
    }
    const hasApprovedAt = await knex.schema.hasColumn('expense', 'approved_at');
    if (hasApprovedAt) {
      await knex.schema.alterTable('expense', function (table) {
        table.dropColumn('approved_at');
      });
    }
    const hasApprovedBy = await knex.schema.hasColumn('expense', 'approved_by');
    if (hasApprovedBy) {
      await knex.schema.alterTable('expense', function (table) {
        table.dropColumn('approved_by');
      });
    }
    const hasMoneyDomain = await knex.schema.hasColumn('expense', 'money_domain');
    if (hasMoneyDomain) {
      await knex.schema.alterTable('expense', function (table) {
        table.dropColumn('money_domain');
      });
    }
    const hasDocStatus = await knex.schema.hasColumn('expense', 'doc_status');
    if (hasDocStatus) {
      await knex.schema.alterTable('expense', function (table) {
        table.dropColumn('doc_status');
      });
    }
  }

  const hasPayCheque = await knex.schema.hasTable('paycheque');
  if (hasPayCheque) {
    const hasChequeNo = await knex.schema.hasColumn('paycheque', 'chequeno');
    if (hasChequeNo) {
      await knex.schema.alterTable('paycheque', function (table) {
        table.dropColumn('chequeno');
      });
    }
  }
};
