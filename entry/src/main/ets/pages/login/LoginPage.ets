import webview from '@ohos.web.webview';
import cryptoFramework from '@ohos.security.cryptoFramework';
import buffer from '@ohos.buffer';
import util from '@ohos.util';
import { LoginPageViewModel } from './LoginPageViewModel';
import { ApiConfig } from '../../common/constants/ApiConfig';
import { PageContext } from '../../common/utils/PageContext';
import { BusinessError } from '@kit.BasicServicesKit';

@Component
struct LoginPage {
  controller: webview.WebviewController = new webview.WebviewController();
  private viewModel: LoginPageViewModel = new LoginPageViewModel();
  private isHandled: boolean = false;
  @State loginUrl: string = '';
  private codeVerifier: string = '';
  @State isLoading: boolean = true;
  @State loadMessage: string = '正在准备登录...';

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.Friction })
      .slide(SlideEffect.Right)
    PageTransitionExit({ duration: 300, curve: Curve.Friction })
      .slide(SlideEffect.Right)
  }

  async aboutToAppear(): Promise<void> {
    this.isLoading = true;
    this.loadMessage = '正在准备登录...';
    try {
      this.codeVerifier = this.generateRandomString(64);
      const codeChallenge = await this.generateCodeChallenge(this.codeVerifier);
      this.loginUrl = `${ApiConfig.OAUTH_LOGIN}?code_challenge=${codeChallenge}&code_challenge_method=S256&client=pixiv-android&redirect_uri=${encodeURIComponent(ApiConfig.REDIRECT_URI)}&state=login`;
      console.info(`登录 URL: ${this.loginUrl}`);
    } catch (err) {
      console.error('初始化登录失败:', err);
      this.loadMessage = '初始化失败，请重试';
    }
    this.isLoading = false;
  }

  build() {
    NavDestination() {
      Column() {
        if (this.isLoading) {
          Column({ space: 12 }) {
            LoadingProgress()
              .width(40)
              .height(40)
            Text(this.loadMessage)
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
            Text(this.viewModel.errorMessage)
              .fontSize(12)
              .fontColor($r('app.color.error'))
              .maxLines(3)
          }
          .width('100%')
          .padding(12)
          .backgroundColor($r('app.color.error_light'))
          .margin({ bottom: 10 })
        }

        Web({ src: this.loginUrl, controller: this.controller })
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .onAppear(() => {
            if (this.loginUrl) {
              this.controller.loadUrl(this.loginUrl);
            }
          })
          .onPageBegin((event) => {
            const url = event.url || '';
            if (!this.isHandled && url.startsWith('pixiv://account/login')) {
              this.isHandled = true;
              console.info('检测到 Pixiv OAuth 回调');
              this.handleCallback(url);
              return;
            }
            this.isLoading = true;
            this.loadMessage = '正在加载登录页面...';
          })
          .onPageEnd(() => {
            this.isLoading = false;
          })
          .onErrorReceive((event) => {
            const errorUrl = event?.request?.getRequestUrl() || '';
            if (errorUrl.startsWith('pixiv://')) return;
            console.error('WebView 错误:', event?.error?.getErrorInfo?.() || '');
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

  private async handleCallback(url: string): Promise<void> {
    this.isLoading = true;
    this.loadMessage = '正在验证身份...';
    const codeMatch = url.match(/[?&]code=([^&]+)/);
    if (!codeMatch) {
      this.viewModel.errorMessage = '登录失败：未获取到授权码';
      this.isLoading = false;
      return;
    }
    const code = decodeURIComponent(codeMatch[1]);
    try {
      await this.viewModel.onLoginSuccess(code, this.codeVerifier, this.controller);
      const pageCtx = AppStorage.get<PageContext>('rootPageContext');
      setTimeout(() => {
        if (pageCtx) { pageCtx.popPage(); }
      }, 1000);
    } catch (err) {
      console.error('登录处理失败:', err);
      this.isLoading = false;
    }
  }

  private generateRandomString(length: number): string {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    let result = '';
    for (let i = 0; i < length; i++) {
      result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return result;
  }

  private async generateCodeChallenge(verifier: string): Promise<string> {
    const mdAlg = cryptoFramework.createMd('SHA256');
    const data = new Uint8Array(buffer.from(verifier, 'utf-8').buffer);
    const input: cryptoFramework.DataBlob = { data: data };
    await mdAlg.update(input);
    const digest = await mdAlg.digest();
    const base64Helper = new util.Base64Helper();
    const base64Str = base64Helper.encodeToStringSync(digest.data);
    return base64Str
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=+$/, '');
  }
}

@Builder
export function LoginBuilder(): void {
  LoginPage()
}
