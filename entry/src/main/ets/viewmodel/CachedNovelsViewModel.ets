import { BaseState } from './BaseState';
import { BaseVM, BaseVMEvent } from './BaseVM';
import { pixivCacheDB } from '../database/PixivCacheDB';
import { PixivNovel } from '../models/PixivModels';
import common from '@ohos.app.ability.common';

export interface SeriesGroup {
  seriesId: string;
  seriesTitle: string;
  novels: PixivNovel[];
}

export interface AuthorGroup {
  authorId: string;
  authorName: string;
  standaloneNovels: PixivNovel[];
  seriesMap: Map<string, SeriesGroup>;
  totalCount: number;
}

export class CachedNovelsEventType {
  static readonly LOAD_CACHED = 'LOAD_CACHED';
  static readonly DELETE_AUTHOR_CACHE = 'DELETE_AUTHOR_CACHE';
  static readonly DELETE_NOVEL_CACHE = 'DELETE_NOVEL_CACHE';
  static readonly CLEAR_ALL = 'CLEAR_ALL';
}

@Observed
export class CachedNovelsState extends BaseState {
  cachedNovels: PixivNovel[] = [];
  authorGroups: AuthorGroup[] = [];
  isLoading: boolean = true;
}

export class CachedNovelsViewModel extends BaseVM<CachedNovelsState> {
  private static instance: CachedNovelsViewModel;

  static getInstance(): CachedNovelsViewModel {
    if (!CachedNovelsViewModel.instance) {
      CachedNovelsViewModel.instance = new CachedNovelsViewModel();
    }
    return CachedNovelsViewModel.instance;
  }

  private constructor() {
    super(new CachedNovelsState());
  }

  sendEvent(event: BaseVMEvent): void {
    switch (event.type) {
      case CachedNovelsEventType.LOAD_CACHED:
        this.loadCachedNovels();
        break;
      case CachedNovelsEventType.DELETE_AUTHOR_CACHE:
        this.deleteAuthorCache((event.param as Record<string, string>)['authorId'] ?? '');
        break;
      case CachedNovelsEventType.DELETE_NOVEL_CACHE:
        this.deleteNovelCache((event.param as Record<string, string>)['novelId'] ?? '');
        break;
      case CachedNovelsEventType.CLEAR_ALL:
        this.clearAll();
        break;
    }
  }

  async loadCachedNovels(): Promise<void> {
    const state = this.state;
    state.isLoading = true;
    try {
      const ctx = AppStorage.get<common.UIAbilityContext>('appContext');
      if (!ctx) return;
      await pixivCacheDB.init(ctx);
      const novels = await pixivCacheDB.getAllCachedNovels();
      state.cachedNovels = novels;
      state.authorGroups = this.groupNovels(novels);
    } catch (err) {
      console.error('获取缓存小说列表失败:', err);
    }
    state.isLoading = false;
  }

  async deleteAuthorCache(authorId: string): Promise<void> {
    const state = this.state;
    const ag = state.authorGroups.find(g => g.authorId === authorId);
    if (!ag) return;
    const all: PixivNovel[] = [
      ...ag.standaloneNovels,
      ...Array.from(ag.seriesMap.values()).flatMap(sg => sg.novels),
    ];
    for (const n of all) {
      await pixivCacheDB.deleteCachedText(n.id);
    }
    await this.loadCachedNovels();
  }

  async deleteNovelCache(novelId: string): Promise<void> {
    await pixivCacheDB.deleteCachedText(novelId);
    this.state.cachedNovels = this.state.cachedNovels.filter(n => n.id !== novelId);
  }

  async clearAll(): Promise<void> {
    await pixivCacheDB.deleteAllCachedNovels();
    await this.loadCachedNovels();
  }

  groupNovels(novels: PixivNovel[]): AuthorGroup[] {
    const authorMap = new Map<string, AuthorGroup>();
    for (const novel of novels) {
      let group = authorMap.get(novel.authorId);
      if (!group) {
        group = {
          authorId: novel.authorId,
          authorName: novel.author,
          standaloneNovels: [],
          seriesMap: new Map(),
          totalCount: 0,
        };
        authorMap.set(novel.authorId, group);
      }
      if (novel.series) {
        const sid = novel.series.id;
        let sg = group.seriesMap.get(sid);
        if (!sg) {
          sg = { seriesId: sid, seriesTitle: novel.series.title, novels: [] };
          group.seriesMap.set(sid, sg);
        }
        sg.novels.push(novel);
      } else {
        group.standaloneNovels.push(novel);
      }
      group.totalCount++;
    }
    for (const ag of authorMap.values()) {
      for (const sg of ag.seriesMap.values()) {
        sg.novels.sort((a, b) => (a.series?.order ?? 0) - (b.series?.order ?? 0));
      }
    }
    return Array.from(authorMap.values()).sort((a, b) =>
      a.authorName.localeCompare(b.authorName)
    );
  }
}
