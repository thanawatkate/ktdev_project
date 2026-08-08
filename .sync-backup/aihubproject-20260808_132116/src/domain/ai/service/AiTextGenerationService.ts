import type { AiTextProviderInterface } from '../provider/AiTextProviderInterface.js';
import type { AiProviderSettingsRepository } from '../repository/AiProviderSettingsRepository.js';
import type { AiMessage, AiTextRequest, AiGenerationResult } from '../../../types/index.js';

const MAX_CONTENT_LENGTH   = 12000;
const MAX_SELECTION_LENGTH = 6000;
const MAX_PROMPT_LENGTH    = 2000;

const ALLOWED_ACTIONS = ['improve', 'formal', 'expand', 'summarize', 'translate_th', 'translate_en', 'proofread', 'custom'] as const;
type Action = typeof ALLOWED_ACTIONS[number];

export class AiTextGenerationService {
  constructor(
    private readonly settingsRepo: AiProviderSettingsRepository,
    private readonly providers: AiTextProviderInterface[],
  ) {}

  async assist(payload: Partial<AiTextRequest>): Promise<AiGenerationResult & { provider: string; providerId: string; model: string }> {
    const settings = await this.settingsRepo.resolveUsage('text_default', 'text');
    if (!settings) throw new Error('AI text provider is not configured');
    if (!settings.apiKey && settings.authConfig.type !== 'none') {
      throw new Error('AI text provider API key is not configured');
    }

    const action       = this.normalizeAction(payload.action ?? 'custom');
    const language     = this.normalizeLanguage(payload.language ?? 'th');
    const prompt       = this.limit(payload.prompt ?? '', MAX_PROMPT_LENGTH);
    const selectedText = this.limit(payload.selectedText ?? '', MAX_SELECTION_LENGTH);
    const content      = this.limit(payload.content ?? '', MAX_CONTENT_LENGTH);

    if (!prompt && !selectedText && !content) {
      throw new Error('Prompt or editor content is required');
    }

    const messages  = this.buildMessages(action, language, prompt, selectedText, content);
    const provider  = this.resolveProvider(settings.provider, settings.adapterType);
    if (!provider) throw new Error(`No provider adapter for "${settings.provider}" / "${settings.adapterType}"`);

    const result = await provider.generate(
      {
        apiKey:     settings.apiKey,
        baseUrl:    settings.baseUrl,
        model:      settings.model,
        adapterType: settings.adapterType,
        authConfig: settings.authConfig,
      },
      messages,
    );

    return {
      ...result,
      provider:   settings.provider,
      providerId: settings.providerId,
      model:      settings.model,
    };
  }

  private resolveProvider(provider: string, adapterType: string): AiTextProviderInterface | null {
    return this.providers.find(p => p.supports(provider, adapterType)) ?? null;
  }

  private normalizeAction(action: string): Action {
    const a = action.toLowerCase().trim();
    return (ALLOWED_ACTIONS as readonly string[]).includes(a) ? (a as Action) : 'custom';
  }

  private normalizeLanguage(language: string): 'th' | 'en' {
    return language.toLowerCase().startsWith('en') ? 'en' : 'th';
  }

  private limit(text: string, max: number): string {
    return text.slice(0, max);
  }

  private buildMessages(action: Action, language: 'th' | 'en', prompt: string, selectedText: string, content: string): AiMessage[] {
    const langName  = language === 'en' ? 'English' : 'Thai';
    const target    = selectedText || content;
    const instruction = this.getInstruction(action, langName, prompt);

    const system = [
      'You are an assistant embedded in a public-sector CMS rich text editor.',
      'Return only the edited or generated content — no preamble, no explanation.',
      'Do not wrap the answer in Markdown code fences.',
      'Preserve useful HTML tags when the input contains HTML.',
      'Avoid inventing facts, names, dates, phone numbers, or official claims.',
      'Use a clear, polite, public-facing tone.',
    ].join('\n');

    const userParts = [`Task: ${instruction}`, `Target language: ${langName}`];
    if (prompt) userParts.push(`User instruction: ${prompt}`);
    if (selectedText) {
      userParts.push(`Selected text:\n${selectedText}`);
      if (content && content !== selectedText) userParts.push(`Editor context:\n${content}`);
    } else {
      userParts.push(`Editor content:\n${target}`);
    }

    return [
      { role: 'system', content: system },
      { role: 'user',   content: userParts.join('\n\n') },
    ];
  }

  private getInstruction(action: Action, lang: string, prompt: string): string {
    switch (action) {
      case 'improve':      return `Improve the clarity, flow, and readability of the text in ${lang}.`;
      case 'formal':       return `Rewrite the text in a formal tone in ${lang}.`;
      case 'expand':       return `Expand the text with more detail in ${lang}.`;
      case 'summarize':    return `Summarize the text concisely in ${lang}.`;
      case 'translate_th': return 'Translate the text to Thai.';
      case 'translate_en': return 'Translate the text to English.';
      case 'proofread':    return `Correct grammar, spelling, and punctuation in ${lang}.`;
      default:             return prompt || 'Process the text as instructed.';
    }
  }
}
