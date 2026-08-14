import { PageContext } from '../../common/utils/PageContext';
import { TranslationSettingsSection } from './TranslationSettingsSection';

@Builder
export function SettingsTranslationBuilder(): void {
  SettingsTranslationPage()
}

@Component
export struct SettingsTranslationPage {
  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.Friction })
      .slide(SlideEffect.Right)
    PageTransitionExit({ duration: 300, curve: Curve.Friction })
      .slide(SlideEffect.Right)
  }

  build() {
    NavDestination() {
      Column() {
        Row() {
          Text('‹')
            .fontSize(28)
            .onClick(() => { const ctx = AppStorage.get<PageContext>('rootPageContext'); if (ctx) { ctx.popPage(); } })
          Text('翻译服务')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.user_name'))
            .margin({ left: 12 })
          Blank()
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .alignItems(VerticalAlign.Center)
        .padding({ left: 16, right: 24, top: 16 })

        Scroll() {
          Column() {
            TranslationSettingsSection()
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ top: 12, left: 16, right: 16 })
        }
        .width('100%')
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .backgroundColor($r('app.color.page_background'))
    }
    .onBackPressed(() => {
      const pageCtx = AppStorage.get<PageContext>('rootPageContext');
      if (pageCtx) { pageCtx.popPage(); }
      return true;
    })
    .hideTitleBar(true)
  }
}
