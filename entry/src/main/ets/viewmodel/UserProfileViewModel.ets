import { BaseState } from './BaseState';
import { BaseVM, BaseVMEvent } from './BaseVM';
import { LoadingModel } from '../models/LoadingModel';
import { BasicDataSource } from '../common/utils/BasicDataSource';
import { IllustBookmark, NovelBookmark, ProfileIllust, ProfileNovel } from '../models/PixivModels';
import { PixivService } from '../services/PixivService';
import { AppApiService } from '../services/AppApiService';

const PAGE_SIZE = 30;

export class UserProfileEventType {
  static readonly LOAD_PROFILE = 'LOAD_PROFILE';
  static readonly LOAD_ILLUSTS = 'LOAD_ILLUSTS';
  static readonly LOAD_MORE_ILLUSTS = 'LOAD_MORE_ILLUSTS';
  static readonly LOAD_NOVELS = 'LOAD_NOVELS';
  static readonly LOAD_MORE_NOVELS = 'LOAD_MORE_NOVELS';
  static readonly LOAD_BOOKMARK_ILLUSTS = 'LOAD_BOOKMARK_ILLUSTS';
  static readonly LOAD_MORE_BOOKMARK_ILLUSTS = 'LOAD_MORE_BOOKMARK_ILLUSTS';
  static readonly LOAD_BOOKMARK_NOVELS = 'LOAD_BOOKMARK_NOVELS';
  static readonly LOAD_MORE_BOOKMARK_NOVELS = 'LOAD_MORE_BOOKMARK_NOVELS';
  static readonly TAB_CHANGE = 'TAB_CHANGE';
}

@Observed
export class UserProfileState extends BaseState {
  userId: string = '';
  userName: string = '';
  userAvatarUrl: string = '';
  userComment: string = '';
  isLoadingProfile: boolean = true;
  profileError: string = '';
  currentTab: number = 0;
  isHeaderVisible: boolean = true;
  swipeProgress: number = 0;

  illustSource: BasicDataSource<IllustBookmark> = new BasicDataSource();
  illustOffset: number = 0;
  hasMoreIllust: boolean = true;
  isLoadingIllust: boolean = true;
  isLoadingMoreIllust: boolean = false;
  illustError: string = '';
  allIllustIds: string[] = [];
  illustPage: number = 1;

  novelSource: BasicDataSource<NovelBookmark> = new BasicDataSource();
  novelOffset: number = 0;
  hasMoreNovel: boolean = true;
  isLoadingNovel: boolean = false;
  isLoadingMoreNovel: boolean = false;
  novelError: string = '';
  allNovelIds: string[] = [];
  novelPage: number = 1;

  bookmarkIllustSource: BasicDataSource<IllustBookmark> = new BasicDataSource();
  bookmarkIllustOffset: number = 0;
  hasMoreBookmarkIllust: boolean = true;
  isLoadingBookmarkIllust: boolean = false;
  isLoadingMoreBookmarkIllust: boolean = false;
  bookmarkIllustError: string = '';

  bookmarkNovelSource: BasicDataSource<NovelBookmark> = new BasicDataSource();
  bookmarkNovelOffset: number = 0;
  hasMoreBookmarkNovel: boolean = true;
  isLoadingBookmarkNovel: boolean = false;
  isLoadingMoreBookmarkNovel: boolean = false;
  bookmarkNovelError: string = '';
}

export class UserProfileViewModel extends BaseVM<UserProfileState> {
  private static instance: UserProfileViewModel;

  static getInstance(): UserProfileViewModel {
    if (!UserProfileViewModel.instance) {
      UserProfileViewModel.instance = new UserProfileViewModel();
    }
    return UserProfileViewModel.instance;
  }

  private constructor() {
    super(new UserProfileState());
  }

  sendEvent(event: BaseVMEvent): void {
    switch (event.type) {
      case UserProfileEventType.LOAD_PROFILE:
        this.loadProfile();
        break;
      case UserProfileEventType.LOAD_ILLUSTS:
        this.loadIllusts();
        break;
      case UserProfileEventType.LOAD_MORE_ILLUSTS:
        this.loadMoreIllusts();
        break;
      case UserProfileEventType.LOAD_NOVELS:
        this.loadNovels();
        break;
      case UserProfileEventType.LOAD_MORE_NOVELS:
        this.loadMoreNovels();
        break;
      case UserProfileEventType.LOAD_BOOKMARK_ILLUSTS:
        this.loadBookmarkIllusts();
        break;
      case UserProfileEventType.LOAD_MORE_BOOKMARK_ILLUSTS:
        this.loadMoreBookmarkIllusts();
        break;
      case UserProfileEventType.LOAD_BOOKMARK_NOVELS:
        this.loadBookmarkNovels();
        break;
      case UserProfileEventType.LOAD_MORE_BOOKMARK_NOVELS:
        this.loadMoreBookmarkNovels();
        break;
      case UserProfileEventType.TAB_CHANGE:
        this.handleTabChange((event.param as Record<string, number>)['index'] ?? 0);
        break;
    }
  }

