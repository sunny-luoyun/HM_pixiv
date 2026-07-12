import { curves } from '@kit.ArkUI';
import { notificationManager } from '@kit.NotificationKit';
import { PixivService } from '../../services/PixivService';
import { LatestCheckService } from '../../services/LatestCheckService';
import { IllustBookmark, NovelBookmark } from '../../models/PixivModels';
import { NovelCard } from '../../components/NovelCard';
import { IllustCard } from '../../components/IllustCard';
import { PullToRefresh } from '../../components/PullToRefresh';
import { SegmentedTabBar } from '../../components/SegmentedTabBar';
import { pixivCacheDB } from '../../database/PixivCacheDB';
import { BasicDataSource } from '../../common/utils/BasicDataSource';
import { getColumnsTemplate, getNovelColumnsTemplate } from '../../common/utils/BreakpointManager';
import { ScrollHeaderManager, ScrollHeaderAction } from '../../common/utils/ScrollHeaderManager';
import common from '@ohos.app.ability.common';

const PRELOAD_THRESHOLD = 1500;

@Component
export struct LatestPage {
  @StorageLink('isLoggedIn') @Watch('onLoginStateChange') isLoggedIn: boolean = false;
  @StorageLink('currentBreakpoint') currentBp: string = 'sm';
  @State currentTab: number = 0;
  private illustSource: BasicDataSource<IllustBookmark> = new BasicDataSource();
  private novelSource: BasicDataSource<NovelBookmark> = new BasicDataSource();
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

  @State isHeaderVisible: boolean = true;
  @State swipeProgress: number = 0;
  private scrollManager: ScrollHeaderManager = new ScrollHeaderManager();
  private lastLoadMoreTime: number = 0;

  // 小说分页
  @State novelPage: number = 1;
  @State novelPages: number = 0;
  @State isLoadingMoreNovel: boolean = false;

  // 预加载
  private scrollContainerHeight: number = 0;
  private scrollContentHeight: number = 0;
  private lastPreloadY: number = -1;

  // 屏蔽列表缓存
  private blockedAuthorIds: Set<string> = new Set();
  private blockedSeriesIds: Set<string> = new Set();
  private blockedSeriesTitleSet: Set<string> = new Set();

  @StorageLink('appForegroundTick') @Watch('onAppForeground') appForegroundTick: number = 0;

  // 前台轮询
  private pollTimer: number | undefined = undefined;
  private readonly POLL_INTERVAL = 5 * 60 * 1000;

  async aboutToAppear() {
    if (!this.isLoggedIn) {
      this.isLoadingIllust = false;
      return;
    }
    await this.loadIllusts();
    await this.loadBlockedLists();
    await this.onAppForeground();
    this.startPolling();
  }

  aboutToDisappear(): void {
    this.stopPolling();
  }

  onLoginStateChange() {
    if (this.isLoggedIn && this.illustSource.totalCount() === 0 && !this.isLoadingIllust) {
      this.loadIllusts();
    }
    if (this.isLoggedIn) {
      this.startPolling();
    } else {
      this.stopPolling();
    }
  }

  private startPolling(): void {
    this.stopPolling();
    if (!this.isLoggedIn) return;
    this.pollTimer = setInterval(async () => {
      try {
        const ctx = getContext(this) as common.UIAbilityContext;
        await LatestCheckService.checkForUpdates(ctx);
      } catch (err) {
        console.error('前台轮询检查更新失败:', err);
      }
    }, this.POLL_INTERVAL);
  }

  private stopPolling(): void {
    if (this.pollTimer !== undefined) {
      clearInterval(this.pollTimer);
      this.pollTimer = undefined;
    }
  }

