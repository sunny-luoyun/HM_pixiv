// entry/src/main/ets/store/AppState.ets
import { CookieManager } from '../services/CookieManager';
import { PixivService, UserInfoResponse } from '../services/PixivService';

@Observed
export class AppState {
  private static instance: AppState;

  isLoggedIn: boolean = false;
  userId: string = '';
  userName: string = '';

  private constructor() {}

  static getInstance(): AppState {
    if (!AppState.instance) {
      AppState.instance = new AppState();
    }
    return AppState.instance;
  }

  async checkLoginStatus() {
    try {
      const cookieStr = await CookieManager.getFullCookie();
      this.isLoggedIn = cookieStr !== '';

      if (this.isLoggedIn) {
        // ✨ 修改：优先从本地持久化存储读取用户信息
        const savedUserId = await CookieManager.getUserId();
        const savedUserName = await CookieManager.getUserName();

        if (savedUserId && savedUserName) {
          // 本地有保存的用户信息，直接使用
          this.userId = savedUserId;
          this.userName = savedUserName;
          console.info(`✅ 从本地存储加载用户信息: ${this.userName} (${this.userId})`);
        } else {
          // 本地没有保存，从 Cookie 中提取（兼容旧数据）
          const cookieMap = CookieManager.parseCookie(cookieStr);
          this.userId = cookieMap.get('user_id') || '';
          this.userName = cookieMap.get('user_name') || '用户';
        }

        // 异步从 API 刷新更准确的用户名
        try {
          await this.refreshUserInfo();
        } catch (err) {
          console.warn('刷新用户信息失败，保留原有用户名:', err);
        }
      } else {
        this.userId = '';
        this.userName = '';
      }
    } catch (err) {
      console.error('检查登录状态失败', err);
      this.isLoggedIn = false;
      this.userId = '';
      this.userName = '';
    }
  }

  async setLoginInfo(cookieStr: string) {
    await CookieManager.saveLoginCookie(cookieStr);
    await this.checkLoginStatus();
  }

  async logout() {
    await CookieManager.clearCookies();
    this.isLoggedIn = false;
    this.userId = '';
    this.userName = '';
  }

  async refreshUserInfo() {
    if (!this.isLoggedIn) return;
    try {
      const userInfo: UserInfoResponse = await PixivService.getUserInfo();
      if (userInfo && !userInfo.error && userInfo.body?.name) {
        this.userName = userInfo.body.name;
        // ✨ 新增：每次更新用户名时，也保存到本地存储
        await CookieManager.saveUserInfo(this.userId, this.userName);
      } else {
        console.warn('获取用户信息失败或没有名字字段');
      }
    } catch (err) {
      console.error('刷新用户信息失败', err);
      throw new Error(`刷新用户信息失败: ${err}`);
    }
  }
}

export const appState = AppState.getInstance();