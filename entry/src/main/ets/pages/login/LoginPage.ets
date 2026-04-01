// entry/src/main/ets/pages/login/LoginPage.ets

import webview from '@ohos.web.webview';
import router from '@ohos.router';
import { CookieManager } from '../../services/CookieManager';
import { appState } from '../../store/AppState';
import { PixivService } from '../../services/PixivService';
interface WebViewUserData {
  userName?: string;
  userId?: string;
  success: boolean;
  error?: string;
  debug?: object;
}

@Entry
@Component
struct LoginPage {
  controller: webview.WebviewController = new webview.WebviewController();
  private isHandled: boolean = false;

  build() {
    Column() {
      Web({ src: 'https://accounts.pixiv.net/login', controller: this.controller })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .onPageEnd(async (event) => {
          if (!this.isHandled && event.url?.startsWith('https://www.pixiv.net/')) {
            this.isHandled = true;
            console.info('✅ 检测到登录成功，已跳转到Pixiv首页');

            try {
              const cookieStr = await CookieManager.collectLoginCookies();
              if (cookieStr) {
                await appState.setLoginInfo(cookieStr);
                console.info('✅ Cookie 已保存');
              }
            } catch (err) {
              console.error('❌ 保存 Cookie 失败:', err);
            }

            // 提取用户信息
            await this.waitAndExtractUserInfo();

            // 返回上一页
            setTimeout(() => {
              router.back();
            }, 300);
          }
        })
        .onConsole((event) => {
          console.info('WebView Console:', event.message);
          return true;
        })
        .width('100%')
        .height('100%')
    }
  }

  /**
   * 等待并提取用户信息
   */
  private async waitAndExtractUserInfo() {
    const delays = [800, 1200, 1600];

    for (let i = 0; i < delays.length; i++) {
      const delay = delays[i];
      console.info(`⏳ 等待 ${delay}ms 后尝试第 ${i + 1} 次...`);
      await this.sleep(delay);

      const userData = await this.extractUserInfoFromDOM();

      // 关键修复：检查数据是否有效
      if (userData?.success && userData?.userId && userData?.userName) {
        // success 为真即可，不要求严格等于 true
        console.info('✅ 成功提取用户信息:', userData);
        await this.saveUserInfo(userData);
        return;
      } else {
        console.warn(`⚠️ 第 ${i + 1} 次提取失败:`, userData);
      }
    }

    // DOM方案失败，尝试API降级
    console.warn('⚠️ DOM方案失败，尝试API降级方案...');
    await this.fallbackToApiMethod();
  }

  /**
   * 从DOM提取用户信息
   */
  private async extractUserInfoFromDOM(): Promise<WebViewUserData> {
    try {
      const result = await this.controller.runJavaScript(`
            (function() {
                let userName = '';
                let userId = '';

                // 获取所有用户链接
                const userLinks = document.querySelectorAll('a[href*="/users/"]');
                console.log('找到用户链接数：', userLinks.length);

                // 从前5个链接中找有效的用户信息
                if (userLinks.length > 0) {
                    for (let i = 0; i < Math.min(5, userLinks.length); i++) {
                        const link = userLinks[i];
                        const linkText = (link.innerText || link.textContent || '').trim();
                        const href = link.href || '';

                        // 跳过明显不是用户名的文本
                        if (linkText && !/^\\d+\\s*(已关注|粉丝|作品|收藏|关注|粉丝数)/.test(linkText)) {
                            const match = href.match(/\\/users\\/(\\d+)/);
                            if (match && match[1]) {
                                userId = match[1];
                                userName = linkText;
                                console.log('找到有效用户：', userName, userId);
                                break;
                            }
                        }
                    }
                }

                return JSON.stringify({
                    userName,
                    userId,
                    success: !!(userName && userId)
                });
            })();
        `);
      // 关键修复：循环解析，直到得到对象
      let parsed: WebViewUserData | string = result;
      while (typeof parsed === 'string') {
        try {
          parsed = JSON.parse(parsed);
        } catch (e) {
          console.error('JSON解析失败，原始数据:', parsed);
          break;
        }
      }

      if (parsed && typeof parsed === 'object') {
        console.info('🔍 DOM提取结果:', JSON.stringify(parsed));
        return parsed as WebViewUserData;
      } else {
        console.warn('解析后不是对象，返回失败状态');
        return { success: false, error: '解析失败' };
      }
    } catch (err) {
      console.error('❌ DOM提取异常:', err);
      return { success: false, error: String(err) };
    }
  }

  /**
   * 保存用户信息
   */
  /**
   * 保存用户信息 - ✨ 关键修改
   */
  private async saveUserInfo(userData: WebViewUserData) {
    if (!userData || !userData.userName || !userData.userId) {
      console.warn('⚠️ 用户信息为空，无法保存');
      return;
    }

    try {
      await CookieManager.saveUserInfo(userData.userId, userData.userName);
      await this.sleep(100);
      // 1. 更新AppState
      appState.userName = userData.userName;
      appState.userId = userData.userId;
      appState.isLoggedIn = true;
      console.info(`✅ 用户信息已永久保存: ${userData.userName} (ID: ${userData.userId})`);
    } catch (err) {
      console.error('❌ 保存用户信息失败:', err);
      // 2. ✨ 保存到本地存储（最重要！）
      await CookieManager.saveUserInfo(userData.userId, userData.userName);

      // 3. 更新Cookie中的用户信息
      let cookieStr = await CookieManager.getFullCookie();
      const cookies = cookieStr
        .split(';')
        .map(c => c.trim())
        .filter(c => !c.startsWith('user_id=') && !c.startsWith('user_name='));

      cookies.push(`user_id=${userData.userId}`);
      cookies.push(`user_name=${userData.userName}`);
      const newCookie = cookies.join('; ');
      await CookieManager.saveLoginCookie(newCookie);

      console.info(`✅ 用户信息已永久保存: ${userData.userName} (ID: ${userData.userId})`);
    }
  }

  /**
   * API降级方案
   */
  private async fallbackToApiMethod() {
    try {
      console.info('📡 调用PixivService API获取用户信息...');
      const userInfo = await PixivService.getUserInfo();

      if (userInfo && !userInfo.error && userInfo.body?.name) {
        const userData: WebViewUserData = {
          userName: userInfo.body.name,
          userId: '0', // 从API可能获取不到ID，使用占位符
          success: true
        };
        await this.saveUserInfo(userData);
        console.info('✅ API方案成功');
      } else {
        console.error('❌ API返回无效数据:', userInfo);
      }
    } catch (err) {
      console.error('❌ API方案失败:', err);
    }
  }

  /**
   * 延迟工具
   */
  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}