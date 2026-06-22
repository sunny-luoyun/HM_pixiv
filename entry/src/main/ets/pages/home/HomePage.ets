import { curves } from '@kit.ArkUI';
import { PixivService } from '../../services/PixivService';
import { IllustBookmark, NovelBookmark } from '../../models/PixivModels';
import { NovelCard } from '../../components/NovelCard';
import { IllustCard } from '../../components/IllustCard';
import { PullToRefresh } from '../../components/PullToRefresh';
import { SegmentedTabBar } from '../../components/SegmentedTabBar';
import { pixivCacheDB } from '../../database/PixivCacheDB';
import { BasicDataSource } from '../../common/utils/BasicDataSource';
import common from '@ohos.app.ability.common';

const PAGE_SIZE = 30;
const MAX_EMPTY_RETRIES = 3;



@Component
export struct HomePage {
  @Consume('isLoggedIn') @Watch('onLoginStateChange') isLoggedIn: boolean;
  @State currentTab: number = 0;
  @State illustCount: number = 0;
  @State novelCount: number = 0;
  private illustSource: BasicDataSource<IllustBookmark> = new BasicDataSource();
  private novelSource: BasicDataSource<NovelBookmark> = new BasicDataSource();
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

  @State isHeaderVisible: boolean = true;
  private lastScrollY: number = 0;

  private illustEmptyRetries: number = 0;
  private novelEmptyRetries: number = 0;
  private illustRetryTimer: number | null = null;
  private illustRetryCount: number = 0;

  async aboutToAppear() {
    if (!this.isLoggedIn) {
      this.isLoadingIllust = false;
      return;
    }
    await this.loadIllusts(true);
  }

  onLoginStateChange() {
    if (this.isLoggedIn && this.illustSource.totalCount() === 0 && !this.isLoadingIllust) {
      this.loadIllusts();
    }
  }

  async loadIllusts(isRetryable: boolean = false) {
    if (this.illustRetryTimer !== null) {
      clearTimeout(this.illustRetryTimer);
      this.illustRetryTimer = null;
    }
    this.isRefreshingIllust = true;
    if (this.illustSource.totalCount() === 0) {
      this.isLoadingIllust = true;
    }
    this.illustError = '';
    this.hasMoreIllust = true;
    this.illustEmptyRetries = 0;

    let failed = false;
    try {
      const res = await PixivService.getDiscoveryIllusts('all', PAGE_SIZE);
      if (!res.error) {
        this.illustSource.reset(res.body?.thumbnails?.illust ?? []);
      } else {
        failed = true;
      }
    } catch (err) {
      console.error('加载发现页插画失败:', err);
      failed = true;
    }

    if (!failed) {
      this.illustRetryCount = 0;
      this.isLoadingIllust = false;
      this.isRefreshingIllust = false;
      return;
    }

    if (isRetryable && this.illustRetryCount < 3) {
      this.illustRetryCount++;
      const self = this;
      this.illustRetryTimer = setTimeout(() => {
        self.illustRetryTimer = null;
        self.loadIllusts(true);
      }, 3500);
      return;
    }

    this.illustError = '加载失败';
    this.isLoadingIllust = false;
    this.isRefreshingIllust = false;
    this.illustRetryCount = 0;
  }

  async loadMoreIllusts() {
    if (this.isLoadingMoreIllust || !this.hasMoreIllust) return;
    this.isLoadingMoreIllust = true;
    try {
      const res = await PixivService.getDiscoveryIllusts('all', PAGE_SIZE);
      if (!res.error) {
        const newWorks = res.body?.thumbnails?.illust ?? [];
        const existingIds = new Set(this.illustSource.getDataArray().map(w => w.id));
        const uniqueNew = newWorks.filter(w => !existingIds.has(w.id));

        if (uniqueNew.length === 0) {
          this.illustEmptyRetries++;
          if (this.illustEmptyRetries >= MAX_EMPTY_RETRIES) {
            this.hasMoreIllust = false;
          }
        } else {
          this.illustEmptyRetries = 0;
          this.illustSource.push(...uniqueNew);
        }
      }
    } catch (err) {
      console.error('加载更多插画失败:', err);
    }
    this.isLoadingMoreIllust = false;
  }

