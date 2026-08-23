import { describe, it, expect } from '@ohos/hypium';
import { getLlmService, resetLlmServiceInstance, shouldUseInAppProxy } from '../main/ets/services/LlmServiceFactory';
import { DeepSeekService } from '../main/ets/services/DeepSeekService';
import { OpenAiCompatService } from '../main/ets/services/OpenAiCompatService';

export default function llmServiceFactoryTest() {
  describe('LlmServiceFactory', () => {

    describe('provider=deepseek（默认）', () => {
      it('返回 DeepSeekService 实例', 0, () => {
        AppStorage.setOrCreate('llmProvider', 'deepseek');
        resetLlmServiceInstance();
        const svc = getLlmService();
        expect(svc instanceof DeepSeekService).assertTrue();
      });
    });

    describe('provider=custom', () => {
      it('返回 OpenAiCompatService 实例', 0, () => {
        AppStorage.setOrCreate('llmProvider', 'custom');
        AppStorage.setOrCreate('customLlmApiBase', 'https://example.com/v1');
        AppStorage.setOrCreate('customLlmApiKey', 'sk-custom');
        AppStorage.setOrCreate('customLlmModel', 'my-model');
        resetLlmServiceInstance();
        const svc = getLlmService();
        expect(svc instanceof OpenAiCompatService).assertTrue();
      });

      it('切换 provider 后返回不同实例', 0, () => {
        AppStorage.setOrCreate('llmProvider', 'custom');
        resetLlmServiceInstance();
        const custom = getLlmService();
        AppStorage.setOrCreate('llmProvider', 'deepseek');
        resetLlmServiceInstance();
        const ds = getLlmService();
        expect(custom instanceof DeepSeekService).assertFalse();
        expect(ds instanceof DeepSeekService).assertTrue();
      });
    });

    describe('prompts 同步', () => {
      it('从 AppStorage 同步自定义 prompt', 0, () => {
        AppStorage.setOrCreate('llmProvider', 'deepseek');
        AppStorage.setOrCreate('titlePrompt', '工厂同步的标题规则');
        AppStorage.setOrCreate('fullPrompt', '');
        AppStorage.setOrCreate('unifiedPrompt', false);
        resetLlmServiceInstance();
        const svc = getLlmService();
        expect(svc.getSystemPrompt(true)).assertEqual('工厂同步的标题规则');
      });
    });

    describe('配置刷新（provider 不变时每次调用同步）', () => {
      it('custom：修改 key 后再次调用立即生效', 0, () => {
        AppStorage.setOrCreate('llmProvider', 'custom');
        AppStorage.setOrCreate('customLlmApiBase', 'https://example.com/v1');
        AppStorage.setOrCreate('customLlmApiKey', '');
        AppStorage.setOrCreate('customLlmModel', 'my-model');
        resetLlmServiceInstance();
        const svc = getLlmService();
        expect(svc.hasValidKey()).assertFalse();
        AppStorage.setOrCreate('customLlmApiKey', 'sk-new');
        getLlmService();
        expect(svc.hasValidKey()).assertTrue();
      });

      it('deepseek：修改 key 后再次调用立即生效', 0, () => {
        AppStorage.setOrCreate('llmProvider', 'deepseek');
        AppStorage.setOrCreate('deepseekApiKey', '');
        resetLlmServiceInstance();
        const svc = getLlmService();
        expect(svc.hasValidKey()).assertFalse();
        AppStorage.setOrCreate('deepseekApiKey', 'sk-deep');
        getLlmService();
        expect(svc.hasValidKey()).assertTrue();
      });
    });

    describe('shouldUseInAppProxy', () => {
      it('custom 且开关开 → true', 0, () => {
        expect(shouldUseInAppProxy('custom', true)).assertTrue();
      });

      it('custom 且开关关 → false', 0, () => {
        expect(shouldUseInAppProxy('custom', false)).assertFalse();
      });

      it('custom 且开关未设置(undefined) → false', 0, () => {
        expect(shouldUseInAppProxy('custom', undefined)).assertFalse();
      });

      it('deepseek 且开关开 → false（DeepSeek 恒直连）', 0, () => {
        expect(shouldUseInAppProxy('deepseek', true)).assertFalse();
      });
    });

    describe('useInAppProxy 工厂同步', () => {
      it('provider=custom 且开关开 → 实例启用代理', 0, () => {
        AppStorage.setOrCreate('llmProvider', 'custom');
        AppStorage.setOrCreate('customLlmApiBase', 'https://example.com/v1');
        AppStorage.setOrCreate('customLlmApiKey', 'sk-custom');
        AppStorage.setOrCreate('customLlmModel', 'my-model');
        AppStorage.setOrCreate('customLlmUseProxy', true);
        resetLlmServiceInstance();
        expect(getLlmService().getUseInAppProxy()).assertTrue();
      });

      it('provider=deepseek 即使开关开也不启用', 0, () => {
        AppStorage.setOrCreate('llmProvider', 'deepseek');
        AppStorage.setOrCreate('customLlmUseProxy', true);
        resetLlmServiceInstance();
        expect(getLlmService().getUseInAppProxy()).assertFalse();
      });

      it('开关关 → 实例不启用', 0, () => {
        AppStorage.setOrCreate('llmProvider', 'custom');
        AppStorage.setOrCreate('customLlmApiBase', 'https://example.com/v1');
        AppStorage.setOrCreate('customLlmApiKey', 'sk-custom');
        AppStorage.setOrCreate('customLlmModel', 'my-model');
        AppStorage.setOrCreate('customLlmUseProxy', false);
        resetLlmServiceInstance();
        expect(getLlmService().getUseInAppProxy()).assertFalse();
      });

      it('开关未设置(undefined) → 实例不启用', 0, () => {
        AppStorage.setOrCreate('llmProvider', 'custom');
        AppStorage.setOrCreate('customLlmApiBase', 'https://example.com/v1');
        AppStorage.setOrCreate('customLlmApiKey', 'sk-custom');
        AppStorage.setOrCreate('customLlmModel', 'my-model');
        resetLlmServiceInstance();
        expect(getLlmService().getUseInAppProxy()).assertFalse();
      });
    });
  });
}
