import http from '@ohos.net.http';
import { BusinessError } from '@ohos.base';
import common from '@ohos.app.ability.common';
import preferences from '@ohos.data.preferences';
import { DeepSeekTokenizer, getDeepSeekTokenizer } from './DeepSeekTokenizer';

const PRICE_INPUT = 1.0;
const PRICE_OUTPUT = 2.0;
const PROMPT_OVERHEAD = 55;

interface StatsResult {
  totalChars: number;
  totalRequests: number;
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

interface ThinkingConfig {
  type: 'enabled' | 'disabled';
}

interface DeepSeekRequestBody {
  model: string;
  messages: DeepSeekMessage[];
  temperature: number;
  max_tokens: number;
  thinking: ThinkingConfig;
}

interface DeepSeekMessage {
  role: string;
  content: string;
  reasoning_content?: string;
}

interface DeepSeekChoice {
  index: number;
  message: DeepSeekMessage;
  finish_reason: string;
}

interface DeepSeekUsage {
  prompt_tokens: number;
  completion_tokens: number;
  total_tokens: number;
}

interface DeepSeekResponse {
  id: string;
  choices: DeepSeekChoice[];
  usage: DeepSeekUsage;
}

interface DeepSeekBalanceInfo {
  currency: string;
  total_balance: string;
  granted_balance: string;
  topped_up_balance: string;
}

interface DeepSeekBalanceResp {
  is_available: boolean;
  balance_infos: DeepSeekBalanceInfo[];
}

interface BalanceFetchResult {
  success: boolean;
  data: string;
  error: string;
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

export class DeepSeekService {
  private apiKey: string = '';
  private baseUrl: string = 'https://api.deepseek.com/chat/completions';
  private model: string = 'deepseek-v4-flash';

  private totalTranslatedChars: number = 0;
  private totalRequests: number = 0;
  private tokenizer: DeepSeekTokenizer | null = null;
  private tokenizerInitPromise: Promise<void> | null = null;
  private appContext: common.UIAbilityContext | null = null;
  private adaptiveRatio: number = 0.65;
  private ratioCount: number = 0;

  constructor(apiKey: string = '') {
    this.apiKey = apiKey;
  }

  private async loadRatioFromStorage(): Promise<void> {
    if (!this.appContext) return;
    const pref = await preferences.getPreferences(this.appContext, 'deepseek_translate');
    const saved = (await pref.get('ratio', 0.65)) as number;
    const count = (await pref.get('ratioCount', 0)) as number;
    if (count > 0) {
      this.adaptiveRatio = saved;
      this.ratioCount = count;
    }
  }

  private async saveRatioToStorage(): Promise<void> {
    if (!this.appContext) return;
    const pref = await preferences.getPreferences(this.appContext, 'deepseek_translate');
    await pref.put('ratio', this.adaptiveRatio);
    await pref.put('ratioCount', this.ratioCount);
    await pref.flush();
  }

  updateApiKey(apiKey: string): void {
    this.apiKey = apiKey;
  }

  hasValidKey(): boolean {
    return this.apiKey.length > 0 && this.apiKey.trim().length > 0;
  }

  getStats(): StatsResult {
    return {
      totalChars: this.totalTranslatedChars,
      totalRequests: this.totalRequests
    };
  }

  async initTokenizer(context: common.UIAbilityContext): Promise<void> {
    this.appContext = context;
    await this.loadRatioFromStorage();
    if (!this.tokenizerInitPromise) {
      this.tokenizerInitPromise = getDeepSeekTokenizer(context).then(t => {
        this.tokenizer = t;
      }).catch(() => {
        this.tokenizerInitPromise = null;
        console.error('Tokenizer init failed');
      });
    }
    return this.tokenizerInitPromise;
  }

  estimateTokens(text: string): number {
    if (this.tokenizer) {
      return this.tokenizer.countTokens(text);
    }
    return Math.round(text.length * 0.68);
  }

  getAdaptiveRatio(): number {
    return this.adaptiveRatio;
  }

  getRatioCount(): number {
    return this.ratioCount;
  }

  async recordUsage(actualInput: number, actualOutput: number): Promise<void> {
    const ratio = actualOutput / actualInput;
    const total = this.ratioCount + 1;
    this.adaptiveRatio = (this.adaptiveRatio * this.ratioCount + ratio) / total;
    this.ratioCount = Math.min(total, 50);
    await this.saveRatioToStorage();
  }

