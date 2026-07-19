import { describe, it, expect } from '@ohos/hypium';
import { StorageKeys } from '../main/ets/common/constants/StorageKeys';

export default function storageKeysTest() {
  describe('StorageKeys', () => {
    it('IS_DARK_MODE 为 "isDarkMode"', 0, () => {
      expect(StorageKeys.IS_DARK_MODE).assertEqual('isDarkMode');
    });

    it('IS_LOGGED_IN 为 "isLoggedIn"', 0, () => {
      expect(StorageKeys.IS_LOGGED_IN).assertEqual('isLoggedIn');
    });

    it('APP_CONTEXT 为 "appContext"', 0, () => {
      expect(StorageKeys.APP_CONTEXT).assertEqual('appContext');
    });

    it('UI_CONTEXT 为 "uiContext"', 0, () => {
      expect(StorageKeys.UI_CONTEXT).assertEqual('uiContext');
    });

    it('DEEPSEEK_API_KEY 为 "deepseekApiKey"', 0, () => {
      expect(StorageKeys.DEEPSEEK_API_KEY).assertEqual('deepseekApiKey');
    });

    it('RESET_ON_REACH_END 为 "resetOnReachEnd"', 0, () => {
      expect(StorageKeys.RESET_ON_REACH_END).assertEqual('resetOnReachEnd');
    });

    it('NAV_ROOT_STACK 为 "navRootStack"', 0, () => {
      expect(StorageKeys.NAV_ROOT_STACK).assertEqual('navRootStack');
    });

    it('PAGE_CONTEXT 为 "pageContext"', 0, () => {
      expect(StorageKeys.PAGE_CONTEXT).assertEqual('pageContext');
    });
  });
}
