import common from '@ohos.app.ability.common';
import { DatabaseCore } from './DatabaseCore';
import { NovelCacheDao } from './NovelCacheDao';
import { BlockListDao } from './BlockListDao';
import { TranslationCacheDao } from './TranslationCacheDao';
import { BrowseHistoryDao } from './BrowseHistoryDao';
import {
  PixivNovel, BlockedAuthor, BlockedSeries, BlockedSeriesTitle, BrowseHistoryRecord
} from '../models/PixivModels';

export class PixivCacheDB {
  async init(ctx: common.UIAbilityContext): Promise<void> {
    await DatabaseCore.init(ctx);
  }

  async saveNovelMeta(novel: PixivNovel): Promise<void> {
    return NovelCacheDao.saveNovelMeta(novel);
  }

  async markCaching(novelId: string): Promise<void> {
    return NovelCacheDao.markCaching(novelId);
  }

  async saveFullText(novelId: string, fullText: string): Promise<void> {
    return NovelCacheDao.saveFullText(novelId, fullText);
  }

  async markCacheFail(novelId: string): Promise<void> {
    return NovelCacheDao.markCacheFail(novelId);
  }

  async deleteCachedText(novelId: string): Promise<void> {
    return NovelCacheDao.deleteCachedText(novelId);
  }

  async getNovelById(novelId: string): Promise<PixivNovel | null> {
    return NovelCacheDao.getNovelById(novelId);
  }

  async getFullText(novelId: string): Promise<string | null> {
    return NovelCacheDao.getFullText(novelId);
  }

  async getNovelsBySeriesId(seriesId: string): Promise<PixivNovel[]> {
    return NovelCacheDao.getNovelsBySeriesId(seriesId);
  }

  async getAllCachedNovels(): Promise<PixivNovel[]> {
    return NovelCacheDao.getAllCachedNovels();
  }

  async getCachedNovelCount(): Promise<number> {
    return NovelCacheDao.getCachedNovelCount();
  }

  async deleteAllCachedNovels(): Promise<number> {
    return NovelCacheDao.deleteAllCachedNovels();
  }

  async deleteNovelById(novelId: string): Promise<boolean> {
    return NovelCacheDao.deleteNovelById(novelId);
  }

  async saveReadingProgress(novelId: string, scrollY: number, isTranslated: boolean = false): Promise<void> {
    return NovelCacheDao.saveReadingProgress(novelId, scrollY, isTranslated);
  }

  async getReadingProgress(novelId: string, isTranslated: boolean = false): Promise<number> {
    return NovelCacheDao.getReadingProgress(novelId, isTranslated);
  }

  async deleteReadingProgress(novelId: string, isTranslated: boolean = false): Promise<void> {
    return NovelCacheDao.deleteReadingProgress(novelId, isTranslated);
  }

  async addBlockedAuthor(authorId: string, authorName: string): Promise<void> {
    return BlockListDao.addBlockedAuthor(authorId, authorName);
  }

  async removeBlockedAuthor(authorId: string): Promise<void> {
    return BlockListDao.removeBlockedAuthor(authorId);
  }

  async getAllBlockedAuthors(): Promise<BlockedAuthor[]> {
    return BlockListDao.getAllBlockedAuthors();
  }

  async getAllBlockedAuthorIds(): Promise<Set<string>> {
    return BlockListDao.getAllBlockedAuthorIds();
  }

  async isAuthorBlocked(authorId: string): Promise<boolean> {
    return BlockListDao.isAuthorBlocked(authorId);
  }

  async addBlockedSeries(seriesId: string, seriesTitle: string, authorId: string, authorName: string): Promise<void> {
    return BlockListDao.addBlockedSeries(seriesId, seriesTitle, authorId, authorName);
  }

  async removeBlockedSeries(seriesId: string): Promise<void> {
    return BlockListDao.removeBlockedSeries(seriesId);
  }

  async getAllBlockedSeries(): Promise<BlockedSeries[]> {
    return BlockListDao.getAllBlockedSeries();
  }

  async getAllBlockedSeriesIds(): Promise<Set<string>> {
    return BlockListDao.getAllBlockedSeriesIds();
  }

  async isSeriesBlocked(seriesId: string): Promise<boolean> {
    return BlockListDao.isSeriesBlocked(seriesId);
  }

  async addBlockedSeriesTitle(title: string): Promise<void> {
    return BlockListDao.addBlockedSeriesTitle(title);
  }

  async removeBlockedSeriesTitle(title: string): Promise<void> {
    return BlockListDao.removeBlockedSeriesTitle(title);
  }

  async getAllBlockedSeriesTitles(): Promise<BlockedSeriesTitle[]> {
    return BlockListDao.getAllBlockedSeriesTitles();
  }

  async getAllBlockedSeriesTitleSet(): Promise<Set<string>> {
    return BlockListDao.getAllBlockedSeriesTitleSet();
  }

  async saveTitleTranslation(novelId: string, translatedTitle: string): Promise<void> {
    return TranslationCacheDao.saveTitleTranslation(novelId, translatedTitle);
  }

  async saveFullTextTranslation(novelId: string, translatedText: string): Promise<void> {
    return TranslationCacheDao.saveFullTextTranslation(novelId, translatedText);
  }

  async updateTranslationProgress(novelId: string, progress: number, status: string): Promise<void> {
    return TranslationCacheDao.updateTranslationProgress(novelId, progress, status);
  }

  async saveBrowseHistory(record: BrowseHistoryRecord, ctx: common.UIAbilityContext): Promise<void> {
    await DatabaseCore.init(ctx);
    return BrowseHistoryDao.saveHistory(record);
  }

  async getAllIllustBrowseHistory(ctx: common.UIAbilityContext, limit?: number, offset?: number): Promise<BrowseHistoryRecord[]> {
    await DatabaseCore.init(ctx);
    return BrowseHistoryDao.getAllIllustHistory(limit, offset);
  }

  async getAllNovelBrowseHistory(ctx: common.UIAbilityContext, limit?: number, offset?: number): Promise<BrowseHistoryRecord[]> {
    await DatabaseCore.init(ctx);
    return BrowseHistoryDao.getAllNovelHistory(limit, offset);
  }

  async getBrowseHistoryCount(ctx: common.UIAbilityContext, contentType: string): Promise<number> {
    await DatabaseCore.init(ctx);
    return BrowseHistoryDao.getCountByType(contentType);
  }

  async deleteBrowseHistory(ctx: common.UIAbilityContext, id: string): Promise<void> {
    await DatabaseCore.init(ctx);
    return BrowseHistoryDao.deleteHistory(id);
  }

  async deleteBrowseHistoryByDate(ctx: common.UIAbilityContext, dateKey: string, contentType: string): Promise<number> {
    await DatabaseCore.init(ctx);
    return BrowseHistoryDao.deleteHistoryByDate(dateKey, contentType);
  }
}

export const pixivCacheDB = new PixivCacheDB();
