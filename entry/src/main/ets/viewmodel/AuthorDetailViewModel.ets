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

export class AuthorDetailEventType {
  static readonly LOAD_AUTHOR = 'LOAD_AUTHOR';
}

@Observed
export class AuthorDetailState extends BaseState {
  authorId: string = '';
  authorName: string = '';
  authorGroup: AuthorGroup | null = null;
  isLoading: boolean = true;
}

export class AuthorDetailViewModel extends BaseVM<AuthorDetailState> {
  private static instance: AuthorDetailViewModel;

  static getInstance(): AuthorDetailViewModel {
    if (!AuthorDetailViewModel.instance) {
      AuthorDetailViewModel.instance = new AuthorDetailViewModel();
    }
    return AuthorDetailViewModel.instance;
  }

  private constructor() {
    super(new AuthorDetailState());
  }

  sendEvent(event: BaseVMEvent): void {
    switch (event.type) {
      case AuthorDetailEventType.LOAD_AUTHOR:
        this.loadAuthorNovels();
        break;
    }
  }

  setAuthor(authorId: string, authorName: string): void {
    this.state.authorId = authorId;
    this.state.authorName = authorName;
  }

  async loadAuthorNovels(): Promise<void> {
    const state = this.state;
    state.isLoading = true;
    try {
      const ctx = AppStorage.get<common.UIAbilityContext>('appContext');
      if (!ctx) return;
      await pixivCacheDB.init(ctx);
      const novels = await pixivCacheDB.getAllCachedNovels();
      const filtered = novels.filter(n => n.authorId === state.authorId && n.cacheStatus === 'cached');
      const groups = this.groupNovels(filtered);
      state.authorGroup = groups.length > 0 ? groups[0] : null;
    } catch (err) {
      console.error('获取作者缓存失败:', err);
    }
    state.isLoading = false;
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
