import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';
import http from '@ohos.net.http';
import { md5String } from '../common/utils/MD5';
import { Date2UTCTimeString } from '../common/utils/TimeUtils';
import { ApiConfig } from '../common/constants/ApiConfig';

interface OAuthTokenProfileImageUrls {
  px_50x50?: string;
  px_170x170?: string;
}

interface OAuthTokenUser {
  id: string;
  name: string;
  account: string;
  mail_address?: string;
  profile_image_urls?: OAuthTokenProfileImageUrls;
}

interface OAuthTokenResponse {
  access_token: string;
  refresh_token: string;
  expires_in: number;
  token_type: string;
  scope: string;
  user: OAuthTokenUser;
}

export class PixivAuth {
  private static instance: PixivAuth;
  private static context: common.BaseContext;
  private static readonly PREF_NAME = 'app_auth';
  private static readonly KEY_ACCESS_TOKEN = 'access_token';
  private static readonly KEY_REFRESH_TOKEN = 'refresh_token';
  private static readonly KEY_USER_ID = 'oauth_user_id';
  private static readonly KEY_USER_NAME = 'oauth_user_name';

  private accessToken: string = '';
  private refreshToken: string = '';
  private userId: string = '';
  private userName: string = '';
  private refreshingPromise: Promise<boolean> | null = null;

  static getInstance(): PixivAuth {
    if (!PixivAuth.instance) {
      PixivAuth.instance = new PixivAuth();
    }
    return PixivAuth.instance;
  }

  static init(context: common.BaseContext) {
    PixivAuth.context = context;
  }

  async loadTokens(): Promise<void> {
    if (!PixivAuth.context) return;
    try {
      const pref = await preferences.getPreferences(PixivAuth.context, PixivAuth.PREF_NAME);
      this.accessToken = await pref.get(PixivAuth.KEY_ACCESS_TOKEN, '') as string;
      this.refreshToken = await pref.get(PixivAuth.KEY_REFRESH_TOKEN, '') as string;
      this.userId = await pref.get(PixivAuth.KEY_USER_ID, '') as string;
      this.userName = await pref.get(PixivAuth.KEY_USER_NAME, '') as string;
      console.info(`PixivAuth: 加载 Token 完成, userId=${this.userId}`);
    } catch (err) {
      console.warn('PixivAuth: 加载 Token 失败', err);
    }
  }

  async saveTokens(): Promise<void> {
    if (!PixivAuth.context) return;
    try {
      const pref = await preferences.getPreferences(PixivAuth.context, PixivAuth.PREF_NAME);
      await pref.put(PixivAuth.KEY_ACCESS_TOKEN, this.accessToken);
      await pref.put(PixivAuth.KEY_REFRESH_TOKEN, this.refreshToken);
      await pref.put(PixivAuth.KEY_USER_ID, this.userId);
      await pref.put(PixivAuth.KEY_USER_NAME, this.userName);
      await pref.flush();
      console.info('PixivAuth: Token 已保存');
    } catch (err) {
      console.error('PixivAuth: 保存 Token 失败', err);
    }
  }

  async clearTokens(): Promise<void> {
    this.accessToken = '';
    this.refreshToken = '';
    this.userId = '';
    this.userName = '';
    if (!PixivAuth.context) return;
    try {
      const pref = await preferences.getPreferences(PixivAuth.context, PixivAuth.PREF_NAME);
      await pref.delete(PixivAuth.KEY_ACCESS_TOKEN);
      await pref.delete(PixivAuth.KEY_REFRESH_TOKEN);
      await pref.delete(PixivAuth.KEY_USER_ID);
      await pref.delete(PixivAuth.KEY_USER_NAME);
      await pref.flush();
    } catch (err) {
      console.warn('PixivAuth: 清除 Token 失败', err);
    }
  }

  isLogin(): boolean {
    return this.accessToken.length > 0;
  }

  getAccessToken(): string {
    return this.accessToken;
  }

  getRefreshToken(): string {
    return this.refreshToken;
  }

  getUserId(): string {
    return this.userId;
  }

  getUserName(): string {
    return this.userName;
  }

  getAuthHeader(): string {
    if (!this.accessToken) return '';
    return `Bearer ${this.accessToken}`;
  }

