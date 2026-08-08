import { env } from '../../../config/env.js';

interface RequestOptions {
  method: string;
  url: string;
  body?: unknown;
  headers: Record<string, string>;
  timeoutMs: number;
}

interface FetchResult {
  status: number;
  data: unknown;
}

export class AiProviderHttpClient {
  private readonly timeoutSeconds: number;
  private readonly retryAttempts: number;
  private readonly retryDelayMs: number;

  constructor() {
    this.timeoutSeconds = env.AI_PROVIDER_TIMEOUT_SECONDS;
    this.retryAttempts  = env.AI_PROVIDER_RETRY_ATTEMPTS;
    this.retryDelayMs   = env.AI_PROVIDER_RETRY_DELAY_MS;
  }

  buildAuthHeaders(
    settings: { apiKey: string; authConfig: { type: string; header: string; queryKey: string } },
    base: Record<string, string>,
  ): { headers: Record<string, string>; queryParam?: string } {
    const headers = { ...base };
    const { type, header, queryKey } = settings.authConfig;
    const apiKey = settings.apiKey;

    if (type === 'bearer' && apiKey) {
      headers[header || 'Authorization'] = `Bearer ${apiKey}`;
      return { headers };
    }

    if (type === 'query' && apiKey) {
      // Query param auth — return separately to append to URL
      return { headers, queryParam: `${queryKey || 'key'}=${encodeURIComponent(apiKey)}` };
    }

    return { headers };
  }

  async requestJson(opts: RequestOptions & { retries?: number }): Promise<unknown> {
    const retries   = opts.retries ?? this.retryAttempts;
    const delayMs   = this.retryDelayMs;
    let lastErr: Error = new Error('Request failed');

    for (let attempt = 0; attempt <= retries; attempt++) {
      try {
        const { status, data } = await this.doFetch(opts);

        if ((status >= 500 || status === 429) && attempt < retries) {
          await this.delay(delayMs * (attempt + 1));
          continue;
        }

        if (status >= 400) {
          const msg = this.extractErrorMessage(data) ?? `AI provider error ${status}`;
          throw new Error(msg);
        }

        return data;
      } catch (err) {
        lastErr = err as Error;
        if (attempt < retries) {
          await this.delay(delayMs * (attempt + 1));
        }
      }
    }

    throw lastErr;
  }

  private async doFetch(opts: RequestOptions): Promise<FetchResult> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), opts.timeoutMs);

    try {
      const init: RequestInit = {
        method:  opts.method,
        headers: opts.headers,
        signal:  controller.signal,
      };

      if (opts.body && opts.method !== 'GET' && opts.method !== 'HEAD') {
        (init as RequestInit & { body: string }).body = JSON.stringify(opts.body);
      }

      const response = await fetch(opts.url, init);
      let data: unknown;
      try {
        data = await response.json();
      } catch {
        data = null;
      }
      return { status: response.status, data };
    } finally {
      clearTimeout(timer);
    }
  }

  private extractErrorMessage(data: unknown): string | null {
    if (!data || typeof data !== 'object') return null;
    const d = data as Record<string, unknown>;
    const err = d['error'];
    if (err && typeof err === 'object') {
      const e = err as Record<string, unknown>;
      return (e['message'] as string) ?? null;
    }
    return (d['message'] as string) ?? null;
  }

  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}
