import { BaseState } from './BaseState';
import { BaseVM, BaseVMEvent } from './BaseVM';
import { LoadingModel, PageLoadModel } from '../models/LoadingModel';
import { BasicDataSource } from '../common/utils/BasicDataSource';
import { IllustBookmark, NovelBookmark } from '../models/PixivModels';
import { PixivService } from '../services/PixivService';
import { pixivCacheDB } from '../database/PixivCacheDB';
import common from '@ohos.app.ability.common';

const PAGE_SIZE = 30;
const MAX_EMPTY_RETRIES = 3;

export class HomeEventType {
  static readonly LOAD_ILLUSTS = 'LOAD_ILLUSTS';
  static readonly LOAD_MORE_ILLUSTS = 'LOAD_MORE_ILLUSTS';
  static readonly LOAD_NOVELS = 'LOAD_NOVELS';
  static readonly LOAD_MORE_NOVELS = 'LOAD_MORE_NOVELS';
  static readonly TAB_CHANGE = 'TAB_CHANGE';
}

@Observed
export class HomeState extends BaseState {
  currentTab: number = 0;
  illustCount: number = 0;
  novelCount: number = 0;
  illustSource: BasicDataSource<IllustBookmark> = new BasicDataSource();
  novelSource: BasicDataSource<NovelBookmark> = new BasicDataSource();
  illustLoad: LoadingModel = new LoadingModel();
  novelLoad: LoadingModel = new LoadingModel();
  isRefreshingIllust: boolean = false;
  isRefreshingNovel: boolean = false;
  isLoadingMoreIllust: boolean = false;
  isLoadingMoreNovel: boolean = false;
  hasMoreIllust: boolean = true;
  hasMoreNovel: boolean = true;
  illustEmptyRetries: number = 0;
  novelEmptyRetries: number = 0;
  illustRetryCount: number = 0;
  illustRetryTimer: number | null = null;
}

export class HomeViewModel extends BaseVM<HomeState> {
  private static instance: HomeViewModel;

  static getInstance(): HomeViewModel {
    if (!HomeViewModel.instance) {
      HomeViewModel.instance = new HomeViewModel();
    }
    return HomeViewModel.instance;
  }

  private constructor() {
    super(new HomeState());
  }

  sendEvent(event: BaseVMEvent): void {
    switch (event.type) {
      case HomeEventType.LOAD_ILLUSTS:
        this.loadIllusts(true);
        break;
      case HomeEventType.LOAD_MORE_ILLUSTS:
        this.loadMoreIllusts();
        break;
      case HomeEventType.LOAD_NOVELS:
        this.loadNovels();
        break;
      case HomeEventType.LOAD_MORE_NOVELS:
        this.loadMoreNovels();
        break;
      case HomeEventType.TAB_CHANGE:
        this.handleTabChange((event.param as Record<string, number>)['index'] ?? 0);
        break;
    }
  }

  async loadIllusts(isRetryable: boolean = false): Promise<void> {
    const state = this.state;
    if (state.illustRetryTimer !== null) {
      clearTimeout(state.illustRetryTimer);
      state.illustRetryTimer = null;
    }
    state.isRefreshingIllust = true;
    if (state.illustSource.totalCount() === 0) {
      state.illustLoad.startLoading();
    }
    state.hasMoreIllust = true;
    state.illustEmptyRetries = 0;

    let failed = false;
    try {
      const res = await PixivService.getDiscoveryIllusts('all', PAGE_SIZE);
      if (!res.error) {
        state.illustSource.reset(res.body?.thumbnails?.illust ?? []);
        state.illustLoad.setSuccess();
      } else {
        failed = true;
      }
    } catch (err) {
      console.error('加载发现页插画失败:', err);
      failed = true;
    }

    if (!failed) {
      state.illustRetryCount = 0;
      state.isRefreshingIllust = false;
      return;
    }

    if (isRetryable && state.illustRetryCount < 3) {
      state.illustRetryCount++;
      state.illustRetryTimer = setTimeout(() => {
        state.illustRetryTimer = null;
        this.loadIllusts(true);
      }, 3500);
      return;
    }

    state.illustLoad.setFailed('加载失败');
    state.isRefreshingIllust = false;
    state.illustRetryCount = 0;
  }

