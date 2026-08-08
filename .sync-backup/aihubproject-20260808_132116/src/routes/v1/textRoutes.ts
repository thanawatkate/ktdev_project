import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import crypto from 'crypto';
import type { AiTextGenerationService } from '../../domain/ai/service/AiTextGenerationService.js';
import type { AiQuotaService } from '../../domain/ai/service/AiQuotaService.js';
import { AiQuotaExceededException } from '../../domain/ai/service/AiQuotaService.js';
import type { AiUsageLoggerService } from '../../domain/ai/service/AiUsageLoggerService.js';
import type { AiModelPricingService } from '../../domain/ai/service/AiModelPricingService.js';
import { buildProjectAuthMiddleware } from '../../middleware/projectAuth.js';
import type { ProjectRepository } from '../../domain/project/ProjectRepository.js';

const assistSchema = z.object({
  action:       z.string().default('custom'),
  content:      z.string().default(''),
  selectedText: z.string().default(''),
  prompt:       z.string().default(''),
  language:     z.string().default('th'),
  userId:       z.string().optional(),
});

export async function textRoutes(
  fastify: FastifyInstance,
  opts: {
    projectRepo:   ProjectRepository;
    textService:   AiTextGenerationService;
    quotaService:  AiQuotaService;
    usageLogger:   AiUsageLoggerService;
    pricingService: AiModelPricingService;
  },
): Promise<void> {
  const projectAuth = buildProjectAuthMiddleware(opts.projectRepo);

  fastify.post('/v1/text/assist', { preHandler: [projectAuth] }, async (request, reply) => {
    const requestId  = crypto.randomBytes(16).toString('hex');
    const startedAt  = Date.now();
    const projectKey = request.project.projectKey;

    const parsed = assistSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: { code: 'INVALID_INPUT', message: 'Invalid request body', details: parsed.error.flatten().fieldErrors } });
    }

    const { userId, ...payload } = parsed.data;

    try {
      await opts.quotaService.assertCanStartRequest(projectKey);
      const result = await opts.textService.assist(payload);
      const cost   = await opts.pricingService.estimateCost(
        result.provider,
        result.model,
        result.usage.inputTokens,
        result.usage.outputTokens,
      );

      await opts.usageLogger.log({
        requestId,
        projectKey,
        userId,
        feature:       'text_assist',
        action:        payload.action,
        provider:      result.provider,
        model:         result.model,
        inputTokens:   result.usage.inputTokens,
        outputTokens:  result.usage.outputTokens,
        totalTokens:   result.usage.totalTokens,
        estimatedCost: cost.estimatedCost,
        currency:      cost.currency,
        status:        'success',
        durationMs:    Date.now() - startedAt,
      });

      return reply.send({
        result:     result.text,
        action:     payload.action,
        provider:   result.provider,
        providerId: result.providerId,
        model:      result.model,
        usage: {
          inputTokens:   result.usage.inputTokens,
          outputTokens:  result.usage.outputTokens,
          totalTokens:   result.usage.totalTokens,
          estimatedCost: cost.estimatedCost,
          currency:      cost.currency,
          pricingFound:  cost.pricingFound,
          requestId,
          source:        result.usage.source,
        },
      });
    } catch (err) {
      const e = err as Error;
      const isQuota = e instanceof AiQuotaExceededException;
      const code    = isQuota ? 'QUOTA_EXCEEDED' : 'AI_REQUEST_FAILED';
      const status  = isQuota ? 429 : 500;

      await opts.usageLogger.log({
        requestId,
        projectKey,
        userId,
        feature:       'text_assist',
        action:        payload.action,
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
