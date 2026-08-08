import type { AiProviderSettingsRepository } from '../repository/AiProviderSettingsRepository.js';

export class AiProviderHealthService {
  constructor(private readonly settingsRepo: AiProviderSettingsRepository) {}

  async getStatus(): Promise<Record<string, unknown>> {
    const settings = await this.settingsRepo.resolveUsage('text_default', 'text');
    const configured = Boolean(
      settings?.baseUrl &&
      settings?.model &&
      (settings?.authConfig.type === 'none' || settings?.apiKey),
    );

    return {
      status:     configured ? 'ok' : 'error',
      configured,
      provider:   settings?.provider   ?? null,
      providerId: settings?.providerId ?? null,
      model:      settings?.model      ?? null,
      timestamp:  new Date().toISOString(),
    };
  }
}
