import { BaseState } from './BaseState';
import { BaseVM, BaseVMEvent } from './BaseVM';
import { BasicDataSource } from '../common/utils/BasicDataSource';
import { UserSearchResult, FollowingUserRaw } from '../models/PixivModels';
import { PixivService } from '../services/PixivService';
import { appState } from '../store/AppState';

const PAGE_LIMIT = 30;

export class FollowingEventType {
  static readonly LOAD_USERS = 'LOAD_USERS';
  static readonly LOAD_MORE_USERS = 'LOAD_MORE_USERS';
}

@Observed
export class FollowingState extends BaseState {
  userSource: BasicDataSource<UserSearchResult> = new BasicDataSource();
  isLoading: boolean = true;
  isLoadingMore: boolean = false;
  hasMore: boolean = true;
  error: string = '';
  currentOffset: number = 0;
}

export class FollowingViewModel extends BaseVM<FollowingState> {
  private static instance: FollowingViewModel;

  static getInstance(): FollowingViewModel {
    if (!FollowingViewModel.instance) {
      FollowingViewModel.instance = new FollowingViewModel();
    }
    return FollowingViewModel.instance;
  }

  private constructor() {
    super(new FollowingState());
  }

  sendEvent(event: BaseVMEvent): void {
    switch (event.type) {
      case FollowingEventType.LOAD_USERS:
        this.loadUsers();
        break;
      case FollowingEventType.LOAD_MORE_USERS:
        this.loadMoreUsers();
        break;
    }
  }

  isLoggedIn(): boolean {
    return appState.isLoggedIn && !!appState.userId;
  }

  async loadUsers(): Promise<void> {
    const state = this.state;
    if (!this.isLoggedIn()) {
      state.isLoading = false;
      state.error = '请先登录';
      return;
    }
    state.isLoading = true;
    state.error = '';
    state.currentOffset = 0;
    state.hasMore = true;
    try {
      const res = await PixivService.getFollowingList(appState.userId, 0, PAGE_LIMIT);
      if (!res.error) {
        state.userSource.reset(res.body.users.map(this.toUserSearchResult));
        state.currentOffset += res.body.users.length;
        if (state.currentOffset >= res.body.total) {
          state.hasMore = false;
        }
      } else {
        state.error = '加载失败';
      }
    } catch (err) {
      state.error = '网络错误，请重试';
    }
    state.isLoading = false;
  }

  async loadMoreUsers(): Promise<void> {
    const state = this.state;
    if (state.isLoadingMore || !state.hasMore) return;
    state.isLoadingMore = true;
    try {
      const res = await PixivService.getFollowingList(appState.userId, state.currentOffset, PAGE_LIMIT);
      if (!res.error) {
        state.userSource.push(...res.body.users.map(this.toUserSearchResult));
        state.currentOffset += res.body.users.length;
        if (state.currentOffset >= res.body.total) {
          state.hasMore = false;
        }
      }
    } catch (err) {
      console.error('加载更多关注失败:', err);
    }
    state.isLoadingMore = false;
  }

  private toUserSearchResult(raw: FollowingUserRaw): UserSearchResult {
    return {
      userId: raw.userId,
      name: raw.userName,
      image: raw.profileImageUrl,
      imageBig: raw.profileImageUrl,
      comment: raw.userComment || '',
      premium: false,
      isFollowed: raw.followed,
      following: 0
    };
  }
}