  async filterBlockedNovels(works: NovelBookmark[]): Promise<NovelBookmark[]> {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
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

  async loadNovels() {
    this.isRefreshingNovel = true;
    if (this.novelSource.totalCount() === 0) {
      this.isLoadingNovel = true;
    }
    this.novelError = '';
    this.hasMoreNovel = true;
    this.novelEmptyRetries = 0;
    try {
      const res = await PixivService.getDiscoveryNovels('all', PAGE_SIZE);
      if (!res.error) {
        const rawWorks = res.body?.thumbnails?.novel ?? [];
        this.novelSource.reset(await this.filterBlockedNovels(rawWorks));
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
        const rawNew = res.body?.thumbnails?.novel ?? [];
        const filteredNew = await this.filterBlockedNovels(rawNew);
        const existingIds = new Set(this.novelSource.getDataArray().map(w => w.id));
        const uniqueNew = filteredNew.filter(w => !existingIds.has(w.id));

        if (uniqueNew.length === 0) {
          this.novelEmptyRetries++;
          if (this.novelEmptyRetries >= MAX_EMPTY_RETRIES) {
            this.hasMoreNovel = false;
          }
        } else {
          this.novelEmptyRetries = 0;
          this.novelSource.push(...uniqueNew);
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

  @Builder
  EndOfListRow(onReset: () => void) {
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
        .onClick(() => { onReset(); })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .margin({ top: 8, bottom: 24 })
  }

  handleHeaderScroll(yOffset: number) {
    const delta = yOffset - this.lastScrollY;
    this.lastScrollY = yOffset;

    if (delta > 8 && this.isHeaderVisible && yOffset > 30) {
      animateTo({ curve: curves.springMotion(0.45, 0.7) }, () => {
        this.isHeaderVisible = false;
      });
    } else if (delta < -8 && !this.isHeaderVisible && yOffset < 10) {
      animateTo({ curve: curves.springMotion(0.45, 0.7) }, () => {
        this.isHeaderVisible = true;
      });
    }
  }

  handleTabChange(index: number) {
    this.currentTab = index;
    this.lastScrollY = 0;
    if (index === 1 && this.novelSource.totalCount() === 0 && !this.isLoadingNovel) {
      this.loadNovels();
    }
  }

  @Builder
  TabsSection() {
    Column() {
      if (this.isHeaderVisible) {
        SegmentedTabBar({
          tabs: ['插画', '小说'],
          currentIndex: this.currentTab,
          onChange: (index: number): void => this.handleTabChange(index)
        })
        .padding({ left: 16, right: 16, top: 8, bottom: 4 })
        .transition(TransitionEffect.translate({ y: -48 })
          .combine(TransitionEffect.OPACITY)
          .animation({ curve: curves.springMotion(0.45, 0.7) }))
      }

      Tabs({ barPosition: BarPosition.Start, index: this.currentTab }) {
        TabContent() {
          if (this.isLoadingIllust && this.illustSource.totalCount() === 0) {
            LoadingProgress().width(40).height(40).margin({ top: 100 })
          } else if (this.illustSource.totalCount() === 0 && this.illustError) {
            Column() {
              Text(this.illustError).fontSize(14).fontColor($r('app.color.text_secondary'))
              Button('重试').margin({ top: 12 }).onClick(() => this.loadIllusts())
            }
            .margin({ top: 80 })
            .alignItems(HorizontalAlign.Center)
          } else if (this.illustSource.totalCount() === 0) {
            Text('暂无推荐插画').fontSize(14).fontColor($r('app.color.text_secondary')).margin({ top: 100 })
          } else {
            PullToRefresh({ refreshing: this.isRefreshingIllust, onRefresh: (): Promise<void> => this.loadIllusts() }) {
              Scroll() {
                Column() {
                  Grid() {
                    LazyForEach(this.illustSource, (item: IllustBookmark, index: number) => {
                    GridItem() {
                      IllustCard({ item: item, index: index })
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
                if (!this.isLoadingMoreIllust && !this.hasMoreIllust && this.illustSource.totalCount() > 0) {
                  this.EndOfListRow(() => { this.loadIllusts(); })
                }
              }
              .width('100%')
              .padding({ bottom: 120 })
            }
            .width('100%')
            .edgeEffect(EdgeEffect.Spring)
            .onReachEnd(() => {
              if (this.hasMoreIllust && !this.isLoadingMoreIllust) {
                this.loadMoreIllusts();
              }
            })
            .onScroll((_xOffset: number, yOffset: number) => {
              this.handleHeaderScroll(yOffset);
            })
            }
          }
        }
        .tabBar('')

        TabContent() {
          if (this.isLoadingNovel && this.novelSource.totalCount() === 0) {
            LoadingProgress().width(40).height(40).margin({ top: 100 })
          } else if (this.novelSource.totalCount() === 0 && this.novelError) {
            Column() {
              Text(this.novelError).fontSize(14).fontColor($r('app.color.text_secondary'))
              Button('重试').margin({ top: 12 }).onClick(() => this.loadNovels())
            }
            .margin({ top: 80 })
            .alignItems(HorizontalAlign.Center)
          } else if (this.novelSource.totalCount() === 0) {
            Text('暂无推荐小说').fontSize(14).fontColor($r('app.color.text_secondary')).margin({ top: 100 })
          } else {
            PullToRefresh({ refreshing: this.isRefreshingNovel, onRefresh: (): Promise<void> => this.loadNovels() }) {
              Scroll() {
                Column() {
                  List() {
                    LazyForEach(this.novelSource, (item: NovelBookmark, index: number) => {
                    ListItem() {
                      NovelCard({ item: item, index: index })
                    }
                  }, (item: NovelBookmark) => item.id)
                }
                .padding(12)
                .width('100%')

                if (this.isLoadingMoreNovel) {
                  LoadingProgress().width(30).height(30).margin({ top: 8, bottom: 16 })
                }
                if (!this.isLoadingMoreNovel && !this.hasMoreNovel && this.novelSource.totalCount() > 0) {
                  this.EndOfListRow(() => { this.loadNovels(); })
                }
              }
              .width('100%')
              .padding({ bottom: 120 })
            }
            .width('100%')
            .edgeEffect(EdgeEffect.Spring)
            .onReachEnd(() => {
              if (this.hasMoreNovel && !this.isLoadingMoreNovel) {
                this.loadMoreNovels();
              }
            })
            .onScroll((_xOffset: number, yOffset: number) => {
              this.handleHeaderScroll(yOffset);
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
        animateTo({ curve: curves.springMotion(0.55, 0.65) }, () => {
          this.currentTab = index;
        });
        this.handleTabChange(index);
      })
      .layoutWeight(1)
    }
    .width('100%')
  }
}