  setUserId(userId: string, userName?: string): void {
    this.state.userId = userId;
    if (userName) this.state.userName = userName;
  }

  async loadProfile(): Promise<void> {
    const state = this.state;
    state.isLoadingProfile = true;
    state.profileError = '';
    let avatarUrl = '';
    try {
      const res = await AppApiService.getUserDetail(Number(state.userId)) as Record<string, Object>;
      const user = res['user'] as Record<string, Object>;
      const profile = res['profile'] as Record<string, Object>;
      if (user) {
        state.userName = String(user['name'] || '');
        const urls = user['profile_image_urls'] as Record<string, string> || {};
        avatarUrl = urls['medium'] || '';
        state.userComment = String(user['comment'] || '');
      }
    } catch (err) {
      console.error('加载作者资料失败:', err);
      try {
        const userInfo = await PixivService.getUserProfile(state.userId);
        if (userInfo && !userInfo.error && userInfo.body) {
          state.userName = userInfo.body.name || state.userName;
          if (userInfo.body.imageBig) avatarUrl = userInfo.body.imageBig;
          else if (userInfo.body.image) avatarUrl = userInfo.body.image;
        }
      } catch (_) {}
    }
    if (avatarUrl) {
      state.userAvatarUrl = await PixivService.cacheImage(avatarUrl, `user_${state.userId}.jpg`);
    }
    state.isLoadingProfile = false;
  }

  async loadIllusts(): Promise<void> {
    const state = this.state;
    state.isLoadingIllust = true;
    state.illustError = '';
    state.illustOffset = 0;
    state.hasMoreIllust = true;
    state.illustPage = 1;
    state.allIllustIds = [];
    try {
      const allRes = await PixivService.getUserProfileAll(state.userId);
      if (allRes.error) {
        state.illustError = '加载失败';
        state.isLoadingIllust = false;
        return;
      }
      const allIds: string[] = [];
      const illustMap = allRes.body.illusts || {};
      const mangaMap = allRes.body.manga || {};
      Object.keys(illustMap).forEach(k => allIds.push(k));
      Object.keys(mangaMap).forEach(k => allIds.push(k));
      if (allIds.length === 0) {
        state.hasMoreIllust = false;
        state.isLoadingIllust = false;
        return;
      }
      allIds.sort((a, b) => Number(b) - Number(a));
      state.allIllustIds = allIds;
      const pageIds = allIds.slice(0, PAGE_SIZE);
      const res = await PixivService.getUserProfileIllusts(state.userId, pageIds);
      if (!res.error) {
        const workMap = res.body.works || {};
        const works: IllustBookmark[] = [];
        for (const id of pageIds) {
          const work = workMap[id];
          if (work) works.push(this.mapProfileIllustToBookmark(work));
        }
        state.illustSource.reset(works);
        state.illustOffset = works.length;
        state.hasMoreIllust = allIds.length > PAGE_SIZE;
      } else {
        state.illustError = '加载失败';
      }
    } catch (err) {
      console.error('加载作者插画失败:', err);
      state.illustError = '加载失败';
    }
    state.isLoadingIllust = false;
  }

  async loadMoreIllusts(): Promise<void> {
    const state = this.state;
    if (state.isLoadingMoreIllust || !state.hasMoreIllust) return;
    state.isLoadingMoreIllust = true;
    try {
      const start = state.illustPage * PAGE_SIZE;
      const pageIds = state.allIllustIds.slice(start, start + PAGE_SIZE);
      if (pageIds.length === 0) {
        state.hasMoreIllust = false;
        state.isLoadingMoreIllust = false;
        return;
      }
      const res = await PixivService.getUserProfileIllusts(state.userId, pageIds);
      if (!res.error) {
        const workMap = res.body.works || {};
        const works: IllustBookmark[] = [];
        for (const id of pageIds) {
          const work = workMap[id];
          if (work) works.push(this.mapProfileIllustToBookmark(work));
        }
        state.illustSource.push(...works);
        state.illustOffset += works.length;
        state.illustPage++;
        state.hasMoreIllust = start + PAGE_SIZE < state.allIllustIds.length;
      }
    } catch (err) {
      console.error('加载更多作者插画失败:', err);
    }
    state.isLoadingMoreIllust = false;
  }

