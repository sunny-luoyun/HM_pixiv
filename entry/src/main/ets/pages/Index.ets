import { HomePage } from './home/HomePage';
import { LatestPage } from './latest/LatestPage';
import { SearchPage } from './search/SearchPage';
import { SettingPage } from './setting/SettingPage';
import { appState } from '../store/AppState';

interface TabItem {
  icon: string;
  label: string;
}

const TAB_ITEMS: TabItem[] = [
  { icon: '◉', label: '发现' },
  { icon: '✦', label: '最新' },
  { icon: '◎', label: '搜索' },
  { icon: '●', label: '我的' }
];

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  @State isReady: boolean = false;
  @Provide('isLoggedIn') isLoggedIn: boolean = false;
  private tabsController: TabsController = new TabsController();

  async aboutToAppear() {
    await appState.checkLoginStatus();
    this.isLoggedIn = appState.isLoggedIn;
    this.isReady = true;
    console.info(`🔄 检查登录状态: ${appState.isLoggedIn ? '已登录' : '未登录'}`);
    console.info(`👤 用户: ${appState.userName || '未知用户'} (${appState.userId || '无ID'})`);
  }

  onPageShow() {
    this.isLoggedIn = appState.isLoggedIn;
  }

  build() {
    if (this.isReady) {
      Stack() {
        Tabs({
          barPosition: BarPosition.End,
          controller: this.tabsController,
          index: this.currentIndex
        }) {
          TabContent() {
            HomePage()
          }
          .tabBar('')

          TabContent() {
            LatestPage()
          }
          .tabBar('')

          TabContent() {
            SearchPage()
          }
          .tabBar('')

          TabContent() {
            SettingPage()
          }
          .tabBar('')
        }
        .vertical(false)
        .scrollable(true)
        .barWidth(0)
        .barHeight(0)
        .onChange((index: number) => {
          this.currentIndex = index;
        })
        .width('100%')
        .height('100%')

        Column() {
          Row() {
            Row() {
              ForEach(TAB_ITEMS, (item: TabItem, index: number) => {
                this.TabItemView(item, index)
              }, (item: TabItem) => item.label)
            }
            .height(60)
            .padding({ left: 6, right: 6 })
            .width('92%')
            .backgroundColor($r('app.color.tab_bar_bg'))
            .borderRadius(30)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .height(80)
        .justifyContent(FlexAlign.Start)
        .position({ bottom: 0 })
      }
      .width('100%')
      .height('100%')
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
  TabItemView(item: TabItem, index: number) {
    Column() {
      Text(item.icon)
        .fontSize(18)
        .fontColor(this.currentIndex === index
          ? $r('app.color.tab_selected')
          : $r('app.color.text_secondary'))
        .margin({ bottom: 2 })

      Text(item.label)
        .fontSize(10)
        .fontColor(this.currentIndex === index
          ? $r('app.color.tab_selected')
          : $r('app.color.text_secondary'))
        .fontWeight(this.currentIndex === index ? FontWeight.Medium : FontWeight.Normal)

      if (this.currentIndex === index) {
        Column()
          .width(18)
          .height(3)
          .backgroundColor($r('app.color.tab_selected'))
          .borderRadius(1.5)
          .margin({ top: 4 })
      } else {
        Column()
          .width(18)
          .height(3)
          .margin({ top: 4 })
      }
    }
    .layoutWeight(1)
    .padding({ top: 8, bottom: 6 })
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.currentIndex = index;
      this.tabsController.changeIndex(index);
    })
  }
}
