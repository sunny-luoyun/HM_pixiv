import { CookieManager } from '../services/CookieManager';
import { PixivService, UserInfoResponse } from '../services/PixivService';
import { OAuthService } from '../services/OAuthService';
import http from '@ohos.net.http';
import fileIo from '@ohos.file.fs';
import common from '@ohos.app.ability.common';

@Observed
export class AppState {
  private static instance: AppState;

  isLoggedIn: boolean = false;
  userId: string = '';
  userName: string = '';
  avatarUrl: string = '';
  hasOAuthTokens: boolean = false;

  private constructor() {}

  static getInstance(): AppState {
    if (!AppState.instance) {
      AppState.instance = new AppState();
    }
    return AppState.instance;
  }

  async checkLoginStatus(skipVerify: boolean = false) {
    try {
      const hasTokens = await CookieManager.hasTokens();
      const cookieStr = await CookieManager.getFullCookie();
      this.hasOAuthTokens = hasTokens;
      this.isLoggedIn = hasTokens || cookieStr !== '';

      if (this.isLoggedIn) {
        const savedUserId = await CookieManager.getUserId();
        const savedUserName = await CookieManager.getUserName();
        if (savedUserId && savedUserName) {
          this.userId = savedUserId;
          this.userName = savedUserName;
        } else if (cookieStr) {
          const cookieMap = CookieManager.parseCookie(cookieStr);
          this.userId = cookieMap.get('user_id') || '';
          this.userName = cookieMap.get('user_name') || '用户';
        }
        const savedAvatarUrl = await CookieManager.getAvatarUrl();
        if (savedAvatarUrl) {
          this.avatarUrl = savedAvatarUrl;
        }

        if (!skipVerify) {
          try {
            let isValid = false;

            if (hasTokens) {
              const expired = await CookieManager.isTokenExpired();
              if (expired) {
                console.info('⏰ Token可能已过期，尝试刷新...');
                const refreshed = await this.tryRefreshToken();
                isValid = refreshed;
              } else {
                isValid = true;
              }
            }

            if (!isValid && cookieStr) {
              try {
                isValid = await this.verifyCookieWithUserId();
              } catch (networkErr) {
                if (hasTokens) {
                  isValid = true;
                } else {
                  throw new Error(String(networkErr));
                }
              }
            }

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

  async tryRefreshToken(): Promise<boolean> {
    try {
      const refreshToken = await CookieManager.getRefreshToken();
      if (!refreshToken) return false;
      const tokenResponse = await OAuthService.refreshAccessToken(refreshToken);
      await CookieManager.saveTokens({
        access_token: tokenResponse.access_token,
        refresh_token: tokenResponse.refresh_token,
        expires_in: tokenResponse.expires_in,
        obtained_at: Date.now(),
      });
      if (tokenResponse.user) {
        this.userId = String(tokenResponse.user.id);
        this.userName = tokenResponse.user.name;
        await CookieManager.saveUserInfo(this.userId, this.userName);
      }
      console.info('✅ Token 刷新成功');
      return true;
    } catch (err) {
      const msg = String(err);
      if (msg.includes('INVALID_REFRESH_TOKEN')) {
        console.warn('⚠️ refresh_token 已失效');
      }
      return false;
    }
  }

  async verifyCookieWithUserId(): Promise<boolean> {
    if (!this.userId) {
      console.warn('用户ID为空，无法验证');
      return false;
    }
    const url = `https://www.pixiv.net/users/${this.userId}`;
    const cookieStr = await CookieManager.getFullCookie();
    const accessToken = await CookieManager.getAccessToken();
    const httpRequest = http.createHttp();
    try {
      const header: Record<string, string> = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://www.pixiv.net/',
      };
      if (cookieStr) header['Cookie'] = cookieStr;
      if (accessToken) header['Authorization'] = `Bearer ${accessToken}`;

      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header,
        connectTimeout: 10000,
        readTimeout: 10000,
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

  async setLoginInfo(cookieStr: string, skipVerify: boolean = false) {
    await CookieManager.saveLoginCookie(cookieStr);
    await this.checkLoginStatus(skipVerify);
  }

  async logout() {
    await CookieManager.clearAll();
    this.isLoggedIn = false;
    this.userId = '';
    this.userName = '';
    this.avatarUrl = '';
    this.hasOAuthTokens = false;
  }

  async cacheAvatar(): Promise<void> {
    if (!this.isLoggedIn || !this.userId) return;
    const webUrl = await CookieManager.getAvatarUrl();
    if (!webUrl || !webUrl.startsWith('http')) return;
    const appContext: common.UIAbilityContext = globalThis.appContext as common.UIAbilityContext;
    if (!appContext) return;
    const cacheDir: string = appContext.cacheDir;
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