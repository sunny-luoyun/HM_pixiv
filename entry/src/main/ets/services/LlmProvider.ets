import http from '@ohos.net.http';
import { BusinessError } from '@ohos.base';

export interface LlmConfig {
  baseUrl: string;
  apiKey: string;
  model: string;
  supportsThinking: boolean;
  maxTokensTitle: number;
  maxTokensFull: number;
  supportsCostEstimate: boolean;
}

export interface TranslationUsage {
  totalChars: number;
  inputTokens: number;
  estimatedOutputTokens: number;
  estimatedCost?: number;
  actualInputTokens?: number;
  actualOutputTokens?: number;
}

export interface TranslationResult {
  success: boolean;
  translatedText?: string;
  error?: string;
  usage?: TranslationUsage;
}

export interface TranslationStats {
  totalChars: number;
  totalRequests: number;
}

interface ThinkingConfig {
  type: string;
}

export const DEFAULT_TITLE_PROMPT = `你是一个专业的日文翻译。请将以下日文标题翻译成中文。
要求：
1. 保持原标题的风格和意境
2. 如果标题包含专有名词（人名、地名等），使用常见译名
3. 翻译要简洁准确
4. 只返回翻译后的中文标题，不要添加任何解释`;

export const DEFAULT_FULL_PROMPT = `你是专业日文小说翻译。将以下日文准确、流畅地译成中文，严格保留原文段落与标点格式，不生硬直译。只输出译文，不附加解释。`;

interface LlmMessage {
  role: string;
  content: string;
  reasoning_content?: string;
}

interface LlmChoice {
  index: number;
  message: LlmMessage;
  finish_reason: string;
}

interface LlmUsageData {
  prompt_tokens: number;
  completion_tokens: number;
  total_tokens: number;
}

interface LlmResponse {
  id: string;
  choices: LlmChoice[];
  usage: LlmUsageData;
}

class AdaptiveConcurrencyController {
  private windowSize: number = 5;
  private readonly minWindow: number = 1;
  private readonly maxWindow: number = 50;
  private readonly successIncrement: number = 1;
  private readonly failureDecrementFactor: number = 2;
  private consecutiveSuccess: number = 0;

  getCurrentWindow(): number {
    return this.windowSize;
  }

  onSuccess(): void {
    this.consecutiveSuccess++;
    if (this.consecutiveSuccess >= 3) {
      this.windowSize = Math.min(this.windowSize + this.successIncrement, this.maxWindow);
      this.consecutiveSuccess = 0;
    }
  }

  onFailure(errorType: 'rate_limit' | 'timeout' | 'other'): void {
    this.consecutiveSuccess = 0;
    switch (errorType) {
      case 'rate_limit':
        this.windowSize = Math.max(this.minWindow, Math.floor(this.windowSize / this.failureDecrementFactor));
        break;
      case 'timeout':
        this.windowSize = Math.max(this.minWindow, this.windowSize - 2);
        break;
      default:
        break;
    }
  }
}

export abstract class BaseLlmService {
  protected baseUrl: string;
  protected apiKey: string;
  protected model: string;
  protected readonly supportsThinking: boolean;
  protected readonly maxTokensTitle: number;
  protected readonly maxTokensFull: number;
  readonly supportsCostEstimate: boolean;

  protected titlePrompt: string = '';
  protected fullPrompt: string = '';
  protected unifiedPrompt: boolean = false;

  private totalTranslatedChars: number = 0;
  private totalRequests: number = 0;

  constructor(config: LlmConfig) {
    this.baseUrl = config.baseUrl;
    this.apiKey = config.apiKey;
    this.model = config.model;
    this.supportsThinking = config.supportsThinking;
    this.maxTokensTitle = config.maxTokensTitle;
    this.maxTokensFull = config.maxTokensFull;
    this.supportsCostEstimate = config.supportsCostEstimate;
  }

  updateApiKey(apiKey: string): void {
    this.apiKey = apiKey;
  }

  hasValidKey(): boolean {
    return this.apiKey.length > 0 && this.apiKey.trim().length > 0;
  }

  getStats(): TranslationStats {
    return {
      totalChars: this.totalTranslatedChars,
      totalRequests: this.totalRequests
    };
  }

  updatePrompts(titlePrompt: string, fullPrompt: string, unifiedPrompt: boolean): void {
    this.titlePrompt = titlePrompt ?? '';
    this.fullPrompt = fullPrompt ?? '';
    this.unifiedPrompt = unifiedPrompt ?? false;
  }

  estimateTokens(text: string): number {
    return Math.round(text.length * 0.68);
  }

