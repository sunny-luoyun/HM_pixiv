import http from '@ohos.net.http';
import common from '@ohos.app.ability.common';
import preferences from '@ohos.data.preferences';
import { DeepSeekTokenizer, getDeepSeekTokenizer } from './DeepSeekTokenizer';
import { ApiConfig } from '../common/constants/ApiConfig';
import { BaseLlmService, LlmConfig, TranslationResult, TranslationUsage } from './LlmProvider';

const PROMPT_OVERHEAD_FALLBACK = 55; // tokenizer 不可用时的兜底值

/**
 * 判断当前北京时间是否为 DeepSeek 高峰时段。
 * 高峰：北京时间周一至周五 09:00-12:00、14:00-18:00
 */
export function isPeakHour(): boolean {
  const now = new Date();
  // 转换为北京时间 UTC+8
  const bjHour = (now.getUTCHours() + 8) % 24;
  const bjMin = now.getUTCMinutes();
  const bjTime = bjHour * 60 + bjMin; // 当前北京时间的分钟数
  const day = now.getUTCDay(); // 0=Sun, 6=Sat

  // 周末全天闲时
  if (day === 0 || day === 6) return false;

  // 高峰1: 09:00-12:00 → 540~720 分钟
  if (bjTime >= 540 && bjTime < 720) return true;
  // 高峰2: 14:00-18:00 → 840~1080 分钟
  if (bjTime >= 840 && bjTime < 1080) return true;

  return false;
}

interface PricePair {
  input: number;
  output: number;
}

/** DeepSeek V4 Flash 最新定价（2026-08-17 起）：元 / 百万 tokens */
function getCurrentPrice(): PricePair {
  if (isPeakHour()) {
    return { input: 3.0, output: 9.0 } as PricePair;
  }
  return { input: 1.5, output: 4.5 } as PricePair;
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

export class DeepSeekService extends BaseLlmService {
  private tokenizer: DeepSeekTokenizer | null = null;
  private tokenizerInitPromise: Promise<void> | null = null;
  private appContext: common.UIAbilityContext | null = null;
  private adaptiveRatio: number = 0.65;
  private ratioCount: number = 0;
  private averageSpeed: number = 0;
  private speedCount: number = 0;

  constructor(apiKey: string = '') {
    const config: LlmConfig = {
      baseUrl: ApiConfig.DEEPSEEK_API,
      apiKey: apiKey,
      model: 'deepseek-v4-flash',
      supportsThinking: true,
      maxTokensTitle: 100,
      maxTokensFull: 131072,
      supportsCostEstimate: true
    };
    super(config);
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

  private async loadSpeedFromStorage(): Promise<void> {
    if (!this.appContext) return;
    const pref = await preferences.getPreferences(this.appContext, 'deepseek_translate');
    const saved = (await pref.get('speed', 0)) as number;
    const count = (await pref.get('speedCount', 0)) as number;
    if (count > 0) {
      this.averageSpeed = saved;
      this.speedCount = count;
    }
  }

  private async saveSpeedToStorage(): Promise<void> {
    if (!this.appContext) return;
    const pref = await preferences.getPreferences(this.appContext, 'deepseek_translate');
    await pref.put('speed', this.averageSpeed);
    await pref.put('speedCount', this.speedCount);
    await pref.flush();
  }

  async initTokenizer(context: common.UIAbilityContext): Promise<void> {
    this.appContext = context;
    await this.loadRatioFromStorage();
    await this.loadSpeedFromStorage();
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

  async loadRatio(context: common.UIAbilityContext): Promise<void> {
    this.appContext = context;
    await this.loadRatioFromStorage();
  }

  async resetAdaptiveRatio(): Promise<void> {
    this.adaptiveRatio = 0.65;
    this.ratioCount = 0;
    await this.saveRatioToStorage();
  }

  async recordUsage(actualInput: number, actualOutput: number): Promise<void> {
    const ratio = actualOutput / actualInput;
    const total = this.ratioCount + 1;
    this.adaptiveRatio = (this.adaptiveRatio * this.ratioCount + ratio) / total;
    this.ratioCount = Math.min(total, 50);
    await this.saveRatioToStorage();
  }

  estimateCost(inputTokens: number, isTitle: boolean = false): number {
    // 根据实际 prompt 内容动态计算开销，而非硬编码
    const systemPrompt = this.getSystemPrompt(isTitle);
    const userPrefix = '请将以下日文翻译成中文：\n';
    const promptOverhead = this.tokenizer
      ? this.tokenizer.countTokens(systemPrompt + userPrefix)
      : Math.round((systemPrompt.length + userPrefix.length) * 0.68) || PROMPT_OVERHEAD_FALLBACK;
    const estimatedInput = inputTokens + promptOverhead;
    const estimatedOutput = Math.round(estimatedInput * this.adaptiveRatio);
    const price = getCurrentPrice();
    const inputCost = estimatedInput * price.input / 1000000;
    const outputCost = estimatedOutput * price.output / 1000000;
    return inputCost + outputCost;
  }

  estimateTime(inputTokens: number): number {
    const estimatedOutput = Math.round(inputTokens * this.adaptiveRatio);
    const estimatedTotalTokens = inputTokens + estimatedOutput;
    const speed = this.averageSpeed > 0 ? this.averageSpeed : 800;
    return Math.round((estimatedTotalTokens / speed) * 1000);
  }

  async fetchBalance(apiKey?: string): Promise<BalanceFetchResult> {
    const key = apiKey ?? (AppStorage.get('deepseekApiKey') as string) ?? '';
    if (!key.trim()) {
      return { success: false, data: '', error: '未配置 API 密钥' };
    }
    try {
      const httpRequest = http.createHttp();
      const response = await httpRequest.request(
        ApiConfig.DEEPSEEK_BALANCE,
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

  protected async onTranslateSuccess(
    actualInput: number,
    actualOutput: number,
    isTitle: boolean,
    elapsedMs: number
  ): Promise<void> {
    if (isTitle) return;
    await this.recordUsage(actualInput, actualOutput);

    const totalTokens = actualInput + actualOutput;
    if (elapsedMs > 500 && totalTokens > 500) {
      const speed = totalTokens / (elapsedMs / 1000);
      const total = this.speedCount + 1;
      this.averageSpeed = (this.averageSpeed * this.speedCount + speed) / total;
      this.speedCount = Math.min(total, 10);
      await this.saveSpeedToStorage();
    }
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
