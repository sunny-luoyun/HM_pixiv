import webview from '@ohos.web.webview';
import { PixivAuth } from '../../services/PixivAuth';
import { CookieManager } from '../../services/CookieManager';
import { appState } from '../../store/AppState';

export class LoginPageViewModel {
  errorMessage: string = '';

  async onLoginSuccess(code: string, codeVerifier: string, webviewController: webview.WebviewController): Promise<void> {
    try {
      this.errorMessage = '';
      const auth = PixivAuth.getInstance();

      await auth.loginWithAuthCode(code, codeVerifier);

      const userId = auth.getUserId();
      const userName = auth.getUserName();
      console.info(`OAuth 登录成功: ${userName} (${userId})`);

      appState.userId = userId;
      appState.userName = userName;
      appState.isLoggedIn = true;
      AppStorage.setOrCreate('isLoggedIn', true);

      try {
        const cookieStr = await CookieManager.collectLoginCookies();
        if (cookieStr) {
          console.info('已采集 PHPSESSID 供 Web Ajax 端点使用');
        }
      } catch (err) {
        console.warn('采集 PHPSESSID 失败:', err);
      }

      try {
        await this.fetchAvatarFromWebView(webviewController, userId);
      } catch (err) {
        console.warn('获取头像失败:', err);
      }

      console.info(`登录成功！欢迎 ${userName}`);
    } catch (err) {
      this.errorMessage = `登录处理失败: ${String(err)}`;
      console.error('登录流程异常:', err);
      throw new Error(String(err));
    }
  }

  private async fetchAvatarFromWebView(webviewController: webview.WebviewController, userId: string): Promise<void> {
    try {
      const result = await webviewController.runJavaScript(`
        (function() {
          const img = document.querySelector('img[src*="profile"]');
          return img ? img.src : '';
        })();
      `);
      const avatarUrl = (typeof result === 'string' ? result : '').replace(/^"|"$/g, '');
      if (avatarUrl && avatarUrl.startsWith('http')) {
        await CookieManager.saveAvatarUrl(avatarUrl);
        await appState.cacheAvatar();
        if (appState.avatarUrl) {
          AppStorage.setOrCreate('avatarUrl', appState.avatarUrl);
        }
      }
    } catch (err) {
      console.warn('从 WebView 提取头像失败:', err);
    }
  }
}
