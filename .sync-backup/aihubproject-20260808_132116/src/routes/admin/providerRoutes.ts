import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { adminAuth } from '../../middleware/adminAuth.js';
import type { AiProviderSettingsRepository } from '../../domain/ai/repository/AiProviderSettingsRepository.js';
import type { AiProviderHttpClient } from '../../domain/ai/provider/AiProviderHttpClient.js';
import { env } from '../../config/env.js';
import { encryptValue } from '../../utils/crypto.js';

const saveProviderSchema = z.object({
  id:                 z.string().min(1),
  provider:           z.string().min(1),
  name:               z.string().min(1),
  apiKey:             z.string().optional(),
  baseUrl:            z.string().url(),
  textModel:          z.string().default(''),
  imageModel:         z.string().default(''),
  enabled:            z.boolean().default(true),
  capabilities:       z.array(z.string()).default(['text', 'image']),
  adapterType:        z.string().default('openai_chat'),
  authConfig:         z.record(z.unknown()).default({}),
  imageRequestConfig: z.record(z.unknown()).default({}),
  testRequestConfig:  z.record(z.unknown()).default({}),
});

const saveMappingSchema = z.array(z.object({
  usageKey:   z.string(),
  providerId: z.string(),
  modelType:  z.enum(['text', 'image']),
}));

export async function providerRoutes(
  fastify: FastifyInstance,
  opts: { settingsRepo: AiProviderSettingsRepository; httpClient: AiProviderHttpClient },
): Promise<void> {

  fastify.get('/admin/providers', { preHandler: [adminAuth] }, async (_req, reply) => {
    const providers = await opts.settingsRepo.listProviders();
    const mapping   = await opts.settingsRepo.getUsageMapping();
    return reply.send({
      providers: providers.map(p => ({ ...p, apiKey: p.apiKey ? '***' : '' })),
      usageMapping: mapping,
    });
  });

  fastify.put('/admin/providers', { preHandler: [adminAuth] }, async (request, reply) => {
    const parsed = saveProviderSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: { code: 'INVALID_INPUT', details: parsed.error.flatten().fieldErrors } });
    }
    await opts.settingsRepo.saveProvider(parsed.data as unknown as Parameters<typeof opts.settingsRepo.saveProvider>[0]);
    return reply.code(200).send({ ok: true });
  });

  fastify.delete('/admin/providers/:id', { preHandler: [adminAuth] }, async (request, reply) => {
    const { id } = request.params as { id: string };
    await opts.settingsRepo.deleteProvider(id);
    return reply.send({ ok: true });
  });

  fastify.put('/admin/providers/mapping', { preHandler: [adminAuth] }, async (request, reply) => {
    const parsed = saveMappingSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: { code: 'INVALID_INPUT', details: parsed.error.flatten().fieldErrors } });
    }
    await opts.settingsRepo.saveUsageMapping(parsed.data);
    return reply.send({ ok: true });
  });

  fastify.post('/admin/providers/test', { preHandler: [adminAuth] }, async (request, reply) => {
    const body = request.body as { providerId?: string };
    if (!body.providerId) {
      return reply.code(400).send({ error: { code: 'MISSING_PROVIDER_ID' } });
    }
    const provider = await opts.settingsRepo.findProvider(body.providerId);
    if (!provider) {
      return reply.code(404).send({ error: { code: 'PROVIDER_NOT_FOUND' } });
    }
    try {
      const testCfg    = provider.testRequestConfig as { method?: string; path?: string };
      const method     = (testCfg.method ?? 'GET').toUpperCase();
      const path       = (testCfg.path ?? '/models').replace('{{model}}', encodeURIComponent(provider.textModel || provider.imageModel));
      const url        = `${provider.baseUrl.replace(/\/$/, '')}${path}`;
      const { headers, queryParam } = opts.httpClient.buildAuthHeaders(
        { apiKey: provider.apiKey, authConfig: provider.authConfig },
        { Accept: 'application/json' },
      );
      const fullUrl    = queryParam ? `${url}${url.includes('?') ? '&' : '?'}${queryParam}` : url;
      const result     = await opts.httpClient.requestJson({ method, url: fullUrl, headers, timeoutMs: 15000 });
      return reply.send({ ok: true, data: result });
    } catch (err) {
      return reply.code(400).send({ ok: false, error: { message: (err as Error).message } });
    }
  });
}
