import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { PageEnum } from '../main/ets/common/constants/PageEnum';
import { StorageKeys } from '../main/ets/common/constants/StorageKeys';

export default function constantsTest() {
  describe('PageEnum', () => {
    it('should_have_all_route_names', 0, () => {
      expect(PageEnum.ILLUST_DETAIL).assertEqual('IllustDetail');
      expect(PageEnum.NOVEL_READER).assertEqual('NovelReader');
      expect(PageEnum.USER_PROFILE).assertEqual('UserProfile');
      expect(PageEnum.LOGIN).assertEqual('Login');
      expect(PageEnum.FAVORITES).assertEqual('Favorites');
      expect(PageEnum.SETTINGS).assertEqual('Settings');
    });

    it('should_have_unique_values', 0, () => {
      const s1: string = PageEnum.ILLUST_DETAIL;
      const s2: string = PageEnum.NOVEL_READER;
      const s3: string = PageEnum.USER_PROFILE;
      expect(s1 !== s2).assertTrue();
      expect(s1 !== s3).assertTrue();
      expect(s2 !== s3).assertTrue();
    });
  });

  describe('StorageKeys', () => {
    it('should_have_defined_keys', 0, () => {
      expect(StorageKeys.IS_DARK_MODE).assertEqual('isDarkMode');
      expect(StorageKeys.APP_CONTEXT).assertEqual('appContext');
      expect(StorageKeys.IS_LOGGED_IN).assertEqual('isLoggedIn');
    });
  });
}
