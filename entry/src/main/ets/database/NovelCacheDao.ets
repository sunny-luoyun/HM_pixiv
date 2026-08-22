import relationalStore from '@ohos.data.relationalStore';
import { DatabaseCore } from './DatabaseCore';
import { PixivNovel, CacheStatus } from '../models/PixivModels';

export class NovelCacheDao {
  static async saveNovelMeta(novel: PixivNovel): Promise<void> {
    if (!DatabaseCore.isReady()) return;
    const store = DatabaseCore.getStore()!;

    const existing = await NovelCacheDao.getNovelById(novel.id);
    const keepFullText         = existing?.fullText    ?? '';
    const keepCachedAt         = existing?.cachedAt    ?? '';
    const keepCacheStatus      = existing?.cacheStatus ?? CacheStatus.NOT_CACHED;
    const keepTitleTranslated  = existing?.titleTranslated     ?? '';
    const keepHasTitleTrans    = existing?.hasTitleTranslation ?? false;
    const keepFullTranslated   = existing?.fullTextTranslated  ?? '';
    const keepHasFullTrans     = existing?.hasFullTranslation  ?? false;
    const keepTransStatus      = existing?.translationStatus   ?? 'none';
    const keepTransProgress    = existing?.translationProgress ?? 0;

    const values: relationalStore.ValuesBucket = {
      'id':             novel.id,
      'title':          novel.title,
      'caption':        novel.caption,
      'author':         novel.author,
      'author_id':      novel.authorId,
      'cover_url':      novel.coverUrl,
      'tags':           JSON.stringify(novel.tags),
      'text_length':    novel.textLength,
      'page_count':     novel.pageCount,
      'create_date':    novel.createDate,
      'update_date':    novel.updateDate,
      'series_id':      novel.series?.id    ?? '',
      'series_title':   novel.series?.title ?? '',
      'series_order':   novel.series?.order ?? 0,
      'bookmark_count': novel.bookmarkCount,
      'view_count':     novel.viewCount,
      'comment_count':  novel.commentCount,
      'cache_status':   keepCacheStatus,
      'cached_at':      keepCachedAt,
      'full_text':      keepFullText,
      'title_translated':      keepTitleTranslated ?? '',
      'has_title_translation': keepHasTitleTrans ? 1 : 0,
      'full_text_translated':  keepFullTranslated ?? '',
      'has_full_translation':  keepHasFullTrans ? 1 : 0,
      'translation_status':    keepTransStatus ?? 'none',
      'translation_progress':  keepTransProgress ?? 0
    };

    try {
      await store.insert(
        DatabaseCore.TableNovels, values,
        relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
      );
    } catch (err) {
      console.error(`[NovelCacheDao] saveNovelMeta 失败 id=${novel.id}: ${JSON.stringify(err)}`);
    }
  }

  static async markCaching(novelId: string): Promise<void> {
    await DatabaseCore.updateCacheFields(novelId, { 'cache_status': CacheStatus.CACHING });
  }

  static async saveFullText(novelId: string, fullText: string): Promise<void> {
    if (!DatabaseCore.isReady()) return;
    if (!fullText || fullText.length === 0) {
      await NovelCacheDao.markCacheFail(novelId);
      return;
    }
    const success = await DatabaseCore.updateCacheFields(novelId, {
      'full_text':    fullText,
      'cache_status': CacheStatus.CACHED,
      'cached_at':    new Date().toISOString()
    });
    if (success) {
      console.info(`[NovelCacheDao] saveFullText 成功 id=${novelId}，长度=${fullText.length}`);
    }
  }

  static async markCacheFail(novelId: string): Promise<void> {
    await DatabaseCore.updateCacheFields(novelId, { 'cache_status': CacheStatus.CACHE_FAIL });
  }

  static async deleteCachedText(novelId: string): Promise<void> {
    await DatabaseCore.updateCacheFields(novelId, {
      'full_text':    '',
      'cache_status': CacheStatus.NOT_CACHED,
      'cached_at':    ''
    });
  }

