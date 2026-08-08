import type { Pool, RowDataPacket } from 'mysql2/promise';
import type { UsageEntry, UsageTotals, PackageInfo } from '../../../types/index.js';

export class AiUsageRepository {
  constructor(private readonly db: Pool) {}

  async getCurrentPackage(scopeType = 'global', scopeId = ''): Promise<PackageInfo> {
    const [rows] = await this.db.execute<RowDataPacket[]>(
      `SELECT * FROM ai_billing_packages
       WHERE scope_type = ? AND (scope_id = ? OR scope_id IS NULL)
         AND is_current = 1 AND deleted_at IS NULL
       ORDER BY package_id DESC LIMIT 1`,
      [scopeType, scopeId],
    );
    return rows[0] ? this.mapPackage(rows[0]) : this.defaultPackage();
  }

  async getMonthlyUsage(month: string, scopeType = 'global', scopeId = ''): Promise<UsageTotals> {
    const [rows] = await this.db.execute<RowDataPacket[]>(
      `SELECT
         COALESCE(SUM(requests_count), 0) AS requests_count,
         COALESCE(SUM(success_count),  0) AS success_count,
         COALESCE(SUM(error_count),    0) AS error_count,
         COALESCE(SUM(input_tokens),   0) AS input_tokens,
         COALESCE(SUM(output_tokens),  0) AS output_tokens,
         COALESCE(SUM(total_tokens),   0) AS total_tokens,
         COALESCE(SUM(estimated_cost), 0) AS estimated_cost
       FROM ai_usage_daily_rollups
       WHERE usage_month = ? AND scope_type = ? AND scope_id = ?`,
      [month, scopeType, scopeId],
    );
    return this.mapUsage((rows[0] ?? {}) as RowDataPacket);
  }

