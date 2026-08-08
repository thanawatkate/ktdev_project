import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { adminAuth } from '../../middleware/adminAuth.js';
import { buildProjectAuthMiddleware } from '../../middleware/projectAuth.js';
import type { AiQuotaService } from '../../domain/ai/service/AiQuotaService.js';
import type { AiModelPricingService } from '../../domain/ai/service/AiModelPricingService.js';
import type { AiUsageRepository } from '../../domain/ai/repository/AiUsageRepository.js';
import type { ProjectRepository } from '../../domain/project/ProjectRepository.js';

const packageSchema = z.object({
  packageName:          z.string().default('Global Default'),
  requestLimitMonthly:  z.number().nullable().default(null),
  tokenLimitMonthly:    z.number().nullable().default(null),
  costLimitMonthly:     z.number().nullable().default(null),
  currency:             z.string().default('USD'),
  alertThresholds:      z.array(z.number()).default([70, 90, 100]),
  hardLimitEnabled:     z.boolean().default(true),
});

export async function billingRoutes(
  fastify: FastifyInstance,
  opts: {
    quotaService:   AiQuotaService;
    pricingService: AiModelPricingService;
    usageRepo:      AiUsageRepository;
    projectRepo:    ProjectRepository;
  },
): Promise<void> {
  const projectAuth = buildProjectAuthMiddleware(opts.projectRepo);

  // Project-scoped usage summary
  fastify.get('/v1/usage/summary', { preHandler: [projectAuth] }, async (request, reply) => {
    const month = (request.query as { month?: string }).month;
    const status = await opts.quotaService.getStatus(request.project.projectKey, month);
    return reply.send(status);
  });

  // Project-scoped usage logs
  fastify.get('/v1/usage/logs', { preHandler: [projectAuth] }, async (request, reply) => {
    const q      = request.query as { page?: string; limit?: string };
    const page   = Math.max(1, Number(q.page ?? 1));
    const limit  = Math.min(100, Math.max(1, Number(q.limit ?? 20)));
    const result = await opts.usageRepo.getLogs(request.project.projectKey, page, limit);
    return reply.send({ ...result, page, limit });
  });

  // Admin — global billing package
  fastify.get('/admin/billing/package', { preHandler: [adminAuth] }, async (_req, reply) => {
    const pkg = await opts.usageRepo.getCurrentPackage();
    return reply.send(pkg);
  });

  fastify.put('/admin/billing/package', { preHandler: [adminAuth] }, async (request, reply) => {
    const parsed = packageSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: { code: 'INVALID_INPUT', details: parsed.error.flatten().fieldErrors } });
    }
    const pkg = await opts.usageRepo.saveGlobalPackage(parsed.data);
    return reply.send(pkg);
  });

  // Admin — model pricing
  fastify.get('/admin/model-pricing', { preHandler: [adminAuth] }, async (_req, reply) => {
    const rows = await opts.pricingService.listPricing();
    return reply.send({ items: rows });
  });

  fastify.put('/admin/model-pricing', { preHandler: [adminAuth] }, async (request, reply) => {
    const { items } = request.body as { items?: unknown[] };
    if (!Array.isArray(items)) {
      return reply.code(400).send({ error: { code: 'INVALID_INPUT', message: 'items must be an array' } });
    }
    const rowSchema = z.object({
      provider:      z.string(),
      model:         z.string(),
      inputCost:     z.number(),
      outputCost:    z.number(),
      currency:      z.string().default('USD'),
      isActive:      z.boolean().default(true),
      effectiveFrom: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
    });
    const parsed = z.array(rowSchema).safeParse(items);
    if (!parsed.success) {
      return reply.code(400).send({ error: { code: 'INVALID_INPUT', details: parsed.error.flatten().fieldErrors } });
    }
    await opts.pricingService.savePricing(parsed.data);
    return reply.send({ ok: true });
  });
}
