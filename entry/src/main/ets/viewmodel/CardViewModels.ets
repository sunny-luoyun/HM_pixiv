import { BaseState } from './BaseState';
import { BaseVM, BaseVMEvent } from './BaseVM';
import { LoadingModel } from '../models/LoadingModel';
import { IllustBookmark, NovelBookmark, UserSearchResult, AppIllust, AppNovel } from '../models/PixivModels';

// ========== 插画卡片 ==========

export class IllustCardEventType {
  static readonly LOAD_ILLUST_CARD = 'LOAD_ILLUST_CARD';
}

@Observed
export class IllustCardState extends BaseState {
  item: IllustBookmark | null = null;
  index: number = 0;
  isLoading: boolean = false;
  isBookmarked: boolean = false;
  localUrl: string = '';
  translatedTitle: string = '';
  hasTranslation: boolean = false;
}

export class IllustCardViewModel extends BaseVM<IllustCardState> {
  private static instance: IllustCardViewModel;

  static getInstance(): IllustCardViewModel {
    if (!IllustCardViewModel.instance) {
      IllustCardViewModel.instance = new IllustCardViewModel();
    }
    return IllustCardViewModel.instance;
  }

  private constructor() {
    super(new IllustCardState());
  }

  sendEvent(event: BaseVMEvent): void {
    switch (event.type) {
      case IllustCardEventType.LOAD_ILLUST_CARD:
        this.setup((event.param as Record<string, Object>)['item'] as IllustBookmark,
          (event.param as Record<string, number>)['index'] ?? 0);
        break;
    }
  }

  setup(item: IllustBookmark, index: number): void {
    const state = this.state;
    state.item = item;
    state.index = index;
    state.isBookmarked = !!item.bookmarkData;
    state.localUrl = item.url;
  }

  updateLocalUrl(url: string): void {
    this.state.localUrl = url;
  }
}

// ========== 小说卡片 ==========

export class NovelCardEventType {
  static readonly LOAD_NOVEL_CARD = 'LOAD_NOVEL_CARD';
}

@Observed
export class NovelCardState extends BaseState {
  item: NovelBookmark | null = null;
  index: number = 0;
  isLoading: boolean = false;
  localUrl: string = '';
  translatedTitle: string = '';
  hasTranslation: boolean = false;
  isCached: boolean = false;
}

export class NovelCardViewModel extends BaseVM<NovelCardState> {
  private static instance: NovelCardViewModel;

  static getInstance(): NovelCardViewModel {
    if (!NovelCardViewModel.instance) {
      NovelCardViewModel.instance = new NovelCardViewModel();
    }
    return NovelCardViewModel.instance;
  }

  private constructor() {
    super(new NovelCardState());
  }

  sendEvent(event: BaseVMEvent): void {
    switch (event.type) {
      case NovelCardEventType.LOAD_NOVEL_CARD:
        this.setup((event.param as Record<string, Object>)['item'] as NovelBookmark,
          (event.param as Record<string, number>)['index'] ?? 0);
        break;
    }
  }

  setup(item: NovelBookmark, index: number): void {
    const state = this.state;
    state.item = item;
    state.index = index;
    state.translatedTitle = item.titleTranslated || '';
    state.hasTranslation = !!item.hasTitleTranslation;
  }

  updateLocalUrl(url: string): void {
    this.state.localUrl = url;
  }
}

// ========== 用户卡片 ==========

export class UserCardEventType {
  static readonly LOAD_USER_CARD = 'LOAD_USER_CARD';
}

@Observed
export class UserCardState extends BaseState {
  item: UserSearchResult | null = null;
  index: number = 0;
  isLoading: boolean = false;
  avatarLocalUrl: string = '';
}

export class UserCardViewModel extends BaseVM<UserCardState> {
  private static instance: UserCardViewModel;

  static getInstance(): UserCardViewModel {
    if (!UserCardViewModel.instance) {
      UserCardViewModel.instance = new UserCardViewModel();
    }
    return UserCardViewModel.instance;
  }

  private constructor() {
    super(new UserCardState());
  }

  sendEvent(event: BaseVMEvent): void {
    switch (event.type) {
      case UserCardEventType.LOAD_USER_CARD:
        this.setup((event.param as Record<string, Object>)['item'] as UserSearchResult,
          (event.param as Record<string, number>)['index'] ?? 0);
        break;
    }
  }

  setup(item: UserSearchResult, index: number): void {
    const state = this.state;
    state.item = item;
    state.index = index;
  }

  updateAvatarLocalUrl(url: string): void {
    this.state.avatarLocalUrl = url;
  }
}
