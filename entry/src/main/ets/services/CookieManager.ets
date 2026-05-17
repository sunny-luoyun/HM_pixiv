// entry/src/main/ets/services/CookieManager.ets
import webview from '@ohos.web.webview';
import { CookieStorage } from '../common/utils/CookieStorage';

export class CookieManager {
  // 需要获取Cookie的域列表（仅实际使用的域）
  private static readonly DOMAINS = [
    'https://accounts.pixiv.net',
    'https://www.pixiv.net'
  ];

  /**
   * 登录成功后，从WebView获取所有相关域的Cookie并合并
   * 注意：只提取真正的键值对，忽略Set-Cookie属性（如Path, HttpOnly等）
   */
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

    // 合并去重：只保留键值对，忽略属性片段（没有等号的直接跳过）
    const cookieMap = new Map<string, string>();
    for (const cookieStr of allCookies) {
      cookieStr.split(';').forEach(pair => {
        const trimmed = pair.trim();
        if (!trimmed) return;
        const eqIndex = trimmed.indexOf('=');
        if (eqIndex === -1) return; // 没有等号，可能是属性（如 HttpOnly），忽略
        const key = trimmed.slice(0, eqIndex);
        const value = trimmed.slice(eqIndex + 1);
        cookieMap.set(key, value);
      });
    }
    // 还原为字符串
    if (!cookieMap.has('PHPSESSID')) {
      console.warn('未找到 PHPSESSID，登录可能失败');
    }
    return Array.from(cookieMap.entries())
      .map(entry => `${entry[0]}=${entry[1]}`)
      .join('; ');
  }

  /**
   * 解析Cookie字符串为Map，自动解码URL编码的值
   */
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
      } catch (e) {
        // 解码失败保留原值
      }
      map.set(key, value);
    });
    return map;
  }

  /**
   * 获取完整的Cookie字符串（用于请求头）
   */
  static async getFullCookie(): Promise<string> {
    return await CookieStorage.getCookie();
  }

  /**
   * 保存登录Cookie
   */
  static async saveLoginCookie(cookieStr: string): Promise<void> {
    await CookieStorage.saveCookie(cookieStr);
  }

  /**
   * ✨ 新增：保存用户信息
   */
  static async saveUserInfo(userId: string, userName: string): Promise<void> {
    await CookieStorage.saveUserInfo(userId, userName);
  }

  /**
   * ✨ 新增：获取保存的用户ID
   */
  static async getUserId(): Promise<string> {
    return await CookieStorage.getUserId();
  }

  /**
   * ✨ 新增：获取保存的用户名
   */
  static async getUserName(): Promise<string> {
    return await CookieStorage.getUserName();
  }

  static async saveAvatarUrl(url: string): Promise<void> {
    return await CookieStorage.saveAvatarUrl(url);
  }

  static async getAvatarUrl(): Promise<string> {
    return await CookieStorage.getAvatarUrl();
  }

  /**
   * 清除所有Cookie（包括Preferences存储和WebView）
   */
  static async clearCookies(): Promise<void> {
    await CookieStorage.clearCookie();
    // 清除WebView中所有相关域的Cookie
    for (const domain of CookieManager.DOMAINS) {
      try {
        webview.WebCookieManager.clearAllCookies();
      } catch (e) {
        console.warn(`清除 ${domain} cookie 失败: ${e}`);
      }
    }
  }
}