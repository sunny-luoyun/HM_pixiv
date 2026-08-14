import { PageContext } from '../../common/utils/PageContext';
import { PageEnum } from '../../common/constants/PageEnum';

@Component
export struct SettingsPage {
  build() {
    NavDestination() {
      Column() {
        Row() {
          Text('设置')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.user_name'))
          Blank()
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 12, bottom: 12 })
        .backgroundColor($r('app.color.glass_bg'))

        Scroll() {
          Column() {
            this.SettingsMenuItem('译', '翻译服务', 'DeepSeek / 自定义模型、提示词', () => {
              const pageCtx = AppStorage.get<PageContext>('rootPageContext');
              if (pageCtx) { pageCtx.openPage(PageEnum.SETTINGS_TRANSLATION); }
            })
            this.SettingsMenuItem('代', '代理设置', '代理模式、订阅、内核', () => {
              const pageCtx = AppStorage.get<PageContext>('rootPageContext');
              if (pageCtx) { pageCtx.openPage(PageEnum.SETTINGS_PROXY); }
            })
            this.SettingsMenuItem('缓', '缓存管理', '图片缓存、小说缓存', () => {
              const pageCtx = AppStorage.get<PageContext>('rootPageContext');
              if (pageCtx) { pageCtx.openPage(PageEnum.SETTINGS_CACHE); }
            })
            this.SettingsMenuItem('滤', '过滤设置', '标签数过滤', () => {
              const pageCtx = AppStorage.get<PageContext>('rootPageContext');
              if (pageCtx) { pageCtx.openPage(PageEnum.SETTINGS_FILTER); }
            })
            this.SettingsMenuItem('读', '阅读器设置', '到底重置进度', () => {
              const pageCtx = AppStorage.get<PageContext>('rootPageContext');
              if (pageCtx) { pageCtx.openPage(PageEnum.SETTINGS_READER); }
            })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Start)
          .padding({ left: 16, right: 16, top: 16 })
        }
        .width('100%')
        .layoutWeight(1)
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
  SettingsMenuItem(icon: string, title: string, desc: string, action: () => void) {
    Row() {
      Text(icon)
        .fontSize(14)
        .fontColor(Color.White)
        .width(30)
        .height(30)
        .textAlign(TextAlign.Center)
        .backgroundColor($r('app.color.tab_selected'))
        .borderRadius(8)
      Column() {
        Text(title)
          .fontSize(16)
          .fontColor($r('app.color.user_name'))
        Text(desc)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })
      Blank()
      Text('›')
        .fontSize(20)
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .height(64)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(14)
    .margin({ bottom: 10 })
    .shadow({ radius: 4, color: $r('app.color.card_shadow'), offsetY: 1 })
    .onClick(action)
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.Friction })
      .slide(SlideEffect.Right)
    PageTransitionExit({ duration: 300, curve: Curve.Friction })
      .slide(SlideEffect.Right)
  }
}

@Builder
export function SettingsBuilder(): void {
  SettingsPage()
}
