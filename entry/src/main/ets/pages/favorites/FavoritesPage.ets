import router from '@ohos.router';
import { PixivService, IllustBookmark, NovelBookmark } from '../../services/PixivService';
import { NovelCard } from '../../components/NovelCard';
import { IllustCard } from '../../components/IllustCard';
import { appState } from '../../store/AppState';

@Entry
@Component
struct FavoritesPage {
  @State currentTab: number = 0;
  @State illustWorks: IllustBookmark[] = [];
  @State novelWorks: NovelBookmark[] = [];
  @State isLoadingIllust: boolean = true;
  @State isLoadingNovel: boolean = false;

  async aboutToAppear() {
    if (!appState.isLoggedIn || !appState.userId) {
      return;
    }
    await this.loadIllusts();
  }

  async loadIllusts() {
    this.isLoadingIllust = true;
    try {
      const res = await PixivService.getIllustBookmarks(appState.userId);
      if (!res.error) {
        this.illustWorks = res.body.works;
      }
    } catch (err) {
      console.error('加载收藏插画失败:', err);
    }
    this.isLoadingIllust = false;
  }

  async loadNovels() {
    this.isLoadingNovel = true;
    try {
      const res = await PixivService.getNovelBookmarks(appState.userId);
      if (!res.error) {
        this.novelWorks = res.body.works;
      }
    } catch (err) {
      console.error('加载收藏小说失败:', err);
    }
    this.isLoadingNovel = false;
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
    .height(48)
    .padding({ left: 16, right: 16 })
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

  @Builder
  TabsSection() {
    Tabs({ barPosition: BarPosition.Start, index: this.currentTab }) {
      TabContent() {
        if (this.isLoadingIllust) {
          LoadingProgress().width(40).height(40).margin({ top: 100 })
        } else if (this.illustWorks.length === 0) {
          Text('暂无收藏插画').fontSize(14).fontColor($r('app.color.text_secondary')).margin({ top: 100 })
        } else {
          Scroll() {
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
          }
          .width('100%')
        }
      }
      .tabBar('插画')

      TabContent() {
        if (this.isLoadingNovel) {
          LoadingProgress().width(40).height(40).margin({ top: 100 })
        } else if (this.novelWorks.length === 0) {
          Text('暂无收藏小说').fontSize(14).fontColor($r('app.color.text_secondary')).margin({ top: 100 })
        } else {
          Scroll() {
            List() {
              ForEach(this.novelWorks, (item: NovelBookmark) => {
                ListItem() {
                  NovelCard({ item: item })
                }
              }, (item: NovelBookmark) => item.id)
            }
            .padding(12)
          }
          .width('100%')
        }
      }
      .tabBar('小说')
    }
    .vertical(false)
    .onChange((index: number) => {
      this.currentTab = index;
      if (index === 1 && this.novelWorks.length === 0 && !this.isLoadingNovel) {
        this.loadNovels();
      }
    })
    .width('100%')
    .layoutWeight(1)
  }

}
