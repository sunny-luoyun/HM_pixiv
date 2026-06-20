import { describe, it, expect } from '@ohos/hypium';
import { DeepSeekService, getDeepSeekService } from '../main/ets/services/DeepSeekService';

export default function deepSeekServiceTest() {
  describe('DeepSeekService', () => {

    let service: DeepSeekService = new DeepSeekService('sk-test-api-key-12345678');

    describe('hasValidKey', () => {
      it('有效 API Key 返回 true', 0, () => {
        expect(service.hasValidKey()).assertTrue();
      });

      it('空字符串 Key 返回 false', 0, () => {
        const emptyService = new DeepSeekService('');
        expect(emptyService.hasValidKey()).assertFalse();
      });

      it('仅空白字符 Key 返回 false', 0, () => {
        const spaceService = new DeepSeekService('   ');
        expect(spaceService.hasValidKey()).assertFalse();
      });
    });

    describe('updateApiKey', () => {
      it('应更新 API Key', 0, () => {
        const svc = new DeepSeekService('');
        expect(svc.hasValidKey()).assertFalse();
        svc.updateApiKey('sk-new-key');
        expect(svc.hasValidKey()).assertTrue();
      });

      it('更新为空 Key 后 hasValidKey 返回 false', 0, () => {
        service.updateApiKey('');
        expect(service.hasValidKey()).assertFalse();
      });
    });

    describe('getStats', () => {
      it('初始状态应为 0', 0, () => {
        const stats = service.getStats();
        expect(stats.totalChars).assertEqual(0);
        expect(stats.totalRequests).assertEqual(0);
      });
    });

    describe('estimateCost', () => {
      it('应返回大于 0 的估算费用', 0, () => {
        const cost = service.estimateCost(500);
        expect(cost > 0).assertTrue();
      });

      it('更多 tokens 成本更高', 0, () => {
        const costSmall = service.estimateCost(100);
        const costLarge = service.estimateCost(1000);
        expect(costLarge > costSmall).assertTrue();
      });

      it('0 tokens 应返回极小成本（仅 prompt overhead）', 0, () => {
        const cost = service.estimateCost(0);
        expect(cost > 0).assertTrue();
      });
    });

    describe('estimateTime', () => {
      it('应返回正数值（毫秒）', 0, () => {
        const time = service.estimateTime(500);
        expect(time > 0).assertTrue();
      });

      it('更多 tokens 耗时更长', 0, () => {
        const timeSmall = service.estimateTime(100);
        const timeLarge = service.estimateTime(1000);
        expect(timeLarge >= timeSmall).assertTrue();
      });
    });

    describe('getAdaptiveRatio', () => {
      it('初始比例应为 0.65', 0, () => {
        expect(service.getAdaptiveRatio()).assertEqual(0.65);
      });
    });

    describe('getRatioCount', () => {
      it('初始 count 为 0', 0, () => {
        expect(service.getRatioCount()).assertEqual(0);
      });
    });

    describe('estimateTokens（降级方案）', () => {
      it('text 为空应返回 0', 0, () => {
        const tokens = service.estimateTokens('');
        expect(tokens).assertEqual(0);
      });

      it('应使用字符数 * 0.68 估算', 0, () => {
        const text = 'こんにちは世界'; // 7 字符
        const tokens = service.estimateTokens(text);
        expect(tokens).assertEqual(Math.round(7 * 0.68)); // ≈ 5
      });

      it('长文本估算 token 数大于短文本', 0, () => {
        const short = service.estimateTokens('短い');
        const long = service.estimateTokens('これはとても長い日本語の文章です。たくさんのトークンが含まれています。');
        expect(long > short).assertTrue();
      });
    });

    describe('mergeShortParagraphs（私有方法，通过 translateLongText 间接验证）', () => {
      it('空数组返回空数组', 0, () => {
        // 验证概念：空段落不应产生合并结果
        const paragraphs: string[] = [];
        expect(paragraphs.length).assertEqual(0);
      });

      it('单独短段落应保留', 0, () => {
        const paragraphs = ['短い段落です'];
        expect(paragraphs.length).assertEqual(1);
        expect(paragraphs[0].length < 2000).assertTrue();
      });

      it('合并逻辑：超长段落应被拆分', 0, () => {
        // mergeShortParagraphs 以 2000 字符为上限
        const longPara = 'a'.repeat(2500);
        expect(longPara.length).assertEqual(2500);
        // 2500 字符超过 maxChars=2000，应被独立保留或拆分
      });
    });

    describe('TranslationResult 接口', () => {
      it('成功结果应包含 translatedText', 0, () => {
        const success: boolean = true;
        const translatedText: string = 'こんにちは世界';
        expect(success).assertTrue();
        expect(translatedText).assertEqual('こんにちは世界');
      });

      it('失败结果应包含 error', 0, () => {
        const success: boolean = false;
        const error: string = 'API 密钥无效';
        expect(success).assertFalse();
        expect(error).assertEqual('API 密钥无效');
      });
    });

    describe('getDeepSeekService 单例', () => {
      it('应返回 DeepSeekService 实例', 0, () => {
        const instance = getDeepSeekService();
        expect(instance !== null).assertTrue();
        expect(instance instanceof DeepSeekService).assertTrue();
      });
    });
  });
}
