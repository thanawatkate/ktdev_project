import type { AiTextProviderInterface, ResolvedSettings, GenerationResult } from './AiTextProviderInterface.js';
import { AiProviderHttpClient } from './AiProviderHttpClient.js';
import { AiProviderResponseHelper } from './AiProviderResponseHelper.js';
import type { AiMessage } from '../../../types/index.js';
import { env } from '../../../config/env.js';

export class GeminiGenerateContentTextProvider implements AiTextProviderInterface {
  constructor(
    private readonly client: AiProviderHttpClient,
    private readonly helper: AiProviderResponseHelper,
  ) {}

  supports(provider: string, adapterType: string): boolean {
    return provider === 'gemini' || adapterType === 'gemini_generate_content';
  }

  async generate(settings: ResolvedSettings, messages: AiMessage[]): Promise<GenerationResult> {
    const baseUrl = settings.baseUrl.replace(/\/$/, '');
    const model   = encodeURIComponent(settings.model).replace(/%2F/gi, '/');

    const { headers, queryParam } = this.client.buildAuthHeaders(
      { apiKey: settings.apiKey, authConfig: settings.authConfig as ResolvedSettings['authConfig'] },
      { 'Content-Type': 'application/json', Accept: 'application/json' },
    );

    const parts: string[] = messages.map(m => `${m.role.toUpperCase()}:\n${m.content}`);
    const url = `${baseUrl}/models/${model}:generateContent${queryParam ? `?${queryParam}` : ''}`;
    const body = {
      contents: [{ role: 'user', parts: [{ text: parts.join('\n\n') }] }],
      generationConfig: { temperature: 0.4 },
    };

    const data = await this.client.requestJson({
      method:    'POST',
      url,
      body,
      headers,
      timeoutMs: env.AI_PROVIDER_TIMEOUT_SECONDS * 1000,
    }) as Record<string, unknown>;

    const responseParts = (
      ((data['candidates'] as unknown[])?.[0] as Record<string, unknown>)?.['content'] as Record<string, unknown>
    )?.['parts'] as Array<Record<string, unknown>> ?? [];

    const content = responseParts
      .filter(p => typeof p['text'] === 'string')
      .map(p => p['text'] as string)
      .join('');

    return {
      text:  this.helper.normalizeResult(content),
      usage: this.helper.normalizeGeminiUsage(
        data['usageMetadata'] as Record<string, number>,
        messages,
        content,
      ),
    };
  }
}
