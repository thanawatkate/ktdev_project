import type { Pool, RowDataPacket } from 'mysql2/promise';
import type { AiProviderConfig } from '../../../types/index.js';
import { decryptValue, encryptValue } from '../../../utils/crypto.js';
import { env } from '../../../config/env.js';

export class AiProviderSettingsRepository {
  constructor(private readonly db: Pool) {}

  async listProviders(): Promise<AiProviderConfig[]> {
    const [rows] = await this.db.execute<RowDataPacket[]>(
      'SELECT * FROM ai_provider_configs ORDER BY sort_order ASC, id ASC',
    );
    return (rows as RowDataPacket[]).map(r => this.mapRow(r, true));
  }

  async findProvider(id: string): Promise<AiProviderConfig | null> {
    const [rows] = await this.db.execute<RowDataPacket[]>(
      'SELECT * FROM ai_provider_configs WHERE id = ? LIMIT 1',
      [id],
    );
    const row = rows[0];
    return row ? this.mapRow(row, true) : null;
  }

  /** Resolve the provider for a given usage key (e.g., 'text_default') with decrypted key */
  async resolveUsage(usageKey: string, fallbackModelType: 'text' | 'image'): Promise<ResolvedUsage | null> {
    const [mappingRows] = await this.db.execute<RowDataPacket[]>(
      'SELECT provider_id, model_type FROM ai_usage_mapping WHERE usage_key = ? LIMIT 1',
      [usageKey],
    );
    const mapping = mappingRows[0];
    const providerId  = (mapping?.['provider_id'] as string) ?? '';
    const modelType   = ((mapping?.['model_type'] as string) ?? fallbackModelType) as 'text' | 'image';

    const provider = await this.findEnabledProvider(providerId, modelType);
    if (!provider) return null;

    const model = modelType === 'image' ? provider.imageModel : provider.textModel;
    return { ...provider, providerId: provider.id, modelType, model };
  }

  async saveProvider(config: Partial<AiProviderConfig> & { id: string }): Promise<void> {
    const encKey = config.apiKey
      ? encryptValue(config.apiKey, env.ENCRYPTION_KEY)
      : null;

    await this.db.execute(
      `INSERT INTO ai_provider_configs
         (id, provider, name, api_key_encrypted, base_url, text_model, image_model,
          enabled, capabilities, adapter_type, auth_config, image_request_config, test_request_config)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE
         provider              = VALUES(provider),
         name                  = VALUES(name),
         api_key_encrypted     = COALESCE(VALUES(api_key_encrypted), api_key_encrypted),
         base_url              = VALUES(base_url),
         text_model            = VALUES(text_model),
         image_model           = VALUES(image_model),
         enabled               = VALUES(enabled),
         capabilities          = VALUES(capabilities),
         adapter_type          = VALUES(adapter_type),
         auth_config           = VALUES(auth_config),
         image_request_config  = VALUES(image_request_config),
         test_request_config   = VALUES(test_request_config)`,
      [
        config.id,
        config.provider ?? 'openai',
        config.name ?? '',
        encKey,
        config.baseUrl ?? '',
        config.textModel ?? '',
        config.imageModel ?? '',
        config.enabled !== false ? 1 : 0,
        JSON.stringify(config.capabilities ?? ['text', 'image']),
        config.adapterType ?? 'openai_chat',
        JSON.stringify(config.authConfig ?? {}),
        JSON.stringify(config.imageRequestConfig ?? {}),
        JSON.stringify(config.testRequestConfig ?? {}),
      ],
    );
  }

  async deleteProvider(id: string): Promise<void> {
    await this.db.execute('DELETE FROM ai_provider_configs WHERE id = ?', [id]);
  }

  async saveUsageMapping(entries: Array<{ usageKey: string; providerId: string; modelType: string }>): Promise<void> {
    for (const entry of entries) {
      await this.db.execute(
        `INSERT INTO ai_usage_mapping (usage_key, provider_id, model_type)
         VALUES (?, ?, ?)
         ON DUPLICATE KEY UPDATE provider_id = VALUES(provider_id), model_type = VALUES(model_type)`,
        [entry.usageKey, entry.providerId, entry.modelType],
      );
    }
  }

  async getUsageMapping(): Promise<Array<{ usageKey: string; providerId: string; modelType: string }>> {
    const [rows] = await this.db.execute<RowDataPacket[]>('SELECT * FROM ai_usage_mapping');
    return (rows as RowDataPacket[]).map(r => ({
      usageKey:   r['usage_key'] as string,
      providerId: r['provider_id'] as string,
      modelType:  r['model_type'] as string,
    }));
  }

  private async findEnabledProvider(preferredId: string, modelType: 'text' | 'image'): Promise<AiProviderConfig | null> {
    if (preferredId) {
      const [rows] = await this.db.execute<RowDataPacket[]>(
        `SELECT * FROM ai_provider_configs
         WHERE id = ? AND enabled = 1
         LIMIT 1`,
        [preferredId],
      );
      if (rows[0]) return this.mapRow(rows[0], true);
    }
    // Fallback: first enabled provider that has the required model type configured
    const modelCol = modelType === 'image' ? 'image_model' : 'text_model';
    const [rows] = await this.db.execute<RowDataPacket[]>(
      `SELECT * FROM ai_provider_configs
       WHERE enabled = 1 AND ${modelCol} != ''
       ORDER BY sort_order ASC LIMIT 1`,
    );
    return rows[0] ? this.mapRow(rows[0], true) : null;
  }

  private mapRow(row: RowDataPacket, decryptKey = false): AiProviderConfig {
    let apiKey = '';
    if (decryptKey && row['api_key_encrypted']) {
      try {
        apiKey = decryptValue(row['api_key_encrypted'] as string, env.ENCRYPTION_KEY);
      } catch {
        apiKey = '';
      }
    }

    const parse = (v: unknown) => {
      if (!v) return {};
      return typeof v === 'string' ? JSON.parse(v) : v;
    };

    const parseArr = (v: unknown): string[] => {
      if (!v) return ['text', 'image'];
      const arr = typeof v === 'string' ? JSON.parse(v) : v;
      return Array.isArray(arr) ? arr : ['text', 'image'];
    };

    return {
      id:                  row['id'] as string,
      provider:            row['provider'] as string,
      name:                row['name'] as string,
      apiKey,
      baseUrl:             row['base_url'] as string,
      textModel:           row['text_model'] as string,
      imageModel:          row['image_model'] as string,
      enabled:             Boolean(row['enabled']),
      capabilities:        parseArr(row['capabilities']),
      adapterType:         row['adapter_type'] as string,
      authConfig:          parse(row['auth_config']),
      imageRequestConfig:  parse(row['image_request_config']),
      testRequestConfig:   parse(row['test_request_config']),
    };
  }
}

export interface ResolvedUsage extends AiProviderConfig {
  providerId: string;
  modelType: 'text' | 'image';
  model: string;
}
