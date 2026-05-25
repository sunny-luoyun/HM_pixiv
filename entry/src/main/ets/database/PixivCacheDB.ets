import relationalStore from '@ohos.data.relationalStore';
import common from '@ohos.app.ability.common';
import { PixivNovel, PixivTag, PixivSeries, CacheStatus, BlockedAuthor, BlockedSeries } from '../models/PixivModels';

const DB_NAME = 'pixiv_cache.db';
const TABLE_NOVELS = 'pixiv_novels';
const DB_VERSION = 3;

const SQL_CREATE_NOVELS_TABLE = `
  CREATE TABLE IF NOT EXISTS ${TABLE_NOVELS} (
    id            TEXT    PRIMARY KEY,
    title         TEXT    NOT NULL,
    caption       TEXT    DEFAULT '',
    author        TEXT    DEFAULT '',
    author_id     TEXT    DEFAULT '',
    cover_url     TEXT    DEFAULT '',
    tags          TEXT    DEFAULT '[]',
    text_length   INTEGER DEFAULT 0,
    page_count    INTEGER DEFAULT 1,
    create_date   TEXT    DEFAULT '',
    update_date   TEXT    DEFAULT '',
    series_id     TEXT    DEFAULT '',
    series_title  TEXT    DEFAULT '',
    series_order  INTEGER DEFAULT 0,
    bookmark_count INTEGER DEFAULT 0,
    view_count    INTEGER DEFAULT 0,
    comment_count INTEGER DEFAULT 0,
    cache_status  TEXT    DEFAULT 'not_cached',
    cached_at     TEXT    DEFAULT '',
    full_text     TEXT    DEFAULT '',
    title_translated      TEXT    DEFAULT '',
    has_title_translation INTEGER DEFAULT 0,
    full_text_translated  TEXT    DEFAULT '',
    has_full_translation  INTEGER DEFAULT 0,
    translation_status    TEXT    DEFAULT 'none',
    translation_progress  INTEGER DEFAULT 0
  )
`;

interface ColumnMap {
  ID: string; TITLE: string; CAPTION: string; AUTHOR: string;
  AUTHOR_ID: string; COVER_URL: string; TAGS: string; TEXT_LENGTH: string;
  PAGE_COUNT: string; CREATE_DATE: string; UPDATE_DATE: string;
  SERIES_ID: string; SERIES_TITLE: string; SERIES_ORDER: string;
  BOOKMARK_COUNT: string; VIEW_COUNT: string; COMMENT_COUNT: string;
  CACHE_STATUS: string; CACHED_AT: string; FULL_TEXT: string;
  TITLE_TRANSLATED: string; HAS_TITLE_TRANSLATION: string;
  FULL_TEXT_TRANSLATED: string; HAS_FULL_TRANSLATION: string;
  TRANSLATION_STATUS: string; TRANSLATION_PROGRESS: string;
}

const COL: ColumnMap = {
  ID: 'id', TITLE: 'title', CAPTION: 'caption', AUTHOR: 'author',
  AUTHOR_ID: 'author_id', COVER_URL: 'cover_url', TAGS: 'tags',
  TEXT_LENGTH: 'text_length', PAGE_COUNT: 'page_count',
  CREATE_DATE: 'create_date', UPDATE_DATE: 'update_date',
  SERIES_ID: 'series_id', SERIES_TITLE: 'series_title', SERIES_ORDER: 'series_order',
  BOOKMARK_COUNT: 'bookmark_count', VIEW_COUNT: 'view_count',
  COMMENT_COUNT: 'comment_count', CACHE_STATUS: 'cache_status',
  CACHED_AT: 'cached_at', FULL_TEXT: 'full_text',
  TITLE_TRANSLATED: 'title_translated',
  HAS_TITLE_TRANSLATION: 'has_title_translation',
  FULL_TEXT_TRANSLATED: 'full_text_translated',
  HAS_FULL_TRANSLATION: 'has_full_translation',
  TRANSLATION_STATUS: 'translation_status',
  TRANSLATION_PROGRESS: 'translation_progress'
};

