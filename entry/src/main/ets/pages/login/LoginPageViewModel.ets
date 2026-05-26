import webview from '@ohos.web.webview';
import { LoginService, LoginUserData } from '../../services/LoginService';
import { PixivService } from '../../services/PixivService';
import { CookieManager } from '../../services/CookieManager';
import { appState } from '../../store/AppState';

export class LoginPageViewModel {
  isProcessing: boolean = false;
  statusMessage: string = '';
  errorMessage: string = '';

  async onLoginSuccess(webviewController: webview.WebviewController): Promise<void> {
    try {
      this.isProcessing = true;
      this.statusMessage = '正在处理登录信息...';
      this.errorMessage = '';

      await LoginService.handleLoginSuccess();

      const userData = await LoginService.extractUserInfoWithRetry(
        () => this.extractUserInfoFromDOM(webviewController)
      );

      await LoginService.saveUserInfo(userData);

      await this.fetchAvatar(userData.userId);

      this.statusMessage = `登录成功！欢迎 ${userData.userName}`;
      this.isProcessing = false;
    } catch (err) {
      this.errorMessage = `登录处理失败: ${String(err)}`;
      this.isProcessing = false;
      console.error('❌ 登录流程异常:', err);
      throw new Error(String(err));
    }
  }

  private async fetchAvatar(userId: string): Promise<void> {
    try {
      const userInfo = await PixivService.getUserProfile(userId);
      const avatarUrl = userInfo?.body?.image || userInfo?.body?.imageBig || '';
      if (avatarUrl) {
        await CookieManager.saveAvatarUrl(avatarUrl);
        await appState.cacheAvatar();
        if (appState.avatarUrl) {
          AppStorage.SetOrCreate('avatarUrl', appState.avatarUrl);
        }
      }
    } catch (err) {
      console.warn('⚠️ 获取头像失败:', err);
    }
  }

  private async extractUserInfoFromDOM(webviewController: webview.WebviewController): Promise<LoginUserData> {
    try {
      const result = await webviewController.runJavaScript(`
        (function() {
          let userName = '';
          let userId = '';
          const userLinks = document.querySelectorAll('a[href*="/users/"]');
          if (userLinks.length > 0) {
            for (let i = 0; i < Math.min(5, userLinks.length); i++) {
              const link = userLinks[i];
              const linkText = (link.innerText || link.textContent || '').trim();
              const href = link.href || '';
              if (linkText && !/^\\d+\\s*(已关注|粉丝|作品|收藏|关注|粉丝数)/.test(linkText)) {
                const match = href.match(/\\/users\\/(\\d+)/);
                if (match && match[1]) {
                  userId = match[1];
                  userName = linkText;
                  break;
                }
              }
            }
          }
          return JSON.stringify({ userName, userId, success: !!(userName && userId) });
        })();
      `);

      let parsed: LoginUserData | string = result;
      while (typeof parsed === 'string') {
        try {
          parsed = JSON.parse(parsed);
        } catch (e) {
          break;
        }
      }

      if (parsed && typeof parsed === 'object') {
        return parsed as LoginUserData;
      }
      return { success: false, userName: '', userId: '', error: '解析失败' };
    } catch (err) {
      throw new Error(`DOM提取失败: ${String(err)}`);
    }
  }
}