  async insertLedger(entry: UsageEntry): Promise<void> {
    await this.db.execute(
      `INSERT IGNORE INTO ai_usage_ledger
         (request_id, scope_type, scope_id, user_id, feature, action, provider, model,
          input_tokens, output_tokens, total_tokens, estimated_cost, currency,
          status, error_code, http_status, duration_ms)
       VALUES (?, 'project', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        entry.requestId,
        entry.projectKey,
        entry.userId ?? null,
        entry.feature,
        entry.action,
        entry.provider,
        entry.model,
        entry.inputTokens,
        entry.outputTokens,
        entry.totalTokens,
        entry.estimatedCost,
        entry.currency,
        entry.status,
        entry.errorCode ?? null,
        entry.httpStatus ?? null,
        entry.durationMs,
      ],
    );
  }

  async upsertDailyRollup(entry: UsageEntry): Promise<void> {
    const today = new Date().toISOString().slice(0, 10);
    const month = today.slice(0, 7);
    const isSuccess = entry.status === 'success' ? 1 : 0;
    const isError   = entry.status !== 'success' ? 1 : 0;

    await this.db.execute(
      `INSERT INTO ai_usage_daily_rollups
         (usage_date, usage_month, scope_type, scope_id, feature, action, provider, model,
          requests_count, success_count, error_count,
          input_tokens, output_tokens, total_tokens, estimated_cost)
       VALUES (?, ?, 'project', ?, ?, ?, ?, ?, 1, ?, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE
         requests_count = requests_count + 1,
         success_count  = success_count  + VALUES(success_count),
         error_count    = error_count    + VALUES(error_count),
         input_tokens   = input_tokens   + VALUES(input_tokens),
         output_tokens  = output_tokens  + VALUES(output_tokens),
         total_tokens   = total_tokens   + VALUES(total_tokens),
         estimated_cost = estimated_cost + VALUES(estimated_cost)`,
      [
        today, month, entry.projectKey,
        entry.feature, entry.action, entry.provider, entry.model,
        isSuccess, isError,
        entry.inputTokens, entry.outputTokens, entry.totalTokens, entry.estimatedCost,
      ],
    );
  }

  async insertAlertIfMissing(data: {
    usageMonth: string; projectKey: string; packageKey: string;
    metric: string; thresholdPercent: number; currentValue: number; limitValue: number;
  }): Promise<void> {
    await this.db.execute(
      `INSERT IGNORE INTO ai_usage_alert_events
         (usage_month, scope_type, scope_id, package_key, metric, threshold_percent, current_value, limit_value)
       VALUES (?, 'project', ?, ?, ?, ?, ?, ?)`,
      [
        data.usageMonth, data.projectKey, data.packageKey,
        data.metric, data.thresholdPercent, data.currentValue, data.limitValue,
      ],
    );
  }

  async findModelPricing(provider: string, model: string): Promise<{ inputCostPer1k: number; outputCostPer1k: number; currency: string } | null> {
    // Try exact match, then wildcard '*'
    const [rows] = await this.db.execute<RowDataPacket[]>(
      `SELECT input_cost_per_1k_tokens, output_cost_per_1k_tokens, currency
       FROM ai_model_pricing
       WHERE provider = ? AND model IN (?, '*') AND is_active = 1 AND deleted_at IS NULL
       ORDER BY CASE WHEN model = ? THEN 0 ELSE 1 END, effective_from DESC
       LIMIT 1`,
      [provider, model, model],
    );
    if (!rows[0]) return null;
    return {
      inputCostPer1k:  Number(rows[0]['input_cost_per_1k_tokens']),
      outputCostPer1k: Number(rows[0]['output_cost_per_1k_tokens']),
      currency:        rows[0]['currency'] as string,
    };
  }

  async listModelPricing(): Promise<RowDataPacket[]> {
    const [rows] = await this.db.execute<RowDataPacket[]>(
      `SELECT pricing_id, provider, model, input_cost_per_1k_tokens,
              output_cost_per_1k_tokens, currency, is_active, effective_from
       FROM ai_model_pricing WHERE deleted_at IS NULL ORDER BY provider, model`,
    );
    return rows;
  }

  async saveModelPricing(rows: Array<{ provider: string; model: string; inputCost: number; outputCost: number; currency: string; isActive: boolean; effectiveFrom: string }>): Promise<void> {
    for (const row of rows) {
      await this.db.execute(
        `INSERT INTO ai_model_pricing
           (provider, model, input_cost_per_1k_tokens, output_cost_per_1k_tokens, currency, is_active, effective_from)
         VALUES (?, ?, ?, ?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE
           input_cost_per_1k_tokens  = VALUES(input_cost_per_1k_tokens),
           output_cost_per_1k_tokens = VALUES(output_cost_per_1k_tokens),
           currency                  = VALUES(currency),
           is_active                 = VALUES(is_active)`,
        [row.provider, row.model, row.inputCost, row.outputCost, row.currency, row.isActive ? 1 : 0, row.effectiveFrom],
      );
    }
  }

  async saveGlobalPackage(pkg: Partial<PackageInfo>): Promise<PackageInfo> {
    const thresholds = pkg.alertThresholds ?? [70, 90, 100];
    await this.db.execute(
      `INSERT INTO ai_billing_packages
         (package_key, package_name, scope_type, scope_id,
          request_limit_monthly, token_limit_monthly, cost_limit_monthly,
          currency, alert_thresholds_json, hard_limit_enabled, is_current)
       VALUES ('global_default', ?, 'global', '', ?, ?, ?, ?, ?, ?, 1)
       ON DUPLICATE KEY UPDATE
         package_name            = VALUES(package_name),
         request_limit_monthly   = VALUES(request_limit_monthly),
         token_limit_monthly     = VALUES(token_limit_monthly),
         cost_limit_monthly      = VALUES(cost_limit_monthly),
         currency                = VALUES(currency),
         alert_thresholds_json   = VALUES(alert_thresholds_json),
         hard_limit_enabled      = VALUES(hard_limit_enabled),
         is_current              = 1,
         deleted_at              = NULL`,
      [
        pkg.packageName ?? 'Global Default',
        pkg.requestLimitMonthly ?? null,
        pkg.tokenLimitMonthly   ?? null,
        pkg.costLimitMonthly    ?? null,
        pkg.currency ?? 'USD',
        JSON.stringify(thresholds),
        pkg.hardLimitEnabled !== false ? 1 : 0,
      ],
    );
    return this.getCurrentPackage();
  }

  async getLogs(projectKey: string, page: number, limit: number): Promise<{ items: RowDataPacket[]; total: number }> {
    const offset = (page - 1) * limit;
    const [rows] = await this.db.execute<RowDataPacket[]>(
      `SELECT request_id, feature, action, provider, model, input_tokens, output_tokens,
              total_tokens, estimated_cost, currency, status, error_code, duration_ms, created_at
       FROM ai_usage_ledger
       WHERE scope_type = 'project' AND scope_id = ?
       ORDER BY created_at DESC LIMIT ? OFFSET ?`,
      [projectKey, limit, offset],
    );
    const [[countRow]] = await this.db.execute<RowDataPacket[]>(
      `SELECT COUNT(*) AS total FROM ai_usage_ledger WHERE scope_type = 'project' AND scope_id = ?`,
      [projectKey],
    );
    return { items: rows, total: Number(countRow?.['total'] ?? 0) };
  }

  private mapPackage(row: RowDataPacket): PackageInfo {
    const rawThresholds = row['alert_thresholds_json'];
    let alertThresholds = [70, 90, 100];
    try {
      const parsed = typeof rawThresholds === 'string' ? JSON.parse(rawThresholds) : rawThresholds;
      if (Array.isArray(parsed)) alertThresholds = parsed;
    } catch { /* use default */ }

    return {
      packageKey:           row['package_key'] as string,
      packageName:          row['package_name'] as string,
      requestLimitMonthly:  row['request_limit_monthly'] != null ? Number(row['request_limit_monthly']) : null,
      tokenLimitMonthly:    row['token_limit_monthly']   != null ? Number(row['token_limit_monthly'])   : null,
      costLimitMonthly:     row['cost_limit_monthly']    != null ? Number(row['cost_limit_monthly'])    : null,
      currency:             row['currency'] as string,
      alertThresholds,
      hardLimitEnabled:     Boolean(row['hard_limit_enabled']),
    };
  }

  private mapUsage(row: RowDataPacket): UsageTotals {
    return {
      requestsCount: Number(row['requests_count'] ?? 0),
      successCount:  Number(row['success_count']  ?? 0),
      errorCount:    Number(row['error_count']    ?? 0),
      inputTokens:   Number(row['input_tokens']   ?? 0),
      outputTokens:  Number(row['output_tokens']  ?? 0),
      totalTokens:   Number(row['total_tokens']   ?? 0),
      estimatedCost: Number(row['estimated_cost'] ?? 0),
    };
  }

  private defaultPackage(): PackageInfo {
    return {
      packageKey:           'global_default',
      packageName:          'Global Default',
      requestLimitMonthly:  null,
      tokenLimitMonthly:    null,
      costLimitMonthly:     null,
      currency:             'USD',
      alertThresholds:      [70, 90, 100],
      hardLimitEnabled:     true,
    };
  }
}