const ALL_COLUMNS: string[] = Object.values(COL);

const TABLE_BLOCKED_AUTHORS = 'blocked_authors';
const TABLE_BLOCKED_SERIES = 'blocked_series';

const SQL_CREATE_BLOCKED_AUTHORS_TABLE = `
  CREATE TABLE IF NOT EXISTS ${TABLE_BLOCKED_AUTHORS} (
    author_id   TEXT    PRIMARY KEY,
    author_name TEXT    NOT NULL,
    blocked_at  TEXT    NOT NULL
  )
`;

const SQL_CREATE_BLOCKED_SERIES_TABLE = `
  CREATE TABLE IF NOT EXISTS ${TABLE_BLOCKED_SERIES} (
    series_id   TEXT    PRIMARY KEY,
    series_title TEXT   NOT NULL,
    author_id   TEXT    NOT NULL,
    author_name TEXT    NOT NULL,
    blocked_at  TEXT    NOT NULL
  )
`;

const SQL_CREATE_PROGRESS_TABLE = `
  CREATE TABLE IF NOT EXISTS reading_progress (
    novel_id      TEXT    NOT NULL,
    is_translated INTEGER DEFAULT 0,
    scroll_y      INTEGER DEFAULT 0,
    last_read_at  TEXT    DEFAULT '',
    PRIMARY KEY (novel_id, is_translated)
  )
`;

export class PixivCacheDB {
  private rdbStore: relationalStore.RdbStore | null = null;
  private initialized: boolean = false;

  async init(ctx: common.UIAbilityContext): Promise<void> {
    if (this.initialized) return;

    const config: relationalStore.StoreConfig = {
      name: DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };

    try {
      this.rdbStore = await relationalStore.getRdbStore(ctx, config);
      const version: number = this.rdbStore.version;

      if (version === 0) {
        await this.rdbStore.executeSql(SQL_CREATE_NOVELS_TABLE);
        await this.rdbStore.executeSql(SQL_CREATE_BLOCKED_AUTHORS_TABLE);
        await this.rdbStore.executeSql(SQL_CREATE_BLOCKED_SERIES_TABLE);
        this.rdbStore.version = DB_VERSION;
      } else if (version < DB_VERSION) {
        await this.upgradeDatabase(version, DB_VERSION);
      }

      await this.initBlocklistTables();
      await this.initProgressTable();
      this.initialized = true;
    } catch (err) {
      console.error(`[PixivCacheDB] 初始化失败: ${JSON.stringify(err)}`);
    }
  }

