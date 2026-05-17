import router from '@ohos.router';
import { AppState, appState } from '../../store/AppState';
import fileIo from '@ohos.file.fs';
import common from '@ohos.app.ability.common';

@Component
export struct SettingPage {
  @StorageLink('appState') appState: AppState = appState;

  aboutToAppear() {
  }

  private getAvatarUrl(): string {
    if (this.appState.isLoggedIn && this.appState.userId) {
      const appContext = globalThis.appContext as common.UIAbilityContext;
      if (appContext) {
        const localPath = appContext.cacheDir + '/avatar_' + this.appState.userId + '.jpg';
        try {
          const file = fileIo.openSync(localPath, fileIo.OpenMode.READ_ONLY);
          fileIo.closeSync(file);
          return 'file://' + localPath;
        } catch (_) {}
      }
    }
    return '';
  }

  build() {
    Column() {
      this.LoginCard()
      this.MenuSection()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  MenuSection() {
    Column() {
      this.MenuItem('我的作品', () => {})
      this.MenuItem('我的收藏', () => {
        router.pushUrl({ url: 'pages/favorites/FavoritesPage' });
      })
      this.MenuItem('设置', () => {
        router.pushUrl({ url: 'pages/settings/SettingsPage' });
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .margin({ top: 20 })
  }

  @Builder
  MenuItem(title: string, action: () => void) {
    Row() {
      Text(title)
        .fontSize(16)
        .fontColor($r('app.color.user_name'))
      Blank()
      Text('›')
        .fontSize(20)
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .height(50)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.loading_card'))
    .borderRadius(12)
    .margin({ bottom: 10 })
    .onClick(action)
  }

  @Builder
  LoginCard() {
    Column() {
      if (this.appState.isLoggedIn) {
        Row() {
          this.UserAvatar()
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
          this.UserAvatar()
          Column() {
            Text('登录 Pixiv 账号')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.user_name'))
            Text('登录后可同步收藏、推荐作品')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
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

  @Builder
  UserAvatar() {
    if (this.getAvatarUrl()) {
      Image(this.getAvatarUrl())
        .width(48)
        .height(48)
        .borderRadius(24)
        .objectFit(ImageFit.Cover)
    } else {
      Image($r('app.media.avatar_placeholder'))
        .width(48)
        .height(48)
        .borderRadius(24)
    }
  }
}
