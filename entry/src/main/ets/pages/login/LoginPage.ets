// entry/src/main/ets/pages/login/LoginPage.ets
import webview from '@ohos.web.webview';
import router from '@ohos.router';
import { LoginPageViewModel } from './LoginPageViewModel';

@Entry
@Component
struct LoginPage {
  controller: webview.WebviewController = new webview.WebviewController();
  private viewModel: LoginPageViewModel = new LoginPageViewModel();
  private isHandled: boolean = false;

  build() {
    Column() {
      // 加载条
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

      // 错误提示
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

      // WebView
      Web({ src: 'https://accounts.pixiv.net/login', controller: this.controller })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .onPageEnd((event) => {
          if (!this.isHandled && event.url?.startsWith('https://www.pixiv.net/')) {
            this.isHandled = true;
            console.info('✅ 检测到登录成功，已跳转到Pixiv首页');
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

  /**
   * 处理登录完成 - 委托给ViewModel和Service
   */
  private async handleLoginCompletion(): Promise<void> {
    try {
      await this.viewModel.onLoginSuccess(this.controller);

      // 登录成功后返回上一页
      setTimeout(() => {
        router.back();
      }, 1000);
    } catch (err) {
      console.error('❌ 登录处理失败:', err);
      // UI会通过viewModel.errorMessage显示错误
    }
  }
}