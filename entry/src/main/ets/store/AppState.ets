// entry/src/main/ets/store/AppState.ets
import { CookieManager } from '../services/CookieManager';
import { PixivService, UserInfoResponse } from '../services/PixivService';
import http from '@ohos.net.http';

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

  async checkLoginStatus(skipVerify: boolean = false) {
    try {
      const cookieStr = await CookieManager.getFullCookie();
      this.isLoggedIn = cookieStr !== '';

      if (this.isLoggedIn) {
        // 读取用户信息（优先本地，其次 Cookie 解析）
        const savedUserId = await CookieManager.getUserId();
        const savedUserName = await CookieManager.getUserName();
        if (savedUserId && savedUserName) {
          this.userId = savedUserId;
          this.userName = savedUserName;
        } else {
          const cookieMap = CookieManager.parseCookie(cookieStr);
          this.userId = cookieMap.get('user_id') || '';
          this.userName = cookieMap.get('user_name') || '用户';
        }

        // 仅当 skipVerify 为 false 时验证
        if (!skipVerify) {
          try {
            const isValid = await this.verifyCookieWithUserId();
            if (!isValid) {
              console.warn('⚠️ Cookie验证失败，自动登出');
              await this.logout();
            } else {
              // 异步刷新用户名
              try {
                await this.refreshUserInfo();
              } catch (err) {
                console.warn('刷新用户信息失败，保留原有用户名:', err);
              }
            }
          } catch (networkErr) {
            console.error('🌐 网络异常，Cookie验证跳过，保持登录状态:', networkErr);
          }
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

  // entry/src/main/ets/store/AppState.ets 中增加以下方法

  /**
   * 使用保存的用户ID验证Cookie是否有效
   * @returns true: 有效；false: 失效（需登出）
   * @throws 网络异常时抛出错误，由调用方决定是否登出
   */
  async verifyCookieWithUserId(): Promise<boolean> {
    if (!this.userId) {
      console.warn('用户ID为空，无法验证');
      return false;
    }

    const url = `https://www.pixiv.net/users/${this.userId}`;
    const cookieStr = await CookieManager.getFullCookie();
    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'Cookie': cookieStr,
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Referer': 'https://www.pixiv.net/'
        },
        connectTimeout: 10000,
        readTimeout: 10000
      });
      const statusCode: number = response.responseCode;

      // ✅ 有效情况：200 OK 且页面包含用户相关信息（可根据需要增加内容校验）
      if (statusCode === 200) {
        const body: string = response.result.toString();
        // 简单校验页面是否包含用户标识（例如 user-id 属性或用户名）
        if (body.includes(`"userId":${this.userId}`) || body.includes(`/users/${this.userId}`)) {
          console.info(`✅ Cookie有效，用户 ${this.userName} (${this.userId}) 可访问主页`);
          return true;
        } else {
          console.warn(`⚠️ 主页返回200但页面内容异常，可能已登出`);
          return false;
        }
      }
      // ❌ 认证失效：401/403 或 302重定向到登录页
      else if (statusCode === 401 || statusCode === 403) {
        console.warn(`❌ Cookie失效，服务器返回 ${statusCode}`);
        return false;
      }
      else if (statusCode === 302) {
        const location: string | undefined = response.header?.['Location'];
        if (location?.includes('/login')) {
          console.warn(`❌ Cookie失效，重定向到登录页: ${location}`);
          return false;
        }
        // 其他302可能是正常跳转，暂视为有效（可选：再请求一次）
        console.info(`ℹ️ 收到302跳转至 ${location}，暂视为有效`);
        return true;
      }
      // 其他状态码视为异常
      else {
        console.warn(`⚠️ 主页请求返回非预期状态码 ${statusCode}`);
        return false;
      }
    } catch (err) {
      // 🌐 网络问题：超时、无网络、DNS错误等，抛出异常以便上层区分
      console.error(`🌐 网络异常，无法验证Cookie: ${err}`);
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