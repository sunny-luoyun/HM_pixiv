import { PixivService, IllustBookmark, NovelBookmark } from '../../services/PixivService';
import { NovelCard } from '../../components/NovelCard';
import { IllustCard } from '../../components/IllustCard';
import { PullToRefresh } from '../../components/PullToRefresh';
import { SegmentedTabBar } from '../../components/SegmentedTabBar';

const PAGE_SIZE = 30;
const MAX_EMPTY_RETRIES = 3;

@Component
export struct HomePage {
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

  @State isLoadingMoreIllust: boolean = false;
  @State isLoadingMoreNovel: boolean = false;
  @State hasMoreIllust: boolean = true;
  @State hasMoreNovel: boolean = true;

  private illustEmptyRetries: number = 0;
  private novelEmptyRetries: number = 0;

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
    this.hasMoreIllust = true;
    this.illustEmptyRetries = 0;
    try {
      const res = await PixivService.getDiscoveryIllusts('all', PAGE_SIZE);
      if (!res.error) {
        this.illustWorks = res.body?.thumbnails?.illust ?? [];
      } else {
        this.illustError = '加载失败';
      }
    } catch (err) {
      console.error('加载发现页插画失败:', err);
      this.illustError = '加载失败';
    }
    this.isLoadingIllust = false;
    this.isRefreshingIllust = false;
  }

  async loadMoreIllusts() {
    if (this.isLoadingMoreIllust || !this.hasMoreIllust) return;
    this.isLoadingMoreIllust = true;
    try {
      const res = await PixivService.getDiscoveryIllusts('all', PAGE_SIZE);
      if (!res.error) {
        const newWorks = res.body?.thumbnails?.illust ?? [];
        const existingIds = new Set(this.illustWorks.map(w => w.id));
        const uniqueNew = newWorks.filter(w => !existingIds.has(w.id));

        if (uniqueNew.length === 0) {
          this.illustEmptyRetries++;
          if (this.illustEmptyRetries >= MAX_EMPTY_RETRIES) {
            this.hasMoreIllust = false;
          }
        } else {
          this.illustEmptyRetries = 0;
          this.illustWorks = [...this.illustWorks, ...uniqueNew];
        }
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
    this.hasMoreNovel = true;
    this.novelEmptyRetries = 0;
    try {
      const res = await PixivService.getDiscoveryNovels('all', PAGE_SIZE);
      if (!res.error) {
        this.novelWorks = res.body?.thumbnails?.novel ?? [];
      } else {
        this.novelError = '加载失败';
      }
    } catch (err) {
      console.error('加载发现页小说失败:', err);
      this.novelError = '加载失败';
    }
    this.isLoadingNovel = false;
    this.isRefreshingNovel = false;
  }

  async loadMoreNovels() {
    if (this.isLoadingMoreNovel || !this.hasMoreNovel) return;
    this.isLoadingMoreNovel = true;
    try {
      const res = await PixivService.getDiscoveryNovels('all', PAGE_SIZE);
      if (!res.error) {
        const newWorks = res.body?.thumbnails?.novel ?? [];
        const existingIds = new Set(this.novelWorks.map(w => w.id));
        const uniqueNew = newWorks.filter(w => !existingIds.has(w.id));

        if (uniqueNew.length === 0) {
          this.novelEmptyRetries++;
          if (this.novelEmptyRetries >= MAX_EMPTY_RETRIES) {
            this.hasMoreNovel = false;
          }
        } else {
          this.novelEmptyRetries = 0;
          this.novelWorks = [...this.novelWorks, ...uniqueNew];
        }
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
      Text('请先登录后查看推荐作品')
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

  handleTabChange(index: number) {
    this.currentTab = index;
    if (index === 1 && this.novelWorks.length === 0 && !this.isLoadingNovel) {
      this.loadNovels();
    }
  }

  @Builder
  TabsSection() {
    Column() {
      SegmentedTabBar({
        tabs: ['插画', '小说'],
        currentIndex: this.currentTab,
        onChange: (index: number): void => this.handleTabChange(index)
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
            Text('暂无推荐插画').fontSize(14).fontColor($r('app.color.text_secondary')).margin({ top: 100 })
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
                if (!this.isLoadingMoreIllust && !this.hasMoreIllust && this.illustWorks.length > 0) {
                  Column() {
                    Text('- 已显示全部作品 -')
                      .fontSize(12)
                      .fontColor($r('app.color.text_secondary'))
                      .width('100%')
                      .textAlign(TextAlign.Center)
                    Button('刷新推荐')
                      .fontSize(13)
                      .fontColor(Color.White)
                      .backgroundColor($r('app.color.tab_selected'))
                      .borderRadius(18)
                      .height(36)
                      .padding({ left: 20, right: 20 })
                      .margin({ top: 12 })
                      .onClick(() => {
                        this.loadIllusts();
                      })
                  }
                  .width('100%')
                  .alignItems(HorizontalAlign.Center)
                  .margin({ top: 8, bottom: 24 })
                }
              }
              .width('100%')
            }
            .width('100%')
            .onReachEnd(() => {
              if (this.hasMoreIllust && !this.isLoadingMoreIllust) {
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
            Text('暂无推荐小说').fontSize(14).fontColor($r('app.color.text_secondary')).margin({ top: 100 })
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
                if (!this.isLoadingMoreNovel && !this.hasMoreNovel && this.novelWorks.length > 0) {
                  Column() {
                    Text('- 已显示全部作品 -')
                      .fontSize(12)
                      .fontColor($r('app.color.text_secondary'))
                      .width('100%')
                      .textAlign(TextAlign.Center)
                    Button('刷新推荐')
                      .fontSize(13)
                      .fontColor(Color.White)
                      .backgroundColor($r('app.color.tab_selected'))
                      .borderRadius(18)
                      .height(36)
                      .padding({ left: 20, right: 20 })
                      .margin({ top: 12 })
                      .onClick(() => {
                        this.loadNovels();
                      })
                  }
                  .width('100%')
                  .alignItems(HorizontalAlign.Center)
                  .margin({ top: 8, bottom: 24 })
                }
              }
              .width('100%')
            }
            .width('100%')
            .onReachEnd(() => {
              if (this.hasMoreNovel && !this.isLoadingMoreNovel) {
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
        this.handleTabChange(index);
      })
      .layoutWeight(1)
    }
    .width('100%')
  }
}
