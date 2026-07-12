import { AppState, appState } from '../../store/AppState';
import { PixivService } from '../../services/PixivService';
import fileIo from '@ohos.file.fs';
import { PageContext } from '../../common/utils/PageContext';
import { PageEnum } from '../../common/constants/PageEnum';

@Component
export struct SettingPage {
  @StorageLink('appState') appState: AppState = appState;

  aboutToAppear() {
  }

  private getAvatarUrl(): string {
    if (this.appState.isLoggedIn && this.appState.userId) {
      const cacheDir = PixivService.getCacheDir();
      if (cacheDir) {
        const localPath = cacheDir + '/avatar_' + this.appState.userId + '.jpg';
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
    .padding({ bottom: 80 })
  }

  @Builder
  MenuSection() {
    Column() {
      this.MenuItem('◉', '我的关注', () => {
        const pageCtx = AppStorage.get<PageContext>('rootPageContext');
        if (pageCtx) { pageCtx.openPage(PageEnum.FOLLOWING); }
      })
      this.MenuItem('◎', '我的缓存', () => {
        const pageCtx = AppStorage.get<PageContext>('rootPageContext');
        if (pageCtx) { pageCtx.openPage(PageEnum.CACHED_NOVELS); }
      })
      this.MenuItem('✦', '我的收藏', () => {
        const pageCtx = AppStorage.get<PageContext>('rootPageContext');
        if (pageCtx) { pageCtx.openPage(PageEnum.FAVORITES); }
      })
      this.MenuItem('🕐', '浏览历史', () => {
        const pageCtx = AppStorage.get<PageContext>('rootPageContext');
        if (pageCtx) { pageCtx.openPage(PageEnum.BROWSE_HISTORY); }
      })
      this.MenuItem('🚫', '屏蔽内容', () => {
        const pageCtx = AppStorage.get<PageContext>('rootPageContext');
        if (pageCtx) { pageCtx.openPage(PageEnum.BLOCKED_CONTENT); }
      })
      this.MenuItem('⚙', '设置', () => {
        const pageCtx = AppStorage.get<PageContext>('rootPageContext');
        if (pageCtx) { pageCtx.openPage(PageEnum.SETTINGS); }
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .margin({ top: 20 })
  }

  @Builder
  MenuItem(icon: string, title: string, action: () => void) {
    Row() {
      Text(icon)
        .fontSize(18)
        .fontColor($r('app.color.tab_selected'))
        .width(28)
        .textAlign(TextAlign.Center)
      Text(title)
        .fontSize(16)
        .fontColor($r('app.color.user_name'))
        .margin({ left: 12 })
      Blank()
      Text('›')
        .fontSize(20)
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .height(54)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(14)
    .margin({ bottom: 10})
    .shadow({ radius: 4, color: $r('app.color.card_shadow'), offsetY: 1 })
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
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius(14)
        .shadow({ radius: 4, color: $r('app.color.card_shadow'), offsetY: 1 })
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
              const pageCtx = AppStorage.get<PageContext>('rootPageContext');
              if (pageCtx) { pageCtx.openPage(PageEnum.LOGIN); }
            })
        }
        .width('100%')
        .padding(16)
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius(14)
        .shadow({ radius: 4, color: $r('app.color.card_shadow'), offsetY: 1 })
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
