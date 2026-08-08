import type { FastifyRequest, FastifyReply } from 'fastify';
import { safeEqual } from '../utils/crypto.js';
import { env } from '../config/env.js';

export async function adminAuth(request: FastifyRequest, reply: FastifyReply): Promise<void> {
  const authHeader = request.headers.authorization ?? '';
  const secret = authHeader.startsWith('Bearer ') ? authHeader.slice(7).trim() : '';

  if (!secret || !safeEqual(secret, env.ADMIN_SECRET)) {
    reply.code(401).send({ error: { code: 'UNAUTHORIZED', message: 'Invalid admin credentials' } });
  }
}
