import { BaseState } from './BaseState';
import { BaseVM, BaseVMEvent } from './BaseVM';
import { LoadingModel } from '../models/LoadingModel';
import { BasicDataSource } from '../common/utils/BasicDataSource';
import { IllustBookmark, NovelBookmark } from '../models/PixivModels';
import { PixivService } from '../services/PixivService';
import { pixivCacheDB } from '../database/PixivCacheDB';
import common from '@ohos.app.ability.common';

export class LatestEventType {
  static readonly LOAD_ILLUSTS = 'LOAD_ILLUSTS';
  static readonly LOAD_MORE_ILLUSTS = 'LOAD_MORE_ILLUSTS';
  static readonly LOAD_NOVELS = 'LOAD_NOVELS';
  static readonly LOAD_MORE_NOVELS = 'LOAD_MORE_NOVELS';
}

@Observed
export class LatestState extends BaseState {
  currentTab: number = 0;
  illustSource: BasicDataSource<IllustBookmark> = new BasicDataSource();
  novelSource: BasicDataSource<NovelBookmark> = new BasicDataSource();
  illustLoad: LoadingModel = new LoadingModel();
  novelLoad: LoadingModel = new LoadingModel();
  isRefreshingIllust: boolean = false;
  isRefreshingNovel: boolean = false;
  isLoadingMoreIllust: boolean = false;
  isLoadingMoreNovel: boolean = false;
  illustPage: number = 1;
  illustPages: number = 0;
  novelPage: number = 1;
  novelPages: number = 0;
}

export class LatestViewModel extends BaseVM<LatestState> {
  private static instance: LatestViewModel;

  static getInstance(): LatestViewModel {
    if (!LatestViewModel.instance) {
      LatestViewModel.instance = new LatestViewModel();
    }
    return LatestViewModel.instance;
  }

  private constructor() {
    super(new LatestState());
  }

  sendEvent(event: BaseVMEvent): void {
    switch (event.type) {
      case LatestEventType.LOAD_ILLUSTS:
        this.loadIllusts();
        break;
      case LatestEventType.LOAD_MORE_ILLUSTS:
        this.loadMoreIllusts();
        break;
      case LatestEventType.LOAD_NOVELS:
        this.loadNovels();
        break;
      case LatestEventType.LOAD_MORE_NOVELS:
        this.loadMoreNovels();
        break;
    }
  }

  async loadIllusts(): Promise<void> {
    const state = this.state;
    state.isRefreshingIllust = true;
    if (state.illustSource.totalCount() === 0) {
      state.illustLoad.startLoading();
    }
    state.illustPage = 1;
    state.illustPages = 0;
    try {
      const res = await PixivService.getFollowLatestIllusts(1, 'all');
      if (!res.error) {
        state.illustSource.reset(res.body?.thumbnails?.illust ?? []);
        state.illustPage = res.body?.page ?? 1;
        state.illustPages = res.body?.pages ?? 1;
        state.illustLoad.setSuccess();
      } else {
        state.illustLoad.setFailed('加载失败');
      }
    } catch (err) {
      console.error('加载关注最新插画失败:', err);
      state.illustLoad.setFailed('加载失败');
    }
    state.isRefreshingIllust = false;
  }

  async loadMoreIllusts(): Promise<void> {
    const state = this.state;
    if (state.isLoadingMoreIllust || state.illustPage >= state.illustPages) return;
    state.isLoadingMoreIllust = true;
    const nextPage = state.illustPage + 1;
    try {
      const res = await PixivService.getFollowLatestIllusts(nextPage, 'all');
      if (!res.error) {
        const newWorks = res.body?.thumbnails?.illust ?? [];
        state.illustSource.push(...newWorks);
        state.illustPage = res.body?.page ?? nextPage;
        state.illustPages = res.body?.pages ?? state.illustPages;
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
    state.novelPage = 1;
    state.novelPages = 0;
    try {
      const res = await PixivService.getFollowLatestNovels(1, 'all');
      if (!res.error) {
        const rawWorks = res.body?.thumbnails?.novel ?? [];
        state.novelSource.reset(await this.filterBlockedNovels(rawWorks));
        state.novelPage = res.body?.page ?? 1;
        state.novelPages = res.body?.pages ?? 1;
        state.novelLoad.setSuccess();
      } else {
        state.novelLoad.setFailed('加载失败');
      }
    } catch (err) {
      console.error('加载关注最新小说失败:', err);
      state.novelLoad.setFailed('加载失败');
    }
    state.isRefreshingNovel = false;
  }

  async loadMoreNovels(): Promise<void> {
    const state = this.state;
    if (state.isLoadingMoreNovel || state.novelPage >= state.novelPages) return;
    state.isLoadingMoreNovel = true;
    const nextPage = state.novelPage + 1;
    try {
      const res = await PixivService.getFollowLatestNovels(nextPage, 'all');
      if (!res.error) {
        const rawNew = res.body?.thumbnails?.novel ?? [];
        const filteredNew = await this.filterBlockedNovels(rawNew);
        state.novelSource.push(...filteredNew);
        state.novelPage = res.body?.page ?? nextPage;
        state.novelPages = res.body?.pages ?? state.novelPages;
      }
    } catch (err) {
      console.error('加载更多小说失败:', err);
    }
    state.isLoadingMoreNovel = false;
  }
}
