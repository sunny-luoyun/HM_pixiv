import { describe, it, expect } from '@ohos/hypium';
import { BaseLlmService, LlmConfig, TranslationResult } from '../main/ets/services/LlmProvider';

class TestLlmService extends BaseLlmService {
  constructor(config: LlmConfig) {
    super(config);
  }
}

function makeService(overrides: Partial<LlmConfig> = {}): TestLlmService {
  const config: LlmConfig = {
    baseUrl: overrides.baseUrl ?? 'https://example.com/v1/chat/completions',
    apiKey: overrides.apiKey ?? 'sk-custom-123',
    model: overrides.model ?? 'test-model',
    supportsThinking: overrides.supportsThinking ?? false,
    maxTokensTitle: overrides.maxTokensTitle ?? 100,
    maxTokensFull: overrides.maxTokensFull ?? 8192,
    supportsCostEstimate: overrides.supportsCostEstimate ?? false
  };
  return new TestLlmService(config);
}

export default function llmProviderTest() {
  describe('BaseLlmService', () => {

    describe('hasValidKey', () => {
      it('有效 Key 返回 true', 0, () => {
        expect(makeService().hasValidKey()).assertTrue();
      });

      it('空 Key 返回 false', 0, () => {
        expect(makeService({ apiKey: '' }).hasValidKey()).assertFalse();
      });

      it('空白 Key 返回 false', 0, () => {
        expect(makeService({ apiKey: '   ' }).hasValidKey()).assertFalse();
      });
    });

    describe('updateApiKey', () => {
      it('更新后 hasValidKey 反映新值', 0, () => {
        const svc = makeService({ apiKey: '' });
        expect(svc.hasValidKey()).assertFalse();
        svc.updateApiKey('sk-new');
        expect(svc.hasValidKey()).assertTrue();
      });
    });

    describe('estimateTokens（默认降级）', () => {
      it('空文本返回 0', 0, () => {
        expect(makeService().estimateTokens('')).assertEqual(0);
      });

      it('使用字符数 * 0.68 估算', 0, () => {
        expect(makeService().estimateTokens('こんにちは世界')).assertEqual(Math.round(7 * 0.68));
      });
    });

    describe('estimateTime', () => {
      it('返回正数值（毫秒）', 0, () => {
        expect(makeService().estimateTime(500) > 0).assertTrue();
      });

      it('更多 tokens 耗时更长', 0, () => {
        const svc = makeService();
        expect(svc.estimateTime(1000) >= svc.estimateTime(100)).assertTrue();
      });
    });

    describe('getSystemPrompt（默认模板）', () => {
      it('标题默认模板包含"标题"', 0, () => {
        expect(makeService().getSystemPrompt(true)).assertContain('标题');
      });

      it('全文默认模板包含"小说"', 0, () => {
        expect(makeService().getSystemPrompt(false)).assertContain('小说');
      });
    });

    describe('getSystemPrompt（自定义 prompt）', () => {
      it('自定义标题 prompt 优先于默认模板', 0, () => {
        const svc = makeService();
        svc.updatePrompts('我的自定义标题翻译规则', '', false);
        expect(svc.getSystemPrompt(true)).assertEqual('我的自定义标题翻译规则');
      });

      it('自定义全文 prompt 优先于默认模板', 0, () => {
        const svc = makeService();
        svc.updatePrompts('', '我的自定义全文翻译规则', false);
        expect(svc.getSystemPrompt(false)).assertEqual('我的自定义全文翻译规则');
      });

      it('空自定义 prompt 回退默认模板', 0, () => {
        const svc = makeService();
        svc.updatePrompts('', '', false);
        expect(svc.getSystemPrompt(true)).assertContain('标题');
      });

      it('统一模式：标题和全文共用 titlePrompt', 0, () => {
        const svc = makeService();
        svc.updatePrompts('统一翻译规则', '应被忽略的全文规则', true);
        expect(svc.getSystemPrompt(true)).assertEqual('统一翻译规则');
        expect(svc.getSystemPrompt(false)).assertEqual('统一翻译规则');
      });

      it('统一模式且 titlePrompt 为空时回退对应默认模板', 0, () => {
        const svc = makeService();
        svc.updatePrompts('', '', true);
        expect(svc.getSystemPrompt(true)).assertContain('标题');
        expect(svc.getSystemPrompt(false)).assertContain('小说');
      });
    });

    describe('buildRequestBody', () => {
      it('自定义模式（supportsThinking=false）不包含 thinking 字段', 0, () => {
        const body = makeService().buildRequestBody('テスト', true) as Record<string, Object>;
        expect(body['thinking'] === undefined).assertTrue();
      });

      it('支持 thinking 时包含 thinking.disabled', 0, () => {
        const body = makeService({ supportsThinking: true }).buildRequestBody('テスト', true) as Record<string, Object>;
        const thinking = body['thinking'] as Record<string, Object>;
        expect(thinking !== undefined).assertTrue();
        expect(thinking['type']).assertEqual('disabled');
      });

      it('标题 max_tokens 使用配置值', 0, () => {
        const body = makeService({ maxTokensTitle: 100 }).buildRequestBody('テスト', true) as Record<string, Object>;
        expect(body['max_tokens']).assertEqual(100);
      });

      it('全文 max_tokens 使用配置值', 0, () => {
        const body = makeService({ maxTokensFull: 8192 }).buildRequestBody('テスト', false) as Record<string, Object>;
        expect(body['max_tokens']).assertEqual(8192);
      });

      it('model 使用配置值', 0, () => {
        const body = makeService({ model: 'my-model' }).buildRequestBody('テスト', true) as Record<string, Object>;
        expect(body['model']).assertEqual('my-model');
      });

      it('temperature：标题 0.8 / 全文 0.3', 0, () => {
        const svc = makeService();
        const titleBody = svc.buildRequestBody('t', true) as Record<string, Object>;
        const fullBody = svc.buildRequestBody('t', false) as Record<string, Object>;
        expect(titleBody['temperature']).assertEqual(0.8);
        expect(fullBody['temperature']).assertEqual(0.3);
      });
    });

    describe('getStats', () => {
      it('初始为 0', 0, () => {
        const stats = makeService().getStats();
        expect(stats.totalChars).assertEqual(0);
        expect(stats.totalRequests).assertEqual(0);
      });
    });

    describe('translateText（无 key 时）', () => {
      it('返回失败并提示配置密钥', 0, () => {
        const svc = makeService({ apiKey: '' });
        svc.translateText('テスト', true).then((r: TranslationResult) => {
          expect(r.success).assertFalse();
          expect(r.error === '请先在设置中配置翻译 API 密钥').assertTrue();
        });
      });
    });

    describe('translateText（空文本）', () => {
      it('返回失败', 0, () => {
        const svc = makeService();
        svc.translateText('', true).then((r: TranslationResult) => {
          expect(r.success).assertFalse();
        });
      });
    });
  });
}