  async onAppForeground(): Promise<void> {
    if (!this.isLoggedIn) return;
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      await LatestCheckService.checkForUpdates(ctx);
      await notificationManager.cancelAll();
      await notificationManager.setBadgeNumber(0);
      console.info('已清除通知和角标');
    } catch (err) {
      console.error('前台恢复检查失败:', err);
    }
  }

  async loadIllusts() {
    this.isRefreshingIllust = true;
    if (this.illustSource.totalCount() === 0) {
      this.isLoadingIllust = true;
    }
    this.illustError = '';
    this.illustPage = 1;
    this.illustPages = 0;
    try {
      const res = await PixivService.getFollowLatestIllusts(1, 'all');
      if (!res.error) {
        this.illustSource.reset(res.body?.thumbnails?.illust ?? []);
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
    this.lastLoadMoreTime = Date.now();
    const nextPage = this.illustPage + 1;
    try {
      const res = await PixivService.getFollowLatestIllusts(nextPage, 'all');
      if (!res.error) {
        const newWorks = res.body?.thumbnails?.illust ?? [];
        // 后台预下载缩略图
        for (const work of newWorks) {
          const url = work.url;
          if (url) {
            PixivService.cacheImage(url, `illust_${work.id}.jpg`).catch(() => {});
          }
        }
        this.illustSource.batchPush(...newWorks);
        this.illustPage = res.body?.page ?? nextPage;
        this.illustPages = res.body?.pages ?? this.illustPages;
      }
    } catch (err) {
      console.error('加载更多插画失败:', err);
    }
    this.isLoadingMoreIllust = false;
    if (this.scrollContentHeight > 0 && this.illustPage < this.illustPages) {
      const remaining = this.scrollContentHeight - this.scrollContainerHeight - Math.max(this.lastPreloadY, 0);
      if (remaining < PRELOAD_THRESHOLD) {
        this.loadMoreIllusts();
      }
    }
  }

  async loadBlockedLists(): Promise<void> {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      await pixivCacheDB.init(ctx);
      this.blockedAuthorIds = await pixivCacheDB.getAllBlockedAuthorIds();
      this.blockedSeriesIds = await pixivCacheDB.getAllBlockedSeriesIds();
      this.blockedSeriesTitleSet = await pixivCacheDB.getAllBlockedSeriesTitleSet() as Set<string>;
    } catch (_) {}
  }

  private filterBlockedNovelsCached(works: NovelBookmark[]): NovelBookmark[] {
    return works.filter(n => {
      if (this.blockedAuthorIds.has(n.userId)) return false;
      const sid = n.series?.id ?? n.seriesId;
      if (sid && this.blockedSeriesIds.has(String(sid))) return false;
      const seriesTitle = n.seriesTitle || n.series?.title || '';
      if (seriesTitle && this.blockedSeriesTitleSet.has(seriesTitle.toLowerCase())) return false;
      return true;
    });
  }

  async loadNovels() {
    this.isRefreshingNovel = true;
    if (this.novelSource.totalCount() === 0) {
      this.isLoadingNovel = true;
    }
    this.novelError = '';
    this.novelPage = 1;
    this.novelPages = 0;
    try {
      const res = await PixivService.getFollowLatestNovels(1, 'all');
      if (!res.error) {
        const rawWorks = res.body?.thumbnails?.novel ?? [];
        this.novelSource.reset(this.filterBlockedNovelsCached(rawWorks));
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
    this.lastLoadMoreTime = Date.now();
    const nextPage = this.novelPage + 1;
    try {
      const res = await PixivService.getFollowLatestNovels(nextPage, 'all');
      if (!res.error) {
        const rawNew = res.body?.thumbnails?.novel ?? [];
        const filteredNew = this.filterBlockedNovelsCached(rawNew);
        this.novelSource.batchPush(...filteredNew);
        this.novelPage = res.body?.page ?? nextPage;
        this.novelPages = res.body?.pages ?? this.novelPages;
      }
    } catch (err) {
      console.error('加载更多小说失败:', err);
    }
    this.isLoadingMoreNovel = false;
    if (this.scrollContentHeight > 0 && this.novelPage < this.novelPages) {
      const remaining = this.scrollContentHeight - this.scrollContainerHeight - Math.max(this.lastPreloadY, 0);
      if (remaining < PRELOAD_THRESHOLD) {
        this.loadMoreNovels();
      }
    }
  }

  handleHeaderScroll(yOffset: number) {
    const action = this.scrollManager.onScroll(this.currentTab, yOffset, this.isHeaderVisible);
    if (action === ScrollHeaderAction.NONE) {
      return;
    }
    if (action === ScrollHeaderAction.SHOW &&
      (this.isLoadingMoreIllust || this.isLoadingMoreNovel)) {
      return;
    }
    animateTo({ curve: curves.springMotion(0.45, 0.7) }, () => {
      this.isHeaderVisible = action === ScrollHeaderAction.SHOW;
    });
  }

  handleHeaderReachStart() {
    const action = this.scrollManager.onReachStart(this.isHeaderVisible);
    if (action === ScrollHeaderAction.NONE) {
      return;
    }
    if (this.isLoadingMoreIllust || this.isLoadingMoreNovel) {
      return;
    }
    animateTo({ curve: curves.springMotion(0.45, 0.7) }, () => {
      this.isHeaderVisible = true;
    });
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
      if (this.isHeaderVisible) {
        SegmentedTabBar({
          tabs: ['插画', '小说'],
          currentIndex: this.currentTab,
          swipeProgress: this.swipeProgress,
          onChange: (index: number) => {
            this.currentTab = index;
            this.scrollManager.onTabChange(index);
            if (index === 1 && this.novelSource.totalCount() === 0 && !this.isLoadingNovel) {
              this.loadNovels();
            }
          }
        })
        .padding({ left: 16, right: 16, top: 8, bottom: 4 })
        .transition(TransitionEffect.translate({ y: -48 })
          .combine(TransitionEffect.OPACITY)
          .animation({ curve: curves.springMotion(0.45, 0.7) }))
      }

      if (this.currentTab === 0) {
        Column() {
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
            Text('没有更多最新插画').fontSize(14).fontColor($r('app.color.text_secondary')).margin({ top: 100 })
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
                .columnsTemplate(getColumnsTemplate(this.currentBp))
                .columnsGap(8)
                .rowsGap(8)
                .padding(12)
                .width('100%')

                if (this.isLoadingMoreIllust) {
                  LoadingProgress().width(30).height(30).margin({ top: 8, bottom: 16 })
                }
                if (!this.isLoadingMoreIllust && this.illustPage >= this.illustPages && this.illustSource.totalCount() > 0) {
                  Text('- 已显示全部作品 -')
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
            .onReachStart(() => { this.handleHeaderReachStart(); })
            .onReachEnd(() => {
              if (!this.isLoadingMoreIllust && this.illustPage < this.illustPages) {
                this.loadMoreIllusts();
              }
            })
            .onScroll((_xOffset: number, yOffset: number) => {
              this.handleHeaderScroll(yOffset);
              if (this.scrollContentHeight > 0) {
                const remaining = this.scrollContentHeight - this.scrollContainerHeight - yOffset;
                if (yOffset > this.lastPreloadY && remaining < PRELOAD_THRESHOLD && this.illustPage < this.illustPages && !this.isLoadingMoreIllust) {
                  this.loadMoreIllusts();
                }
              }
              this.lastPreloadY = yOffset;
            })
            .onAreaChange((_old: Area, area: Area) => {
              this.scrollContainerHeight = area.height as number;
            })
            }
          }
        }
        .width('100%')
        .layoutWeight(1)
      } else {
        Column() {
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
            Text('没有更多最新小说').fontSize(14).fontColor($r('app.color.text_secondary')).margin({ top: 100 })
          } else {
            PullToRefresh({ refreshing: this.isRefreshingNovel, onRefresh: (): Promise<void> => this.loadNovels() }) {
              Scroll() {
                Column() {
                  Grid() {
                    LazyForEach(this.novelSource, (item: NovelBookmark, index: number) => {
                    GridItem() {
                      NovelCard({ item: item, index: index })
                    }
                  }, (item: NovelBookmark) => item.id)
                }
                .columnsTemplate(getNovelColumnsTemplate(this.currentBp))
                .columnsGap(8)
                .rowsGap(8)
                .padding(12)
                .width('100%')

                if (this.isLoadingMoreNovel) {
                  LoadingProgress().width(30).height(30).margin({ top: 8, bottom: 16 })
                }
                if (!this.isLoadingMoreNovel && this.novelPage >= this.novelPages && this.novelSource.totalCount() > 0) {
                  Text('- 已显示全部作品 -')
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
            .onReachStart(() => { this.handleHeaderReachStart(); })
            .onReachEnd(() => {
              if (!this.isLoadingMoreNovel && this.novelPage < this.novelPages) {
                this.loadMoreNovels();
              }
            })
            .onScroll((_xOffset: number, yOffset: number) => {
              this.handleHeaderScroll(yOffset);
              if (this.scrollContentHeight > 0) {
                const remaining = this.scrollContentHeight - this.scrollContainerHeight - yOffset;
                if (yOffset > this.lastPreloadY && remaining < PRELOAD_THRESHOLD && this.novelPage < this.novelPages && !this.isLoadingMoreNovel) {
                  this.loadMoreNovels();
                }
              }
              this.lastPreloadY = yOffset;
            })
            .onAreaChange((_old: Area, area: Area) => {
              this.scrollContainerHeight = area.height as number;
            })
            }
          }
        }
        .width('100%')
        .layoutWeight(1)
      }
    }
    .width('100%')
  }
}

