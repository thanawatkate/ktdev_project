import type { FastifyInstance } from 'fastify';
import type { AiProviderSettingsRepository } from '../../domain/ai/repository/AiProviderSettingsRepository.js';

export async function healthRoutes(
  fastify: FastifyInstance,
  opts: { settingsRepo: AiProviderSettingsRepository },
): Promise<void> {
  fastify.get('/v1/health', async (_request, reply) => {
    const settings = await opts.settingsRepo.resolveUsage('text_default', 'text');
    const configured = Boolean(
      settings &&
      settings.baseUrl &&
      settings.model &&
      (settings.authConfig.type === 'none' || settings.apiKey),
    );

    reply.code(configured ? 200 : 503).send({
      status:     configured ? 'ok' : 'error',
      configured,
      provider:   settings?.provider   ?? null,
      providerId: settings?.providerId ?? null,
      model:      settings?.model      ?? null,
      timestamp:  new Date().toISOString(),
    });
  });
}
