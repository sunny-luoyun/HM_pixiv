import { curves } from '@kit.ArkUI';
import { PixivService } from '../../services/PixivService';
import { IllustBookmark, NovelBookmark } from '../../models/PixivModels';
import { NovelCard } from '../../components/NovelCard';
import { IllustCard } from '../../components/IllustCard';
import { SegmentedTabBar } from '../../components/SegmentedTabBar';
import { BasicDataSource } from '../../common/utils/BasicDataSource';
import { getColumnsTemplate, getNovelColumnsTemplate } from '../../common/utils/BreakpointManager';
import { appState } from '../../store/AppState';
import { PageContext } from '../../common/utils/PageContext';

const PAGE_SIZE = 30;

@Component
struct FavoritesPage {
  @StorageLink('currentBreakpoint') currentBp: string = 'sm';
  private isActive: boolean = true;
  @State currentTab: number = 0;
  @State isHeaderVisible: boolean = true;
  @State swipeProgress: number = 0;
  @State isAnimationStarted: boolean = false;
  private lastScrollY: number = 0;
  private swiperController: SwiperController = new SwiperController();
  private swiperWidth: number = 0;
  private animStartIndex: number = 0;
  private illustSource: BasicDataSource<IllustBookmark> = new BasicDataSource();
  private novelSource: BasicDataSource<NovelBookmark> = new BasicDataSource();
  @State isLoadingIllust: boolean = true;
  @State isLoadingNovel: boolean = false;
  @State illustError: string = '';
  @State novelError: string = '';

  @State isLoadingMoreIllust: boolean = false;
  @State isLoadingMoreNovel: boolean = false;
  @State hasMoreIllust: boolean = true;
  @State hasMoreNovel: boolean = true;
  @State illustOffset: number = 0;
  @State novelOffset: number = 0;

  aboutToDisappear() {
    this.isActive = false;
  }

  async aboutToAppear() {
    if (!appState.isLoggedIn || !appState.userId) {
      this.isLoadingIllust = false;
      return;
    }
    await this.loadIllusts();
  }

  async loadIllusts() {
    this.isLoadingIllust = true;
    this.illustError = '';
    this.illustOffset = 0;
    this.hasMoreIllust = true;
    try {
      const res = await PixivService.getIllustBookmarks(appState.userId, 0, PAGE_SIZE);
      if (!this.isActive) return;
      if (!res.error) {
        this.illustSource.reset(res.body.works);
        this.illustOffset = this.illustSource.totalCount();
        if (this.illustOffset >= res.body.total) {
          this.hasMoreIllust = false;
        }
      } else {
        this.illustError = '加载失败';
      }
    } catch (err) {
      if (!this.isActive) return;
      console.error('加载收藏插画失败:', err);
      this.illustError = '加载失败';
    }
    this.isLoadingIllust = false;
  }

  async loadMoreIllusts() {
    if (this.isLoadingMoreIllust || !this.hasMoreIllust) return;
    this.isLoadingMoreIllust = true;
    try {
      const res = await PixivService.getIllustBookmarks(appState.userId, this.illustOffset, PAGE_SIZE);
      if (!this.isActive) return;
      if (!res.error) {
        this.illustSource.push(...res.body.works);
        this.illustOffset += res.body.works.length;
        if (this.illustOffset >= res.body.total) {
          this.hasMoreIllust = false;
        }
      }
    } catch (err) {
      if (!this.isActive) return;
      console.error('加载更多收藏插画失败:', err);
    }
    this.isLoadingMoreIllust = false;
  }

  async loadNovels() {
    this.isLoadingNovel = true;
    this.novelError = '';
    this.novelOffset = 0;
    this.hasMoreNovel = true;
    try {
      const res = await PixivService.getNovelBookmarks(appState.userId, 0, PAGE_SIZE);
      if (!this.isActive) return;
      if (!res.error) {
        this.novelSource.reset(res.body.works);
        this.novelOffset = this.novelSource.totalCount();
        if (this.novelOffset >= res.body.total) {
          this.hasMoreNovel = false;
        }
      } else {
        this.novelError = '加载失败';
      }
    } catch (err) {
      if (!this.isActive) return;
      console.error('加载收藏小说失败:', err);
      this.novelError = '加载失败';
    }
    this.isLoadingNovel = false;
  }

