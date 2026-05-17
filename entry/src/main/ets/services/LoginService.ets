// entry/src/main/ets/services/LoginService.ets
import { CookieManager } from './CookieManager';
import { PixivService } from './PixivService';
import { appState } from '../store/AppState';

/**
 * 登录流程中WebView中提取的用户数据
 */
export interface LoginUserData {
  userName: string;
  userId: string;
  success: boolean;
  error?: string;
}

/**
 * 登录服务 - 封装所有登录相关的业务逻辑
 * 保持页面层的纯净，只处理UI展现
 */
export class LoginService {
  /**
   * 处理登录成功后的Cookie收集和保存
   */
  static async handleLoginSuccess(): Promise<void> {
    try {
      const cookieStr = await CookieManager.collectLoginCookies();
      if (!cookieStr) {
        throw new Error('未能获取到登录Cookie，请重新登录');
      }
      await CookieManager.saveLoginCookie(cookieStr);
      await appState.setLoginInfo(cookieStr, true);
      console.info('✅ Cookie 已保存');
    } catch (err) {
      console.error('❌ 保存 Cookie 失败:', err);
      throw new Error(`Cookie 保存失败: ${String(err)}`);
    }
  }

  /**
   * 从WebView中提取用户信息 (支持多次重试)
   */
  static async extractUserInfoWithRetry(
    extractFn: () => Promise<LoginUserData>,
    maxRetries: number = 3,
    initialDelay: number = 800
  ): Promise<LoginUserData> {
    const delays = LoginService.generateDelays(initialDelay, maxRetries);

    for (let i = 0; i < delays.length; i++) {
      const delay = delays[i];
      console.info(`⏳ 等待 ${delay}ms 后尝试第 ${i + 1} 次...`);
      await LoginService.sleep(delay);

      try {
        const userData = await extractFn();
        // 验证数据有效性
        if (userData?.success && userData?.userId && userData?.userName) {
          console.info('✅ 成功提取用户信息:', userData);
          return userData;
        } else {
          console.warn(`⚠️ 第 ${i + 1} 次提取失败:`, userData);
        }
      } catch (err) {
        console.error(`⚠️ 第 ${i + 1} 次提取异常:`, err);
      }
    }
    // DOM方案失败，尝试API降级
    console.warn('⚠️ DOM方案失败，尝试API降级方案...');
    try {
      return await LoginService.fallbackToApiMethod();
    } catch (apiErr) {
      console.warn('⚠️ API降级也失败:', apiErr);
    }

    // Cookie降级方案：从已保存的Cookie中提取用户信息
    console.warn('⚠️ 尝试从Cookie中提取用户信息...');
    const cookieStr = await CookieManager.getFullCookie();
    if (cookieStr) {
      const cookieMap = CookieManager.parseCookie(cookieStr);
      const userId = cookieMap.get('user_id') || '';
      const userName = cookieMap.get('user_name') || '';
      if (userId && userName) {
        console.info('✅ Cookie方案成功获取用户信息:', userName, userId);
        return { userName, userId, success: true };
      }
    }
    throw new Error('所有方案都无法获取用户信息');
  }

  /**
   * 保存用户信息到持久化存储和AppState
   */
  static async saveUserInfo(userData: LoginUserData): Promise<void> {
    if (!userData || !userData.userName || !userData.userId) {
      console.warn('⚠️ 用户信息为空，无法保存');
      throw new Error('用户信息无效');
    }

    try {
      // 1. 保存到本地存储
      await CookieManager.saveUserInfo(userData.userId, userData.userName);

      // 2. 更新AppState
      appState.userName = userData.userName;
      appState.userId = userData.userId;
      appState.isLoggedIn = true;

      console.info(`✅ 用户信息已保存: ${userData.userName} (ID: ${userData.userId})`);
    } catch (err) {
      console.error('❌ 保存用户信息失败:', err);
      throw new Error(String(err));
    }
  }

  /**
   * API降级方案 - 当DOM提取失败时使用
   */
  private static async fallbackToApiMethod(): Promise<LoginUserData> {
    try {
      console.info('🏠 调用PixivService API获取用户信息...');
      // /ajax/user/me 已废弃，从Cookie中获取userId后查用户信息
      const cookieStr = await CookieManager.getFullCookie();
      const cookieUserId = cookieStr ? CookieManager.parseCookie(cookieStr).get('user_id') || '' : '';
      if (!cookieUserId) {
        throw new Error('Cookie中无user_id');
      }
      const userInfo = await PixivService.getUserProfile(cookieUserId);

      if (userInfo && !userInfo.error && userInfo.body?.name) {
        const userData: LoginUserData = {
          userName: userInfo.body.name,
          userId: userInfo.body.userId || cookieUserId,
          success: true
        };
        console.info('✅ API方案成功获取用户信息');
        return userData;
      } else {
        throw new Error(`API返回无效数据: ${JSON.stringify(userInfo)}`);
      }
    } catch (err) {
      console.error('❌ API方案失败:', err);
      throw new Error(`无法获取用户信息 - ${String(err)}`);
    }
  }

  /**
   * 生成延迟时间序列 - 指数退避策略
   */
  private static generateDelays(initialDelay: number, count: number): number[] {
    const delays: number[] = [];
    for (let i = 0; i < count; i++) {
      delays.push(initialDelay + i * 400);
    }
    return delays;
  }

  /**
   * 通用延迟工具
   */
  private static sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}