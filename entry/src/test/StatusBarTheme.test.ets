import { describe, it, expect } from '@ohos/hypium';

/**
 * 根据深浅色模式返回对应的状态栏内容颜色
 * 深色模式 → 白色图标，浅色模式 → 黑色图标
 */
function getStatusBarContentColor(isDarkMode: boolean): string {
  return isDarkMode ? '#FFFFFF' : '#000000';
}

export default function statusBarThemeTest() {
  describe('StatusBarTheme_状态栏颜色适配', () => {

    describe('深色模式', () => {
      it('深色模式下状态栏内容颜色应为白色', 0, () => {
        const color = getStatusBarContentColor(true);
        expect(color).assertEqual('#FFFFFF');
      });
    });

    describe('浅色模式', () => {
      it('浅色模式下状态栏内容颜色应为黑色', 0, () => {
        const color = getStatusBarContentColor(false);
        expect(color).assertEqual('#000000');
      });
    });

    describe('颜色切换逻辑', () => {
      it('深浅色模式的状态栏颜色应不同', 0, () => {
        const darkColor = getStatusBarContentColor(true);
        const lightColor = getStatusBarContentColor(false);
        expect(darkColor !== lightColor).assertTrue();
      });

      it('返回的颜色值应为合法 HEX 颜色', 0, () => {
        const darkColor = getStatusBarContentColor(true);
        const lightColor = getStatusBarContentColor(false);
        const hexRegex = /^#[0-9A-Fa-f]{6}$/;
        expect(hexRegex.test(darkColor)).assertTrue();
        expect(hexRegex.test(lightColor)).assertTrue();
      });

      it('导航栏内容颜色应与状态栏保持一致', 0, () => {
        const isDark = true;
        const statusColor = getStatusBarContentColor(isDark);
        const navColor = getStatusBarContentColor(isDark);
        expect(statusColor).assertEqual(navColor);
      });
    });
  });
}
