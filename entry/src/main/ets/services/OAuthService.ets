import http from '@ohos.net.http';
import cryptoFramework from '@ohos.security.cryptoFramework';
import util from '@ohos.util';

export interface TokenResponse {
  access_token: string;
  expires_in: number;
  refresh_token: string;
  scope: string;
  token_type: string;
  user?: TokenUser;
}

export interface ProfileImageUrls {
  px_16x16?: string;
  px_50x50?: string;
  px_170x170?: string;
}

export interface TokenUser {
  id: number;
  name: string;
  account: string;
  profile_image_urls?: ProfileImageUrls;
  is_premium?: boolean;
}

interface OAuthErrorResponse {
  error: string;
  error_description: string;
}

export class OAuthService {
  private static readonly CLIENT_ID = 'MOBrBDS8blbauoSck0ZfDbtuzpyT';
  private static readonly CLIENT_SECRET = 'lsACyCD94FhDUtGTXi3QzcFE2uU1hqtDaKeqrdwj';
  private static readonly TOKEN_URL = 'https://oauth.secure.pixiv.net/auth/token';
  private static readonly REDIRECT_URI = 'https://app-api.pixiv.net/web/v1/users/auth/pixiv/callback';
  private static readonly CALLBACK_SCHEME = 'pixiv://account/login';

  private static codeVerifier: string = '';
  private static codeChallenge: string = '';

  static hasPendingPKCE(): boolean {
    return OAuthService.codeVerifier !== '';
  }

  static generateCodeVerifier(): string {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    let result = '';
    for (let i = 0; i < 64; i++) {
      result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return result;
  }

  static async generateCodeChallenge(verifier: string): Promise<string> {
    const encoder = new util.TextEncoder();
    const inputData = encoder.encodeInto(verifier);
    const md = cryptoFramework.createMd('SHA256');
    await md.update({ data: inputData });
    const digest = await md.digest();
    const base64 = new util.Base64Helper();
    const encoded = await base64.encodeToString(digest.data);
    return encoded.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  }

  static async generatePKCE(): Promise<void> {
    OAuthService.codeVerifier = OAuthService.generateCodeVerifier();
    OAuthService.codeChallenge = await OAuthService.generateCodeChallenge(OAuthService.codeVerifier);
  }

  static getLoginUrl(): string {
    if (!OAuthService.codeChallenge) {
      return 'https://accounts.pixiv.net/login';
    }
    return `https://app-api.pixiv.net/web/v1/login?code_challenge=${OAuthService.codeChallenge}&code_challenge_method=S256&client=pixiv-android`;
  }

  static isCallbackUrl(url: string): boolean {
    return url.startsWith(OAuthService.CALLBACK_SCHEME);
  }

  static extractCodeFromUrl(url: string): string | null {
    try {
      const queryStart = url.indexOf('?');
      if (queryStart === -1) return null;
      const query = url.substring(queryStart + 1);
      const params = query.split('&');
      for (const param of params) {
        const parts = param.split('=');
        if (parts.length === 2 && parts[0] === 'code') {
          return decodeURIComponent(parts[1]);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static async exchangeCodeForToken(code: string): Promise<TokenResponse> {
    if (!OAuthService.codeVerifier) {
      throw new Error('No pending PKCE challenge');
    }

    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(OAuthService.TOKEN_URL, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'PixivAndroidApp/5.0.234 (Android 11; Pixel 5)',
          'Accept': 'application/json',
        },
        extraData: OAuthService.buildFormData({
          'client_id': OAuthService.CLIENT_ID,
          'client_secret': OAuthService.CLIENT_SECRET,
          'grant_type': 'authorization_code',
          'code': code,
          'code_verifier': OAuthService.codeVerifier,
          'redirect_uri': OAuthService.REDIRECT_URI,
          'include_policy': 'true',
        }),
      });

      if (response.responseCode === 200) {
        OAuthService.codeVerifier = '';
        OAuthService.codeChallenge = '';
        return JSON.parse(response.result as string) as TokenResponse;
      }

      let errMsg = `HTTP ${response.responseCode}`;
      try {
        const errBody = JSON.parse(response.result as string) as OAuthErrorResponse;
        errMsg = `${errBody.error}: ${errBody.error_description}`;
      } catch (_) {}
      throw new Error(`Token exchange failed: ${errMsg}`);
    } finally {
      httpRequest.destroy();
    }
  }

  static async refreshAccessToken(refreshToken: string): Promise<TokenResponse> {
    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(OAuthService.TOKEN_URL, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'PixivAndroidApp/5.0.234 (Android 11; Pixel 5)',
          'Accept': 'application/json',
        },
        extraData: OAuthService.buildFormData({
          'client_id': OAuthService.CLIENT_ID,
          'client_secret': OAuthService.CLIENT_SECRET,
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          'include_policy': 'true',
        }),
      });

      if (response.responseCode === 200) {
        return JSON.parse(response.result as string) as TokenResponse;
      }

      let errMsg = `HTTP ${response.responseCode}`;
      try {
        const errBody = JSON.parse(response.result as string) as OAuthErrorResponse;
        if (errBody.error === 'invalid_grant' &&
          errBody.error_description?.includes('Invalid refresh token')) {
          throw new Error('INVALID_REFRESH_TOKEN');
        }
        errMsg = `${errBody.error}: ${errBody.error_description}`;
      } catch (e) {
        if (e instanceof Error && e.message === 'INVALID_REFRESH_TOKEN') throw e;
      }
      throw new Error(`Token refresh failed: ${errMsg}`);
    } finally {
      httpRequest.destroy();
    }
  }

  private static buildFormData(params: Record<string, string>): string {
    return Object.entries(params)
      .map((entry: [string, string]) => `${encodeURIComponent(entry[0])}=${encodeURIComponent(entry[1])}`)
      .join('&');
  }
}