  estimateCost(inputTokens: number): number {
    const estimatedInput = inputTokens + PROMPT_OVERHEAD;
    const estimatedOutput = Math.round(estimatedInput * this.adaptiveRatio);
    const inputCost = estimatedInput * PRICE_INPUT / 1000000;
    const outputCost = estimatedOutput * PRICE_OUTPUT / 1000000;
    return inputCost + outputCost;
  }

  async fetchBalance(apiKey?: string): Promise<BalanceFetchResult> {
    const key = apiKey ?? (AppStorage.get('deepseekApiKey') as string) ?? '';
    if (!key.trim()) {
      return { success: false, data: '', error: '未配置 API 密钥' };
    }
    try {
      const httpRequest = http.createHttp();
      const response = await httpRequest.request(
        'https://api.deepseek.com/user/balance',
        {
          method: http.RequestMethod.GET,
          header: {
            'Accept': 'application/json',
            'Authorization': `Bearer ${key}`
          },
          connectTimeout: 10000,
          readTimeout: 10000
        }
      );
      httpRequest.destroy();

      if (response.responseCode === 200) {
        const body = JSON.parse(response.result as string) as DeepSeekBalanceResp;
        let total = '0';
        for (let i = 0; i < body.balance_infos.length; i++) {
          if (body.balance_infos[i].currency === 'CNY') {
            total = body.balance_infos[i].total_balance;
            break;
          }
        }
        if (total === '0' && body.balance_infos.length > 0) {
          total = body.balance_infos[0].total_balance;
        }
        return { success: true, data: total, error: '' };
      } else {
        return { success: false, data: '', error: `HTTP ${response.responseCode}` };
      }
    } catch (e) {
      return { success: false, data: '', error: String(e) };
    }
  }

  async translateText(text: string, isTitle: boolean = false): Promise<TranslationResult> {
    if (!this.hasValidKey()) {
      return { success: false, error: '请先在设置中填入 DeepSeek API 密钥' };
    }

    if (!text || text.trim().length === 0) {
      return { success: false, error: '翻译文本不能为空' };
    }

    const systemPrompt = isTitle
      ? `你是一个专业的日文翻译。请将以下日文标题翻译成中文。
要求：
1. 保持原标题的风格和意境
2. 如果标题包含专有名词（人名、地名等），使用常见译名
3. 翻译要简洁准确
4. 只返回翻译后的中文标题，不要添加任何解释`
      : `你是专业日文小说翻译。将以下日文准确、流畅地译成中文，严格保留原文段落与标点格式，不生硬直译。只输出译文，不附加解释。`;

    const PREFIX = '请将以下日文翻译成中文：\n';
    const userPrompt = PREFIX + text;

    const messages: DeepSeekMessage[] = [
      { role: 'system', content: systemPrompt } as DeepSeekMessage,
      { role: 'user', content: userPrompt } as DeepSeekMessage
    ];

    const requestBody: DeepSeekRequestBody = {
      model: this.model,
      messages: messages,
      temperature: isTitle ? 0.8 : 0.3,
      max_tokens: isTitle ? 100 : 131072,
      thinking: { type: 'disabled' }
    };

    const httpRequest = http.createHttp();

    try {
      const response = await httpRequest.request(this.baseUrl, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.apiKey}`
        },
        extraData: JSON.stringify(requestBody),
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
      const data = JSON.parse(raw) as DeepSeekResponse;

      if (data.choices && data.choices.length > 0) {
        const translated = data.choices[0].message.content;

        this.totalRequests++;
        this.totalTranslatedChars += text.length;

        const actualInputTokens = data.usage?.prompt_tokens ?? this.estimateTokens(text);
        const actualOutputTokens = data.usage?.completion_tokens ?? this.estimateTokens(translated);
        const inputTokens = this.estimateTokens(text);

        console.info(`[Translation] input=${actualInputTokens} output=${actualOutputTokens} total=${actualInputTokens + actualOutputTokens}`);

        await this.recordUsage(actualInputTokens, actualOutputTokens);

        return {
          success: true,
          translatedText: translated,
          usage: {
            totalChars: text.length,
            inputTokens: inputTokens,
            estimatedOutputTokens: Math.round(inputTokens * this.adaptiveRatio),
            estimatedCost: this.estimateCost(inputTokens),
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
      const result = await this.translateText(text, false);
      onProgress?.(1, 1);
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

let _deepSeekInstance: DeepSeekService | null = null;

export function getDeepSeekService(): DeepSeekService {
  const apiKey = AppStorage.get<string>('deepseekApiKey') ?? '';
  if (!_deepSeekInstance) {
    _deepSeekInstance = new DeepSeekService(apiKey);
  } else {
    _deepSeekInstance.updateApiKey(apiKey);
  }
  return _deepSeekInstance;
}
