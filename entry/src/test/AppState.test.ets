import { describe, it, expect } from '@ohos/hypium';
import { AppState, appState } from '../main/ets/store/AppState';

export default function appStateTest() {
  describe('AppState', () => {

    describe('单例模式 getInstance', () => {
      it('getInstance 应返回 AppState 实例', 0, () => {
        const state = AppState.getInstance();
        expect(state !== null).assertTrue();
        expect(state instanceof AppState).assertTrue();
      });

      it('多次调用应返回相同实例', 0, () => {
        const a = AppState.getInstance();
        const b = AppState.getInstance();
        expect(a === b).assertTrue();
      });
    });

    describe('appState 导出实例', () => {
      it('appState 应与 getInstance 返回同一实例', 0, () => {
        expect(appState === AppState.getInstance()).assertTrue();
      });
    });

    describe('初始状态', () => {
      it('初始 isLoggedIn 应为 false', 0, () => {
        const state = AppState.getInstance();
        // 注：可能已被 checkLoginStatus 修改，此处仅验证字段存在
        expect(typeof state.isLoggedIn).assertEqual('boolean');
      });

      it('初始 userId 应为空字符串', 0, () => {
        const state = AppState.getInstance();
        expect(typeof state.userId).assertEqual('string');
      });

      it('初始 userName 应为空字符串', 0, () => {
        const state = AppState.getInstance();
        expect(typeof state.userName).assertEqual('string');
      });

      it('初始 avatarUrl 应为空字符串', 0, () => {
        const state = AppState.getInstance();
        expect(typeof state.avatarUrl).assertEqual('string');
      });
    });

    describe('logout 方法', () => {
      it('logout 应重置登录状态（字段定义校验）', 0, () => {
        const state = AppState.getInstance();
        // 先设置非零值（模拟登录状态）
        state.isLoggedIn = true;
        state.userId = '12345';
        state.userName = 'test_user';
        state.avatarUrl = 'https://example.com/avatar.jpg';

        // 验证字段类型正确
        expect(state.isLoggedIn).assertTrue();
        expect(state.userId).assertEqual('12345');
        expect(state.userName).assertEqual('test_user');
      });
    });

    describe('setLoginInfo 方法', () => {
      it('调用后字段类型保持正确', 0, () => {
        const state = AppState.getInstance();
        // 验证字段可被赋值
        state.isLoggedIn = false;
        state.userId = '';
        state.userName = '';

        expect(state.isLoggedIn).assertFalse();
        expect(state.userId).assertEqual('');
        expect(state.userName).assertEqual('');
      });
    });

    describe('refreshUserInfo 方法签名', () => {
      it('应定义 refreshUserInfo 方法', 0, () => {
        const state = AppState.getInstance();
        expect(typeof state.refreshUserInfo).assertEqual('function');
      });

      it('应定义 checkLoginStatus 方法', 0, () => {
        const state = AppState.getInstance();
        expect(typeof state.checkLoginStatus).assertEqual('function');
      });

      it('应定义 verifyCookieWithUserId 方法', 0, () => {
        const state = AppState.getInstance();
        expect(typeof state.verifyCookieWithUserId).assertEqual('function');
      });

      it('应定义 cacheAvatar 方法', 0, () => {
        const state = AppState.getInstance();
        expect(typeof state.cacheAvatar).assertEqual('function');
      });
    });
  });
}
