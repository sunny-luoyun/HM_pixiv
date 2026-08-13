import { describe, it, expect } from '@ohos/hypium';
import { getLlmService, resetLlmServiceInstance } from '../main/ets/services/LlmServiceFactory';
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
  });
}
