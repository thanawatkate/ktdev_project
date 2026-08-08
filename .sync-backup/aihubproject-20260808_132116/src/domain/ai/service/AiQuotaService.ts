import type { AiUsageRepository } from '../repository/AiUsageRepository.js';
import type { QuotaStatus } from '../../../types/index.js';

export class AiQuotaExceededException extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'AiQuotaExceededException';
  }
}

export class AiQuotaService {
  constructor(private readonly repo: AiUsageRepository) {}

  async assertCanStartRequest(projectKey: string, month?: string): Promise<QuotaStatus> {
    const status = await this.getStatus(projectKey, month);
    if (!status.package.hardLimitEnabled) return status;

    for (const [metric, limit] of Object.entries(status.limits)) {
      if (limit === null) continue;
      const current = status.usage[metric as keyof typeof status.usage] ?? 0;
      if (current >= limit) {
        throw new AiQuotaExceededException(`AI quota exceeded for ${metric}`);
      }
    }
    return status;
  }

  async getStatus(projectKey: string, month?: string): Promise<QuotaStatus> {
    const m      = month ?? new Date().toISOString().slice(0, 7);
    // Try project-scoped package first, fall back to global
    let pkg = await this.repo.getCurrentPackage('project', projectKey);
    if (pkg.packageKey === 'global_default') {
      pkg = await this.repo.getCurrentPackage('global', '');
    }
    const usage  = await this.repo.getMonthlyUsage(m, 'project', projectKey);
    const limits = {
      requestsCount: pkg.requestLimitMonthly,
      totalTokens:   pkg.tokenLimitMonthly,
      estimatedCost: pkg.costLimitMonthly,
    };
    const percentages = {
      requestsCount: this.pct(usage.requestsCount, limits.requestsCount),
      totalTokens:   this.pct(usage.totalTokens,   limits.totalTokens),
      estimatedCost: this.pct(usage.estimatedCost, limits.estimatedCost),
    };
    return { month: m, package: pkg, usage, limits, percentages };
  }

  private pct(current: number, limit: number | null): number {
    if (limit === null || limit <= 0) return 0;
    return Math.round((current / limit) * 10000) / 100;
  }
}
