import router from '@ohos.router';
import { curves } from '@kit.ArkUI';
import { PixivService } from '../../services/PixivService';
import { IllustBookmark, NovelBookmark } from '../../models/PixivModels';
import { NovelCard } from '../../components/NovelCard';
import { IllustCard } from '../../components/IllustCard';
import { SegmentedTabBar } from '../../components/SegmentedTabBar';
import { BasicDataSource } from '../../common/utils/BasicDataSource';
import { appState } from '../../store/AppState';

const PAGE_SIZE = 30;

@Entry
@Component
struct FavoritesPage {
  private isActive: boolean = true;
  @State currentTab: number = 0;
  @State isHeaderVisible: boolean = true;
  private lastScrollY: number = 0;
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

  @Builder
  TopBar() {
    Row() {
      Text('‹')
        .fontSize(28)
        .fontColor($r('app.color.tab_selected'))
        .onClick(() => {
          router.back();
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
          router.back();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
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

  @Builder
  TabsSection() {
    Column() {
      if (this.isHeaderVisible) {
        SegmentedTabBar({
          tabs: ['插画', '小说'],
          currentIndex: this.currentTab,
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
                .columnsTemplate('1fr 1fr')
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
          } else if (this.novelSource.totalCount() === 0) {
            Text('暂无收藏小说').fontSize(14).fontColor($r('app.color.text_secondary')).margin({ top: 100 })
          } else {
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
              if (this.hasMoreNovel && !this.isLoadingMoreNovel) {
                this.loadMoreNovels();
              }
            })
            .onScroll((_xOffset: number, yOffset: number) => {
              this.handleHeaderScroll(yOffset);
            })
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
        if (index === 1 && this.novelSource.totalCount() === 0 && !this.isLoadingNovel) {
          this.loadNovels();
        }
      })
      .layoutWeight(1)
    }
    .width('100%')
  }
}
