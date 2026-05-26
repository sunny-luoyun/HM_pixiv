import { CookieManager } from './CookieManager';
import { PixivService } from './PixivService';
import { appState } from '../store/AppState';

export interface LoginUserData {
  userName: string;
  userId: string;
  success: boolean;
  error?: string;
}

export class LoginService {

  static async handleLoginSuccess(): Promise<void> {
    try {
      const cookieStr = await CookieManager.collectLoginCookies();
      if (!cookieStr) {
        throw new Error('未能获取到登录Cookie，请重新登录');
      }
      await appState.setLoginInfo(cookieStr, true);
      console.info('✅ Cookie 已保存');
    } catch (err) {
      console.error('❌ 保存 Cookie 失败:', err);
      throw new Error(`Cookie 保存失败: ${String(err)}`);
    }
  }

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
    console.warn('⚠️ DOM方案失败，尝试API降级方案...');
    try {
      return await LoginService.fallbackToApiMethod();
    } catch (apiErr) {
      console.warn('⚠️ API降级也失败:', apiErr);
    }
    console.warn('⚠️ 尝试从存储中提取用户信息...');
    const savedUserId = await CookieManager.getUserId();
    const savedUserName = await CookieManager.getUserName();
    if (savedUserId && savedUserName) {
      console.info('✅ 存储方案成功获取用户信息:', savedUserName, savedUserId);
      return { userName: savedUserName, userId: savedUserId, success: true };
    }
    throw new Error('所有方案都无法获取用户信息');
  }

  static async saveUserInfo(userData: LoginUserData): Promise<void> {
    if (!userData || !userData.userName || !userData.userId) {
      console.warn('⚠️ 用户信息为空，无法保存');
      throw new Error('用户信息无效');
    }
    try {
      await CookieManager.saveUserInfo(userData.userId, userData.userName);
      appState.userName = userData.userName;
      appState.userId = userData.userId;
      appState.isLoggedIn = true;
      console.info(`✅ 用户信息已保存: ${userData.userName} (ID: ${userData.userId})`);
    } catch (err) {
      console.error('❌ 保存用户信息失败:', err);
      throw new Error(String(err));
    }
  }

  private static async fallbackToApiMethod(): Promise<LoginUserData> {
    try {
      console.info('🏠 调用PixivService API获取用户信息...');
      const cookieUserId = await CookieManager.getUserId();
      if (!cookieUserId) {
        throw new Error('未找到用户ID');
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

  private static generateDelays(initialDelay: number, count: number): number[] {
    const delays: number[] = [];
    for (let i = 0; i < count; i++) {
      delays.push(initialDelay + i * 400);
    }
    return delays;
  }

  private static sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}