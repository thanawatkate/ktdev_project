import { z } from 'zod';
import dotenv from 'dotenv';

dotenv.config();

const schema = z.object({
  NODE_ENV:                     z.enum(['development', 'production', 'test']).default('development'),
  PORT:                         z.coerce.number().default(3400),
  HOST:                         z.string().default('0.0.0.0'),
  DB_HOST:                      z.string().default('localhost'),
  DB_PORT:                      z.coerce.number().default(3306),
  DB_NAME:                      z.string(),
  DB_USER:                      z.string(),
  DB_PASSWORD:                  z.string(),
  ADMIN_SECRET:                 z.string().min(32, 'ADMIN_SECRET must be at least 32 characters'),
  ENCRYPTION_KEY:               z.string().length(64, 'ENCRYPTION_KEY must be 64 hex characters (32 bytes)'),
  AI_PROVIDER_TIMEOUT_SECONDS:  z.coerce.number().default(60),
  AI_PROVIDER_RETRY_ATTEMPTS:   z.coerce.number().default(1),
  AI_PROVIDER_RETRY_DELAY_MS:   z.coerce.number().default(250),
  CORS_ORIGINS:                 z.string().default('http://localhost:5173'),
});

const parsed = schema.safeParse(process.env);
if (!parsed.success) {
  console.error('[config] Invalid environment variables:\n', parsed.error.flatten().fieldErrors);
  process.exit(1);
}

export const env = parsed.data;
export type Env = typeof env;
