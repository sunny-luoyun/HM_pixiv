import webview from '@ohos.web.webview';
import router from '@ohos.router';
import { LoginPageViewModel } from './LoginPageViewModel';
import { OAuthService } from '../../services/OAuthService';

@Entry
@Component
struct LoginPage {
  controller: webview.WebviewController = new webview.WebviewController();
  private viewModel: LoginPageViewModel = new LoginPageViewModel();
  private isHandled: boolean = false;
  private loginUrl: string = 'https://accounts.pixiv.net/login';

  aboutToAppear() {
    this.viewModel.initOAuth().then(() => {
      this.loginUrl = OAuthService.getLoginUrl();
    });
  }

  build() {
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
        .onLoadIntercept((event) => {
          const url = event?.data?.getRequestUrl?.() ?? '';
          if (OAuthService.isCallbackUrl(url)) {
            if (!this.isHandled) {
              this.isHandled = true;
              const code = OAuthService.extractCodeFromUrl(url);
              if (code) {
                console.info('✅ 拦截到OAuth回调，提取授权码');
                this.handleOAuthCallback(code);
              }
            }
            return true;
          }
          return false;
        })
        .onPageEnd((event) => {
          if (!this.isHandled && event.url?.startsWith('https://www.pixiv.net/')) {
            this.isHandled = true;
            console.info('✅ 检测到登录成功（回退方案），跳转到Pixiv首页');
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

  private async handleOAuthCallback(code: string): Promise<void> {
    try {
      await this.viewModel.onOAuthCodeReceived(code);
      setTimeout(() => { router.back(); }, 1000);
    } catch (err) {
      console.error('❌ OAuth登录处理失败:', err);
    }
  }

  private async handleLoginCompletion(): Promise<void> {
    try {
      await this.viewModel.onLoginSuccess(this.controller);
      setTimeout(() => { router.back(); }, 1000);
    } catch (err) {
      console.error('❌ 登录处理失败:', err);
    }
  }
}