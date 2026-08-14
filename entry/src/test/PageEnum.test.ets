import { describe, it, expect } from '@ohos/hypium';
import { PageEnum } from '../main/ets/common/constants/PageEnum';

export default function pageEnumTest() {
  describe('PageEnum', () => {
    it('ILLUST_DETAIL 应为 "IllustDetail"', 0, () => {
      expect(PageEnum.ILLUST_DETAIL).assertEqual('IllustDetail');
    });

    it('ILLUST_COMMENTS 应为 "IllustComments"', 0, () => {
      expect(PageEnum.ILLUST_COMMENTS).assertEqual('IllustComments');
    });

    it('NOVEL_READER 应为 "NovelReader"', 0, () => {
      expect(PageEnum.NOVEL_READER).assertEqual('NovelReader');
    });

    it('NOVEL_SERIES 应为 "NovelSeries"', 0, () => {
      expect(PageEnum.NOVEL_SERIES).assertEqual('NovelSeries');
    });

    it('NOVEL_COMMENTS 应为 "NovelComments"', 0, () => {
      expect(PageEnum.NOVEL_COMMENTS).assertEqual('NovelComments');
    });

    it('USER_PROFILE 应为 "UserProfile"', 0, () => {
      expect(PageEnum.USER_PROFILE).assertEqual('UserProfile');
    });

    it('LOGIN 应为 "Login"', 0, () => {
      expect(PageEnum.LOGIN).assertEqual('Login');
    });

    it('FAVORITES 应为 "Favorites"', 0, () => {
      expect(PageEnum.FAVORITES).assertEqual('Favorites');
    });

    it('FOLLOWING 应为 "Following"', 0, () => {
      expect(PageEnum.FOLLOWING).assertEqual('Following');
    });

    it('BLOCKED_CONTENT 应为 "BlockedContent"', 0, () => {
      expect(PageEnum.BLOCKED_CONTENT).assertEqual('BlockedContent');
    });

    it('SETTINGS 应为 "Settings"', 0, () => {
      expect(PageEnum.SETTINGS).assertEqual('Settings');
    });

    it('AUTHOR_DETAIL 应为 "AuthorDetail"', 0, () => {
      expect(PageEnum.AUTHOR_DETAIL).assertEqual('AuthorDetail');
    });

    it('CACHED_NOVELS 应为 "CachedNovels"', 0, () => {
      expect(PageEnum.CACHED_NOVELS).assertEqual('CachedNovels');
    });

    it('CACHED_NOVELS_SIMPLE 应为 "CachedNovelsSimple"', 0, () => {
      expect(PageEnum.CACHED_NOVELS_SIMPLE).assertEqual('CachedNovelsSimple');
    });

    it('SERIES_DETAIL 应为 "SeriesDetail"', 0, () => {
      expect(PageEnum.SERIES_DETAIL).assertEqual('SeriesDetail');
    });

    it('MAIN_TABS 应为 "mainTabs"', 0, () => {
      expect(PageEnum.MAIN_TABS).assertEqual('mainTabs');
    });

    it('BROWSE_HISTORY 应为 "BrowseHistory"', 0, () => {
      expect(PageEnum.BROWSE_HISTORY).assertEqual('BrowseHistory');
    });

    it('SETTINGS_TRANSLATION 应为 "SettingsTranslation"', 0, () => {
      expect(PageEnum.SETTINGS_TRANSLATION).assertEqual('SettingsTranslation');
    });

    it('SETTINGS_PROXY 应为 "SettingsProxy"', 0, () => {
      expect(PageEnum.SETTINGS_PROXY).assertEqual('SettingsProxy');
    });

    it('SETTINGS_CACHE 应为 "SettingsCache"', 0, () => {
      expect(PageEnum.SETTINGS_CACHE).assertEqual('SettingsCache');
    });

    it('SETTINGS_FILTER 应为 "SettingsFilter"', 0, () => {
      expect(PageEnum.SETTINGS_FILTER).assertEqual('SettingsFilter');
    });

    it('SETTINGS_READER 应为 "SettingsReader"', 0, () => {
      expect(PageEnum.SETTINGS_READER).assertEqual('SettingsReader');
    });
  });
}