  async loginWithAuthCode(code: string, codeVerifier: string): Promise<void> {
    console.info('PixivAuth: 使用授权码登录...');
    const now = new Date();
    const localTime = Date2UTCTimeString(now);
    const hashString = `${localTime}${ApiConfig.HASH_SECRET}`;
    const clientHash = await md5String(hashString);

    const body = [
      `client_id=${encodeURIComponent(ApiConfig.CLIENT_ID)}`,
      `client_secret=${encodeURIComponent(ApiConfig.CLIENT_SECRET)}`,
      `get_secure_url=1`,
      `grant_type=authorization_code`,
      `code=${encodeURIComponent(code)}`,
      `code_verifier=${encodeURIComponent(codeVerifier)}`,
      `redirect_uri=${encodeURIComponent(ApiConfig.REDIRECT_URI)}`,
      `include_policy=true`,
    ].join('&');

    const resp = await this.postAuthToken(body, localTime, clientHash);
    await this.handleTokenResponse(resp);
  }

  async loginWithRefreshToken(token: string): Promise<boolean> {
    console.info('PixivAuth: 使用 Refresh Token 登录...');
    const now = new Date();
    const localTime = Date2UTCTimeString(now);
    const hashString = `${localTime}${ApiConfig.HASH_SECRET}`;
    const clientHash = await md5String(hashString);

    const body = [
      `client_id=${encodeURIComponent(ApiConfig.CLIENT_ID)}`,
      `client_secret=${encodeURIComponent(ApiConfig.CLIENT_SECRET)}`,
      `get_secure_url=1`,
      `grant_type=refresh_token`,
      `refresh_token=${encodeURIComponent(token)}`,
    ].join('&');

    try {
      const resp = await this.postAuthToken(body, localTime, clientHash);
      await this.handleTokenResponse(resp);
      return true;
    } catch (err) {
      console.error('PixivAuth: Refresh Token 登录失败', err);
      return false;
    }
  }

  async refreshAccessToken(): Promise<boolean> {
    if (!this.refreshToken) {
      console.warn('PixivAuth: 无 Refresh Token');
      return false;
    }
    if (this.refreshingPromise) {
      console.info('PixivAuth: Token 刷新进行中，等待...');
      return this.refreshingPromise;
    }
    this.refreshingPromise = this.doRefresh();
    try {
      const result = await this.refreshingPromise;
      return result;
    } finally {
      this.refreshingPromise = null;
    }
  }

  private async doRefresh(): Promise<boolean> {
    console.info('PixivAuth: 正在刷新 Token...');
    return await this.loginWithRefreshToken(this.refreshToken);
  }

  private async postAuthToken(body: string, localTime: string, clientHash: string): Promise<OAuthTokenResponse> {
    const httpRequest = http.createHttp();
    try {
      const resp = await httpRequest.request(ApiConfig.OAUTH_TOKEN, {
        method: http.RequestMethod.POST,
        header: {
          'User-Agent': ApiConfig.USER_AGENT_APP,
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded',
          'X-Client-Time': localTime,
          'X-Client-Hash': clientHash,
          'App-OS': 'android',
          'App-OS-Version': '11.0',
          'App-Version': '5.0.234',
        },
        extraData: body,
        connectTimeout: 10000,
        readTimeout: 10000,
      });
interface OAuthTokenApiResponse {
  response?: OAuthTokenResponse;
}

// ... later in postAuthToken method:

      if (resp.responseCode === 200) {
        const data: OAuthTokenApiResponse = JSON.parse(resp.result as string) as OAuthTokenApiResponse;
        if (data.response) {
          return data.response;
        }
        throw new Error(`OAuth 响应格式异常: ${resp.result}`);
      }
      throw new Error(`OAuth 请求失败 HTTP ${resp.responseCode}: ${resp.result}`);
    } finally {
      httpRequest.destroy();
    }
  }

  private async handleTokenResponse(resp: OAuthTokenResponse): Promise<void> {
    this.accessToken = resp.access_token;
    this.refreshToken = resp.refresh_token;
    if (resp.user) {
      this.userId = String(resp.user.id);
      this.userName = resp.user.name;
    }
    await this.saveTokens();
    console.info(`PixivAuth: 登录成功, userId=${this.userId}, name=${this.userName}`);
  }
}
