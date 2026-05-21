import { PixivService, IllustBookmark, NovelBookmark } from '../../services/PixivService';
import { NovelCard } from '../../components/NovelCard';
import { IllustCard } from '../../components/IllustCard';
import { PullToRefresh } from '../../components/PullToRefresh';
import { SegmentedTabBar } from '../../components/SegmentedTabBar';

@Component
export struct LatestPage {
  @Consume('isLoggedIn') @Watch('onLoginStateChange') isLoggedIn: boolean;
  @State currentTab: number = 0;
  @State illustWorks: IllustBookmark[] = [];
  @State novelWorks: NovelBookmark[] = [];
  @State isLoadingIllust: boolean = true;
  @State isLoadingNovel: boolean = false;
  @State isRefreshingIllust: boolean = false;
  @State isRefreshingNovel: boolean = false;
  @State illustError: string = '';
  @State novelError: string = '';

  // 插画分页
  @State illustPage: number = 1;
  @State illustPages: number = 0;
  @State isLoadingMoreIllust: boolean = false;

  // 小说分页
  @State novelPage: number = 1;
  @State novelPages: number = 0;
  @State isLoadingMoreNovel: boolean = false;

  async aboutToAppear() {
    if (!this.isLoggedIn) {
      this.isLoadingIllust = false;
      return;
    }
    await this.loadIllusts();
  }

  onLoginStateChange() {
    if (this.isLoggedIn && this.illustWorks.length === 0 && !this.isLoadingIllust) {
      this.loadIllusts();
    }
  }

  async loadIllusts() {
    this.isRefreshingIllust = true;
    this.isLoadingIllust = true;
    this.illustError = '';
    this.illustPage = 1;
    this.illustPages = 0;
    try {
      const res = await PixivService.getFollowLatestIllusts(1, 'all');
      if (!res.error) {
        this.illustWorks = res.body?.thumbnails?.illust ?? [];
        this.illustPage = res.body?.page ?? 1;
        this.illustPages = res.body?.pages ?? 1;
      } else {
        this.illustError = '加载失败';
      }
    } catch (err) {
      console.error('加载关注最新插画失败:', err);
      this.illustError = '加载失败';
    }
    this.isLoadingIllust = false;
    this.isRefreshingIllust = false;
  }

  async loadMoreIllusts() {
    if (this.isLoadingMoreIllust || this.illustPage >= this.illustPages) return;
    this.isLoadingMoreIllust = true;
    const nextPage = this.illustPage + 1;
    try {
      const res = await PixivService.getFollowLatestIllusts(nextPage, 'all');
      if (!res.error) {
        const newWorks = res.body?.thumbnails?.illust ?? [];
        this.illustWorks = [...this.illustWorks, ...newWorks];
        this.illustPage = res.body?.page ?? nextPage;
        this.illustPages = res.body?.pages ?? this.illustPages;
      }
    } catch (err) {
      console.error('加载更多插画失败:', err);
    }
    this.isLoadingMoreIllust = false;
  }

  async loadNovels() {
    this.isRefreshingNovel = true;
    this.isLoadingNovel = true;
    this.novelError = '';
    this.novelPage = 1;
    this.novelPages = 0;
    try {
      const res = await PixivService.getFollowLatestNovels(1, 'all');
      if (!res.error) {
        this.novelWorks = res.body?.thumbnails?.novel ?? [];
        this.novelPage = res.body?.page ?? 1;
        this.novelPages = res.body?.pages ?? 1;
      } else {
        this.novelError = '加载失败';
      }
    } catch (err) {
      console.error('加载关注最新小说失败:', err);
      this.novelError = '加载失败';
    }
    this.isLoadingNovel = false;
    this.isRefreshingNovel = false;
  }

  async loadMoreNovels() {
    if (this.isLoadingMoreNovel || this.novelPage >= this.novelPages) return;
    this.isLoadingMoreNovel = true;
    const nextPage = this.novelPage + 1;
    try {
      const res = await PixivService.getFollowLatestNovels(nextPage, 'all');
      if (!res.error) {
        const newWorks = res.body?.thumbnails?.novel ?? [];
        this.novelWorks = [...this.novelWorks, ...newWorks];
        this.novelPage = res.body?.page ?? nextPage;
        this.novelPages = res.body?.pages ?? this.novelPages;
      }
    } catch (err) {
      console.error('加载更多小说失败:', err);
    }
    this.isLoadingMoreNovel = false;
  }

