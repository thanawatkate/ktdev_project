import type { AiMessage } from '../../../types/index.js';

export class AiProviderResponseHelper {
  normalizeResult(content: string): string {
    const result = content.trim();
    if (!result) throw new Error('AI provider returned an empty response');
    return result.replace(/^```(?:html|markdown|md|text)?\s*|\s*```$/gi, '');
  }

  normalizeOpenAiUsage(
    usage: Record<string, number> | null | undefined,
    messages: AiMessage[],
    text: string,
  ) {
    if (usage && typeof usage === 'object') {
      const input  = Math.max(0, (usage['prompt_tokens']     ?? 0));
      const output = Math.max(0, (usage['completion_tokens'] ?? 0));
      return { inputTokens: input, outputTokens: output, totalTokens: input + output, source: 'provider' as const };
    }
    return this.estimateUsage(messages, text);
  }

  normalizeGeminiUsage(
    usage: Record<string, number> | null | undefined,
    messages: AiMessage[],
    text: string,
  ) {
    if (usage && typeof usage === 'object') {
      const input  = Math.max(0, (usage['promptTokenCount']     ?? 0));
      const output = Math.max(0, (usage['candidatesTokenCount'] ?? 0));
      const total  = Math.max(0, (usage['totalTokenCount']      ?? input + output));
      return { inputTokens: input, outputTokens: output, totalTokens: total, source: 'provider' as const };
    }
    return this.estimateUsage(messages, text);
  }

  estimateUsage(messages: AiMessage[], text: string) {
    const prompt = messages.map(m => m.content).join('\n');
    const input  = this.estimateTokens(prompt);
    const output = this.estimateTokens(text);
    return { inputTokens: input, outputTokens: output, totalTokens: input + output, source: 'estimated' as const };
  }

  private estimateTokens(value: string): number {
    if (!value) return 0;
    return Math.max(1, Math.ceil(value.length / 4));
  }
}
