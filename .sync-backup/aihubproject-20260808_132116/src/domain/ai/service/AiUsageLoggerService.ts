import type { AiUsageRepository } from '../repository/AiUsageRepository.js';
import type { AiQuotaService } from './AiQuotaService.js';
import type { UsageEntry } from '../../../types/index.js';

export class AiUsageLoggerService {
  constructor(
    private readonly repo: AiUsageRepository,
    private readonly quota: AiQuotaService,
  ) {}

  async log(entry: UsageEntry): Promise<void> {
    try {
      await this.repo.insertLedger(entry);
      await this.repo.upsertDailyRollup(entry);
      await this.recordThresholdAlerts(entry.projectKey);
    } catch (err) {
      console.error('[AiUsageLoggerService] log failed:', (err as Error).message);
    }
  }

  private async recordThresholdAlerts(projectKey: string): Promise<void> {
    const status     = await this.quota.getStatus(projectKey);
    const pkg        = status.package;
    const metricMap  = { requestsCount: 'requests', totalTokens: 'tokens', estimatedCost: 'cost' } as const;

    for (const [usageKey, metric] of Object.entries(metricMap)) {
      const limit = status.limits[usageKey as keyof typeof status.limits];
      if (limit === null || limit <= 0) continue;

      const percent = status.percentages[usageKey as keyof typeof status.percentages] ?? 0;
      for (const threshold of pkg.alertThresholds) {
        if (percent >= threshold) {
          await this.repo.insertAlertIfMissing({
            usageMonth:       status.month,
            projectKey,
            packageKey:       pkg.packageKey,
            metric,
            thresholdPercent: threshold,
            currentValue:     status.usage[usageKey as keyof typeof status.usage] as number,
            limitValue:       limit,
          });
        }
      }
    }
  }
}
