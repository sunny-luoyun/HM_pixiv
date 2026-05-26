// entry/src/main/ets/common/utils/CookieStorage.ets
import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';

export class CookieStorage {
  private static PREFERENCES_NAME = 'app_cookie';
  private static KEY_COOKIE = 'pixiv_cookie';
  private static KEY_USER_ID = 'pixiv_user_id';
  private static KEY_USER_NAME = 'pixiv_user_name';
  private static KEY_AVATAR_URL = 'pixiv_avatar_url';
  private static KEY_PHPSESSID = 'pixiv_phpsessid';
  private static context: common.BaseContext;

  static init(context: common.BaseContext) {
    CookieStorage.context = context;
  }

  // 保存 Cookie
  static async saveCookie(cookie: string): Promise<void> {
    if (!CookieStorage.context) throw new Error('CookieStorage not initialized');
    const pref = await preferences.getPreferences(CookieStorage.context, CookieStorage.PREFERENCES_NAME);
    await pref.put(CookieStorage.KEY_COOKIE, cookie);
    await pref.flush();
  }

  // ✨ 新增：保存用户信息
  static async saveUserInfo(userId: string, userName: string): Promise<void> {
    if (!CookieStorage.context) throw new Error('CookieStorage not initialized');
    const pref = await preferences.getPreferences(CookieStorage.context, CookieStorage.PREFERENCES_NAME);
    await pref.put(CookieStorage.KEY_USER_ID, userId);
    await pref.put(CookieStorage.KEY_USER_NAME, userName);
    await pref.flush();
  }

  // 获取 Cookie
  static async getCookie(): Promise<string> {
    if (!CookieStorage.context) return '';
    const pref = await preferences.getPreferences(CookieStorage.context, CookieStorage.PREFERENCES_NAME);
    return await pref.get(CookieStorage.KEY_COOKIE, '') as string;
  }

  // ✨ 新增：获取用户ID
  static async getUserId(): Promise<string> {
    if (!CookieStorage.context) return '';
    const pref = await preferences.getPreferences(CookieStorage.context, CookieStorage.PREFERENCES_NAME);
    return await pref.get(CookieStorage.KEY_USER_ID, '') as string;
  }

  // ✨ 新增：获取用户名
  static async getUserName(): Promise<string> {
    if (!CookieStorage.context) return '';
    const pref = await preferences.getPreferences(CookieStorage.context, CookieStorage.PREFERENCES_NAME);
    return await pref.get(CookieStorage.KEY_USER_NAME, '') as string;
  }

  static async saveAvatarUrl(url: string): Promise<void> {
    if (!CookieStorage.context) throw new Error('CookieStorage not initialized');
    const pref = await preferences.getPreferences(CookieStorage.context, CookieStorage.PREFERENCES_NAME);
    await pref.put(CookieStorage.KEY_AVATAR_URL, url);
    await pref.flush();
  }

  static async getAvatarUrl(): Promise<string> {
    if (!CookieStorage.context) return '';
    const pref = await preferences.getPreferences(CookieStorage.context, CookieStorage.PREFERENCES_NAME);
    return await pref.get(CookieStorage.KEY_AVATAR_URL, '') as string;
  }

  static async savePhpSessId(phpsessid: string): Promise<void> {
    if (!CookieStorage.context) throw new Error('CookieStorage not initialized');
    const pref = await preferences.getPreferences(CookieStorage.context, CookieStorage.PREFERENCES_NAME);
    await pref.put(CookieStorage.KEY_PHPSESSID, phpsessid);
    const cookie = `PHPSESSID=${phpsessid}`;
    await pref.put(CookieStorage.KEY_COOKIE, cookie);
    await pref.flush();
  }

  static async getPhpSessId(): Promise<string> {
    if (!CookieStorage.context) return '';
    const pref = await preferences.getPreferences(CookieStorage.context, CookieStorage.PREFERENCES_NAME);
    return await pref.get(CookieStorage.KEY_PHPSESSID, '') as string;
  }

  // 清除所有数据
  static async clearCookie(): Promise<void> {
    if (!CookieStorage.context) return;
    const pref = await preferences.getPreferences(CookieStorage.context, CookieStorage.PREFERENCES_NAME);
    await pref.delete(CookieStorage.KEY_COOKIE);
    await pref.delete(CookieStorage.KEY_USER_ID);
    await pref.delete(CookieStorage.KEY_USER_NAME);
    await pref.delete(CookieStorage.KEY_AVATAR_URL);
    await pref.delete(CookieStorage.KEY_PHPSESSID);
    await pref.flush();
  }
}