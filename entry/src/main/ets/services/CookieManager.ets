import webview from '@ohos.web.webview';
import { CookieStorage } from '../common/utils/CookieStorage';
import { TokenStorage, PixivTokens } from '../common/utils/TokenStorage';

export class CookieManager {
  private static readonly DOMAINS = [
    'https://accounts.pixiv.net',
    'https://www.pixiv.net'
  ];

  static async collectLoginCookies(): Promise<string> {
    const allCookies: string[] = [];
    for (const domain of CookieManager.DOMAINS) {
      try {
        const cookie = webview.WebCookieManager.getCookie(domain);
        if (cookie) allCookies.push(cookie);
      } catch (e) {
        console.warn(`获取 ${domain} cookie 失败: ${e}`);
      }
    }
    const cookieMap = new Map<string, string>();
    for (const cookieStr of allCookies) {
      cookieStr.split(';').forEach(pair => {
        const trimmed = pair.trim();
        if (!trimmed) return;
        const eqIndex = trimmed.indexOf('=');
        if (eqIndex === -1) return;
        const key = trimmed.slice(0, eqIndex);
        const value = trimmed.slice(eqIndex + 1);
        cookieMap.set(key, value);
      });
    }
    if (!cookieMap.has('PHPSESSID')) {
      console.warn('未找到 PHPSESSID，登录可能失败');
    }
    return Array.from(cookieMap.entries())
      .map(entry => `${entry[0]}=${entry[1]}`)
      .join('; ');
  }

  static parseCookie(cookieStr: string): Map<string, string> {
    const map = new Map<string, string>();
    if (!cookieStr) return map;
    cookieStr.split(';').forEach(pair => {
      const trimmed = pair.trim();
      if (!trimmed) return;
      const eqIndex = trimmed.indexOf('=');
      if (eqIndex === -1) return;
      let key = trimmed.slice(0, eqIndex);
      let value = trimmed.slice(eqIndex + 1);
      try {
        value = decodeURIComponent(value);
      } catch (e) {}
      map.set(key, value);
    });
    return map;
  }

  static async getFullCookie(): Promise<string> {
    const cookie = await CookieStorage.getCookie();
    const phpsessid = await CookieStorage.getPhpSessId();
    if (!phpsessid) return cookie;
    const map = CookieManager.parseCookie(cookie);
    map.set('PHPSESSID', phpsessid);
    return Array.from(map.entries())
      .map(entry => `${entry[0]}=${entry[1]}`)
      .join('; ');
  }

  static async saveLoginCookie(cookieStr: string): Promise<void> {
    await CookieStorage.saveCookie(cookieStr);
  }

  static async saveUserInfo(userId: string, userName: string): Promise<void> {
    await CookieStorage.saveUserInfo(userId, userName);
  }

  static async getUserId(): Promise<string> {
    return await CookieStorage.getUserId();
  }

  static async getUserName(): Promise<string> {
    return await CookieStorage.getUserName();
  }

  static async saveAvatarUrl(url: string): Promise<void> {
    return await CookieStorage.saveAvatarUrl(url);
  }

  static async getAvatarUrl(): Promise<string> {
    return await CookieStorage.getAvatarUrl();
  }

  static async clearCookies(): Promise<void> {
    await CookieStorage.clearCookie();
    for (const domain of CookieManager.DOMAINS) {
      try {
        webview.WebCookieManager.clearAllCookies();
      } catch (e) {
        console.warn(`清除 ${domain} cookie 失败: ${e}`);
      }
    }
  }

  // ======== OAuth Token Management ========

  static async saveTokens(tokens: PixivTokens): Promise<void> {
    await TokenStorage.saveTokens(tokens);
  }

  static async getTokens(): Promise<PixivTokens | null> {
    return await TokenStorage.getTokens();
  }

  static async getAccessToken(): Promise<string> {
    return await TokenStorage.getAccessToken();
  }

  static async getRefreshToken(): Promise<string> {
    return await TokenStorage.getRefreshToken();
  }

  static async isTokenExpired(): Promise<boolean> {
    return await TokenStorage.isTokenExpired();
  }

  static async hasTokens(): Promise<boolean> {
    return await TokenStorage.hasTokens();
  }

  static async clearTokens(): Promise<void> {
    await TokenStorage.clearTokens();
  }

  static async clearAll(): Promise<void> {
    await CookieManager.clearCookies();
    await CookieManager.clearTokens();
  }
}