  estimateTime(inputTokens: number): number {
    const estimatedOutput = Math.round(inputTokens * 0.65);
    const estimatedTotalTokens = inputTokens + estimatedOutput;
    const speed = 800;
    return Math.round((estimatedTotalTokens / speed) * 1000);
  }

  getAdaptiveRatio(): number {
    return 0.65;
  }

  getRatioCount(): number {
    return 0;
  }

  protected async onTranslateSuccess(
    actualInput: number,
    actualOutput: number,
    isTitle: boolean,
    elapsedMs: number
  ): Promise<void> {
    // 子类可覆写（如 DeepSeek 记录校准比例与速度）
  }

  getSystemPrompt(isTitle: boolean): string {
    if (this.unifiedPrompt) {
      const p = this.titlePrompt.trim();
      return p.length > 0 ? p : (isTitle ? DEFAULT_TITLE_PROMPT : DEFAULT_FULL_PROMPT);
    }
    if (isTitle) {
      return this.titlePrompt.trim().length > 0 ? this.titlePrompt.trim() : DEFAULT_TITLE_PROMPT;
    }
    return this.fullPrompt.trim().length > 0 ? this.fullPrompt.trim() : DEFAULT_FULL_PROMPT;
  }

  buildRequestBody(text: string, isTitle: boolean): Record<string, Object> {
    const messages: LlmMessage[] = [
      { role: 'system', content: this.getSystemPrompt(isTitle) } as LlmMessage,
      { role: 'user', content: '请将以下日文翻译成中文：\n' + text } as LlmMessage
    ];
    const body: Record<string, Object> = {
      'model': this.model,
      'messages': messages,
      'temperature': isTitle ? 0.8 : 0.3,
      'max_tokens': isTitle ? this.maxTokensTitle : this.maxTokensFull
    };
    if (this.supportsThinking) {
      const thinkingConfig: ThinkingConfig = { type: 'disabled' };
      body['thinking'] = thinkingConfig;
    }
    return body;
  }

