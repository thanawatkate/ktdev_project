import type { AiTextProviderInterface, ResolvedSettings, GenerationResult } from './AiTextProviderInterface.js';
import { AiProviderHttpClient } from './AiProviderHttpClient.js';
import { AiProviderResponseHelper } from './AiProviderResponseHelper.js';
import type { AiMessage } from '../../../types/index.js';
import { env } from '../../../config/env.js';

/** Generic HTTP-JSON text provider for any OpenAI-compatible or custom endpoint */
export class HttpJsonTextProvider implements AiTextProviderInterface {
  constructor(
    private readonly client: AiProviderHttpClient,
    private readonly helper: AiProviderResponseHelper,
  ) {}

  supports(provider: string, adapterType: string): boolean {
    return adapterType === 'http_json' || provider === 'custom';
  }

  async generate(settings: ResolvedSettings, messages: AiMessage[]): Promise<GenerationResult> {
    const baseUrl = settings.baseUrl.replace(/\/$/, '');
    const { headers, queryParam } = this.client.buildAuthHeaders(
      { apiKey: settings.apiKey, authConfig: settings.authConfig as ResolvedSettings['authConfig'] },
      { 'Content-Type': 'application/json', Accept: 'application/json' },
    );

    const url = `${baseUrl}/chat/completions${queryParam ? `?${queryParam}` : ''}`;
    const body = {
      model:       settings.model,
      messages:    messages.map(m => ({ role: m.role, content: m.content })),
      temperature: 0.4,
    };

    const data = await this.client.requestJson({
      method:    'POST',
      url,
      body,
      headers,
      timeoutMs: env.AI_PROVIDER_TIMEOUT_SECONDS * 1000,
    }) as Record<string, unknown>;

    const choice  = ((data['choices'] as unknown[])?.[0] ?? {}) as Record<string, unknown>;
    const message = (choice['message'] ?? {}) as Record<string, unknown>;
    const content = (message['content'] as string) ?? '';

    return {
      text:  this.helper.normalizeResult(content),
      usage: this.helper.normalizeOpenAiUsage(
        data['usage'] as Record<string, number>,
        messages,
        content,
      ),
    };
  }
}
