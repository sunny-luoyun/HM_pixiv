import { PixivService } from '../../services/PixivService';
import { UserSearchResult, FollowingUserRaw } from '../../models/PixivModels';
import { UserCard } from '../../components/UserCard';
import { BasicDataSource } from '../../common/utils/BasicDataSource';
import { appState } from '../../store/AppState';
import { PageContext } from '../../common/utils/PageContext';

const PAGE_LIMIT = 30;
const PRELOAD_THRESHOLD = 1500;

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

@Component
struct FollowingPage {
  private isActive: boolean = true;
  private userSource: BasicDataSource<UserSearchResult> = new BasicDataSource();
  @State isLoading: boolean = true;
  @State isLoadingMore: boolean = false;
  @State hasMore: boolean = true;
  @State error: string = '';
  @State currentOffset: number = 0;

  // 预加载
  private scrollContainerHeight: number = 0;
  private scrollContentHeight: number = 0;
  private lastPreloadY: number = -1;

  aboutToDisappear() {
    this.isActive = false;
  }

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
      if (!this.isActive) return;
      if (!res.error) {
        this.userSource.reset(res.body.users.map(toUserSearchResult));
        this.currentOffset += res.body.users.length;
        if (this.currentOffset >= res.body.total) {
          this.hasMore = false;
        }
      } else {
        this.error = '加载失败';
      }
    } catch (err) {
      if (!this.isActive) return;
      this.error = '网络错误，请重试';
    }
    this.isLoading = false;
  }

  async loadMoreUsers() {
    if (this.isLoadingMore || !this.hasMore) return;
    this.isLoadingMore = true;
    try {
      const res = await PixivService.getFollowingList(appState.userId, this.currentOffset, PAGE_LIMIT);
      if (!this.isActive) return;
      if (!res.error) {
        this.userSource.batchPush(...res.body.users.map(toUserSearchResult));
        this.currentOffset += res.body.users.length;
        if (this.currentOffset >= res.body.total) {
          this.hasMore = false;
        }
      }
    } catch (err) {
      if (!this.isActive) return;
      console.error('加载更多关注失败:', err);
    }
    this.isLoadingMore = false;
    if (this.scrollContentHeight > 0 && this.hasMore) {
      const remaining = this.scrollContentHeight - this.scrollContainerHeight - Math.max(this.lastPreloadY, 0);
      if (remaining < PRELOAD_THRESHOLD) {
        this.loadMoreUsers();
      }
    }
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.Friction })
      .slide(SlideEffect.Right)
    PageTransitionExit({ duration: 300, curve: Curve.Friction })
      .slide(SlideEffect.Right)
  }

  build() {
    NavDestination() {
      Column() {
        this.TopBar()

        if (this.isLoading) {
          LoadingProgress().width(40).height(40).margin({ top: 100 })
        } else if (this.error && this.userSource.totalCount() === 0) {
          Column() {
            Text(this.error).fontSize(14).fontColor($r('app.color.text_secondary'))
            Button('重试').margin({ top: 12 }).onClick(() => this.loadUsers())
          }
          .margin({ top: 80 })
          .alignItems(HorizontalAlign.Center)
        } else if (this.userSource.totalCount() === 0) {
          Text('暂无关注').fontSize(14).fontColor($r('app.color.text_secondary')).margin({ top: 100 })
        } else {
          Scroll() {
            Column() {
              Grid() {
                LazyForEach(this.userSource, (item: UserSearchResult, index: number) => {
                  GridItem() {
                    UserCard({ item: item, index: index })
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
              if (!this.isLoadingMore && !this.hasMore && this.userSource.totalCount() > 0) {
                Text('- 已显示全部关注 -')
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
                  .width('100%')
                  .textAlign(TextAlign.Center)
                  .margin({ top: 8, bottom: 24 })
              }
            }
            .width('100%')
            .padding({ bottom: 120 })
            .onAreaChange((_old: Area, area: Area) => {
              this.scrollContentHeight = area.height as number;
            })
          }
          .width('100%')
          .edgeEffect(EdgeEffect.Spring)
          .onReachEnd(() => {
            if (this.hasMore && !this.isLoadingMore) {
              this.loadMoreUsers();
            }
          })
          .onScroll((_xOffset: number, yOffset: number) => {
            if (this.scrollContentHeight > 0) {
              const remaining = this.scrollContentHeight - this.scrollContainerHeight - yOffset;
              if (yOffset > this.lastPreloadY && remaining < PRELOAD_THRESHOLD && this.hasMore && !this.isLoadingMore) {
                this.loadMoreUsers();
              }
            }
            this.lastPreloadY = yOffset;
          })
          .onAreaChange((_old: Area, area: Area) => {
            this.scrollContainerHeight = area.height as number;
          })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_background'))
    }
    .onBackPressed(() => {
      const pageCtx = AppStorage.get<PageContext>('rootPageContext');
      if (pageCtx) { pageCtx.popPage(); }
      return true;
    })
    .hideTitleBar(true)
  }

  @Builder
  TopBar() {
    Row() {
      Text('‹')
        .fontSize(28)
        .fontColor($r('app.color.tab_selected'))
        .onClick(() => {
          const ctx = AppStorage.get<PageContext>('rootPageContext');
          if (ctx) { ctx.popPage(); }
        })
      Text('我的关注')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .margin({ left: 12 })
      Blank()
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.glass_bg'))
  }
}

@Builder
export function FollowingBuilder(): void {
  FollowingPage()
}
