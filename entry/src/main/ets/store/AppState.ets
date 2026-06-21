import { CookieManager } from '../services/CookieManager';
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
      const cookieStr = await CookieManager.getFullCookie();
      this.isLoggedIn = cookieStr !== '';

      if (this.isLoggedIn) {
        const savedUserId = await CookieManager.getUserId();
        const savedUserName = await CookieManager.getUserName();
        if (savedUserId && savedUserName) {
          this.userId = savedUserId;
          this.userName = savedUserName;
        }
        const savedAvatarUrl = await CookieManager.getAvatarUrl();
        if (savedAvatarUrl) {
          this.avatarUrl = savedAvatarUrl;
        }

        if (!skipVerify) {
          try {
            let isValid = await this.verifyCookieWithUserId();

            if (!isValid) {
              console.warn('⚠️ 认证验证失败，自动登出');
              await this.logout();
            }
          } catch (networkErr) {
            console.error('🌐 网络异常，认证验证跳过，保持登录状态:', networkErr);
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
      this.userId = '';
      this.userName = '';
    }
  }

  async verifyCookieWithUserId(): Promise<boolean> {
    if (!this.userId) {
      console.warn('用户ID为空，无法验证');
      return false;
    }
    const url = `${ApiConfig.PIXIV_WEB}/users/${this.userId}`;
    const cookieStr = await CookieManager.getFullCookie();
    const httpRequest = http.createHttp();
    try {
      const header: Record<string, string> = {
        'User-Agent': ApiConfig.USER_AGENT,
        'Referer': ApiConfig.REFERER,
      };
      if (cookieStr) header['Cookie'] = cookieStr;

      const proxyConfig = await ProxyService.getRequestProxyConfig();
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header,
        connectTimeout: 3000,
        readTimeout: 3000,
        usingProxy: proxyConfig || false,
      });
      const statusCode: number = response.responseCode;

      if (statusCode === 200) {
        const body: string = response.result.toString();
        if (body.includes(`"userId":${this.userId}`) || body.includes(`/users/${this.userId}`)) {
          console.info(`✅ 认证有效，用户 ${this.userName} (${this.userId})`);
          return true;
        }
        console.warn(`⚠️ 页面内容异常，可能已登出`);
        return false;
      } else if (statusCode === 401 || statusCode === 403) {
        console.warn(`❌ 认证失效，服务器返回 ${statusCode}`);
        return false;
      } else if (statusCode === 302) {
        const location: string | undefined = (response.header as Record<string, string>)?.['Location'];
        if (location?.includes('/login')) {
          console.warn(`❌ 认证失效，重定向到登录页`);
          return false;
        }
        return true;
      } else {
        console.warn(`⚠️ 非预期状态码 ${statusCode}`);
        return false;
      }
    } catch (err) {
      console.error(`🌐 网络异常: ${err}`);
      throw new Error(`NETWORK_ERROR: ${err}`);
    } finally {
      httpRequest.destroy();
    }
  }

  async setLoginInfo(_cookieStr: string, skipVerify: boolean = false) {
    await this.checkLoginStatus(skipVerify);
  }

  async logout() {
    await CookieManager.clearAll();
    this.isLoggedIn = false;
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