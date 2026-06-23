import { BaseState } from './BaseState';
import { BaseVM, BaseVMEvent } from './BaseVM';
import { LoadingModel } from '../models/LoadingModel';
import { BasicDataSource } from '../common/utils/BasicDataSource';
import { IllustBookmark, NovelBookmark, UserSearchResult } from '../models/PixivModels';
import { PixivService } from '../services/PixivService';
import { pixivCacheDB } from '../database/PixivCacheDB';
import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';

export class SearchEventType {
  static readonly SEARCH = 'SEARCH';
  static readonly LOAD_MORE_ILLUSTS = 'LOAD_MORE_ILLUSTS';
  static readonly LOAD_MORE_NOVELS = 'LOAD_MORE_NOVELS';
  static readonly LOAD_MORE_USERS = 'LOAD_MORE_USERS';
  static readonly TAB_CHANGE = 'TAB_CHANGE';
  static readonly LOAD_HISTORY = 'LOAD_HISTORY';
  static readonly ADD_HISTORY = 'ADD_HISTORY';
  static readonly REMOVE_HISTORY = 'REMOVE_HISTORY';
  static readonly CLEAR_HISTORY = 'CLEAR_HISTORY';
}

@Observed
export class SearchState extends BaseState {
  keyword: string = '';
  currentTab: number = 0;
  hasSearched: boolean = false;
  searchHistory: string[] = [];
  showHistory: boolean = false;
  illustSource: BasicDataSource<IllustBookmark> = new BasicDataSource();
  illustLoad: LoadingModel = new LoadingModel();
  illustPage: number = 1;
  illustPages: number = 0;
  isLoadingMoreIllust: boolean = false;
  novelSource: BasicDataSource<NovelBookmark> = new BasicDataSource();
  novelLoad: LoadingModel = new LoadingModel();
  novelPage: number = 1;
  novelPages: number = 0;
  isLoadingMoreNovel: boolean = false;
  userSource: BasicDataSource<UserSearchResult> = new BasicDataSource();
  userLoad: LoadingModel = new LoadingModel();
  userPage: number = 1;
  userPages: number = 0;
  isLoadingMoreUser: boolean = false;
}

export class SearchViewModel extends BaseVM<SearchState> {
  private static instance: SearchViewModel;

  static getInstance(): SearchViewModel {
    if (!SearchViewModel.instance) {
      SearchViewModel.instance = new SearchViewModel();
    }
    return SearchViewModel.instance;
  }

  private constructor() {
    super(new SearchState());
  }

  sendEvent(event: BaseVMEvent): void {
    switch (event.type) {
      case SearchEventType.SEARCH:
        this.onSearch();
        break;
      case SearchEventType.LOAD_MORE_ILLUSTS:
        this.loadMoreIllusts();
        break;
      case SearchEventType.LOAD_MORE_NOVELS:
        this.loadMoreNovels();
        break;
      case SearchEventType.LOAD_MORE_USERS:
        this.loadMoreUsers();
        break;
      case SearchEventType.TAB_CHANGE:
        this.handleTabChange((event.param as Record<string, number>)['index'] ?? 0);
        break;
      case SearchEventType.LOAD_HISTORY:
        this.loadSearchHistory();
        break;
      case SearchEventType.ADD_HISTORY:
        this.addToHistory((event.param as Record<string, string>)['keyword'] ?? '');
        break;
      case SearchEventType.REMOVE_HISTORY:
        this.removeFromHistory((event.param as Record<string, string>)['keyword'] ?? '');
        break;
      case SearchEventType.CLEAR_HISTORY:
        this.clearHistory();
        break;
    }
  }

  loadSearchHistory(): void {
    const ctx = AppStorage.get<common.UIAbilityContext>('appContext');
    if (!ctx) return;
    preferences.getPreferences(ctx, 'app_search_history')
      .then(pref => pref.get('searchHistory', '[]'))
      .then((stored: string | preferences.ValueType) => {
        try {
          this.state.searchHistory = JSON.parse(stored as string);
        } catch {
          this.state.searchHistory = [];
        }
      })
      .catch(() => {});
  }

  saveSearchHistory(): void {
    const ctx = AppStorage.get<common.UIAbilityContext>('appContext');
    if (!ctx) return;
    preferences.getPreferences(ctx, 'app_search_history')
      .then(pref => {
        pref.put('searchHistory', JSON.stringify(this.state.searchHistory));
        pref.flush();
      })
      .catch(() => {});
  }

  addToHistory(keyword: string): void {
    const trimmed = keyword.trim();
    if (!trimmed) return;
    const filtered = this.state.searchHistory.filter(h => h !== trimmed);
    this.state.searchHistory = [trimmed, ...filtered].slice(0, 10);
    this.saveSearchHistory();
  }

  removeFromHistory(keyword: string): void {
    this.state.searchHistory = this.state.searchHistory.filter(h => h !== keyword);
    if (this.state.searchHistory.length === 0) {
      this.state.showHistory = false;
    }
    this.saveSearchHistory();
  }