  async loadNovels(): Promise<void> {
    const state = this.state;
    state.isLoadingNovel = true;
    state.novelError = '';
    state.novelOffset = 0;
    state.hasMoreNovel = true;
    state.novelPage = 1;
    state.allNovelIds = [];
    try {
      const allRes = await PixivService.getUserProfileAll(state.userId);
      if (allRes.error) {
        state.novelError = '加载失败';
        state.isLoadingNovel = false;
        return;
      }
      const novelMap = allRes.body.novels || {};
      const allIds = Object.keys(novelMap);
      if (allIds.length === 0) {
        state.hasMoreNovel = false;
        state.isLoadingNovel = false;
        return;
      }
      allIds.sort((a, b) => Number(b) - Number(a));
      state.allNovelIds = allIds;
      const pageIds = allIds.slice(0, PAGE_SIZE);
      const res = await PixivService.getUserProfileNovels(state.userId, pageIds);
      if (!res.error) {
        const workMap = this.extractNovelWorks(res.body as Record<string, Object>);
        const works: NovelBookmark[] = [];
        for (const id of pageIds) {
          const work = workMap[id];
          if (work) works.push(this.mapProfileNovelToBookmark(work));
        }
        state.novelSource.reset(works);
        state.novelOffset = works.length;
        state.hasMoreNovel = allIds.length > PAGE_SIZE;
      } else {
        state.novelError = '加载失败';
      }
    } catch (err) {
      console.error('加载作者小说失败:', err);
      state.novelError = '加载失败';
    }
    state.isLoadingNovel = false;
  }

  async loadMoreNovels(): Promise<void> {
    const state = this.state;
    if (state.isLoadingMoreNovel || !state.hasMoreNovel) return;
    state.isLoadingMoreNovel = true;
    try {
      const start = state.novelPage * PAGE_SIZE;
      const pageIds = state.allNovelIds.slice(start, start + PAGE_SIZE);
      if (pageIds.length === 0) {
        state.hasMoreNovel = false;
        state.isLoadingMoreNovel = false;
        return;
      }
      const res = await PixivService.getUserProfileNovels(state.userId, pageIds);
      if (!res.error) {
        const workMap = this.extractNovelWorks(res.body as Record<string, Object>);
        const works: NovelBookmark[] = [];
        for (const id of pageIds) {
          const work = workMap[id];
          if (work) works.push(this.mapProfileNovelToBookmark(work));
        }
        state.novelSource.push(...works);
        state.novelOffset += works.length;
        state.novelPage++;
        state.hasMoreNovel = start + PAGE_SIZE < state.allNovelIds.length;
      }
    } catch (err) {
      console.error('加载更多作者小说失败:', err);
    }
    state.isLoadingMoreNovel = false;
  }

  async loadBookmarkIllusts(): Promise<void> {
    const state = this.state;
    state.isLoadingBookmarkIllust = true;
    state.bookmarkIllustError = '';
    state.bookmarkIllustOffset = 0;
    state.hasMoreBookmarkIllust = true;
    try {
      const res = await PixivService.getIllustBookmarks(state.userId, 0, PAGE_SIZE, '', 'show');
      if (!res.error) {
        state.bookmarkIllustSource.reset(res.body.works);
        state.bookmarkIllustOffset = state.bookmarkIllustSource.totalCount();
        if (state.bookmarkIllustOffset >= res.body.total) {
          state.hasMoreBookmarkIllust = false;
        }
      } else {
        state.bookmarkIllustError = '加载失败';
      }
    } catch (err) {
      console.error('加载作者收藏插画失败:', err);
      state.bookmarkIllustError = '加载失败';
    }
    state.isLoadingBookmarkIllust = false;
  }

  async loadMoreBookmarkIllusts(): Promise<void> {
    const state = this.state;
    if (state.isLoadingMoreBookmarkIllust || !state.hasMoreBookmarkIllust) return;
    state.isLoadingMoreBookmarkIllust = true;
    try {
      const res = await PixivService.getIllustBookmarks(state.userId, state.bookmarkIllustOffset, PAGE_SIZE, '', 'show');
      if (!res.error) {
        state.bookmarkIllustSource.push(...res.body.works);
        state.bookmarkIllustOffset += res.body.works.length;
        if (state.bookmarkIllustOffset >= res.body.total) {
          state.hasMoreBookmarkIllust = false;
        }
      }
    } catch (err) {
      console.error('加载更多作者收藏插画失败:', err);
    }
    state.isLoadingMoreBookmarkIllust = false;
  }

