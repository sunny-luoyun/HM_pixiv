import { describe, it, expect } from '@ohos/hypium';
import { OpenAiCompatService } from '../main/ets/services/OpenAiCompatService';
import { TranslationResult } from '../main/ets/services/LlmProvider';

export default function openAiCompatServiceTest() {
  describe('OpenAiCompatService', () => {

    let service: OpenAiCompatService = new OpenAiCompatService(
      'https://example.com/v1/chat/completions', 'sk-custom-123', 'my-model');

    describe('构造与配置', () => {
      it('hasValidKey 为 true', 0, () => {
        expect(service.hasValidKey()).assertTrue();
      });

      it('空 key 构造 hasValidKey 为 false', 0, () => {
        expect(new OpenAiCompatService('', '', '').hasValidKey()).assertFalse();
      });

      it('supportsCostEstimate 为 false（自定义模式无费用估算）', 0, () => {
        expect(service.supportsCostEstimate).assertFalse();
      });
    });

    describe('updateConfig', () => {
      it('更新后 hasValidKey 反映新 key', 0, () => {
        service.updateConfig('https://a.com/v1', '', 'm1');
        expect(service.hasValidKey()).assertFalse();
        service.updateConfig('https://a.com/v1', 'sk-new', 'm1');
        expect(service.hasValidKey()).assertTrue();
      });
    });

    describe('estimateTokens（默认降级）', () => {
      it('字符数 * 0.68 估算', 0, () => {
        expect(service.estimateTokens('こんにちは世界')).assertEqual(Math.round(7 * 0.68));
      });
    });

    describe('getSystemPrompt', () => {
      it('自定义标题 prompt 优先', 0, () => {
        service.updatePrompts('我的标题规则', '', false);
        expect(service.getSystemPrompt(true)).assertEqual('我的标题规则');
        service.updatePrompts('', '', false);
      });

      it('未设置时用默认模板', 0, () => {
        expect(service.getSystemPrompt(true)).assertContain('标题');
        expect(service.getSystemPrompt(false)).assertContain('小说');
      });
    });

    describe('buildRequestBody', () => {
      it('自定义模式不含 thinking 字段', 0, () => {
        const body = service.buildRequestBody('テスト', true) as Record<string, Object>;
        expect(body['thinking'] === undefined).assertTrue();
      });

      it('全文 max_tokens 为 8192（保守值）', 0, () => {
        const body = service.buildRequestBody('テスト', false) as Record<string, Object>;
        expect(body['max_tokens']).assertEqual(8192);
      });
    });

    describe('translateText（无 key 时）', () => {
      it('返回失败并提示配置密钥', 0, async () => {
        const svc = new OpenAiCompatService('', '', '');
        const r: TranslationResult = await svc.translateText('テスト', true);
        expect(r.success).assertFalse();
      });
    });
  });
}
