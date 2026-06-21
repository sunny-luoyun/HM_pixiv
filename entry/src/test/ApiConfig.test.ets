import { describe, it, expect } from '@ohos/hypium';
import { ApiConfig } from '../main/ets/common/constants/ApiConfig';

export default function apiConfigTest() {
  describe('ApiConfig', () => {

    describe('Pixiv URL 常量', () => {
      it('PIXIV_WEB 应为非空 https 链接', 0, () => {
        expect(ApiConfig.PIXIV_WEB.length > 0).assertTrue();
        expect(ApiConfig.PIXIV_WEB.startsWith('https://')).assertTrue();
      });

      it('PIXIV_APP 应为非空 https 链接', 0, () => {
        expect(ApiConfig.PIXIV_APP.length > 0).assertTrue();
        expect(ApiConfig.PIXIV_APP.startsWith('https://')).assertTrue();
      });

      it('PIXIV_ACCOUNTS 应为非空 https 链接', 0, () => {
        expect(ApiConfig.PIXIV_ACCOUNTS.length > 0).assertTrue();
        expect(ApiConfig.PIXIV_ACCOUNTS.startsWith('https://')).assertTrue();
      });

      it('PIXIV_LOGIN 应为非空 https 链接', 0, () => {
        expect(ApiConfig.PIXIV_LOGIN.length > 0).assertTrue();
        expect(ApiConfig.PIXIV_LOGIN.startsWith('https://')).assertTrue();
      });
    });

    describe('DeepSeek URL 常量', () => {
      it('DEEPSEEK_API 应为非空 https 链接', 0, () => {
        expect(ApiConfig.DEEPSEEK_API.length > 0).assertTrue();
        expect(ApiConfig.DEEPSEEK_API.startsWith('https://')).assertTrue();
      });

      it('DEEPSEEK_BALANCE 应为非空 https 链接', 0, () => {
        expect(ApiConfig.DEEPSEEK_BALANCE.length > 0).assertTrue();
        expect(ApiConfig.DEEPSEEK_BALANCE.startsWith('https://')).assertTrue();
      });
    });

    describe('请求头常量', () => {
      it('USER_AGENT 应包含常见浏览器标识', 0, () => {
        expect(ApiConfig.USER_AGENT.length > 0).assertTrue();
        expect(ApiConfig.USER_AGENT.includes('Mozilla/5.0')).assertTrue();
      });

      it('REFERER 应为 pixiv 主页链接', 0, () => {
        expect(ApiConfig.REFERER.startsWith('https://www.pixiv.net')).assertTrue();
      });
    });

    describe('URL 一致性', () => {
      it('PIXIV_WEB 不应包含末尾斜杠（避免拼接冲突）', 0, () => {
        expect(ApiConfig.PIXIV_WEB.endsWith('/')).assertFalse();
      });

      it('PIXIV_APP 不应包含末尾斜杠', 0, () => {
        expect(ApiConfig.PIXIV_APP.endsWith('/')).assertFalse();
      });

      it('PIXIV_ACCOUNTS 不应包含末尾斜杠', 0, () => {
        expect(ApiConfig.PIXIV_ACCOUNTS.endsWith('/')).assertFalse();
      });

      it('DEEPSEEK_API 应以 /chat/completions 结尾', 0, () => {
        expect(ApiConfig.DEEPSEEK_API.endsWith('/chat/completions')).assertTrue();
      });

      it('DEEPSEEK_BALANCE 应以 /user/balance 结尾', 0, () => {
        expect(ApiConfig.DEEPSEEK_BALANCE.endsWith('/user/balance')).assertTrue();
      });
    });

    describe('边界值', () => {
      it('所有 URL 均不含空格', 0, () => {
        const urls = [
          ApiConfig.PIXIV_WEB,
          ApiConfig.PIXIV_APP,
          ApiConfig.PIXIV_ACCOUNTS,
          ApiConfig.PIXIV_LOGIN,
          ApiConfig.DEEPSEEK_API,
          ApiConfig.DEEPSEEK_BALANCE
        ];
        for (let i = 0; i < urls.length; i++) {
          expect(urls[i].includes(' ')).assertFalse();
        }
      });

      it('所有 URL 均不以 . 结尾', 0, () => {
        const urls = [
          ApiConfig.PIXIV_WEB,
          ApiConfig.PIXIV_APP,
          ApiConfig.PIXIV_ACCOUNTS,
          ApiConfig.PIXIV_LOGIN,
          ApiConfig.DEEPSEEK_API,
          ApiConfig.DEEPSEEK_BALANCE
        ];
        for (let i = 0; i < urls.length; i++) {
          expect(urls[i].endsWith('.')).assertFalse();
        }
      });
    });
  });
}