  static async getNovelById(novelId: string): Promise<PixivNovel | null> {
    if (!DatabaseCore.isReady()) return null;
    const store = DatabaseCore.getStore()!;
    const predicates = new relationalStore.RdbPredicates(DatabaseCore.TableNovels);
    predicates.equalTo(DatabaseCore.Col.ID, novelId);
    try {
      const result = await store.query(predicates, DatabaseCore.getAllColumns());
      const novels = DatabaseCore.resultSetToNovels(result);
      return novels.length > 0 ? novels[0] : null;
    } catch (err) {
      console.error(`[NovelCacheDao] getNovelById 失败: ${JSON.stringify(err)}`);
      return null;
    }
  }

  static async getFullText(novelId: string): Promise<string | null> {
    if (!DatabaseCore.isReady()) return null;
    const store = DatabaseCore.getStore()!;
    const predicates = new relationalStore.RdbPredicates(DatabaseCore.TableNovels);
    predicates.equalTo(DatabaseCore.Col.ID, novelId)
      .and()
      .equalTo(DatabaseCore.Col.CACHE_STATUS, CacheStatus.CACHED);
    try {
      const result = await store.query(predicates, [DatabaseCore.Col.FULL_TEXT]);
      if (result.rowCount > 0) {
        result.goToFirstRow();
        const text = result.getString(result.getColumnIndex(DatabaseCore.Col.FULL_TEXT));
        result.close();
        return text || null;
      }
      result.close();
      return null;
    } catch (err) {
      console.error(`[NovelCacheDao] getFullText 失败: ${JSON.stringify(err)}`);
      return null;
    }
  }

  static async getNovelsBySeriesId(seriesId: string): Promise<PixivNovel[]> {
    if (!DatabaseCore.isReady()) return [];
    const store = DatabaseCore.getStore()!;
    const predicates = new relationalStore.RdbPredicates(DatabaseCore.TableNovels);
    predicates.equalTo(DatabaseCore.Col.SERIES_ID, seriesId)
      .equalTo(DatabaseCore.Col.CACHE_STATUS, CacheStatus.CACHED)
      .orderByAsc(DatabaseCore.Col.SERIES_ORDER);
    try {
      const cols = DatabaseCore.getAllColumns().filter(c => c !== DatabaseCore.Col.FULL_TEXT);
      const result = await store.query(predicates, cols);
      return DatabaseCore.resultSetToNovels(result);
    } catch (err) {
      console.error(`[NovelCacheDao] getNovelsBySeriesId 失败: ${JSON.stringify(err)}`);
      return [];
    }
  }

  static async getAllCachedNovels(): Promise<PixivNovel[]> {
    if (!DatabaseCore.isReady()) return [];
    const store = DatabaseCore.getStore()!;
    const predicates = new relationalStore.RdbPredicates(DatabaseCore.TableNovels);
    predicates.equalTo(DatabaseCore.Col.CACHE_STATUS, CacheStatus.CACHED)
      .orderByDesc(DatabaseCore.Col.CACHED_AT);
    try {
      const cols = DatabaseCore.getAllColumns().filter(c => c !== DatabaseCore.Col.FULL_TEXT);
      const result = await store.query(predicates, cols);
      return DatabaseCore.resultSetToNovels(result);
    } catch (err) {
      console.error(`[NovelCacheDao] getAllCachedNovels 失败: ${JSON.stringify(err)}`);
      return [];
    }
  }

  static async getCachedNovelCount(): Promise<number> {
    if (!DatabaseCore.isReady()) return 0;
    const store = DatabaseCore.getStore()!;
    const predicates = new relationalStore.RdbPredicates(DatabaseCore.TableNovels);
    predicates.equalTo(DatabaseCore.Col.CACHE_STATUS, CacheStatus.CACHED);
    try {
      const result = await store.query(predicates, [DatabaseCore.Col.ID]);
      const count = result.rowCount;
      result.close();
      return count;
    } catch (err) {
      console.error(`[NovelCacheDao] getCachedNovelCount 失败: ${JSON.stringify(err)}`);
      return 0;
    }
  }

