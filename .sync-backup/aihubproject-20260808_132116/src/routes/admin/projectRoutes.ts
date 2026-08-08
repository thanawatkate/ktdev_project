import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { adminAuth } from '../../middleware/adminAuth.js';
import { generateApiKey, hashApiKey } from '../../utils/crypto.js';
import type { ProjectRepository } from '../../domain/project/ProjectRepository.js';

const createProjectSchema = z.object({
  projectKey:      z.string().min(2).max(60).regex(/^[a-z0-9_-]+$/),
  projectName:     z.string().min(1).max(100),
  allowedFeatures: z.array(z.string()).nullable().default(null),
});

export async function projectRoutes(
  fastify: FastifyInstance,
  opts: { projectRepo: ProjectRepository },
): Promise<void> {

  fastify.get('/admin/projects', { preHandler: [adminAuth] }, async (_req, reply) => {
    const projects = await opts.projectRepo.listAll();
    return reply.send({ projects });
  });

  fastify.post('/admin/projects', { preHandler: [adminAuth] }, async (request, reply) => {
    const parsed = createProjectSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: { code: 'INVALID_INPUT', details: parsed.error.flatten().fieldErrors } });
    }

    const rawKey   = generateApiKey();
    const prefix   = rawKey.slice(0, 16);
    const keyHash  = hashApiKey(rawKey);

    await opts.projectRepo.create({
      projectKey:      parsed.data.projectKey,
      projectName:     parsed.data.projectName,
      apiKeyHash:      keyHash,
      apiKeyPrefix:    prefix,
      allowedFeatures: parsed.data.allowedFeatures,
    });

    // Return the raw key ONCE — not stored in DB
    return reply.code(201).send({
      projectKey: parsed.data.projectKey,
      apiKey:     rawKey,
      prefix,
      warning:    'Save this API key now — it will not be shown again.',
    });
  });

  fastify.post('/admin/projects/:key/rotate', { preHandler: [adminAuth] }, async (request, reply) => {
    const { key } = request.params as { key: string };
    const rawKey  = generateApiKey();
    const prefix  = rawKey.slice(0, 16);
    await opts.projectRepo.rotateApiKey(key, hashApiKey(rawKey), prefix);
    return reply.send({
      projectKey: key,
      apiKey:     rawKey,
      prefix,
      warning:    'Save this API key now — it will not be shown again.',
    });
  });

  fastify.delete('/admin/projects/:key', { preHandler: [adminAuth] }, async (request, reply) => {
    const { key } = request.params as { key: string };
    await opts.projectRepo.setActive(key, false);
    return reply.send({ ok: true });
  });
}