  async loadBookmarkNovels(): Promise<void> {
    const state = this.state;
    state.isLoadingBookmarkNovel = true;
    state.bookmarkNovelError = '';
    state.bookmarkNovelOffset = 0;
    state.hasMoreBookmarkNovel = true;
    try {
      const res = await PixivService.getNovelBookmarks(state.userId, 0, PAGE_SIZE, '', 'show');
      if (!res.error) {
        state.bookmarkNovelSource.reset(res.body.works);
        state.bookmarkNovelOffset = state.bookmarkNovelSource.totalCount();
        if (state.bookmarkNovelOffset >= res.body.total) {
          state.hasMoreBookmarkNovel = false;
        }
      } else {
        state.bookmarkNovelError = '加载失败';
      }
    } catch (err) {
      console.error('加载作者收藏小说失败:', err);
      state.bookmarkNovelError = '加载失败';
    }
    state.isLoadingBookmarkNovel = false;
  }

  async loadMoreBookmarkNovels(): Promise<void> {
    const state = this.state;
    if (state.isLoadingMoreBookmarkNovel || !state.hasMoreBookmarkNovel) return;
    state.isLoadingMoreBookmarkNovel = true;
    try {
      const res = await PixivService.getNovelBookmarks(state.userId, state.bookmarkNovelOffset, PAGE_SIZE, '', 'show');
      if (!res.error) {
        state.bookmarkNovelSource.push(...res.body.works);
        state.bookmarkNovelOffset += res.body.works.length;
        if (state.bookmarkNovelOffset >= res.body.total) {
          state.hasMoreBookmarkNovel = false;
        }
      }
    } catch (err) {
      console.error('加载更多作者收藏小说失败:', err);
    }
    state.isLoadingMoreBookmarkNovel = false;
  }

  handleTabChange(index: number): void {
    this.state.currentTab = index;
    if (index === 0 && this.state.illustSource.totalCount() === 0 && !this.state.isLoadingIllust) {
      this.loadIllusts();
    } else if (index === 1 && this.state.novelSource.totalCount() === 0 && !this.state.isLoadingNovel) {
      this.loadNovels();
    } else if (index === 2 && this.state.bookmarkIllustSource.totalCount() === 0 && !this.state.isLoadingBookmarkIllust) {
      this.loadBookmarkIllusts();
    } else if (index === 3 && this.state.bookmarkNovelSource.totalCount() === 0 && !this.state.isLoadingBookmarkNovel) {
      this.loadBookmarkNovels();
    }
  }

  private mapProfileIllustToBookmark(item: ProfileIllust): IllustBookmark {
    return {
      id: item.id,
      title: item.title,
      illustType: item.illustType,
      url: item.url,
      tags: item.tags,
      userId: item.userId,
      userName: item.userName || this.state.userName,
      width: item.width,
      height: item.height,
      pageCount: item.pageCount,
      bookmarkData: item.bookmarkData as IllustBookmark['bookmarkData'],
      profileImageUrl: item.profileImageUrl || '',
      createDate: item.createDate || '',
    };
  }

  private extractNovelWorks(body: Record<string, Object>): Record<string, ProfileNovel> {
    if (body['works'] && typeof body['works'] === 'object') {
      const works = body['works'] as Record<string, ProfileNovel>;
      if (Object.keys(works).length > 0) return works;
    }
    const direct: Record<string, ProfileNovel> = {};
    const keys = Object.keys(body);
    for (const key of keys) {
      const val = body[key];
      if (val && typeof val === 'object' && (val as Record<string, Object>)['id']) {
        direct[key] = val as ProfileNovel;
      }
    }
    return direct;
  }

  private mapProfileNovelToBookmark(item: ProfileNovel): NovelBookmark {
    return {
      id: item.id,
      title: item.title,
      tags: item.tags || [],
      userId: item.userId,
      userName: item.userName || this.state.userName,
      bookmarkData: null,
      profileImageUrl: item.profileImageUrl || '',
      createDate: item.createDate || '',
      updateDate: item.updateDate || '',
      textCount: item.textCount || 0,
      wordCount: item.wordCount || 0,
      characterCount: 0,
      readingTime: item.readingTime || 0,
      useWordCount: true,
      url: item.url,
      description: item.description || '',
      pageCount: item.pageCount,
      width: 0,
      height: 0,
      restrict: 0,
      xRestrict: 0,
      sl: 6,
      isBookmarkable: true,
      isUnlisted: false,
      isMasked: false,
      bookmarkCount: item.bookmarkCount || 0,
      commentCount: 0,
      markerCount: 0,
      seriesId: item.seriesId,
      seriesTitle: item.seriesTitle,
      seriesContentOrder: item.seriesContentOrder,
      seriesOrder: item.seriesOrder,
      series: item.series,
      originalWork: false,
      aiType: 0,
    };
  }
}
