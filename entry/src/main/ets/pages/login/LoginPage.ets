import webview from '@ohos.web.webview';
import { LoginPageViewModel } from './LoginPageViewModel';
import { ApiConfig } from '../../common/constants/ApiConfig';
import { PageContext } from '../../common/utils/PageContext';

@Component
struct LoginPage {
  controller: webview.WebviewController = new webview.WebviewController();
  private viewModel: LoginPageViewModel = new LoginPageViewModel();
  private isHandled: boolean = false;
  private loginUrl: string = ApiConfig.PIXIV_LOGIN;

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.Friction })
      .slide(SlideEffect.Right)
    PageTransitionExit({ duration: 300, curve: Curve.Friction })
      .slide(SlideEffect.Right)
  }

  build() {
    NavDestination() {
      Column() {
        if (this.viewModel.isProcessing) {
          Row() {
            LoadingProgress()
              .width(40)
              .height(40)
              .margin({ right: 10 })
            Text(this.viewModel.statusMessage)
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.surface_secondary'))
          .justifyContent(FlexAlign.Center)
        }

        if (this.viewModel.errorMessage) {
          Row() {
            Image($r('app.media.error'))
              .width(20)
              .height(20)
              .margin({ right: 10 })
            Text(this.viewModel.errorMessage)
              .fontSize(12)
              .fontColor($r('app.color.error'))
              .maxLines(2)
          }
          .width('100%')
          .padding(12)
          .backgroundColor($r('app.color.error_light'))
          .margin({ bottom: 10 })
        }

        Web({ src: this.loginUrl, controller: this.controller })
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .onPageEnd((event) => {
            if (!this.isHandled && event.url?.startsWith('https://www.pixiv.net/')) {
              this.isHandled = true;
              console.info('✅ 检测到登录成功，跳转到Pixiv首页');
              this.handleLoginCompletion();
            }
          })
          .onConsole((event) => {
            console.info('WebView Console:', event.message);
            return true;
          })
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

  private async handleLoginCompletion(): Promise<void> {
    try {
      await this.viewModel.onLoginSuccess(this.controller);
      const pageCtx = AppStorage.get<PageContext>('rootPageContext');
      setTimeout(() => {
        if (pageCtx) { pageCtx.popPage(); }
      }, 1000);
    } catch (err) {
      console.error('❌ 登录处理失败:', err);
    }
  }
}

@Builder
export function LoginBuilder(): void {
  LoginPage()
}