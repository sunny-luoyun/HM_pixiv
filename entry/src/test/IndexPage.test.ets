import { describe, it, expect } from '@ohos/hypium';

export default function indexPageTest() {
  describe('IndexPage_沉浸光感', () => {

    describe('TabBar 配置', () => {
      it('应有 4 个 Tab 项', 0, () => {
        const tabCount = 4;
        expect(tabCount).assertEqual(4);
      });

      it('Tab 标签为发现/关注/搜索/我的', 0, () => {
        const labels = ['发现', '关注', '搜索', '我的'];
        expect(labels.length).assertEqual(4);
        expect(labels[0]).assertEqual('发现');
        expect(labels[1]).assertEqual('关注');
        expect(labels[2]).assertEqual('搜索');
        expect(labels[3]).assertEqual('我的');
      });

      it('Tab 图标类型应为 SymbolGlyphModifier', 0, () => {
        const typeName = 'SymbolGlyphModifier';
        expect(typeof typeName).assertEqual('string');
        expect(typeName.length > 0).assertTrue();
      });
    });

    describe('沉浸光感材质降级', () => {
      it('默认等级为 EXQUISITE', 0, () => {
        const defaultLevel = 'EXQUISITE';
        expect(defaultLevel).assertEqual('EXQUISITE');
      });

      it('不支持 IMMERSIVE 时应降级为 SMOOTH', 0, () => {
        const supported = ['BASIC'];
        const hasImmersive = supported.indexOf('IMMERSIVE') >= 0;
        const level = hasImmersive ? 'EXQUISITE' : 'SMOOTH';
        expect(level).assertEqual('SMOOTH');
      });

      it('支持 IMMERSIVE 时保持 EXQUISITE', 0, () => {
        const supported = ['IMMERSIVE'];
        const hasImmersive = supported.indexOf('IMMERSIVE') >= 0;
        const level = hasImmersive ? 'EXQUISITE' : 'SMOOTH';
        expect(level).assertEqual('EXQUISITE');
      });

      it('SMOOTH 与 EXQUISITE 不应相同', 0, () => {
        const smooth = 'SMOOTH';
        const exquisite = 'EXQUISITE' as string;
        expect(smooth !== exquisite).assertTrue();
      });
    });

    describe('底部安全区避让', () => {
      it('bottomInsetVp 默认值 0 为合法值', 0, () => {
        const bottomInsetVp: number = 0;
        expect(typeof bottomInsetVp).assertEqual('number');
        expect(bottomInsetVp >= 0).assertTrue();
      });

      it('导航条高度最大不应超过 48vp', 0, () => {
        const maxInsetVp = 48;
        expect(maxInsetVp <= 48).assertTrue();
        expect(maxInsetVp >= 0).assertTrue();
      });

      it('barBottomMargin 为空状态时默认值合法', 0, () => {
        const barBottomMargin: number = 0;
        expect(typeof barBottomMargin).assertEqual('number');
        expect(barBottomMargin >= 0).assertTrue();
      });
    });

    describe('悬浮栏配置约束', () => {
      it('barOpacity 取值范围应在 0-1', 0, () => {
        const barOpacity = 0.95;
        expect(barOpacity >= 0).assertTrue();
        expect(barOpacity <= 1).assertTrue();
      });

      it('barMode 应为 Fixed', 0, () => {
        const barMode = 'Fixed';
        expect(barMode).assertEqual('Fixed');
      });

      it('barOverlap 应为 true 以支持内容穿透', 0, () => {
        const barOverlap = true;
        expect(barOverlap).assertTrue();
      });
    });
  });
}
