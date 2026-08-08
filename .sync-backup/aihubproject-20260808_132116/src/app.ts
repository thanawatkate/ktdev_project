import Fastify from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import { env } from './config/env.js';
import { pool } from './db/database.js';

// Repositories
import { ProjectRepository } from './domain/project/ProjectRepository.js';
import { AiProviderSettingsRepository } from './domain/ai/repository/AiProviderSettingsRepository.js';
import { AiUsageRepository } from './domain/ai/repository/AiUsageRepository.js';

// Providers
import { AiProviderHttpClient } from './domain/ai/provider/AiProviderHttpClient.js';
import { AiProviderResponseHelper } from './domain/ai/provider/AiProviderResponseHelper.js';
import { OpenAiChatTextProvider } from './domain/ai/provider/OpenAiChatTextProvider.js';
import { GeminiGenerateContentTextProvider } from './domain/ai/provider/GeminiGenerateContentTextProvider.js';
import { HttpJsonTextProvider } from './domain/ai/provider/HttpJsonTextProvider.js';

// Services
import { AiTextGenerationService } from './domain/ai/service/AiTextGenerationService.js';
import { AiModelPricingService } from './domain/ai/service/AiModelPricingService.js';
import { AiQuotaService } from './domain/ai/service/AiQuotaService.js';
import { AiUsageLoggerService } from './domain/ai/service/AiUsageLoggerService.js';

// Services (image)
import { AiImageGenerationService } from './domain/ai/service/AiImageGenerationService.js';

// Routes
import { healthRoutes } from './routes/v1/healthRoutes.js';
import { textRoutes } from './routes/v1/textRoutes.js';
import { imageRoutes } from './routes/v1/imageRoutes.js';
import { providerRoutes } from './routes/admin/providerRoutes.js';
import { projectRoutes } from './routes/admin/projectRoutes.js';
import { billingRoutes } from './routes/admin/billingRoutes.js';

export async function buildApp() {
  const fastify = Fastify({
    logger: env.NODE_ENV !== 'test',
  });

  // Security
  await fastify.register(helmet, { contentSecurityPolicy: false });
  await fastify.register(cors, {
    origin: env.CORS_ORIGINS.split(',').map(o => o.trim()),
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  });

  // Wire up dependencies
  const httpClient      = new AiProviderHttpClient();
  const responseHelper  = new AiProviderResponseHelper();
  const projectRepo     = new ProjectRepository(pool);
  const settingsRepo    = new AiProviderSettingsRepository(pool);
  const usageRepo       = new AiUsageRepository(pool);

  const textProviders = [
    new OpenAiChatTextProvider(httpClient, responseHelper),
    new GeminiGenerateContentTextProvider(httpClient, responseHelper),
    new HttpJsonTextProvider(httpClient, responseHelper),
  ];

  const pricingService  = new AiModelPricingService(usageRepo);
  const quotaService    = new AiQuotaService(usageRepo);
  const usageLogger     = new AiUsageLoggerService(usageRepo, quotaService);
  const textService     = new AiTextGenerationService(settingsRepo, textProviders);
  const imageService    = new AiImageGenerationService(settingsRepo, httpClient);

  // Register routes
  await fastify.register(healthRoutes, { settingsRepo });
  await fastify.register(textRoutes,  { projectRepo, textService, quotaService, usageLogger, pricingService });
  await fastify.register(imageRoutes, { projectRepo, imageService, quotaService, usageLogger, pricingService });
  await fastify.register(providerRoutes, { settingsRepo, httpClient });
  await fastify.register(projectRoutes, { projectRepo });
  await fastify.register(billingRoutes, { quotaService, pricingService, usageRepo, projectRepo });

  // 404 handler
  fastify.setNotFoundHandler((_req, reply) => {
    reply.code(404).send({ error: { code: 'NOT_FOUND', message: 'Route not found' } });
  });

  // Global error handler
  fastify.setErrorHandler((err, _req, reply) => {
    fastify.log.error(err);
    const status = err.statusCode ?? 500;
    reply.code(status).send({ error: { code: 'INTERNAL_ERROR', message: env.NODE_ENV === 'production' ? 'An error occurred' : err.message } });
  });

  return fastify;
}
