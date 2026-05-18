import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';

export interface PixivTokens {
  access_token: string;
  refresh_token: string;
  expires_in: number;
  obtained_at: number;
}

export class TokenStorage {
  private static PREFERENCES_NAME = 'app_token';
  private static KEY_ACCESS_TOKEN = 'pixiv_access_token';
  private static KEY_REFRESH_TOKEN = 'pixiv_refresh_token';
  private static KEY_EXPIRES_IN = 'pixiv_expires_in';
  private static KEY_OBTAINED_AT = 'pixiv_obtained_at';
  private static context: common.BaseContext;

  static init(context: common.BaseContext) {
    TokenStorage.context = context;
  }

  static async saveTokens(tokens: PixivTokens): Promise<void> {
    if (!TokenStorage.context) throw new Error('TokenStorage not initialized');
    const pref = await preferences.getPreferences(TokenStorage.context, TokenStorage.PREFERENCES_NAME);
    await pref.put(TokenStorage.KEY_ACCESS_TOKEN, tokens.access_token);
    await pref.put(TokenStorage.KEY_REFRESH_TOKEN, tokens.refresh_token);
    await pref.put(TokenStorage.KEY_EXPIRES_IN, tokens.expires_in);
    await pref.put(TokenStorage.KEY_OBTAINED_AT, tokens.obtained_at);
    await pref.flush();
  }

  static async getTokens(): Promise<PixivTokens | null> {
    if (!TokenStorage.context) return null;
    const pref = await preferences.getPreferences(TokenStorage.context, TokenStorage.PREFERENCES_NAME);
    const accessToken = await pref.get(TokenStorage.KEY_ACCESS_TOKEN, '') as string;
    if (!accessToken) return null;
    return {
      access_token: accessToken,
      refresh_token: await pref.get(TokenStorage.KEY_REFRESH_TOKEN, '') as string,
      expires_in: await pref.get(TokenStorage.KEY_EXPIRES_IN, 0) as number,
      obtained_at: await pref.get(TokenStorage.KEY_OBTAINED_AT, 0) as number,
    };
  }

  static async getAccessToken(): Promise<string> {
    const tokens = await TokenStorage.getTokens();
    return tokens?.access_token ?? '';
  }

  static async getRefreshToken(): Promise<string> {
    const tokens = await TokenStorage.getTokens();
    return tokens?.refresh_token ?? '';
  }

  static async isTokenExpired(): Promise<boolean> {
    const tokens = await TokenStorage.getTokens();
    if (!tokens) return true;
    const now = Date.now();
    const expiresMs = tokens.expires_in * 1000;
    return (now - tokens.obtained_at) >= expiresMs;
  }

  static async hasTokens(): Promise<boolean> {
    const accessToken = await TokenStorage.getAccessToken();
    return accessToken !== '';
  }

  static async clearTokens(): Promise<void> {
    if (!TokenStorage.context) return;
    const pref = await preferences.getPreferences(TokenStorage.context, TokenStorage.PREFERENCES_NAME);
    await pref.delete(TokenStorage.KEY_ACCESS_TOKEN);
    await pref.delete(TokenStorage.KEY_REFRESH_TOKEN);
    await pref.delete(TokenStorage.KEY_EXPIRES_IN);
    await pref.delete(TokenStorage.KEY_OBTAINED_AT);
    await pref.flush();
  }
}
