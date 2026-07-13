import relationalStore from '@ohos.data.relationalStore';
import { DatabaseCore } from './DatabaseCore';
import { BrowseHistoryRecord } from '../models/PixivModels';

function resultSetToHistoryRecords(result: relationalStore.ResultSet): BrowseHistoryRecord[] {
  const records: BrowseHistoryRecord[] = [];
  try {
    while (result.goToNextRow()) {
      const tagsRaw = result.getString(result.getColumnIndex('tags'));
      let tags: string[] = [];
      try {
        tags = JSON.parse(tagsRaw || '[]') as string[];
      } catch (_) {
        tags = [];
      }
      records.push({
        id: result.getString(result.getColumnIndex('id')),
        contentType: result.getString(result.getColumnIndex('content_type')) as 'illust' | 'novel',
        contentId: result.getString(result.getColumnIndex('content_id')),
        title: result.getString(result.getColumnIndex('title')),
        coverUrl: result.getString(result.getColumnIndex('cover_url')),
        userId: result.getString(result.getColumnIndex('user_id')),
        userName: result.getString(result.getColumnIndex('user_name')),
        pageCount: result.getLong(result.getColumnIndex('page_count')),
        tags: tags,
        bookmarkCount: result.getLong(result.getColumnIndex('bookmark_count')),
        wordCount: result.getLong(result.getColumnIndex('word_count')),
        seriesId: result.getString(result.getColumnIndex('series_id')),
        seriesTitle: result.getString(result.getColumnIndex('series_title')),
        createDate: result.getString(result.getColumnIndex('create_date')),
        updateDate: result.getString(result.getColumnIndex('update_date')),
        viewedAt: result.getString(result.getColumnIndex('viewed_at'))
      });
    }
  } finally {
    result.close();
  }
  return records;
}

export class BrowseHistoryDao {
  static async saveHistory(record: BrowseHistoryRecord): Promise<void> {
    if (!DatabaseCore.isReady()) return;
    const store = DatabaseCore.getStore()!;
    const values: relationalStore.ValuesBucket = {
      'id': record.id,
      'content_type': record.contentType,
      'content_id': record.contentId,
      'title': record.title,
      'cover_url': record.coverUrl,
      'user_id': record.userId,
      'user_name': record.userName,
      'page_count': record.pageCount,
      'tags': JSON.stringify(record.tags),
      'bookmark_count': record.bookmarkCount,
      'word_count': record.wordCount,
      'series_id': record.seriesId,
      'series_title': record.seriesTitle,
      'create_date': record.createDate,
      'update_date': record.updateDate,
      'viewed_at': record.viewedAt
    };
    try {
      const predicates = new relationalStore.RdbPredicates(DatabaseCore.TableBrowseHistory);
      predicates.equalTo('id', record.id);
      const existing = await store.query(predicates, ['id']);
      const exists = existing.goToFirstRow();
      existing.close();
      if (exists) {
        await store.update(values, predicates);
      } else {
        await store.insert(DatabaseCore.TableBrowseHistory, values);
      }
    } catch (err) {
      console.error('[BrowseHistoryDao] saveHistory 失败:', JSON.stringify(err));
    }
  }

  static async getAllIllustHistory(limit: number = 30, offset: number = 0): Promise<BrowseHistoryRecord[]> {
    if (!DatabaseCore.isReady()) return [];
    const store = DatabaseCore.getStore()!;
    const sql = `SELECT * FROM ${DatabaseCore.TableBrowseHistory} WHERE content_type = 'illust' ORDER BY viewed_at DESC LIMIT ? OFFSET ?`;
    try {
      const bindArgs: Array<number> = [limit, offset];
      const result = await store.querySql(sql, bindArgs);
      return resultSetToHistoryRecords(result);
    } catch (err) {
      console.error('[BrowseHistoryDao] getAllIllustHistory 失败:', JSON.stringify(err));
      return [];
    }
  }

  static async getAllNovelHistory(limit: number = 30, offset: number = 0): Promise<BrowseHistoryRecord[]> {
    if (!DatabaseCore.isReady()) return [];
    const store = DatabaseCore.getStore()!;
    const sql = `SELECT * FROM ${DatabaseCore.TableBrowseHistory} WHERE content_type = 'novel' ORDER BY viewed_at DESC LIMIT ? OFFSET ?`;
    try {
      const bindArgs: Array<number> = [limit, offset];
      const result = await store.querySql(sql, bindArgs);
      return resultSetToHistoryRecords(result);
    } catch (err) {
      console.error('[BrowseHistoryDao] getAllNovelHistory 失败:', JSON.stringify(err));
      return [];
    }
  }

  static async deleteHistory(id: string): Promise<void> {
    if (!DatabaseCore.isReady()) return;
    const store = DatabaseCore.getStore()!;
    try {
      const predicates = new relationalStore.RdbPredicates(DatabaseCore.TableBrowseHistory);
      predicates.equalTo('id', id);
      await store.delete(predicates);
    } catch (err) {
      console.error('[BrowseHistoryDao] deleteHistory 失败:', JSON.stringify(err));
    }
  }

  static async deleteHistoryByDate(dateKey: string, contentType: string): Promise<number> {
    if (!DatabaseCore.isReady()) return 0;
    const store = DatabaseCore.getStore()!;
    try {
      const predicates = new relationalStore.RdbPredicates(DatabaseCore.TableBrowseHistory);
      predicates.equalTo('content_type', contentType);
      predicates.like('viewed_at', dateKey + '%');
      const rows = await store.delete(predicates);
      return rows;
    } catch (err) {
      console.error('[BrowseHistoryDao] deleteHistoryByDate 失败:', JSON.stringify(err));
      return 0;
    }
  }

  static async getCountByType(contentType: string): Promise<number> {
    if (!DatabaseCore.isReady()) return 0;
    const store = DatabaseCore.getStore()!;
    const predicates = new relationalStore.RdbPredicates(DatabaseCore.TableBrowseHistory);
    predicates.equalTo('content_type', contentType);
    try {
      const result = await store.query(predicates, ['id']);
      const count = result.rowCount;
      result.close();
      return count;
    } catch (err) {
      console.error('[BrowseHistoryDao] getCountByType 失败:', JSON.stringify(err));
      return 0;
    }
  }
}