  static async deleteAllCachedNovels(): Promise<number> {
    if (!DatabaseCore.isReady()) return 0;
    const store = DatabaseCore.getStore()!;
    const predicates = new relationalStore.RdbPredicates(DatabaseCore.TableNovels);
    predicates.equalTo(DatabaseCore.Col.CACHE_STATUS, CacheStatus.CACHED);
    try {
      const rows = await store.delete(predicates);
      return rows;
    } catch (err) {
      console.error(`[NovelCacheDao] deleteAllCachedNovels 失败: ${JSON.stringify(err)}`);
      return 0;
    }
  }

  static async deleteNovelById(novelId: string): Promise<boolean> {
    if (!DatabaseCore.isReady()) return false;
    const store = DatabaseCore.getStore()!;
    const predicates = new relationalStore.RdbPredicates(DatabaseCore.TableNovels);
    predicates.equalTo(DatabaseCore.Col.ID, novelId);
    try {
      const rows = await store.delete(predicates);
      return rows > 0;
    } catch (err) {
      console.error(`[NovelCacheDao] deleteNovelById 失败 id=${novelId}: ${JSON.stringify(err)}`);
      return false;
    }
  }

  static async saveReadingProgress(novelId: string, scrollY: number, isTranslated: boolean = false): Promise<void> {
    if (!DatabaseCore.isReady() || !novelId) return;
    const store = DatabaseCore.getStore()!;
    const values: relationalStore.ValuesBucket = {
      'novel_id':    novelId,
      'is_translated': isTranslated ? 1 : 0,
      'scroll_y':    Math.max(0, Math.floor(scrollY)),
      'last_read_at': new Date().toISOString()
    };
    try {
      await store.insert(
        DatabaseCore.TableProgress, values,
        relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
      );
    } catch (err) {
      console.error(`[NovelCacheDao] 保存进度失败: ${JSON.stringify(err)}`);
    }
  }

  static async getReadingProgress(novelId: string, isTranslated: boolean = false): Promise<number> {
    if (!DatabaseCore.isReady() || !novelId) return 0;
    const store = DatabaseCore.getStore()!;
    try {
      const predicates = new relationalStore.RdbPredicates(DatabaseCore.TableProgress);
      predicates.equalTo('novel_id', novelId)
        .and()
        .equalTo('is_translated', isTranslated ? 1 : 0);
      const result = await store.query(predicates, ['scroll_y']);
      if (result.rowCount > 0) {
        result.goToFirstRow();
        const y = result.getLong(result.getColumnIndex('scroll_y'));
        result.close();
        return y;
      }
      result.close();
      return 0;
    } catch (err) {
      return 0;
    }
  }

  static async deleteReadingProgress(novelId: string, isTranslated: boolean = false): Promise<void> {
    if (!DatabaseCore.isReady() || !novelId) return;
    const store = DatabaseCore.getStore()!;
    const predicates = new relationalStore.RdbPredicates(DatabaseCore.TableProgress);
    predicates.equalTo('novel_id', novelId)
      .and()
      .equalTo('is_translated', isTranslated ? 1 : 0);
    try {
      await store.delete(predicates);
    } catch (err) {
      console.error(`[NovelCacheDao] 删除进度失败: ${JSON.stringify(err)}`);
    }
  }

  static async getLastReadTimes(novelIds: string[]): Promise<Map<string, string>> {
    const map = new Map<string, string>();
    if (!DatabaseCore.isReady() || novelIds.length === 0) return map;
    const store = DatabaseCore.getStore()!;
    try {
      // 一次查出所有有阅读记录的小说的 last_read_at
      const placeholders = novelIds.map(() => '?').join(',');
      const sql = `SELECT novel_id, last_read_at FROM ${DatabaseCore.TableProgress}
                   WHERE novel_id IN (${placeholders})
                   AND is_translated = 0`;
      const result = await store.querySql(sql, novelIds);
      while (result.goToNextRow()) {
        const nid = result.getString(result.getColumnIndex('novel_id'));
        const lra = result.getString(result.getColumnIndex('last_read_at'));
        if (nid && lra) {
          map.set(nid, lra);
        }
      }
      result.close();
    } catch (err) {
      console.error(`[NovelCacheDao] getLastReadTimes 失败: ${JSON.stringify(err)}`);
    }
    return map;
  }
}
