import { describe, it, expect } from '@ohos/hypium';
import { getReaderColors, ReaderColors } from '../main/ets/common/utils/ThemeUtil';

export default function themeUtilTest() {
  describe('ThemeUtil', () => {
    describe('getReaderColors', () => {
      it('暗色模式返回深色主题', 0, () => {
        const colors = getReaderColors(true);
        expect(colors.pageBg).assertEqual('#0D0D0D');
        expect(colors.headerBg).assertEqual('#141414');
        expect(colors.primaryText).assertEqual('#E6E6E6');
        expect(colors.secondaryText).assertEqual('#888888');
      });

      it('亮色模式返回浅色主题', 0, () => {
        const colors = getReaderColors(false);
        expect(colors.pageBg).assertEqual('#F9F7F2');
        expect(colors.headerBg).assertEqual('#FFFFFF');
        expect(colors.primaryText).assertEqual('#1A1A1A');
        expect(colors.secondaryText).assertEqual('#666666');
      });

      it('暗色模式 accentText 为蓝色', 0, () => {
        const colors = getReaderColors(true);
        expect(colors.accentText).assertEqual('#0A84FF');
      });

      it('亮色模式 accentText 为蓝色', 0, () => {
        const colors = getReaderColors(false);
        expect(colors.accentText).assertEqual('#007DFF');
      });

      it('translateBtnText 两种模式下一致', 0, () => {
        const dark = getReaderColors(true);
        const light = getReaderColors(false);
        expect(dark.translateBtnText).assertEqual('#007DFF');
        expect(light.translateBtnText).assertEqual('#007DFF');
      });

      it('dangerText 两种模式下一致', 0, () => {
        const dark = getReaderColors(true);
        const light = getReaderColors(false);
        expect(dark.dangerText).assertEqual('#FF4D4F');
        expect(light.dangerText).assertEqual('#FF4D4F');
      });

      it('结果包含所有 17 个字段', 0, () => {
        const colors = getReaderColors(false);
        const keys = Object.keys(colors);
        expect(keys.length).assertEqual(17);
      });
    });
  });
}
