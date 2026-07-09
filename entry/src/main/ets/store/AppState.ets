import { CookieManager } from '../services/CookieManager';
import { PixivAuth } from '../services/PixivAuth';
import { PixivService } from '../services/PixivService';
import { UserInfoResponse } from '../models/PixivModels';
import { ProxyService } from '../services/ProxyService';
import { ApiConfig } from '../common/constants/ApiConfig';
import http from '@ohos.net.http';
import fileIo from '@ohos.file.fs';

@Observed
export class AppState {
  private static instance: AppState;

  isLoggedIn: boolean = false;
  userId: string = '';
  userName: string = '';
  avatarUrl: string = '';

  private constructor() {}

  static getInstance(): AppState {
    if (!AppState.instance) {
      AppState.instance = new AppState();
    }
    return AppState.instance;
  }

  async checkLoginStatus(skipVerify: boolean = false) {
    try {
      const auth = PixivAuth.getInstance();
      await auth.loadTokens();
      this.isLoggedIn = auth.isLogin();
      AppStorage.setOrCreate('isLoggedIn', this.isLoggedIn);

      if (this.isLoggedIn) {
        this.userId = auth.getUserId();
        this.userName = auth.getUserName();

        const savedAvatarUrl = await CookieManager.getAvatarUrl();
        if (savedAvatarUrl) {
          this.avatarUrl = savedAvatarUrl;
        }

        if (!skipVerify) {
          try {
            const refreshed = await auth.refreshAccessToken();
            if (refreshed) {
              this.userId = auth.getUserId();
              this.userName = auth.getUserName();
            }
          } catch (refreshErr) {
            console.warn('Token 自动刷新失败:', refreshErr);
          }

          try {
            let isValid = await this.verifyTokenValid();
            if (!isValid) {
              console.warn('认证验证失败，自动登出');
              await this.logout();
            }
          } catch (networkErr) {
            console.error('网络异常，认证验证跳过，保持登录状态:', networkErr);
          }
        }
      } else {
        this.userId = '';
        this.userName = '';
      }
      if (this.isLoggedIn) {
        try {
          await this.cacheAvatar();
        } catch (err) {
          console.warn('缓存头像失败:', err);
        }
      }
    } catch (err) {
      console.error('检查登录状态失败', err);
      this.isLoggedIn = false;
      AppStorage.setOrCreate('isLoggedIn', false);
      this.userId = '';
      this.userName = '';
    }
  }

  async verifyTokenValid(): Promise<boolean> {
    const auth = PixivAuth.getInstance();
    if (!auth.isLogin()) return false;
    try {
      const httpRequest = http.createHttp();
      const url = `${ApiConfig.PIXIV_APP}/v2/user/detail?user_id=${this.userId}&filter=for_ios`;
      const header: Record<string, string> = {
        'User-Agent': ApiConfig.USER_AGENT_APP,
        'Authorization': auth.getAuthHeader(),
      };
      const proxyConfig = await ProxyService.getRequestProxyConfig();
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header,
        connectTimeout: 5000,
        readTimeout: 5000,
        usingProxy: proxyConfig || false,
      });
      httpRequest.destroy();
      if (response.responseCode === 200) {
        console.info('Token 有效');
        return true;
      }
      console.warn(`Token 验证失败 HTTP ${response.responseCode}`);
      return false;
    } catch (err) {
      console.error('Token 验证网络异常:', err);
      throw new Error(`NETWORK_ERROR: ${String(err)}`);
    }
  }

  async setLoginInfo(_cookieStr: string, skipVerify: boolean = false) {
    await this.checkLoginStatus(skipVerify);
  }

  async logout() {
    const auth = PixivAuth.getInstance();
    await auth.clearTokens();
    await CookieManager.clearAll();
    this.isLoggedIn = false;
    AppStorage.setOrCreate('isLoggedIn', false);
    this.userId = '';
    this.userName = '';
    this.avatarUrl = '';
  }

  async cacheAvatar(): Promise<void> {
    if (!this.isLoggedIn || !this.userId) return;
    const webUrl = await CookieManager.getAvatarUrl();
    if (!webUrl || !webUrl.startsWith('http')) return;
    const cacheDir: string = PixivService.getCacheDir();
    if (!cacheDir) return;
    const fileName = `avatar_${this.userId}.jpg`;
    const localPath = cacheDir + '/' + fileName;
    try {
      const file = fileIo.openSync(localPath, fileIo.OpenMode.READ_ONLY);
      fileIo.closeSync(file);
      this.avatarUrl = 'file://' + localPath;
      return;
    } catch (_) {}
    const success = await PixivService.downloadImageDirect(webUrl, localPath);
    this.avatarUrl = success ? 'file://' + localPath : webUrl;
    await CookieManager.saveAvatarUrl(this.avatarUrl);
  }

  async refreshUserInfo() {
    if (!this.isLoggedIn || !this.userId) return;
    try {
      const userInfo: UserInfoResponse = await PixivService.getUserProfile(this.userId);
      if (userInfo && !userInfo.error && userInfo.body?.name) {
        this.userName = userInfo.body.name;
        if (userInfo.body.image) {
          await CookieManager.saveAvatarUrl(userInfo.body.image);
          await this.cacheAvatar();
        }
        await CookieManager.saveUserInfo(this.userId, this.userName);
      }
    } catch (err) {
      console.error('刷新用户信息失败', err);
      throw new Error(`刷新用户信息失败: ${err}`);
    }
  }
}

export const appState = AppState.getInstance();