  clearHistory(): void {
    this.state.searchHistory = [];
    this.state.showHistory = false;
    this.saveSearchHistory();
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

  async searchIllusts(page: number, reset: boolean = false): Promise<void> {
    const state = this.state;
    if (!state.keyword.trim()) return;
    if (reset) {
      state.illustLoad.startLoading();
      state.illustSource.reset([]);
    }
    try {
      const res = await PixivService.searchIllusts(state.keyword.trim(), page, 's_tag', 'illust_and_ugoira');
      if (!res.error) {
        const raw = res.body?.illust?.data ?? [];
        const works: IllustBookmark[] = [];
        for (let i = 0; i < raw.length; i++) {
          const item = raw[i];
          if (item && typeof item.id === 'string') {
            works.push(item);
          }
        }
        if (reset) {
          state.illustSource.reset(works);
        } else {
          state.illustSource.push(...works);
        }
        const total = res.body?.illust?.total ?? 0;
        state.illustPage = page;
        state.illustPages = Math.ceil(total / 30) || 1;
        state.illustLoad.setSuccess();
      } else {
        if (reset) state.illustLoad.setFailed('搜索失败');
      }
    } catch (err) {
      console.error('搜索插画失败:', err);
      if (reset) state.illustLoad.setFailed('搜索失败');
    }
    state.isLoadingMoreIllust = false;
  }

  async searchNovels(page: number, reset: boolean = false): Promise<void> {
    const state = this.state;
    if (!state.keyword.trim()) return;
    if (reset) {
      state.novelLoad.startLoading();
      state.novelSource.reset([]);
    }
    try {
      const res = await PixivService.searchNovels(state.keyword.trim(), page, 's_tag');
      if (!res.error) {
        const raw = res.body?.novel?.data ?? [];
        const works: NovelBookmark[] = [];
        for (let i = 0; i < raw.length; i++) {
          const item = raw[i];
          if (item && typeof item.id === 'string') {
            works.push(item);
          }
        }
        const filtered = await this.filterBlockedNovels(works);
        if (reset) {
          state.novelSource.reset(filtered);
        } else {
          state.novelSource.push(...filtered);
        }
        const total = res.body?.novel?.total ?? 0;
        state.novelPage = page;
        state.novelPages = Math.ceil(total / 30) || 1;
        state.novelLoad.setSuccess();
      } else {
        if (reset) state.novelLoad.setFailed('搜索失败');
      }
    } catch (err) {
      console.error('搜索小说失败:', err);
      if (reset) state.novelLoad.setFailed('搜索失败');
    }
    state.isLoadingMoreNovel = false;
  }

  async searchUsers(page: number, reset: boolean = false): Promise<void> {
    const state = this.state;
    if (!state.keyword.trim()) return;
    if (reset) {
      state.userLoad.startLoading();
      state.userSource.reset([]);
    }
    try {
      const res = await PixivService.searchUsers(state.keyword.trim(), page);
      if (!res.error) {
        const raw = res.body?.users ?? [];
        const users: UserSearchResult[] = [];
        for (let i = 0; i < raw.length; i++) {
          const item = raw[i];
          if (item && typeof item.userId === 'string') {
            users.push(item);
          }
        }
        if (reset) {
          state.userSource.reset(users);
        } else {
          state.userSource.push(...users);
        }
        const total = res.body?.page?.total ?? 0;
        state.userPage = page;
        state.userPages = Math.ceil(total / 10) || 1;
        state.userLoad.setSuccess();
      } else {
        if (reset) state.userLoad.setFailed('搜索失败');
      }
    } catch (err) {
      console.error('搜索用户失败:', err);
      if (reset) state.userLoad.setFailed('搜索失败');
    }
    state.isLoadingMoreUser = false;
  }

  async onSearch(): Promise<void> {
    const state = this.state;
    if (!state.keyword.trim()) return;
    this.addToHistory(state.keyword);
    state.hasSearched = true;
    state.showHistory = false;
    if (state.currentTab === 0) {
      await this.searchIllusts(1, true);
    } else if (state.currentTab === 1) {
      await this.searchNovels(1, true);
    } else {
      await this.searchUsers(1, true);
    }
  }

  async loadMoreIllusts(): Promise<void> {
    const state = this.state;
    if (state.isLoadingMoreIllust || state.illustPage >= state.illustPages) return;
    state.isLoadingMoreIllust = true;
    await this.searchIllusts(state.illustPage + 1, false);
  }

  async loadMoreNovels(): Promise<void> {
    const state = this.state;
    if (state.isLoadingMoreNovel || state.novelPage >= state.novelPages) return;
    state.isLoadingMoreNovel = true;
    await this.searchNovels(state.novelPage + 1, false);
  }

  async loadMoreUsers(): Promise<void> {
    const state = this.state;
    if (state.isLoadingMoreUser || state.userPage >= state.userPages) return;
    state.isLoadingMoreUser = true;
    await this.searchUsers(state.userPage + 1, false);
  }

  handleTabChange(index: number): void {
    this.state.currentTab = index;
    if (!this.state.hasSearched) return;
    if (index === 0 && this.state.illustSource.totalCount() === 0 && !this.state.illustLoad.isLoading) {
      this.searchIllusts(1, true);
    } else if (index === 1 && this.state.novelSource.totalCount() === 0 && !this.state.novelLoad.isLoading) {
      this.searchNovels(1, true);
    } else if (index === 2 && this.state.userSource.totalCount() === 0 && !this.state.userLoad.isLoading) {
      this.searchUsers(1, true);
    }
  }
}
