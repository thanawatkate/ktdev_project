import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import crypto from 'crypto';
import type { AiImageGenerationService } from '../../domain/ai/service/AiImageGenerationService.js';
import type { AiQuotaService } from '../../domain/ai/service/AiQuotaService.js';
import { AiQuotaExceededException } from '../../domain/ai/service/AiQuotaService.js';
import type { AiUsageLoggerService } from '../../domain/ai/service/AiUsageLoggerService.js';
import type { AiModelPricingService } from '../../domain/ai/service/AiModelPricingService.js';
import { buildProjectAuthMiddleware } from '../../middleware/projectAuth.js';
import type { ProjectRepository } from '../../domain/project/ProjectRepository.js';

const imageSchema = z.object({
  prompt:                  z.string().min(1).max(2000),
  size:                    z.string().default('1024x1024'),
  quality:                 z.string().default('standard'),
  targetWidth:             z.coerce.number().int().min(1).default(1432),
  targetHeight:            z.coerce.number().int().min(0).default(446),
  referenceImageBase64:    z.string().optional(),
  referenceImageMimeType:  z.string().optional(),
  usageKey:                z.string().default('carousel_image'),
  userId:                  z.string().optional(),
});

export async function imageRoutes(
  fastify: FastifyInstance,
  opts: {
    projectRepo:    ProjectRepository;
    imageService:   AiImageGenerationService;
    quotaService:   AiQuotaService;
    usageLogger:    AiUsageLoggerService;
    pricingService: AiModelPricingService;
  },
): Promise<void> {
  const projectAuth = buildProjectAuthMiddleware(opts.projectRepo);

  fastify.post('/v1/image/generate', { preHandler: [projectAuth] }, async (request, reply) => {
    const requestId  = crypto.randomBytes(16).toString('hex');
    const startedAt  = Date.now();
    const projectKey = request.project.projectKey;

    const parsed = imageSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: { code: 'INVALID_INPUT', details: parsed.error.flatten().fieldErrors } });
    }

    const { userId, ...params } = parsed.data;

    try {
      await opts.quotaService.assertCanStartRequest(projectKey);
      const result = await opts.imageService.generate(params);

      // Image generation tokens are estimated — most providers don't return token counts
      const inputTokens  = 0;
      const outputTokens = 0;
      const cost = await opts.pricingService.estimateCost(result.provider, result.model, inputTokens, outputTokens);

      await opts.usageLogger.log({
        requestId,
        projectKey,
        userId,
        feature:       'image_generate',
        action:        params.usageKey,
        provider:      result.provider,
        model:         result.model,
        inputTokens,
        outputTokens,
        totalTokens:   0,
        estimatedCost: cost.estimatedCost,
        currency:      cost.currency,
        status:        'success',
        durationMs:    Date.now() - startedAt,
      });

      return reply.send({
        imageBase64: result.imageBase64,
        mimeType:    result.mimeType,
        provider:    result.provider,
        providerId:  result.providerId,
        model:       result.model,
        requestId,
      });
    } catch (err) {
      const e       = err as Error;
      const isQuota = e instanceof AiQuotaExceededException;
      const code    = isQuota ? 'QUOTA_EXCEEDED' : 'AI_IMAGE_GENERATION_FAILED';
      const status  = isQuota ? 429 : 500;

      await opts.usageLogger.log({
        requestId,
        projectKey,
        userId,
        feature:       'image_generate',
        action:        params.usageKey,
        provider:      '',
        model:         '',
        inputTokens:   0,
        outputTokens:  0,
        totalTokens:   0,
        estimatedCost: 0,
        currency:      'USD',
        status:        isQuota ? 'quota_exceeded' : 'error',
        errorCode:     code,
        httpStatus:    status,
        durationMs:    Date.now() - startedAt,
      });

      return reply.code(status).send({ error: { code, message: e.message } });
    }
  });
}
