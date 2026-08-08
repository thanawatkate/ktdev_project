import type { AiUsageRepository } from '../repository/AiUsageRepository.js';
import type { CostEstimate } from '../../../types/index.js';

export class AiModelPricingService {
  constructor(private readonly repo: AiUsageRepository) {}

  async listPricing() {
    return this.repo.listModelPricing();
  }

  async savePricing(rows: Array<{ provider: string; model: string; inputCost: number; outputCost: number; currency: string; isActive: boolean; effectiveFrom: string }>) {
    return this.repo.saveModelPricing(rows);
  }

  async estimateCost(provider: string, model: string, inputTokens: number, outputTokens: number): Promise<CostEstimate> {
    const pricing = await this.repo.findModelPricing(provider, model);
    if (!pricing) {
      return { estimatedCost: 0, currency: 'USD', pricingFound: false };
    }
    const cost = (inputTokens / 1000) * pricing.inputCostPer1k + (outputTokens / 1000) * pricing.outputCostPer1k;
    return {
      estimatedCost: Math.round(cost * 1e8) / 1e8,
      currency:      pricing.currency,
      pricingFound:  true,
    };
  }
}