  async loadMoreNovels() {
    if (this.isLoadingMoreNovel || !this.hasMoreNovel) return;
    this.isLoadingMoreNovel = true;
    try {
      const res = await PixivService.getNovelBookmarks(appState.userId, this.novelOffset, PAGE_SIZE);
      if (!this.isActive) return;
      if (!res.error) {
        this.novelSource.push(...res.body.works);
        this.novelOffset += res.body.works.length;
        if (this.novelOffset >= res.body.total) {
          this.hasMoreNovel = false;
        }
      }
    } catch (err) {
      if (!this.isActive) return;
      console.error('加载更多收藏小说失败:', err);
    }
    this.isLoadingMoreNovel = false;
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
        if (!appState.isLoggedIn) {
          this.NotLoggedInView()
        } else {
          this.TabsSection()
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
      Text('我的收藏')
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

  @Builder
  NotLoggedInView() {
    Column() {
      Text('请先登录后查看收藏')
        .fontSize(16)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 80 })
      Button('去登录')
        .margin({ top: 16 })
        .onClick(() => {
          const ctx = AppStorage.get<PageContext>('rootPageContext');
          if (ctx) { ctx.popPage(); }
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  handleHeaderScroll(yOffset: number) {
    const delta = yOffset - this.lastScrollY;
    this.lastScrollY = yOffset;

    if (delta > 0 && this.isHeaderVisible && yOffset > 5) {
      animateTo({ curve: curves.springMotion(0.45, 0.7) }, () => {
        this.isHeaderVisible = false;
      });
    } else if (delta < -3 && !this.isHeaderVisible) {
      animateTo({ curve: curves.springMotion(0.45, 0.7) }, () => {
        this.isHeaderVisible = true;
      });
    }
  }

  handleHeaderReachStart() {
    if (!this.isHeaderVisible) {
      animateTo({ curve: curves.springMotion(0.45, 0.7) }, () => {
        this.isHeaderVisible = true;
      });
    }
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
          if (this.isLoadingIllust) {
            LoadingProgress().width(40).height(40).margin({ top: 100 })
          } else if (this.illustError) {
            Column() {
              Text(this.illustError).fontSize(14).fontColor($r('app.color.text_secondary'))
              Button('重试').margin({ top: 12 }).onClick(() => this.loadIllusts())
            }
            .margin({ top: 80 })
            .alignItems(HorizontalAlign.Center)
          } else if (this.illustSource.totalCount() === 0) {
            Text('暂无收藏插画').fontSize(14).fontColor($r('app.color.text_secondary')).margin({ top: 100 })
          } else {
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
                if (!this.isLoadingMoreIllust && !this.hasMoreIllust && this.illustSource.totalCount() > 0) {
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
            .onReachStart(() => { this.handleHeaderReachStart(); })
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
        .width('100%')

        Column() {
          if (this.isLoadingNovel) {
            LoadingProgress().width(40).height(40).margin({ top: 100 })
          } else if (this.novelError) {
            Column() {
              Text(this.novelError).fontSize(14).fontColor($r('app.color.text_secondary'))
              Button('重试').margin({ top: 12 }).onClick(() => this.loadNovels())
            }
            .margin({ top: 80 })
            .alignItems(HorizontalAlign.Center)
          } else if (this.novelSource.totalCount() === 0) {
            Text('暂无收藏小说').fontSize(14).fontColor($r('app.color.text_secondary')).margin({ top: 100 })
          } else {
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
                if (!this.isLoadingMoreNovel && !this.hasMoreNovel && this.novelSource.totalCount() > 0) {
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
            .onReachStart(() => { this.handleHeaderReachStart(); })
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

@Builder
export function FavoritesBuilder(): void {
  FavoritesPage()
}
