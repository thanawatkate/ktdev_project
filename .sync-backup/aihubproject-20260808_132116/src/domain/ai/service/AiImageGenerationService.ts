import type { AiProviderSettingsRepository } from '../repository/AiProviderSettingsRepository.js';
import { AiProviderHttpClient } from '../provider/AiProviderHttpClient.js';
import { env } from '../../../config/env.js';

export interface ImageGenerateParams {
  prompt: string;
  size: string;
  quality: string;
  targetWidth: number;
  targetHeight: number;
  referenceImageBase64?: string;
  referenceImageMimeType?: string;
  usageKey?: string;
}

export interface ImageResult {
  imageBase64: string;
  mimeType: string;
  provider: string;
  providerId: string;
  model: string;
}

export class AiImageGenerationService {
  constructor(
    private readonly settingsRepo: AiProviderSettingsRepository,
    private readonly httpClient: AiProviderHttpClient,
  ) {}

  async generate(params: ImageGenerateParams): Promise<ImageResult> {
    const usageKey = params.usageKey ?? 'carousel_image';
    const settings = await this.settingsRepo.resolveUsage(usageKey, 'image');
    if (!settings) throw new Error('AI image provider is not configured');
    if (!settings.apiKey && settings.authConfig.type !== 'none') {
      throw new Error('AI image provider API key is not configured');
    }

    const prompt = this.buildPrompt(params.prompt, params.targetWidth, params.targetHeight);
    const { provider, adapterType } = settings;

    let imageBase64: string;
    let mimeType: string;

    if (provider === 'gemini' || adapterType === 'gemini_generate_content') {
      ({ imageBase64, mimeType } = await this.generateGemini(settings, prompt, params));
    } else {
      // openai / openai_compatible / http_json / custom
      ({ imageBase64, mimeType } = await this.generateOpenAi(settings, prompt, params));
    }

    return {
      imageBase64,
      mimeType,
      provider: settings.provider,
      providerId: settings.providerId,
      model: settings.imageModel,
    };
  }

  // -----------------------------------------------------------------------

  private async generateOpenAi(
    settings: Awaited<ReturnType<AiProviderSettingsRepository['resolveUsage']>> & object,
    prompt: string,
    params: ImageGenerateParams,
  ): Promise<{ imageBase64: string; mimeType: string }> {
    const base  = (settings as { baseUrl: string }).baseUrl.replace(/\/$/, '');
    const model = (settings as { imageModel: string }).imageModel;
    const apiKey = (settings as { apiKey: string }).apiKey;
    const timeoutMs = env.AI_PROVIDER_TIMEOUT_SECONDS * 1000;

    // Image edit (with reference) uses multipart
    if (params.referenceImageBase64) {
      const form = new FormData();
      const refBytes = Buffer.from(params.referenceImageBase64, 'base64');
      const mime     = params.referenceImageMimeType ?? 'image/png';
      const ext      = mime.split('/')[1] ?? 'png';
      form.append('image', new Blob([refBytes], { type: mime }), `reference.${ext}`);
      form.append('model',   model);
      form.append('prompt',  prompt);
      form.append('size',    params.size   || '1024x1024');
      form.append('quality', params.quality || 'standard');
      form.append('n',       '1');

      const ctrl  = new AbortController();
      const timer = setTimeout(() => ctrl.abort(), timeoutMs);
      try {
        const resp = await fetch(`${base}/images/edits`, {
          method:  'POST',
          headers: { Authorization: `Bearer ${apiKey}`, Accept: 'application/json' },
          body:    form,
          signal:  ctrl.signal,
        });
        const data = await resp.json() as Record<string, unknown>;
        return await this.extractOpenAiImage(data);
      } finally {
        clearTimeout(timer);
      }
    }

    // Standard text-to-image
    const body = { model, prompt, size: params.size || '1024x1024', quality: params.quality || 'standard', n: 1, response_format: 'b64_json' };
    const data = await this.httpClient.requestJson({
      method:    'POST',
      url:       `${base}/images/generations`,
      body,
      headers:   { 'Content-Type': 'application/json', Accept: 'application/json', Authorization: `Bearer ${apiKey}` },
      timeoutMs,
    }) as Record<string, unknown>;

    return await this.extractOpenAiImage(data);
  }

  private async generateGemini(
    settings: Awaited<ReturnType<AiProviderSettingsRepository['resolveUsage']>> & object,
    prompt: string,
    params: ImageGenerateParams,
  ): Promise<{ imageBase64: string; mimeType: string }> {
    const base   = (settings as { baseUrl: string }).baseUrl.replace(/\/$/, '');
    const model  = encodeURIComponent((settings as { imageModel: string }).imageModel).replace(/%2F/gi, '/');
    const apiKey = (settings as { apiKey: string }).apiKey;

    const parts: unknown[] = [{ text: prompt }];
    if (params.referenceImageBase64) {
      parts.unshift({ inlineData: { mimeType: params.referenceImageMimeType ?? 'image/png', data: params.referenceImageBase64 } });
    }

    const data = await this.httpClient.requestJson({
      method:    'POST',
      url:       `${base}/models/${model}:generateContent?key=${encodeURIComponent(apiKey)}`,
      body:      { contents: [{ role: 'user', parts }], generationConfig: { responseModalities: ['TEXT', 'IMAGE'] } },
      headers:   { 'Content-Type': 'application/json', Accept: 'application/json' },
      timeoutMs: env.AI_PROVIDER_TIMEOUT_SECONDS * 1000,
    }) as Record<string, unknown>;

    const candidates = (data['candidates'] as unknown[]) ?? [];
    for (const c of candidates) {
      const parts2 = ((c as Record<string, unknown>)['content'] as Record<string, unknown>)?.['parts'] as unknown[] ?? [];
      for (const p of parts2) {
        const inline = ((p as Record<string, unknown>)['inlineData'] ?? (p as Record<string, unknown>)['inline_data']) as Record<string, string> | undefined;
        if (inline?.['data']) {
          return { imageBase64: inline['data'], mimeType: inline['mimeType'] ?? 'image/png' };
        }
      }
    }
    throw new Error('Gemini did not return an image');
  }

  private async extractOpenAiImage(data: Record<string, unknown>): Promise<{ imageBase64: string; mimeType: string }> {
    const items = (data['data'] as unknown[]) ?? [];
    const first = (items[0] ?? {}) as Record<string, string>;
    if (first['b64_json']) return { imageBase64: first['b64_json'], mimeType: 'image/png' };
    if (first['url'])      return await this.downloadAndEncode(first['url']);
    throw new Error('AI provider did not return an image');
  }

  private async downloadAndEncode(url: string): Promise<{ imageBase64: string; mimeType: string }> {
    const resp  = await fetch(url, { signal: AbortSignal.timeout(30000) });
    const mime  = resp.headers.get('content-type') ?? 'image/png';
    const bytes = Buffer.from(await resp.arrayBuffer());
    return { imageBase64: bytes.toString('base64'), mimeType: mime.split(';')[0]?.trim() ?? 'image/png' };
  }

  private buildPrompt(rawPrompt: string, w: number, h: number): string {
    const hint = h > 0 ? `${w}x${h} website carousel banner` : `${w}px wide website carousel image`;
    return `${rawPrompt.trim()}\n\nCreate a polished ${hint}. Avoid text, logos, watermarks, UI mockups, and distorted people. Keep the main subject centered with safe margins for responsive cropping.`;
  }
}
