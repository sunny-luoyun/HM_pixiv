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

@Component
export struct LatestPage {
  @Consume('isLoggedIn') @Watch('onLoginStateChange') isLoggedIn: boolean;
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
  @State isAnimationStarted: boolean = false;
  private lastScrollY: number = 0;
  private swiperController: SwiperController = new SwiperController();
  private swiperWidth: number = 0;
  private animStartIndex: number = 0;

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
    if (this.isLoggedIn && this.illustSource.totalCount() === 0 && !this.isLoadingIllust) {
      this.loadIllusts();
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
    const nextPage = this.illustPage + 1;
    try {
      const res = await PixivService.getFollowLatestIllusts(nextPage, 'all');
      if (!res.error) {
        const newWorks = res.body?.thumbnails?.illust ?? [];
        this.illustSource.push(...newWorks);
        this.illustPage = res.body?.page ?? nextPage;
        this.illustPages = res.body?.pages ?? this.illustPages;
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
    this.novelPage = 1;
    this.novelPages = 0;
    try {
      const res = await PixivService.getFollowLatestNovels(1, 'all');
      if (!res.error) {
        const rawWorks = res.body?.thumbnails?.novel ?? [];
        this.novelSource.reset(await this.filterBlockedNovels(rawWorks));
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
        const rawNew = res.body?.thumbnails?.novel ?? [];
        const filteredNew = await this.filterBlockedNovels(rawNew);
        this.novelSource.push(...filteredNew);
        this.novelPage = res.body?.page ?? nextPage;
        this.novelPages = res.body?.pages ?? this.novelPages;
      }
    } catch (err) {
      console.error('加载更多小说失败:', err);
    }
    this.isLoadingMoreNovel = false;
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
            this.lastScrollY = 0;
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

      Swiper(this.swiperController) {
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
                .columnsTemplate('1fr 1fr')
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
            }
            .width('100%')
            .edgeEffect(EdgeEffect.Spring)
            .onReachEnd(() => {
              if (!this.isLoadingMoreIllust && this.illustPage < this.illustPages) {
                this.loadMoreIllusts();
              }
            })
            .onScroll((_xOffset: number, yOffset: number) => {
              this.handleHeaderScroll(yOffset);
            })
            }
          }
        }
        .width('100%')

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
            }
            .width('100%')
            .edgeEffect(EdgeEffect.Spring)
            .onReachEnd(() => {
              if (!this.isLoadingMoreNovel && this.novelPage < this.novelPages) {
                this.loadMoreNovels();
              }
            })
            .onScroll((_xOffset: number, yOffset: number) => {
              this.handleHeaderScroll(yOffset);
            })
            }
          }
        }
        .width('100%')
      }
      .index(this.currentTab)
      .indicator(false)
      .loop(false)
      .vertical(false)
      .cachedCount(1)
      .onGestureSwipe((index: number, extraInfo: SwiperAnimationEvent) => {
        if ((index === 0 && extraInfo.currentOffset > 0) ||
          (index === 1 && extraInfo.currentOffset < 0)) {
          this.swipeProgress = 0;
          return;
        }
        const w = this.swiperWidth > 0 ? this.swiperWidth : 1;
        const ratio = Math.abs(extraInfo.currentOffset) / w;
        this.swipeProgress = extraInfo.currentOffset < 0 ? ratio : -ratio;
      })
      .onAnimationStart((index: number, _targetIndex: number) => {
        this.isAnimationStarted = true;
        this.animStartIndex = index;
      })
      .onContentDidScroll((_selectedIndex: number, index: number, position: number, mainAxisLength: number) => {
        this.swiperWidth = mainAxisLength;
        if (!this.isAnimationStarted || index !== this.animStartIndex) return;
        const targetIndex = position < 0 ? index + 1 : index - 1;
        if (targetIndex < 0 || targetIndex >= 2) return;
        const dir = targetIndex > index ? 1 : -1;
        this.swipeProgress = dir * Math.abs(Math.min(Math.max(position, -1), 1));
      })
      .onAnimationEnd((index: number) => {
        this.isAnimationStarted = false;
        this.swipeProgress = 0;
        this.currentTab = index;
        this.lastScrollY = 0;
        if (index === 1 && this.novelSource.totalCount() === 0 && !this.isLoadingNovel) {
          this.loadNovels();
        }
      })
      .layoutWeight(1)
      .onAreaChange((_old: Area, area: Area) => {
        this.swiperWidth = area.width as number;
      })
    }
    .width('100%')
  }
}
