import { BaseState } from './BaseState';
import { BaseVM, BaseVMEvent } from './BaseVM';
import { LoginService, LoginUserData } from '../services/LoginService';
import { PixivService } from '../services/PixivService';
import { CookieManager } from '../services/CookieManager';
import { appState } from '../store/AppState';
import webview from '@ohos.web.webview';

export class LoginEventType {
  static readonly LOGIN_SUCCESS = 'LOGIN_SUCCESS';
  static readonly EXTRACT_USER_INFO = 'EXTRACT_USER_INFO';
}

@Observed
export class LoginState extends BaseState {
  isProcessing: boolean = false;
  statusMessage: string = '';
  errorMessage: string = '';
  loginComplete: boolean = false;
}

export class LoginViewModel extends BaseVM<LoginState> {
  private static instance: LoginViewModel;

  static getInstance(): LoginViewModel {
    if (!LoginViewModel.instance) {
      LoginViewModel.instance = new LoginViewModel();
    }
    return LoginViewModel.instance;
  }

  private constructor() {
    super(new LoginState());
  }

  sendEvent(event: BaseVMEvent): void {
    switch (event.type) {
      case LoginEventType.LOGIN_SUCCESS: {
        const controller = (event.param as Record<string, webview.WebviewController>)['controller'];
        if (controller) this.onLoginSuccess(controller);
        break;
      }
      case LoginEventType.EXTRACT_USER_INFO: {
        const controller = (event.param as Record<string, webview.WebviewController>)['controller'];
        if (controller) this.extractUserInfoFromDOM(controller);
        break;
      }
    }
  }

  async onLoginSuccess(webController: webview.WebviewController): Promise<void> {
    const state = this.state;
    try {
      state.isProcessing = true;
      state.statusMessage = '正在处理登录信息...';
      state.errorMessage = '';

      await LoginService.handleLoginSuccess();

      const userData = await LoginService.extractUserInfoWithRetry(
        () => this.extractUserInfoFromDOM(webController)
      );

      await LoginService.saveUserInfo(userData);

      await this.fetchAvatar(userData.userId);

      state.statusMessage = `登录成功！欢迎 ${userData.userName}`;
      state.isProcessing = false;
      state.loginComplete = true;
    } catch (err) {
      state.errorMessage = `登录处理失败: ${String(err)}`;
      state.isProcessing = false;
      console.error('登录流程异常:', err);
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
          AppStorage.setOrCreate('avatarUrl', appState.avatarUrl);
        }
      }
    } catch (err) {
      console.warn('获取头像失败:', err);
    }
  }

  private async extractUserInfoFromDOM(webController: webview.WebviewController): Promise<LoginUserData> {
    try {
      const result = await webController.runJavaScript(`
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
      let parseGuard: number = 0;
      while (typeof parsed === 'string' && parseGuard < 10) {
        parseGuard++;
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
