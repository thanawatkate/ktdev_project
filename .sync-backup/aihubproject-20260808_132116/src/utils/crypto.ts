import crypto from 'crypto';

/** SHA-256 hash of a project API key for safe storage */
export function hashApiKey(rawKey: string): string {
  return crypto.createHash('sha256').update(rawKey).digest('hex');
}

/** Generate a new project API key: hub_live_<32 random hex chars> */
export function generateApiKey(): string {
  return `hub_live_${crypto.randomBytes(16).toString('hex')}`;
}

/** AES-256-GCM encrypt — returns iv:tag:ciphertext (all hex) */
export function encryptValue(plaintext: string, keyHex: string): string {
  const key = Buffer.from(keyHex, 'hex');
  const iv  = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  const encrypted = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return `${iv.toString('hex')}:${tag.toString('hex')}:${encrypted.toString('hex')}`;
}

/** AES-256-GCM decrypt */
export function decryptValue(data: string, keyHex: string): string {
  const [ivHex, tagHex, encHex] = data.split(':');
  if (!ivHex || !tagHex || !encHex) throw new Error('Invalid encrypted value format');
  const key       = Buffer.from(keyHex, 'hex');
  const iv        = Buffer.from(ivHex, 'hex');
  const tag       = Buffer.from(tagHex, 'hex');
  const encrypted = Buffer.from(encHex, 'hex');
  const decipher  = crypto.createDecipheriv('aes-256-gcm', key, iv);
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(encrypted), decipher.final()]).toString('utf8');
}

/** Timing-safe string comparison to prevent timing attacks */
export function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) {
    // Still run comparison to avoid length leak
    crypto.timingSafeEqual(Buffer.alloc(1), Buffer.alloc(1));
    return false;
  }
  return crypto.timingSafeEqual(Buffer.from(a), Buffer.from(b));
}
