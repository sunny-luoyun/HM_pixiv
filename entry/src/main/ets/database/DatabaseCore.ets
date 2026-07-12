import relationalStore from '@ohos.data.relationalStore';
import common from '@ohos.app.ability.common';
import { PixivNovel, PixivTag, PixivSeries, CacheStatus } from '../models/PixivModels';

const DB_NAME = 'pixiv_cache.db';

interface TableNames {
  NOVELS: string;
  BLOCKED_AUTHORS: string;
  BLOCKED_SERIES: string;
  BLOCKED_SERIES_TITLES: string;
  PROGRESS: string;
  BROWSE_HISTORY: string;
}

const TABLES: TableNames = {
  NOVELS: 'pixiv_novels',
  BLOCKED_AUTHORS: 'blocked_authors',
  BLOCKED_SERIES: 'blocked_series',
  BLOCKED_SERIES_TITLES: 'blocked_series_titles',
  PROGRESS: 'reading_progress',
  BROWSE_HISTORY: 'browse_history',
};
const DB_VERSION = 5;

const SQL_CREATE_NOVELS_TABLE = `
  CREATE TABLE IF NOT EXISTS ${TABLES.NOVELS} (
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

const SQL_CREATE_BLOCKED_AUTHORS_TABLE = `
  CREATE TABLE IF NOT EXISTS ${TABLES.BLOCKED_AUTHORS} (
    author_id   TEXT    PRIMARY KEY,
    author_name TEXT    NOT NULL,
    blocked_at  TEXT    NOT NULL
  )
`;

const SQL_CREATE_BLOCKED_SERIES_TABLE = `
  CREATE TABLE IF NOT EXISTS ${TABLES.BLOCKED_SERIES} (
    series_id   TEXT    PRIMARY KEY,
    series_title TEXT   NOT NULL,
    author_id   TEXT    NOT NULL,
    author_name TEXT    NOT NULL,
    blocked_at  TEXT    NOT NULL
  )
