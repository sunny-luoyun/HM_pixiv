import webview from '@ohos.web.webview';
import { CookieStorage } from '../common/utils/CookieStorage';
import { ApiConfig } from '../common/constants/ApiConfig';

export class CookieManager {
  private static readonly DOMAINS = [
    ApiConfig.PIXIV_ACCOUNTS,
    ApiConfig.PIXIV_WEB
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
    const phpsessid = cookieMap.get('PHPSESSID');
    if (phpsessid) {
      await CookieStorage.savePhpSessId(phpsessid);
    } else {
      console.warn('未找到 PHPSESSID，登录可能失败');
    }
    return Array.from(cookieMap.entries())
      .map(entry => `${entry[0]}=${entry[1]}`)
      .join('; ');
  }

  static async getFullCookie(): Promise<string> {
    const phpsessid = await CookieStorage.getPhpSessId();
    if (!phpsessid) return '';
    return `PHPSESSID=${phpsessid}`;
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

  static async clearAll(): Promise<void> {
    await CookieManager.clearCookies();
  }
}