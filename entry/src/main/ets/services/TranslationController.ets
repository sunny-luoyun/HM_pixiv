import common from '@ohos.app.ability.common';
import { getLlmService } from './LlmServiceFactory';
import { DeepSeekService } from './DeepSeekService';
import { pixivCacheDB } from '../database/PixivCacheDB';
import { PixivService } from './PixivService';
import { parsePixivBlocks, ContentBlock } from '../common/utils/NovelParser';

export interface TranslateTitleResult {
  success: boolean;
  translatedTitle?: string;
  error?: string;
}

export interface TranslateFullTextResult {
  success: boolean;
  translatedBlocks?: ContentBlock[];
  error?: string;
}

export interface PrepareFullTranslationError {
  error: string;
}

export interface PrepareFullTranslationSuccess {
  originalText: string;
  estimateInfo: string;
}

export interface NovelDetailResult {
  commentCount: number;
}

export function buildEstimateInfo(
  originalText: string,
  inputTokens: number,
  estimatedMs: number,
  estimatedCostYuan: number,
  ratio: number,
  count: number,
  showCostInfo: boolean
): string {
  const totalSec = Math.round(estimatedMs / 1000);
  const min = Math.floor(totalSec / 60);
  const sec = totalSec % 60;
  const fmtTime = min > 0
    ? (sec > 0 ? `约 ${min} 分 ${sec} 秒` : `约 ${min} 分`)
    : `约 ${sec} 秒`;

  if (!showCostInfo) {
    return `预计翻译 ${originalText.length} 字符\n` +
      `预计耗时 ${fmtTime}\n` +
      `是否继续？`;
  }

  return `预计翻译 ${originalText.length} 字符 / ${inputTokens} tokens\n` +
    `预计耗时 ${fmtTime}\n` +
    `费用约 ¥${estimatedCostYuan.toFixed(4)}\n` +
    `输出/输入比 ${ratio.toFixed(3)}（已校准 ${count} 次）\n` +
    `是否继续？`;
}

export class TranslationController {
  static async translateTitle(
    novelId: string,
    title: string,
  ): Promise<TranslateTitleResult> {
    const service = getLlmService();

    if (!service.hasValidKey()) {
      const r: TranslateTitleResult = { success: false, error: '请先在设置中配置翻译 API 密钥' };
      return r;
    }

    const result = await service.translateText(title, true);

    if (result.success && result.translatedText) {
      await pixivCacheDB.saveTitleTranslation(novelId, result.translatedText);
      const r: TranslateTitleResult = { success: true, translatedTitle: result.translatedText };
      return r;
    }
    const r: TranslateTitleResult = { success: false, error: result.error || '翻译失败' };
    return r;
  }

  static async prepareFullTranslation(
    novelId: string,
  ): Promise<PrepareFullTranslationSuccess | PrepareFullTranslationError> {
    const service = getLlmService();

    if (!service.hasValidKey()) {
      const r: PrepareFullTranslationError = { error: '请先在设置中配置翻译 API 密钥' };
      return r;
    }

    const ctx = AppStorage.get<common.UIAbilityContext>('appContext');
    if (ctx) {
      await pixivCacheDB.init(ctx);
      if (service instanceof DeepSeekService) {
        await service.initTokenizer(ctx);
      }
    }
    const originalText = await pixivCacheDB.getFullText(novelId);

    if (!originalText) {
      const r: PrepareFullTranslationError = { error: '找不到原文内容' };
      return r;
    }
    const inputTokens = service.estimateTokens(originalText);
    const estimatedMs = service.estimateTime(inputTokens);
    const estimatedCostYuan = service instanceof DeepSeekService ? service.estimateCost(inputTokens) : 0;
    const ratio = service.getAdaptiveRatio();
    const count = service.getRatioCount();

    const estimateInfo = buildEstimateInfo(
      originalText,
      inputTokens,
      estimatedMs,
      estimatedCostYuan,
      ratio,
      count,
      service.supportsCostEstimate
    );

    const r: PrepareFullTranslationSuccess = { originalText, estimateInfo };
    return r;
  }

  static async performFullTranslation(
    novelId: string,
    originalText: string,
    onProgress?: (current: number, total: number) => void,
  ): Promise<TranslateFullTextResult> {
    const service = getLlmService();

    await pixivCacheDB.updateTranslationProgress(novelId, 0, 'in_progress');

    const result = await service.translateLongText(
      originalText,
      (current, total) => {
        if (onProgress) onProgress(current, total);
      }
    );

    if (!result.success) {
      await pixivCacheDB.updateTranslationProgress(novelId, 0, 'none');
      const r: TranslateFullTextResult = { success: false, error: result.error || '网络请求失败，请稍后重试' };
      return r;
    }

    const translatedText = result.translatedText ?? originalText;
    const translatedBlocks = parsePixivBlocks(translatedText);

    await pixivCacheDB.saveFullTextTranslation(novelId, translatedText);

    const r: TranslateFullTextResult = { success: true, translatedBlocks };
    return r;
  }

  static async fetchNovelDetail(novelId: string): Promise<NovelDetailResult> {
    try {
      const detail = await PixivService.fetchNovelDetail(novelId);
      const r: NovelDetailResult = { commentCount: detail.commentCount ?? 0 };
      return r;
    } catch {
      const r: NovelDetailResult = { commentCount: 0 };
      return r;
    }
  }
}
