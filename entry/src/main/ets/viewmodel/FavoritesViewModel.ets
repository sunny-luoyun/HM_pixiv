import { BaseState } from './BaseState';
import { BaseVM, BaseVMEvent } from './BaseVM';
import { LoadingModel } from '../models/LoadingModel';
import { BasicDataSource } from '../common/utils/BasicDataSource';
import { IllustBookmark, NovelBookmark } from '../models/PixivModels';
import { PixivService } from '../services/PixivService';
import { appState } from '../store/AppState';

const PAGE_SIZE = 30;

export class FavoritesEventType {
  static readonly LOAD_ILLUSTS = 'LOAD_ILLUSTS';
  static readonly LOAD_MORE_ILLUSTS = 'LOAD_MORE_ILLUSTS';
  static readonly LOAD_NOVELS = 'LOAD_NOVELS';
  static readonly LOAD_MORE_NOVELS = 'LOAD_MORE_NOVELS';
}

@Observed
export class FavoritesState extends BaseState {
  isActive: boolean = true;
  currentTab: number = 0;
  illustSource: BasicDataSource<IllustBookmark> = new BasicDataSource();
  novelSource: BasicDataSource<NovelBookmark> = new BasicDataSource();
  illustLoad: LoadingModel = new LoadingModel();
  novelLoad: LoadingModel = new LoadingModel();
  isLoadingMoreIllust: boolean = false;
  isLoadingMoreNovel: boolean = false;
  hasMoreIllust: boolean = true;
  hasMoreNovel: boolean = true;
  illustOffset: number = 0;
  novelOffset: number = 0;
}

export class FavoritesViewModel extends BaseVM<FavoritesState> {
  private static instance: FavoritesViewModel;

  static getInstance(): FavoritesViewModel {
    if (!FavoritesViewModel.instance) {
      FavoritesViewModel.instance = new FavoritesViewModel();
    }
    return FavoritesViewModel.instance;
  }

  private constructor() {
    super(new FavoritesState());
  }

  sendEvent(event: BaseVMEvent): void {
    switch (event.type) {
      case FavoritesEventType.LOAD_ILLUSTS:
        this.loadIllusts();
        break;
      case FavoritesEventType.LOAD_MORE_ILLUSTS:
        this.loadMoreIllusts();
        break;
      case FavoritesEventType.LOAD_NOVELS:
        this.loadNovels();
        break;
      case FavoritesEventType.LOAD_MORE_NOVELS:
        this.loadMoreNovels();
        break;
    }
  }

  deactivate(): void {
    this.state.isActive = false;
  }

  async loadIllusts(): Promise<void> {
    const state = this.state;
    state.illustLoad.startLoading();
    state.illustOffset = 0;
    state.hasMoreIllust = true;
    try {
      const res = await PixivService.getIllustBookmarks(appState.userId, 0, PAGE_SIZE);
      if (!state.isActive) return;
      if (!res.error) {
        state.illustSource.reset(res.body.works);
        state.illustOffset = state.illustSource.totalCount();
        if (state.illustOffset >= res.body.total) {
          state.hasMoreIllust = false;
        }
        state.illustLoad.setSuccess();
      } else {
        state.illustLoad.setFailed('加载失败');
      }
    } catch (err) {
      if (!state.isActive) return;
      console.error('加载收藏插画失败:', err);
      state.illustLoad.setFailed('加载失败');
    }
  }

  async loadMoreIllusts(): Promise<void> {
    const state = this.state;
    if (state.isLoadingMoreIllust || !state.hasMoreIllust) return;
    state.isLoadingMoreIllust = true;
    try {
      const res = await PixivService.getIllustBookmarks(appState.userId, state.illustOffset, PAGE_SIZE);
      if (!state.isActive) return;
      if (!res.error) {
        state.illustSource.push(...res.body.works);
        state.illustOffset += res.body.works.length;
        if (state.illustOffset >= res.body.total) {
          state.hasMoreIllust = false;
        }
      }
    } catch (err) {
      if (!state.isActive) return;
      console.error('加载更多收藏插画失败:', err);
    }
    state.isLoadingMoreIllust = false;
  }

  async loadNovels(): Promise<void> {
    const state = this.state;
    state.novelLoad.startLoading();
    state.novelOffset = 0;
    state.hasMoreNovel = true;
    try {
      const res = await PixivService.getNovelBookmarks(appState.userId, 0, PAGE_SIZE);
      if (!state.isActive) return;
      if (!res.error) {
        state.novelSource.reset(res.body.works);
        state.novelOffset = state.novelSource.totalCount();
        if (state.novelOffset >= res.body.total) {
          state.hasMoreNovel = false;
        }
        state.novelLoad.setSuccess();
      } else {
        state.novelLoad.setFailed('加载失败');
      }
    } catch (err) {
      if (!state.isActive) return;
      console.error('加载收藏小说失败:', err);
      state.novelLoad.setFailed('加载失败');
    }
  }

  async loadMoreNovels(): Promise<void> {
    const state = this.state;
    if (state.isLoadingMoreNovel || !state.hasMoreNovel) return;
    state.isLoadingMoreNovel = true;
    try {
      const res = await PixivService.getNovelBookmarks(appState.userId, state.novelOffset, PAGE_SIZE);
      if (!state.isActive) return;
      if (!res.error) {
        state.novelSource.push(...res.body.works);
        state.novelOffset += res.body.works.length;
        if (state.novelOffset >= res.body.total) {
          state.hasMoreNovel = false;
        }
      }
    } catch (err) {
      if (!state.isActive) return;
      console.error('加载更多收藏小说失败:', err);
    }
    state.isLoadingMoreNovel = false;
  }
}
