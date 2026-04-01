import router from '@ohos.router';
import { AppState, appState } from '../../store/AppState';

@Component
export struct SettingPage {
  @StorageLink('appState') appState: AppState = appState; // 自动响应变化

  build() {
    Column() {
      this.LoginCard()
      Text('其他设置')
        .fontSize(16)
        .margin({ top: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  LoginCard() {
    Column() {
      if (this.appState.isLoggedIn) {
        Row() {
          Image($r('app.media.avatar_placeholder'))
            .width(48)
            .height(48)
            .borderRadius(24)
          Column() {
            Text(this.appState.userName || '已登录用户')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.user_name'))
            Text('已登录')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 12 })
          Blank()
          Button('退出登录')
            .onClick(async () => {
              await this.appState.logout();
            })
        }
        .width('100%')
        .padding(16)
        .backgroundColor($r('app.color.loading_card'))
        .borderRadius(12)
      } else {
        Row() {
          Image($r('app.media.avatar_placeholder'))
            .width(48)
            .height(48)
            .borderRadius(24)
          Column() {
            Text('登录 Pixiv 账号')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.user_name'))
            Text('登录后可同步收藏、推荐作品')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .fontColor($r('app.color.user_name'))
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 12 })
          Blank()
          Button('去登录')
            .onClick(() => {
              router.pushUrl({ url: 'pages/login/LoginPage' });
            })
        }
        .width('100%')
        .padding(16)
        .backgroundColor($r('app.color.loading_card'))
        .borderRadius(12)
      }
    }
    .margin({ top: 16, left: 16, right: 16 })
  }
}