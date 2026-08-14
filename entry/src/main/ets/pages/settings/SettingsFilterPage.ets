import { TranslationStorage } from '../../common/utils/TranslationStorage';
import { PageContext } from '../../common/utils/PageContext';

@Builder
export function SettingsFilterBuilder(): void {
  SettingsFilterPage()
}

@Component
export struct SettingsFilterPage {
  @State filterEnabled: boolean = true;
  @State maxNovelTags: number = 50;
  @State inputText: string = '';

  aboutToAppear() {
    this.filterEnabled = AppStorage.get<boolean>('novelTagFilterEnabled') ?? false;
    const val = AppStorage.get<number>('maxNovelTags') ?? 50;
    this.maxNovelTags = val;
    this.inputText = String(val);
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
          Text('过滤设置')
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
                  Text('标签数过滤')
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.user_name'))
                  Text('隐藏标签数量超过限制的盗版小说（按 / 拆分统计）')
                    .fontSize(12)
                    .fontColor($r('app.color.text_secondary'))
                    .margin({ top: 2 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Toggle({ type: ToggleType.Switch, isOn: this.filterEnabled })
                  .onChange((isOn: boolean) => {
                    this.filterEnabled = isOn;
                    AppStorage.setOrCreate('novelTagFilterEnabled', isOn);
                    TranslationStorage.saveNovelTagFilterEnabled(isOn);
                  })
              }
              .width('100%')

              if (this.filterEnabled) {
                Row() {
                  TextInput({ text: this.inputText, placeholder: '50' })
                    .width(80)
                    .height(36)
                    .type(InputType.Number)
                    .onChange((val: string) => {
                      this.inputText = val;
                      const n: number = parseInt(val) || 0;
                      const clamped: number = n < 0 ? 0 : n;
                      this.maxNovelTags = clamped;
                      AppStorage.setOrCreate('maxNovelTags', clamped);
                      TranslationStorage.saveMaxNovelTags(clamped);
                    })
                  Text(' 个标签')
                    .fontSize(14)
                    .fontColor($r('app.color.text_secondary'))
                    .margin({ left: 8 })
                  Blank()
                }
                .width('100%')
                .margin({ top: 12 })

                Text('设为 0 关闭过滤，默认 50')
                  .fontSize(11)
                  .fontColor($r('app.color.text_secondary'))
                  .width('100%')
                  .margin({ top: 6 })
              }
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius(14)
            .shadow({ radius: 4, color: $r('app.color.card_shadow'), offsetY: 1 })
            .margin({ bottom: 12 })
          }
          .width('100%')
          .constraintSize({ minHeight: '100%' })
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