  async translateText(text: string, isTitle: boolean = false): Promise<TranslationResult> {
    if (!this.hasValidKey()) {
      return { success: false, error: '请先在设置中配置翻译 API 密钥' };
    }

    if (!text || text.trim().length === 0) {
      return { success: false, error: '翻译文本不能为空' };
    }

    const httpRequest = http.createHttp();
    const startTime = Date.now();

    try {
      const response = await httpRequest.request(this.baseUrl, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.apiKey}`
        },
        extraData: JSON.stringify(this.buildRequestBody(text, isTitle)),
        connectTimeout: 30000,
        readTimeout: 300000
      });

      const code = response.responseCode;

      if (code === 401 || code === 403) {
        return { success: false, error: 'API 密钥无效或已过期，请在设置中重新填入' };
      }

      if (code === 429) {
        return { success: false, error: '请求过于频繁，请稍后再试' };
      }

      if (code !== 200) {
        return { success: false, error: `翻译服务请求失败（HTTP ${code}）` };
      }

      const raw = response.result as string;
      const data = JSON.parse(raw) as LlmResponse;

      if (data.choices && data.choices.length > 0) {
        const translated = data.choices[0].message.content;

        this.totalRequests++;
        this.totalTranslatedChars += text.length;

        const actualInputTokens = data.usage?.prompt_tokens ?? this.estimateTokens(text);
        const actualOutputTokens = data.usage?.completion_tokens ?? this.estimateTokens(translated);
        const inputTokens = this.estimateTokens(text);

        console.info(`[Translation] input=${actualInputTokens} output=${actualOutputTokens} total=${actualInputTokens + actualOutputTokens}`);

        const elapsedMs = Date.now() - startTime;
        await this.onTranslateSuccess(actualInputTokens, actualOutputTokens, isTitle, elapsedMs);

        return {
          success: true,
          translatedText: translated,
          usage: {
            totalChars: text.length,
            inputTokens: inputTokens,
            estimatedOutputTokens: Math.round(inputTokens * 0.65),
            actualInputTokens: actualInputTokens,
            actualOutputTokens: actualOutputTokens
          }
        };
      } else {
        return { success: false, error: '翻译服务返回空结果' };
      }

    } catch (err) {
      const error = err as BusinessError;
      let errorMsg = '网络错误，请检查后重试';

      switch (error.code) {
        case 2300006:
          errorMsg = '无法连接网络，请检查网络设置';
          break;
        case 2300007:
        case 2300028:
          errorMsg = '连接超时，请检查网络后重试';
          break;
        default:
          errorMsg = `翻译失败：${error.message || '未知错误'}`;
      }

      return { success: false, error: errorMsg };
    } finally {
      httpRequest.destroy();
    }
  }

  async translateParagraphs(
    paragraphs: string[],
    onProgress?: (current: number, total: number, translated: string) => void
  ): Promise<TranslationResult[]> {
    const total = paragraphs.length;
    if (total === 0) return [];

    const results: TranslationResult[] = new Array(total);
    let completedCount = 0;
    const controller = new AdaptiveConcurrencyController();

    const handleParagraph = async (index: number): Promise<void> => {
      const text = paragraphs[index];
      if (!text.trim()) {
        results[index] = { success: true, translatedText: '' };
      } else {
        try {
          results[index] = await this.translateText(text, false);
        } catch (e) {
          results[index] = { success: false, error: '未知异常' };
        }
      }
      completedCount++;
      onProgress?.(completedCount, total, results[index].translatedText || '');
      const res = results[index];
      if (res.success) {
        controller.onSuccess();
      } else {
        if (res.error?.includes('频繁')) controller.onFailure('rate_limit');
        else if (res.error?.includes('超时') || res.error?.includes('timeout')) controller.onFailure('timeout');
        else controller.onFailure('other');
      }
    };

    if (total >= 2) {
      await handleParagraph(0);
      await handleParagraph(1);
      await new Promise<void>((resolve) => setTimeout(resolve, 5000));
    } else if (total === 1) {
      await handleParagraph(0);
      return results;
    }

    let nextIndex = 2;
    const activePromises = new Set<Promise<void>>();
    let finalResolve: (() => void) | null = null;
    const finalPromise = new Promise<void>((resolve) => { finalResolve = resolve; });

    const dispatchNext = (): void => {
      while (activePromises.size < controller.getCurrentWindow() && nextIndex < total) {
        const index = nextIndex++;
        let p: Promise<void> = handleParagraph(index)
          .catch((err: Error) => console.error(`段落 ${index} 异常:`, err.message))
          .finally(() => {
            activePromises.delete(p);
            dispatchNext();
          });
        activePromises.add(p);
      }
      if (nextIndex >= total && activePromises.size === 0) {
        finalResolve?.();
      }
    };

    dispatchNext();
    await finalPromise;
    return results;
  }

  private mergeShortParagraphs(paragraphs: string[], maxChars: number = 2000): string[] {
    const merged: string[] = [];
    let current = '';
    for (const para of paragraphs) {
      const text = para.trim();
      if (!text) continue;
      if (current && (current.length + text.length + 1) > maxChars) {
        merged.push(current);
        current = text;
      } else {
        current = current ? current + '\n' + text : text;
      }
    }
    if (current) merged.push(current);
    return merged;
  }

  async translateLongText(
    text: string,
    onProgress?: (current: number, total: number) => void
  ): Promise<TranslationResult> {
    const inputTokens = this.estimateTokens(text);
    const estimatedTotal = inputTokens * 2;
    const MAX_SAFE_TOKENS = 100000;

    if (estimatedTotal < MAX_SAFE_TOKENS) {
      const estimatedMs = this.estimateTime(inputTokens);
      const startTime = Date.now();
      const timerId = setInterval(() => {
        const elapsed = Date.now() - startTime;
        const pct = Math.min(Math.floor((elapsed / estimatedMs) * 88), 88);
        onProgress?.(pct, 100);
      }, 200);

      let result: TranslationResult = { success: false, error: '' };
      let currentPct = 0;
      try {
        result = await this.translateText(text, false);
      } finally {
        clearInterval(timerId);
        if (result.success) {
          currentPct = Math.min(Math.floor((Date.now() - startTime) / estimatedMs * 88), 88);
          const steps = 5;
          const stepDelay = 80;
          const increment = (100 - currentPct) / steps;
          for (let i = 1; i <= steps; i++) {
            const nextPct = Math.min(Math.floor(currentPct + increment * i), 100);
            onProgress?.(nextPct, 100);
            if (i < steps) {
              await new Promise<void>(r => setTimeout(r, stepDelay));
            }
          }
        }
      }
      return result;
    }

    const paragraphs = text.split('\n');
    const merged = this.mergeShortParagraphs(paragraphs, 2000);
    const results = await this.translateParagraphs(merged, (current, total) => {
      onProgress?.(current, total);
    });

    const translated = results.map((r, i) => {
      if (!merged[i]) return '';
      return (r.success && r.translatedText) ? r.translatedText : merged[i];
    });

    return {
      success: true,
      translatedText: translated.join('\n')
    };
  }
}