  async saveNovelMeta(novel: PixivNovel): Promise<void> {
    if (!this.checkReady()) return;

    const existing = await this.getNovelById(novel.id);
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
      await this.rdbStore!.insert(
        TABLE_NOVELS, values,
        relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
      );
    } catch (err) {
      console.error(`[PixivCacheDB] saveNovelMeta 失败 id=${novel.id}: ${JSON.stringify(err)}`);
    }
  }

  async markCaching(novelId: string): Promise<void> {
    await this.updateCacheFields(novelId, { 'cache_status': CacheStatus.CACHING });
  }

  async saveFullText(novelId: string, fullText: string): Promise<void> {
    if (!this.checkReady()) return;
    if (!fullText || fullText.length === 0) {
      await this.markCacheFail(novelId);
      return;
    }
    const success = await this.updateCacheFields(novelId, {
      'full_text':    fullText,
      'cache_status': CacheStatus.CACHED,
      'cached_at':    new Date().toISOString()
    });
    if (success) {
      console.info(`[PixivCacheDB] saveFullText 成功 id=${novelId}，长度=${fullText.length}`);
    }
  }

  async markCacheFail(novelId: string): Promise<void> {
    await this.updateCacheFields(novelId, { 'cache_status': CacheStatus.CACHE_FAIL });
  }

  async deleteCachedText(novelId: string): Promise<void> {
    await this.updateCacheFields(novelId, {
      'full_text':    '',
      'cache_status': CacheStatus.NOT_CACHED,
      'cached_at':    ''
    });
  }

  async getNovelById(novelId: string): Promise<PixivNovel | null> {
    if (!this.checkReady()) return null;
    const predicates = new relationalStore.RdbPredicates(TABLE_NOVELS);
    predicates.equalTo(COL.ID, novelId);
    try {
      const result = await this.rdbStore!.query(predicates, ALL_COLUMNS);
      const novels = this.resultSetToNovels(result);
      return novels.length > 0 ? novels[0] : null;
    } catch (err) {
      console.error(`[PixivCacheDB] getNovelById 失败: ${JSON.stringify(err)}`);
      return null;
    }
  }

  async getFullText(novelId: string): Promise<string | null> {
    if (!this.checkReady()) return null;
    const predicates = new relationalStore.RdbPredicates(TABLE_NOVELS);
    predicates.equalTo(COL.ID, novelId)
      .and()
      .equalTo(COL.CACHE_STATUS, CacheStatus.CACHED);
    try {
      const result = await this.rdbStore!.query(predicates, [COL.FULL_TEXT]);
      if (result.rowCount > 0) {
        result.goToFirstRow();
        const text = result.getString(result.getColumnIndex(COL.FULL_TEXT));
        result.close();
        return text || null;
      }
      result.close();
      return null;
    } catch (err) {
      console.error(`[PixivCacheDB] getFullText 失败: ${JSON.stringify(err)}`);
      return null;
    }
  }

  async getNovelsBySeriesId(seriesId: string): Promise<PixivNovel[]> {
    if (!this.checkReady()) return [];
    const predicates = new relationalStore.RdbPredicates(TABLE_NOVELS);
    predicates.equalTo(COL.SERIES_ID, seriesId)
      .equalTo(COL.CACHE_STATUS, CacheStatus.CACHED)
      .orderByAsc(COL.SERIES_ORDER);
    try {
      const cols = ALL_COLUMNS.filter(c => c !== COL.FULL_TEXT);
      const result = await this.rdbStore!.query(predicates, cols);
      return this.resultSetToNovels(result);
    } catch (err) {
      console.error(`[PixivCacheDB] getNovelsBySeriesId 失败: ${JSON.stringify(err)}`);
      return [];
    }
  }

  async getAllCachedNovels(): Promise<PixivNovel[]> {
    if (!this.checkReady()) return [];
    const predicates = new relationalStore.RdbPredicates(TABLE_NOVELS);
    predicates.equalTo(COL.CACHE_STATUS, CacheStatus.CACHED)
      .orderByDesc(COL.CACHED_AT);
    try {
      const cols = ALL_COLUMNS.filter(c => c !== COL.FULL_TEXT);
      const result = await this.rdbStore!.query(predicates, cols);
      return this.resultSetToNovels(result);
    } catch (err) {
      console.error(`[PixivCacheDB] getAllCachedNovels 失败: ${JSON.stringify(err)}`);
      return [];
    }
  }

  async saveReadingProgress(novelId: string, scrollY: number, isTranslated: boolean = false): Promise<void> {
    if (!this.checkReady() || !novelId) return;
    const values: relationalStore.ValuesBucket = {
      'novel_id':    novelId,
      'is_translated': isTranslated ? 1 : 0,
      'scroll_y':    Math.max(0, Math.floor(scrollY)),
      'last_read_at': new Date().toISOString()
    };
    try {
      await this.rdbStore!.insert(
        'reading_progress', values,
        relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
      );
    } catch (err) {
      console.error(`[PixivCacheDB] 保存进度失败: ${JSON.stringify(err)}`);
    }
  }

  async getCachedNovelCount(): Promise<number> {
    if (!this.checkReady()) return 0;
    const predicates = new relationalStore.RdbPredicates(TABLE_NOVELS);
    predicates.equalTo(COL.CACHE_STATUS, CacheStatus.CACHED);
    try {
      const result = await this.rdbStore!.query(predicates, [COL.ID]);
      const count = result.rowCount;
      result.close();
      return count;
    } catch (err) {
      console.error(`[PixivCacheDB] getCachedNovelCount 失败: ${JSON.stringify(err)}`);
      return 0;
    }
  }

  async deleteAllCachedNovels(): Promise<number> {
    if (!this.checkReady()) return 0;
    const predicates = new relationalStore.RdbPredicates(TABLE_NOVELS);
    predicates.equalTo(COL.CACHE_STATUS, CacheStatus.CACHED);
    try {
      const rows = await this.rdbStore!.delete(predicates);
      return rows;
    } catch (err) {
      console.error(`[PixivCacheDB] deleteAllCachedNovels 失败: ${JSON.stringify(err)}`);
      return 0;
    }
  }

  async deleteNovelById(novelId: string): Promise<boolean> {
    if (!this.checkReady()) return false;
    const predicates = new relationalStore.RdbPredicates(TABLE_NOVELS);
    predicates.equalTo(COL.ID, novelId);
    try {
      const rows = await this.rdbStore!.delete(predicates);
      return rows > 0;
    } catch (err) {
      console.error(`[PixivCacheDB] deleteNovelById 失败 id=${novelId}: ${JSON.stringify(err)}`);
      return false;
    }
  }

  async deleteReadingProgress(novelId: string, isTranslated: boolean = false): Promise<void> {
    if (!this.checkReady() || !novelId) return;
    const predicates = new relationalStore.RdbPredicates('reading_progress');
    predicates.equalTo('novel_id', novelId)
      .and()
      .equalTo('is_translated', isTranslated ? 1 : 0);
    try {
      await this.rdbStore!.delete(predicates);
    } catch (err) {
      console.error(`[PixivCacheDB] 删除进度失败: ${JSON.stringify(err)}`);
    }
  }

  async getReadingProgress(novelId: string, isTranslated: boolean = false): Promise<number> {
    if (!this.checkReady() || !novelId) return 0;
    try {
      const predicates = new relationalStore.RdbPredicates('reading_progress');
      predicates.equalTo('novel_id', novelId)
        .and()
        .equalTo('is_translated', isTranslated ? 1 : 0);
      const result = await this.rdbStore!.query(predicates, ['scroll_y']);
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

  private async initBlocklistTables(): Promise<void> {
    if (!this.rdbStore) return;
    try {
      await this.rdbStore.executeSql(SQL_CREATE_BLOCKED_AUTHORS_TABLE);
      await this.rdbStore.executeSql(SQL_CREATE_BLOCKED_SERIES_TABLE);
    } catch (err) {
      console.error('[PixivCacheDB] 屏蔽表初始化失败:', JSON.stringify(err));
    }
  }

  async addBlockedAuthor(authorId: string, authorName: string): Promise<void> {
    if (!this.checkReady()) return;
    const values: relationalStore.ValuesBucket = {
      'author_id': authorId,
      'author_name': authorName,
      'blocked_at': new Date().toISOString()
    };
    try {
      await this.rdbStore!.insert(
        TABLE_BLOCKED_AUTHORS, values,
        relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
      );
    } catch (err) {
      console.error(`[PixivCacheDB] addBlockedAuthor 失败: ${JSON.stringify(err)}`);
    }
  }

  async removeBlockedAuthor(authorId: string): Promise<void> {
    if (!this.checkReady()) return;
    const predicates = new relationalStore.RdbPredicates(TABLE_BLOCKED_AUTHORS);
    predicates.equalTo('author_id', authorId);
    try {
      await this.rdbStore!.delete(predicates);
    } catch (err) {
      console.error(`[PixivCacheDB] removeBlockedAuthor 失败: ${JSON.stringify(err)}`);
    }
  }

  async getAllBlockedAuthors(): Promise<BlockedAuthor[]> {
    if (!this.checkReady()) return [];
    const predicates = new relationalStore.RdbPredicates(TABLE_BLOCKED_AUTHORS);
    predicates.orderByDesc('blocked_at');
    try {
      const result = await this.rdbStore!.query(predicates, ['author_id', 'author_name', 'blocked_at']);
      const authors: BlockedAuthor[] = [];
      while (result.goToNextRow()) {
        authors.push({
          authorId: result.getString(result.getColumnIndex('author_id')),
          authorName: result.getString(result.getColumnIndex('author_name')),
          blockedAt: result.getString(result.getColumnIndex('blocked_at'))
        });
      }
      result.close();
      return authors;
    } catch (err) {
      console.error(`[PixivCacheDB] getAllBlockedAuthors 失败: ${JSON.stringify(err)}`);
      return [];
    }
  }

  async getAllBlockedAuthorIds(): Promise<Set<string>> {
    const authors = await this.getAllBlockedAuthors();
    return new Set(authors.map(a => a.authorId));
  }

  async isAuthorBlocked(authorId: string): Promise<boolean> {
    if (!this.checkReady()) return false;
    const predicates = new relationalStore.RdbPredicates(TABLE_BLOCKED_AUTHORS);
    predicates.equalTo('author_id', authorId);
    try {
      const result = await this.rdbStore!.query(predicates, ['author_id']);
      const count = result.rowCount;
      result.close();
      return count > 0;
    } catch (err) {
      console.error(`[PixivCacheDB] isAuthorBlocked 失败: ${JSON.stringify(err)}`);
      return false;
    }
  }

  async addBlockedSeries(seriesId: string, seriesTitle: string, authorId: string, authorName: string): Promise<void> {
    if (!this.checkReady()) return;
    const values: relationalStore.ValuesBucket = {
      'series_id': seriesId,
      'series_title': seriesTitle,
      'author_id': authorId,
      'author_name': authorName,
      'blocked_at': new Date().toISOString()
    };
    try {
      await this.rdbStore!.insert(
        TABLE_BLOCKED_SERIES, values,
        relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
      );
    } catch (err) {
      console.error(`[PixivCacheDB] addBlockedSeries 失败: ${JSON.stringify(err)}`);
    }
  }

  async removeBlockedSeries(seriesId: string): Promise<void> {
    if (!this.checkReady()) return;
    const predicates = new relationalStore.RdbPredicates(TABLE_BLOCKED_SERIES);
    predicates.equalTo('series_id', seriesId);
    try {
      await this.rdbStore!.delete(predicates);
    } catch (err) {
      console.error(`[PixivCacheDB] removeBlockedSeries 失败: ${JSON.stringify(err)}`);
    }
  }

  async getAllBlockedSeries(): Promise<BlockedSeries[]> {
    if (!this.checkReady()) return [];
    const predicates = new relationalStore.RdbPredicates(TABLE_BLOCKED_SERIES);
    predicates.orderByDesc('blocked_at');
    try {
      const result = await this.rdbStore!.query(predicates, ['series_id', 'series_title', 'author_id', 'author_name', 'blocked_at']);
      const series: BlockedSeries[] = [];
      while (result.goToNextRow()) {
        series.push({
          seriesId: result.getString(result.getColumnIndex('series_id')),
          seriesTitle: result.getString(result.getColumnIndex('series_title')),
          authorId: result.getString(result.getColumnIndex('author_id')),
          authorName: result.getString(result.getColumnIndex('author_name')),
          blockedAt: result.getString(result.getColumnIndex('blocked_at'))
        });
      }
      result.close();
      return series;
    } catch (err) {
      console.error(`[PixivCacheDB] getAllBlockedSeries 失败: ${JSON.stringify(err)}`);
      return [];
    }
  }

  async getAllBlockedSeriesIds(): Promise<Set<string>> {
    const series = await this.getAllBlockedSeries();
    return new Set(series.map(s => s.seriesId));
  }

  async isSeriesBlocked(seriesId: string): Promise<boolean> {
    if (!this.checkReady()) return false;
    const predicates = new relationalStore.RdbPredicates(TABLE_BLOCKED_SERIES);
    predicates.equalTo('series_id', seriesId);
    try {
      const result = await this.rdbStore!.query(predicates, ['series_id']);
      const count = result.rowCount;
      result.close();
      return count > 0;
    } catch (err) {
      console.error(`[PixivCacheDB] isSeriesBlocked 失败: ${JSON.stringify(err)}`);
      return false;
    }
  }

  private async upgradeDatabase(oldVersion: number, newVersion: number): Promise<void> {
    if (oldVersion < 2) {
      const alterQueries = [
        `ALTER TABLE ${TABLE_NOVELS} ADD COLUMN title_translated TEXT DEFAULT '';`,
        `ALTER TABLE ${TABLE_NOVELS} ADD COLUMN has_title_translation INTEGER DEFAULT 0;`,
        `ALTER TABLE ${TABLE_NOVELS} ADD COLUMN full_text_translated TEXT DEFAULT '';`,
        `ALTER TABLE ${TABLE_NOVELS} ADD COLUMN has_full_translation INTEGER DEFAULT 0;`,
        `ALTER TABLE ${TABLE_NOVELS} ADD COLUMN translation_status TEXT DEFAULT 'none';`,
        `ALTER TABLE ${TABLE_NOVELS} ADD COLUMN translation_progress INTEGER DEFAULT 0;`
      ];
      for (const query of alterQueries) {
        try {
          await this.rdbStore!.executeSql(query);
        } catch (e) {
          console.warn(`[PixivCacheDB] ALTER TABLE 跳过: ${JSON.stringify(e)}`);
        }
      }
    }
    if (oldVersion < 3) {
      try {
        await this.rdbStore!.executeSql(SQL_CREATE_BLOCKED_AUTHORS_TABLE);
        await this.rdbStore!.executeSql(SQL_CREATE_BLOCKED_SERIES_TABLE);
      } catch (e) {
        console.warn(`[PixivCacheDB] 屏蔽表创建跳过: ${JSON.stringify(e)}`);
      }
    }
    this.rdbStore!.version = newVersion;
  }

  async saveTitleTranslation(novelId: string, translatedTitle: string): Promise<void> {
    await this.updateCacheFields(novelId, {
      'title_translated': translatedTitle,
      'has_title_translation': 1
    });
  }

  async saveFullTextTranslation(novelId: string, translatedText: string): Promise<void> {
    await this.updateCacheFields(novelId, {
      'full_text_translated': translatedText,
      'has_full_translation': 1,
      'translation_status': 'completed',
      'translation_progress': 100
    });
  }

  async updateTranslationProgress(novelId: string, progress: number, status: string): Promise<void> {
    await this.updateCacheFields(novelId, {
      'translation_progress': progress,
      'translation_status': status
    });
  }

  private async initProgressTable(): Promise<void> {
    if (!this.rdbStore) return;
    try {
      await this.rdbStore.executeSql(SQL_CREATE_PROGRESS_TABLE);

      try {
        await this.rdbStore.executeSql(
          "ALTER TABLE reading_progress ADD COLUMN is_translated INTEGER DEFAULT 0;"
        );
        await this.migrateProgressTable();
      } catch (e) {
        // is_translated 列已存在，无需迁移
      }
    } catch (err) {
      console.error('[PixivCacheDB] 进度表初始化失败:', JSON.stringify(err));
    }
  }

  private async migrateProgressTable(): Promise<void> {
    try {
      await this.rdbStore!.executeSql(
        `CREATE TABLE IF NOT EXISTS reading_progress_new (
          novel_id      TEXT    NOT NULL,
          is_translated INTEGER DEFAULT 0,
          scroll_y      INTEGER DEFAULT 0,
          last_read_at  TEXT    DEFAULT '',
          PRIMARY KEY (novel_id, is_translated)
        );`
      );
      await this.rdbStore!.executeSql(
        `INSERT OR IGNORE INTO reading_progress_new (novel_id, is_translated, scroll_y, last_read_at)
         SELECT novel_id, 0, scroll_y, last_read_at FROM reading_progress;`
      );
      await this.rdbStore!.executeSql(`DROP TABLE IF EXISTS reading_progress;`);
      await this.rdbStore!.executeSql(`ALTER TABLE reading_progress_new RENAME TO reading_progress;`);
    } catch (e) {
      console.error('[PixivCacheDB] 进度表迁移失败:', JSON.stringify(e));
    }
  }

  private checkReady(): boolean {
    if (!this.initialized || !this.rdbStore) {
      return false;
    }
    return true;
  }

  private async updateCacheFields(novelId: string, fields: relationalStore.ValuesBucket): Promise<boolean> {
    if (!this.checkReady()) return false;
    const predicates = new relationalStore.RdbPredicates(TABLE_NOVELS);
    predicates.equalTo(COL.ID, novelId);
    try {
      const rows = await this.rdbStore!.update(fields, predicates);
      return rows > 0;
    } catch (err) {
      console.error(`[PixivCacheDB] updateCacheFields 失败 id=${novelId}: ${JSON.stringify(err)}`);
      return false;
    }
  }

  private resultSetToNovels(result: relationalStore.ResultSet): PixivNovel[] {
    const novels: PixivNovel[] = [];
    try {
      while (result.goToNextRow()) {
        const tagsRaw = result.getString(result.getColumnIndex(COL.TAGS));
        let tags: PixivTag[] = [];
        try { tags = JSON.parse(tagsRaw || '[]'); } catch { tags = []; }

        const seriesId    = result.getString(result.getColumnIndex(COL.SERIES_ID));
        const seriesTitle = result.getString(result.getColumnIndex(COL.SERIES_TITLE));
        const seriesOrder = result.getLong(result.getColumnIndex(COL.SERIES_ORDER));
        const series: PixivSeries | undefined = seriesId
          ? { id: seriesId, title: seriesTitle, order: seriesOrder }
          : undefined;

        let fullText: string | undefined = undefined;
        try {
          const ftIdx = result.getColumnIndex(COL.FULL_TEXT);
          if (ftIdx >= 0) {
            const ft = result.getString(ftIdx);
            fullText = ft || undefined;
          }
        } catch {}

        novels.push({
          id:            result.getString(result.getColumnIndex(COL.ID)),
          title:         result.getString(result.getColumnIndex(COL.TITLE)),
          caption:       result.getString(result.getColumnIndex(COL.CAPTION)),
          author:        result.getString(result.getColumnIndex(COL.AUTHOR)),
          authorId:      result.getString(result.getColumnIndex(COL.AUTHOR_ID)),
          coverUrl:      result.getString(result.getColumnIndex(COL.COVER_URL)),
          tags,
          textLength:    result.getLong(result.getColumnIndex(COL.TEXT_LENGTH)),
          pageCount:     result.getLong(result.getColumnIndex(COL.PAGE_COUNT)),
          createDate:    result.getString(result.getColumnIndex(COL.CREATE_DATE)),
          updateDate:    result.getString(result.getColumnIndex(COL.UPDATE_DATE)),
          series,
          bookmarkCount: result.getLong(result.getColumnIndex(COL.BOOKMARK_COUNT)),
          viewCount:     result.getLong(result.getColumnIndex(COL.VIEW_COUNT)),
          commentCount:  result.getLong(result.getColumnIndex(COL.COMMENT_COUNT)),
          cacheStatus:   (result.getString(result.getColumnIndex(COL.CACHE_STATUS)) as CacheStatus) || CacheStatus.NOT_CACHED,
          cachedAt:      result.getString(result.getColumnIndex(COL.CACHED_AT)) || undefined,
          fullText,
          titleTranslated:     result.getString(result.getColumnIndex(COL.TITLE_TRANSLATED)) || undefined,
          hasTitleTranslation: result.getLong(result.getColumnIndex(COL.HAS_TITLE_TRANSLATION)) === 1,
          fullTextTranslated:  result.getString(result.getColumnIndex(COL.FULL_TEXT_TRANSLATED)) || undefined,
          hasFullTranslation:  result.getLong(result.getColumnIndex(COL.HAS_FULL_TRANSLATION)) === 1,
          translationStatus:   (result.getString(result.getColumnIndex(COL.TRANSLATION_STATUS)) || 'none') as 'none' | 'in_progress' | 'completed' | 'failed',
          translationProgress: result.getLong(result.getColumnIndex(COL.TRANSLATION_PROGRESS)) ?? 0
        });
      }
    } finally {
      result.close();
    }
    return novels;
  }
}

export const pixivCacheDB = new PixivCacheDB();
