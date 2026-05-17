// entry/src/main/ets/pages/Index.ets
import { HomePage } from './home/HomePage';
import { LatestPage } from './latest/LatestPage';
import { SearchPage } from './search/SearchPage';
import { SettingPage } from './setting/SettingPage';
import { appState } from '../store/AppState';

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  @State isReady: boolean = false;
  private tabsController: TabsController = new TabsController();
  async aboutToAppear() {
    await appState.checkLoginStatus();
    this.isReady = true;
    console.info(`🔄 检查登录状态: ${appState.isLoggedIn ? '已登录' : '未登录'}`);
    console.info(`👤 用户: ${appState.userName || '未知用户'} (${appState.userId || '无ID'})`);
  }

  build() {
    if (this.isReady) {
      Tabs({
        barPosition: BarPosition.End,
        controller: this.tabsController
      }) {
        TabContent() {
          HomePage()
        }
        .tabBar(this.TabBarBuilder('发现', 0))

        TabContent() {
          LatestPage()
        }
        .tabBar(this.TabBarBuilder('最新', 1))

        TabContent() {
          SearchPage()
        }
        .tabBar(this.TabBarBuilder('搜索', 2))

        TabContent() {
          SettingPage()
        }
        .tabBar(this.TabBarBuilder('我的', 3))
      }
      .vertical(false)
      .scrollable(true)
      .barHeight(56)
      .onChange((index: number) => {
        this.currentIndex = index;
      })
    } else {
      Column() {
        LoadingProgress().width(40).height(40)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('app.color.page_background'))
    }
  }

  @Builder
  TabBarBuilder(title: string, index: number) {
    Column() {
      Text(title)
        .fontSize(14)
        .fontColor(this.currentIndex === index ? $r('app.color.tab_selected') : $r('app.color.tab_normal'))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}