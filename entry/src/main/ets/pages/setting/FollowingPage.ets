import router from '@ohos.router';
import { PixivService, UserSearchResult, FollowingUserRaw } from '../../services/PixivService';
import { UserCard } from '../../components/UserCard';
import { appState } from '../../store/AppState';

const PAGE_LIMIT = 30;

function toUserSearchResult(raw: FollowingUserRaw): UserSearchResult {
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

@Entry
@Component
struct FollowingPage {
  @State users: UserSearchResult[] = [];
  @State isLoading: boolean = true;
  @State isLoadingMore: boolean = false;
  @State hasMore: boolean = true;
  @State error: string = '';
  @State currentOffset: number = 0;

  async aboutToAppear() {
    if (!appState.isLoggedIn || !appState.userId) {
      this.isLoading = false;
      this.error = '请先登录';
      return;
    }
    await this.loadUsers();
  }

  async loadUsers() {
    this.isLoading = true;
    this.error = '';
    this.currentOffset = 0;
    this.hasMore = true;
    try {
      const res = await PixivService.getFollowingList(appState.userId, 0, PAGE_LIMIT);
      if (!res.error) {
        this.users = res.body.users.map(toUserSearchResult);
        this.currentOffset += res.body.users.length;
        if (this.currentOffset >= res.body.total) {
          this.hasMore = false;
        }
      } else {
        this.error = '加载失败';
      }
    } catch (err) {
      this.error = '网络错误，请重试';
    }
    this.isLoading = false;
  }

  async loadMoreUsers() {
    if (this.isLoadingMore || !this.hasMore) return;
    this.isLoadingMore = true;
    try {
      const res = await PixivService.getFollowingList(appState.userId, this.currentOffset, PAGE_LIMIT);
      if (!res.error) {
        this.users = [...this.users, ...res.body.users.map(toUserSearchResult)];
        this.currentOffset += res.body.users.length;
        if (this.currentOffset >= res.body.total) {
          this.hasMore = false;
        }
      }
    } catch (err) {
      console.error('加载更多关注失败:', err);
    }
    this.isLoadingMore = false;
  }

  build() {
    Column() {
      this.TopBar()

      if (this.isLoading) {
        LoadingProgress().width(40).height(40).margin({ top: 100 })
      } else if (this.error && this.users.length === 0) {
        Column() {
          Text(this.error).fontSize(14).fontColor($r('app.color.text_secondary'))
          Button('重试').margin({ top: 12 }).onClick(() => this.loadUsers())
        }
        .margin({ top: 80 })
        .alignItems(HorizontalAlign.Center)
      } else if (this.users.length === 0) {
        Text('暂无关注').fontSize(14).fontColor($r('app.color.text_secondary')).margin({ top: 100 })
      } else {
        Scroll() {
          Column() {
            Grid() {
              ForEach(this.users, (item: UserSearchResult) => {
                GridItem() {
                  UserCard({ item: item })
                }
              }, (item: UserSearchResult) => item.userId)
            }
            .columnsTemplate('1fr')
            .columnsGap(8)
            .rowsGap(8)
            .padding(12)
            .width('100%')

            if (this.isLoadingMore) {
              LoadingProgress().width(30).height(30).margin({ top: 8, bottom: 16 })
            }
            if (!this.isLoadingMore && !this.hasMore && this.users.length > 0) {
              Text('- 已显示全部关注 -')
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
                .textAlign(TextAlign.Center)
                .margin({ top: 8, bottom: 24 })
            }
          }
          .width('100%')
        }
        .width('100%')
        .onReachEnd(() => {
          if (this.hasMore && !this.isLoadingMore) {
            this.loadMoreUsers();
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  TopBar() {
    Row() {
      Text('‹')
        .fontSize(28)
        .fontColor($r('app.color.tab_selected'))
        .onClick(() => {
          router.back();
        })
      Text('我的关注')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .margin({ left: 12 })
      Blank()
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.loading_card'))
  }
}