`;

const SQL_CREATE_BLOCKED_SERIES_TITLES_TABLE = `
  CREATE TABLE IF NOT EXISTS ${TABLES.BLOCKED_SERIES_TITLES} (
    title      TEXT    PRIMARY KEY,
    blocked_at TEXT    NOT NULL
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

const SQL_CREATE_BROWSE_HISTORY_TABLE = `
  CREATE TABLE IF NOT EXISTS ${TABLES.BROWSE_HISTORY} (
    id            TEXT    PRIMARY KEY,
    content_type  TEXT    NOT NULL,
    content_id    TEXT    NOT NULL,
    title         TEXT    NOT NULL,
    cover_url     TEXT    DEFAULT '',
    user_id       TEXT    DEFAULT '',
    user_name     TEXT    DEFAULT '',
    page_count    INTEGER DEFAULT 0,
    tags          TEXT    DEFAULT '[]',
    bookmark_count INTEGER DEFAULT 0,
    word_count    INTEGER DEFAULT 0,
    series_id     TEXT    DEFAULT '',
    series_title  TEXT    DEFAULT '',
    create_date   TEXT    DEFAULT '',
    update_date   TEXT    DEFAULT '',
    viewed_at     TEXT    NOT NULL
  )
`;

export class DatabaseCore {
  private static rdbStore: relationalStore.RdbStore | null = null;
  private static initialized: boolean = false;

  static async init(ctx: common.UIAbilityContext): Promise<void> {
    if (DatabaseCore.initialized) return;

    const config: relationalStore.StoreConfig = {
      name: DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };

    try {
      DatabaseCore.rdbStore = await relationalStore.getRdbStore(ctx, config);
      const version: number = DatabaseCore.rdbStore.version;

      if (version === 0) {
        await DatabaseCore.rdbStore.executeSql(SQL_CREATE_NOVELS_TABLE);
        await DatabaseCore.rdbStore.executeSql(SQL_CREATE_BLOCKED_AUTHORS_TABLE);
        await DatabaseCore.rdbStore.executeSql(SQL_CREATE_BLOCKED_SERIES_TABLE);
        await DatabaseCore.rdbStore.executeSql(SQL_CREATE_BROWSE_HISTORY_TABLE);
        DatabaseCore.rdbStore.version = DB_VERSION;
      } else if (version < DB_VERSION) {
        await DatabaseCore.upgradeDatabase(version, DB_VERSION);
      }

      await DatabaseCore.initBlocklistTables();
      await DatabaseCore.initProgressTable();
      await DatabaseCore.initBrowseHistoryTable();
      DatabaseCore.initialized = true;
    } catch (err) {
      console.error(`[DatabaseCore] 初始化失败: ${JSON.stringify(err)}`);
    }
  }

  static getStore(): relationalStore.RdbStore | null {
    return DatabaseCore.rdbStore;
  }

  static isReady(): boolean {
    return DatabaseCore.initialized && DatabaseCore.rdbStore !== null;
  }

  static get Col(): ColumnMap {
    return COL;
  }

  static getAllColumns(): string[] {
    return ALL_COLUMNS;
  }

  static get TableNovels(): string {
    return TABLES.NOVELS;
  }

  static get TableBlockedAuthors(): string {
    return TABLES.BLOCKED_AUTHORS;
  }

  static get TableBlockedSeries(): string {
    return TABLES.BLOCKED_SERIES;
  }

  static get TableBlockedSeriesTitles(): string {
    return TABLES.BLOCKED_SERIES_TITLES;
  }

  static get TableProgress(): string {
    return TABLES.PROGRESS;
  }

  static get TableBrowseHistory(): string {
    return TABLES.BROWSE_HISTORY;
  }

  static resultSetToNovels(result: relationalStore.ResultSet): PixivNovel[] {
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

  static async updateCacheFields(novelId: string, fields: relationalStore.ValuesBucket): Promise<boolean> {
    if (!DatabaseCore.isReady()) return false;
    const predicates = new relationalStore.RdbPredicates(TABLES.NOVELS);
    predicates.equalTo(COL.ID, novelId);
    try {
      const rows = await DatabaseCore.rdbStore!.update(fields, predicates);
      return rows > 0;
    } catch (err) {
      console.error(`[DatabaseCore] updateCacheFields 失败 id=${novelId}: ${JSON.stringify(err)}`);
      return false;
    }
  }

  private static async upgradeDatabase(oldVersion: number, newVersion: number): Promise<void> {
    if (oldVersion < 2) {
      const alterQueries = [
        `ALTER TABLE ${TABLES.NOVELS} ADD COLUMN title_translated TEXT DEFAULT '';`,
        `ALTER TABLE ${TABLES.NOVELS} ADD COLUMN has_title_translation INTEGER DEFAULT 0;`,
        `ALTER TABLE ${TABLES.NOVELS} ADD COLUMN full_text_translated TEXT DEFAULT '';`,
        `ALTER TABLE ${TABLES.NOVELS} ADD COLUMN has_full_translation INTEGER DEFAULT 0;`,
        `ALTER TABLE ${TABLES.NOVELS} ADD COLUMN translation_status TEXT DEFAULT 'none';`,
        `ALTER TABLE ${TABLES.NOVELS} ADD COLUMN translation_progress INTEGER DEFAULT 0;`
      ];
      for (const query of alterQueries) {
        try {
          await DatabaseCore.rdbStore!.executeSql(query);
        } catch (e) {
          console.warn(`[DatabaseCore] ALTER TABLE 跳过: ${JSON.stringify(e)}`);
        }
      }
    }
    if (oldVersion < 3) {
      try {
        await DatabaseCore.rdbStore!.executeSql(SQL_CREATE_BLOCKED_AUTHORS_TABLE);
        await DatabaseCore.rdbStore!.executeSql(SQL_CREATE_BLOCKED_SERIES_TABLE);
      } catch (e) {
        console.warn(`[DatabaseCore] 屏蔽表创建跳过: ${JSON.stringify(e)}`);
      }
    }
    if (oldVersion < 4) {
      try {
        await DatabaseCore.rdbStore!.executeSql(SQL_CREATE_BLOCKED_SERIES_TITLES_TABLE);
      } catch (e) {
        console.warn(`[DatabaseCore] 系列名称屏蔽表创建跳过: ${JSON.stringify(e)}`);
      }
    }
    if (oldVersion < 5) {
      try {
        await DatabaseCore.rdbStore!.executeSql(SQL_CREATE_BROWSE_HISTORY_TABLE);
      } catch (e) {
        console.warn(`[DatabaseCore] 浏览历史表创建跳过: ${JSON.stringify(e)}`);
      }
    }
    DatabaseCore.rdbStore!.version = newVersion;
  }

  private static async initBlocklistTables(): Promise<void> {
    if (!DatabaseCore.rdbStore) return;
    try {
      await DatabaseCore.rdbStore.executeSql(SQL_CREATE_BLOCKED_AUTHORS_TABLE);
      await DatabaseCore.rdbStore.executeSql(SQL_CREATE_BLOCKED_SERIES_TABLE);
      await DatabaseCore.rdbStore.executeSql(SQL_CREATE_BLOCKED_SERIES_TITLES_TABLE);
    } catch (err) {
      console.error('[DatabaseCore] 屏蔽表初始化失败:', JSON.stringify(err));
    }
  }

  private static async initProgressTable(): Promise<void> {
    if (!DatabaseCore.rdbStore) return;
    try {
      await DatabaseCore.rdbStore.executeSql(SQL_CREATE_PROGRESS_TABLE);

      try {
        await DatabaseCore.rdbStore.executeSql(
          "ALTER TABLE reading_progress ADD COLUMN is_translated INTEGER DEFAULT 0;"
        );
        await DatabaseCore.migrateProgressTable();
      } catch (e) {
        // is_translated 列已存在，无需迁移
      }
    } catch (err) {
      console.error('[DatabaseCore] 进度表初始化失败:', JSON.stringify(err));
    }
  }

  private static async migrateProgressTable(): Promise<void> {
    try {
      await DatabaseCore.rdbStore!.executeSql(
        `CREATE TABLE IF NOT EXISTS reading_progress_new (
          novel_id      TEXT    NOT NULL,
          is_translated INTEGER DEFAULT 0,
          scroll_y      INTEGER DEFAULT 0,
          last_read_at  TEXT    DEFAULT '',
          PRIMARY KEY (novel_id, is_translated)
        );`
      );
      await DatabaseCore.rdbStore!.executeSql(
        `INSERT OR IGNORE INTO reading_progress_new (novel_id, is_translated, scroll_y, last_read_at)
         SELECT novel_id, 0, scroll_y, last_read_at FROM reading_progress;`
      );
      await DatabaseCore.rdbStore!.executeSql(`DROP TABLE IF EXISTS reading_progress;`);
      await DatabaseCore.rdbStore!.executeSql(`ALTER TABLE reading_progress_new RENAME TO reading_progress;`);
    } catch (e) {
      console.error('[DatabaseCore] 进度表迁移失败:', JSON.stringify(e));
    }
  }

  private static async initBrowseHistoryTable(): Promise<void> {
    if (!DatabaseCore.rdbStore) return;
    try {
      await DatabaseCore.rdbStore.executeSql(SQL_CREATE_BROWSE_HISTORY_TABLE);
    } catch (err) {
      console.error('[DatabaseCore] 浏览历史表初始化失败:', JSON.stringify(err));
    }
  }
}