  async loadMoreIllusts(): Promise<void> {
    const state = this.state;
    if (state.isLoadingMoreIllust || !state.hasMoreIllust) return;
    state.isLoadingMoreIllust = true;
    try {
      const res = await PixivService.getDiscoveryIllusts('all', PAGE_SIZE);
      if (!res.error) {
        const newWorks = res.body?.thumbnails?.illust ?? [];
        const existingIds = new Set(state.illustSource.getDataArray().map(w => w.id));
        const uniqueNew = newWorks.filter(w => !existingIds.has(w.id));
        if (uniqueNew.length === 0) {
          state.illustEmptyRetries++;
          if (state.illustEmptyRetries >= MAX_EMPTY_RETRIES) {
            state.hasMoreIllust = false;
          }
        } else {
          state.illustEmptyRetries = 0;
          state.illustSource.push(...uniqueNew);
        }
      }
    } catch (err) {
      console.error('加载更多插画失败:', err);
    }
    state.isLoadingMoreIllust = false;
  }

  async filterBlockedNovels(works: NovelBookmark[]): Promise<NovelBookmark[]> {
    try {
      const ctx = AppStorage.get<common.UIAbilityContext>('appContext');
      if (!ctx) return works;
      await pixivCacheDB.init(ctx);
      const blockedIds = await Promise.all([
        pixivCacheDB.getAllBlockedAuthorIds(),
        pixivCacheDB.getAllBlockedSeriesIds(),
        pixivCacheDB.getAllBlockedSeriesTitleSet()
      ]);
      const blockedAuthorIds = blockedIds[0];
      const blockedSeriesIds = blockedIds[1];
      const blockedSeriesTitleSet = blockedIds[2] as Set<string>;
      return works.filter(n => {
        if (blockedAuthorIds.has(n.userId)) return false;
        const sid = n.series?.id ?? n.seriesId;
        if (sid && blockedSeriesIds.has(String(sid))) return false;
        const seriesTitle = n.seriesTitle || n.series?.title || '';
        if (seriesTitle && blockedSeriesTitleSet.has(seriesTitle.toLowerCase())) return false;
        return true;
      });
    } catch (_) {
      return works;
    }
  }

  async loadNovels(): Promise<void> {
    const state = this.state;
    state.isRefreshingNovel = true;
    if (state.novelSource.totalCount() === 0) {
      state.novelLoad.startLoading();
    }
    state.hasMoreNovel = true;
    state.novelEmptyRetries = 0;
    try {
      const res = await PixivService.getDiscoveryNovels('all', PAGE_SIZE);
      if (!res.error) {
        const rawWorks = res.body?.thumbnails?.novel ?? [];
        state.novelSource.reset(await this.filterBlockedNovels(rawWorks));
        state.novelLoad.setSuccess();
      } else {
        state.novelLoad.setFailed('加载失败');
      }
    } catch (err) {
      console.error('加载发现页小说失败:', err);
      state.novelLoad.setFailed('加载失败');
    }
    state.isRefreshingNovel = false;
  }

  async loadMoreNovels(): Promise<void> {
    const state = this.state;
    if (state.isLoadingMoreNovel || !state.hasMoreNovel) return;
    state.isLoadingMoreNovel = true;
    try {
      const res = await PixivService.getDiscoveryNovels('all', PAGE_SIZE);
      if (!res.error) {
        const rawNew = res.body?.thumbnails?.novel ?? [];
        const filteredNew = await this.filterBlockedNovels(rawNew);
        const existingIds = new Set(state.novelSource.getDataArray().map(w => w.id));
        const uniqueNew = filteredNew.filter(w => !existingIds.has(w.id));
        if (uniqueNew.length === 0) {
          state.novelEmptyRetries++;
          if (state.novelEmptyRetries >= MAX_EMPTY_RETRIES) {
            state.hasMoreNovel = false;
          }
        } else {
          state.novelEmptyRetries = 0;
          state.novelSource.push(...uniqueNew);
        }
      }
    } catch (err) {
      console.error('加载更多小说失败:', err);
    }
    state.isLoadingMoreNovel = false;
  }

  handleTabChange(index: number): void {
    this.state.currentTab = index;
    if (index === 1 && this.state.novelSource.totalCount() === 0 &&
      !this.state.novelLoad.isLoading) {
      this.loadNovels();
    }
  }
}
