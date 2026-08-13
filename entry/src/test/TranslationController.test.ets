import { describe, it, expect } from '@ohos/hypium';
import { buildEstimateInfo } from '../main/ets/services/TranslationController';

export default function translationControllerTest() {
  describe('TranslationController.buildEstimateInfo', () => {

    it('DeepSeek 模式（showCostInfo=true）包含费用与校准行', 0, () => {
      const info = buildEstimateInfo('你好'.repeat(50), 100, 60000, 0.0123, 0.65, 3, true);
      expect(info).assertContain('tokens');
      expect(info).assertContain('费用约 ¥0.0123');
      expect(info).assertContain('输出/输入比 0.650');
    });

    it('自定义模式（showCostInfo=false）不含 token/费用/校准行', 0, () => {
      const info = buildEstimateInfo('你好'.repeat(50), 100, 60000, 0.0123, 0.65, 3, false);
      expect(info.indexOf('tokens')).assertEqual(-1);
      expect(info.indexOf('费用')).assertEqual(-1);
      expect(info.indexOf('校准')).assertEqual(-1);
      expect(info).assertContain('预计翻译 100 字符');
      expect(info).assertContain('约 1 分');
    });

    it('耗时格式：不足 1 分钟显示秒', 0, () => {
      const info = buildEstimateInfo('a', 10, 45000, 0.01, 0.65, 0, false);
      expect(info).assertContain('约 45 秒');
    });
  });
}
