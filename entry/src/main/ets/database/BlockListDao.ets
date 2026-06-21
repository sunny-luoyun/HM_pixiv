import relationalStore from '@ohos.data.relationalStore';
import { DatabaseCore } from './DatabaseCore';
import { BlockedAuthor, BlockedSeries, BlockedSeriesTitle } from '../models/PixivModels';

export class BlockListDao {
  static async addBlockedAuthor(authorId: string, authorName: string): Promise<void> {
    if (!DatabaseCore.isReady()) return;
    const store = DatabaseCore.getStore()!;
    const values: relationalStore.ValuesBucket = {
      'author_id': authorId,
      'author_name': authorName,
      'blocked_at': new Date().toISOString()
    };
    try {
      await store.insert(
        DatabaseCore.TableBlockedAuthors, values,
        relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
      );
    } catch (err) {
      console.error(`[BlockListDao] addBlockedAuthor 失败: ${JSON.stringify(err)}`);
    }
  }

  static async removeBlockedAuthor(authorId: string): Promise<void> {
    if (!DatabaseCore.isReady()) return;
    const store = DatabaseCore.getStore()!;
    const predicates = new relationalStore.RdbPredicates(DatabaseCore.TableBlockedAuthors);
    predicates.equalTo('author_id', authorId);
    try {
      await store.delete(predicates);
    } catch (err) {
      console.error(`[BlockListDao] removeBlockedAuthor 失败: ${JSON.stringify(err)}`);
    }
  }

  static async getAllBlockedAuthors(): Promise<BlockedAuthor[]> {
    if (!DatabaseCore.isReady()) return [];
    const store = DatabaseCore.getStore()!;
    const predicates = new relationalStore.RdbPredicates(DatabaseCore.TableBlockedAuthors);
    predicates.orderByDesc('blocked_at');
    try {
      const result = await store.query(predicates, ['author_id', 'author_name', 'blocked_at']);
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
      console.error(`[BlockListDao] getAllBlockedAuthors 失败: ${JSON.stringify(err)}`);
      return [];
    }
  }

  static async getAllBlockedAuthorIds(): Promise<Set<string>> {
    const authors = await BlockListDao.getAllBlockedAuthors();
    return new Set(authors.map(a => a.authorId));
  }

  static async isAuthorBlocked(authorId: string): Promise<boolean> {
    if (!DatabaseCore.isReady()) return false;
    const store = DatabaseCore.getStore()!;
    const predicates = new relationalStore.RdbPredicates(DatabaseCore.TableBlockedAuthors);
    predicates.equalTo('author_id', authorId);
    try {
      const result = await store.query(predicates, ['author_id']);
      const count = result.rowCount;
      result.close();
      return count > 0;
    } catch (err) {
      console.error(`[BlockListDao] isAuthorBlocked 失败: ${JSON.stringify(err)}`);
      return false;
    }
  }

  static async addBlockedSeries(seriesId: string, seriesTitle: string, authorId: string, authorName: string): Promise<void> {
    if (!DatabaseCore.isReady()) return;
    const store = DatabaseCore.getStore()!;
    const values: relationalStore.ValuesBucket = {
      'series_id': seriesId,
      'series_title': seriesTitle,
      'author_id': authorId,
      'author_name': authorName,
      'blocked_at': new Date().toISOString()
    };
    try {
      await store.insert(
        DatabaseCore.TableBlockedSeries, values,
        relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
      );
    } catch (err) {
      console.error(`[BlockListDao] addBlockedSeries 失败: ${JSON.stringify(err)}`);
    }
  }

  static async removeBlockedSeries(seriesId: string): Promise<void> {
    if (!DatabaseCore.isReady()) return;
    const store = DatabaseCore.getStore()!;
    const predicates = new relationalStore.RdbPredicates(DatabaseCore.TableBlockedSeries);
    predicates.equalTo('series_id', seriesId);
    try {
      await store.delete(predicates);
    } catch (err) {
      console.error(`[BlockListDao] removeBlockedSeries 失败: ${JSON.stringify(err)}`);
    }
  }

  static async getAllBlockedSeries(): Promise<BlockedSeries[]> {
    if (!DatabaseCore.isReady()) return [];
    const store = DatabaseCore.getStore()!;
    const predicates = new relationalStore.RdbPredicates(DatabaseCore.TableBlockedSeries);
    predicates.orderByDesc('blocked_at');
    try {
      const result = await store.query(predicates, ['series_id', 'series_title', 'author_id', 'author_name', 'blocked_at']);
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
      console.error(`[BlockListDao] getAllBlockedSeries 失败: ${JSON.stringify(err)}`);
      return [];
    }
  }

  static async getAllBlockedSeriesIds(): Promise<Set<string>> {
    const series = await BlockListDao.getAllBlockedSeries();
    return new Set(series.map(s => s.seriesId));
  }

  static async isSeriesBlocked(seriesId: string): Promise<boolean> {
    if (!DatabaseCore.isReady()) return false;
    const store = DatabaseCore.getStore()!;
    const predicates = new relationalStore.RdbPredicates(DatabaseCore.TableBlockedSeries);
    predicates.equalTo('series_id', seriesId);
    try {
      const result = await store.query(predicates, ['series_id']);
      const count = result.rowCount;
      result.close();
      return count > 0;
    } catch (err) {
      console.error(`[BlockListDao] isSeriesBlocked 失败: ${JSON.stringify(err)}`);
      return false;
    }
  }

  static async addBlockedSeriesTitle(title: string): Promise<void> {
    if (!DatabaseCore.isReady() || !title) return;
    const store = DatabaseCore.getStore()!;
    const values: relationalStore.ValuesBucket = {
      'title': title,
      'blocked_at': new Date().toISOString()
    };
    try {
      await store.insert(
        DatabaseCore.TableBlockedSeriesTitles, values,
        relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
      );
    } catch (err) {
      console.error(`[BlockListDao] addBlockedSeriesTitle 失败: ${JSON.stringify(err)}`);
    }
  }

  static async removeBlockedSeriesTitle(title: string): Promise<void> {
    if (!DatabaseCore.isReady() || !title) return;
    const store = DatabaseCore.getStore()!;
    const predicates = new relationalStore.RdbPredicates(DatabaseCore.TableBlockedSeriesTitles);
    predicates.equalTo('title', title);
    try {
      await store.delete(predicates);
    } catch (err) {
      console.error(`[BlockListDao] removeBlockedSeriesTitle 失败: ${JSON.stringify(err)}`);
    }
  }

  static async getAllBlockedSeriesTitles(): Promise<BlockedSeriesTitle[]> {
    if (!DatabaseCore.isReady()) return [];
    const store = DatabaseCore.getStore()!;
    const predicates = new relationalStore.RdbPredicates(DatabaseCore.TableBlockedSeriesTitles);
    predicates.orderByDesc('blocked_at');
    try {
      const result = await store.query(predicates, ['title', 'blocked_at']);
      const titles: BlockedSeriesTitle[] = [];
      while (result.goToNextRow()) {
        titles.push({
          title: result.getString(result.getColumnIndex('title')),
          blockedAt: result.getString(result.getColumnIndex('blocked_at'))
        });
      }
      result.close();
      return titles;
    } catch (err) {
      console.error(`[BlockListDao] getAllBlockedSeriesTitles 失败: ${JSON.stringify(err)}`);
      return [];
    }
  }

  static async getAllBlockedSeriesTitleSet(): Promise<Set<string>> {
    const titles = await BlockListDao.getAllBlockedSeriesTitles();
    return new Set(titles.map(t => t.title.toLowerCase()));
  }
}
