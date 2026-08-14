import { TranslationStorage } from '../../common/utils/TranslationStorage';
import { PageContext } from '../../common/utils/PageContext';

@Builder
export function SettingsReaderBuilder(): void {
  SettingsReaderPage()
}

@Component
export struct SettingsReaderPage {
  @State resetOnReachEnd: boolean = false;

  aboutToAppear() {
    this.resetOnReachEnd = AppStorage.get<boolean>('resetOnReachEnd') ?? false;
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
        Row() {
          Text('‹')
            .fontSize(28)
            .onClick(() => { const ctx = AppStorage.get<PageContext>('rootPageContext'); if (ctx) { ctx.popPage(); } })
          Text('阅读器设置')
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
            Column() {
              Row() {
                Column() {
                  Text('到底重置进度')
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.user_name'))
                  Text('滑到小说底部后，不保存进度，下次从头开始阅读')
                    .fontSize(12)
                    .fontColor($r('app.color.text_secondary'))
                    .margin({ top: 2 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Toggle({ type: ToggleType.Switch, isOn: this.resetOnReachEnd })
                  .onChange((isOn: boolean) => {
                    this.resetOnReachEnd = isOn;
                    AppStorage.setOrCreate('resetOnReachEnd', isOn);
                    TranslationStorage.saveResetOnReachEnd(isOn);
                  })
              }
              .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius(14)
            .shadow({ radius: 4, color: $r('app.color.card_shadow'), offsetY: 1 })
            .margin({ bottom: 12 })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Start)
          .alignItems(HorizontalAlign.Start)
          .padding({ top: 12 })
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
