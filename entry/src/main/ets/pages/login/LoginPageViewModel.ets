// entry/src/main/ets/pages/login/LoginPageViewModel.ets
import webview from '@ohos.web.webview';
import { LoginService, LoginUserData } from '../../services/LoginService';
import { PixivService } from '../../services/PixivService';
import { CookieManager } from '../../services/CookieManager';
import { appState } from '../../store/AppState';

/**
 * LoginPage 的 ViewModel
 * 负责UI状态管理和与LoginService的交互
 */
export class LoginPageViewModel {
  // UI状态
  isProcessing: boolean = false;
  statusMessage: string = '';
  errorMessage: string = '';

  /**
   * 处理登录完成事件
   */
  async onLoginSuccess(webviewController: webview.WebviewController): Promise<void> {
    try {
      this.isProcessing = true;
      this.statusMessage = '正在处理登录信息...';
      this.errorMessage = '';

      // 第一步：收集并保存Cookie
      console.info('📦 第一步：收集Cookie...');
      await LoginService.handleLoginSuccess();

      // 第二步：提取用户信息
      console.info('👤 第二步：提取用户信息...');
      const userData = await LoginService.extractUserInfoWithRetry(
        () => this.extractUserInfoFromDOM(webviewController)
      );

      // 第三步：保存用户信息
      console.info('💾 第三步：保存用户信息...');
      await LoginService.saveUserInfo(userData);

      // 第四步：获取用户头像URL并下载缓存
      console.info('🖼️ 第四步：获取用户头像...');
      try {
        const userInfo = await PixivService.getUserInfo();
        if (userInfo?.body?.image) {
          await CookieManager.saveAvatarUrl(userInfo.body.image);
          await appState.cacheAvatar();
          console.info('✅ 头像已缓存到本地');
        }
      } catch (err) {
        console.warn('⚠️ 获取头像失败，后续可刷新:', err);
      }

      this.statusMessage = `登录成功！欢迎 ${userData.userName}`;
      this.isProcessing = false;
    } catch (err) {
      this.errorMessage = `登录处理失败: ${String(err)}`;
      this.isProcessing = false;
      console.error('❌ 登录流程异常:', err);
      throw new Error(String(err));
    }
  }

  /**
   * 从DOM中提取用户信息
   */
  private async extractUserInfoFromDOM(webviewController: webview.WebviewController): Promise<LoginUserData> {
    try {
      const result = await webviewController.runJavaScript(`
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

      // 解析JavaScript返回值
      let parsed: LoginUserData | string = result;
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
        return parsed as LoginUserData;
      } else {
        console.warn('解析后不是对象，返回失败状态');
        return { success: false, userName: '', userId: '', error: '解析失败' };
      }
    } catch (err) {
      console.error('❌ DOM提取异常:', err);
      throw new Error(`DOM提取失败: ${String(err)}`);
    }
  }
}