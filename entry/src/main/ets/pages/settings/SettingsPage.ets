import { AppState, appState } from '../../store/AppState';
import { TranslationStorage } from '../../common/utils/TranslationStorage';
import { PageContext } from '../../common/utils/PageContext';
import { ProxySettingsSection } from './ProxySettingsSection';
import { TranslationSettingsSection } from './TranslationSettingsSection';
import { CacheSettingsSection } from './CacheSettingsSection';

@Component
export struct SettingsPage {
  @StorageLink('appState') appState: AppState = appState;

  @State resetOnReachEnd: boolean = false;

  aboutToAppear() {
    this.resetOnReachEnd = AppStorage.get<boolean>('resetOnReachEnd') ?? false;
  }

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
            TranslationSettingsSection()
            ReadingSettingsCard({ resetOnReachEnd: this.resetOnReachEnd })
            ProxySettingsSection()
            Column() {
              Text('缓存管理')
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.user_name'))
                .width('100%')
                .margin({ bottom: 12 })
              CacheSettingsSection()
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
            .margin({ top: 20 })
          }
          .width('100%')
          .padding({ top: 12 })
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

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.Friction })
      .slide(SlideEffect.Right)
    PageTransitionExit({ duration: 300, curve: Curve.Friction })
      .slide(SlideEffect.Right)
  }
}

@Component
struct ReadingSettingsCard {
  @State resetOnReachEnd: boolean = false;

  build() {
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
}

@Builder
export function SettingsBuilder(): void {
  SettingsPage()
}