  build() {
    Column() {
      if (!this.isLoggedIn) {
        this.NotLoggedInView()
      } else {
        this.TabsSection()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  NotLoggedInView() {
    Column() {
      Text('请先登录后查看最新作品')
        .fontSize(16)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 80 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  RefreshIndicator() {
    Column() {
      LoadingProgress()
        .width(28)
        .height(28)
        .color($r('app.color.tab_selected'))
    }
    .width('100%')
    .height(50)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  TabsSection() {
    Column() {
      SegmentedTabBar({
        tabs: ['插画', '小说'],
        currentIndex: this.currentTab,
        onChange: (index: number) => {
          this.currentTab = index;
          if (index === 1 && this.novelWorks.length === 0 && !this.isLoadingNovel) {
            this.loadNovels();
          }
        }
      })
      .padding({ left: 16, right: 16, top: 8, bottom: 4 })

      Tabs({ barPosition: BarPosition.Start, index: this.currentTab }) {
        TabContent() {
          if (this.isLoadingIllust) {
            LoadingProgress().width(40).height(40).margin({ top: 100 })
          } else if (this.illustError) {
            Column() {
              Text(this.illustError).fontSize(14).fontColor($r('app.color.text_secondary'))
              Button('重试').margin({ top: 12 }).onClick(() => this.loadIllusts())
            }
            .margin({ top: 80 })
            .alignItems(HorizontalAlign.Center)
          } else if (this.illustWorks.length === 0) {
            Text('没有更多最新插画').fontSize(14).fontColor($r('app.color.text_secondary')).margin({ top: 100 })
          } else {
            PullToRefresh({ refreshing: this.isRefreshingIllust, onRefresh: (): Promise<void> => this.loadIllusts() }) {
              Scroll() {
                Column() {
                  Grid() {
                    ForEach(this.illustWorks, (item: IllustBookmark) => {
                    GridItem() {
                      IllustCard({ item: item })
                    }
                  }, (item: IllustBookmark) => item.id)
                }
                .columnsTemplate('1fr 1fr')
                .columnsGap(8)
                .rowsGap(8)
                .padding(12)
                .width('100%')

                if (this.isLoadingMoreIllust) {
                  LoadingProgress().width(30).height(30).margin({ top: 8, bottom: 16 })
                }
                if (!this.isLoadingMoreIllust && this.illustPage >= this.illustPages && this.illustWorks.length > 0) {
                  Text('- 已显示全部作品 -')
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
              if (!this.isLoadingMoreIllust && this.illustPage < this.illustPages) {
                this.loadMoreIllusts();
              }
            })
            }
          }
        }
        .tabBar('')

        TabContent() {
          if (this.isLoadingNovel) {
            LoadingProgress().width(40).height(40).margin({ top: 100 })
          } else if (this.novelError) {
            Column() {
              Text(this.novelError).fontSize(14).fontColor($r('app.color.text_secondary'))
              Button('重试').margin({ top: 12 }).onClick(() => this.loadNovels())
            }
            .margin({ top: 80 })
            .alignItems(HorizontalAlign.Center)
          } else if (this.novelWorks.length === 0) {
            Text('没有更多最新小说').fontSize(14).fontColor($r('app.color.text_secondary')).margin({ top: 100 })
          } else {
            PullToRefresh({ refreshing: this.isRefreshingNovel, onRefresh: (): Promise<void> => this.loadNovels() }) {
              Scroll() {
                Column() {
                  List() {
                    ForEach(this.novelWorks, (item: NovelBookmark) => {
                    ListItem() {
                      NovelCard({ item: item })
                    }
                  }, (item: NovelBookmark) => item.id)
                }
                .padding(12)
                .width('100%')

                if (this.isLoadingMoreNovel) {
                  LoadingProgress().width(30).height(30).margin({ top: 8, bottom: 16 })
                }
                if (!this.isLoadingMoreNovel && this.novelPage >= this.novelPages && this.novelWorks.length > 0) {
                  Text('- 已显示全部作品 -')
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
              if (!this.isLoadingMoreNovel && this.novelPage < this.novelPages) {
                this.loadMoreNovels();
              }
            })
            }
          }
        }
        .tabBar('')
      }
      .vertical(false)
      .barWidth(0)
      .barHeight(0)
      .onChange((index: number) => {
        animateTo({ curve: Curve.Friction, duration: 250 }, () => {
          this.currentTab = index;
        });
        if (index === 1 && this.novelWorks.length === 0 && !this.isLoadingNovel) {
          this.loadNovels();
        }
      })
      .layoutWeight(1)
    }
    .width('100%')
  }
}
