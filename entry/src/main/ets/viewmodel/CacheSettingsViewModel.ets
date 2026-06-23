import { BaseState } from './BaseState';
import { BaseVM, BaseVMEvent } from './BaseVM';
import { PixivService } from '../services/PixivService';
import { pixivCacheDB } from '../database/PixivCacheDB';
import { formatFileSize } from '../common/utils/FormatUtil';
import common from '@ohos.app.ability.common';

export class CacheSettingsEventType {
  static readonly INIT_CACHE = 'INIT_CACHE';
  static readonly REFRESH_CACHE = 'REFRESH_CACHE';
  static readonly CLEAR_IMAGE_CACHE = 'CLEAR_IMAGE_CACHE';
  static readonly CLEAR_ALL_IMAGE_CACHE = 'CLEAR_ALL_IMAGE_CACHE';
  static readonly CLEAR_NOVEL_CACHE = 'CLEAR_NOVEL_CACHE';
}

@Observed
export class CacheSettingsState extends BaseState {
  illustCacheSize: number = 0;
  illustCacheCount: number = 0;
  novelCoverCacheSize: number = 0;
  novelCoverCacheCount: number = 0;
  avatarCacheSize: number = 0;
  avatarCacheCount: number = 0;
  totalCacheSize: number = 0;
  cachedNovelCount: number = 0;
  isLoadingCache: boolean = true;
}

export class CacheSettingsViewModel extends BaseVM<CacheSettingsState> {
  private static instance: CacheSettingsViewModel;

  static getInstance(): CacheSettingsViewModel {
    if (!CacheSettingsViewModel.instance) {
      CacheSettingsViewModel.instance = new CacheSettingsViewModel();
    }
    return CacheSettingsViewModel.instance;
  }

  private constructor() {
    super(new CacheSettingsState());
  }

  sendEvent(event: BaseVMEvent): void {
    switch (event.type) {
      case CacheSettingsEventType.INIT_CACHE:
        this.initCache();
        break;
      case CacheSettingsEventType.REFRESH_CACHE:
        this.refreshCacheInfo();
        break;
      case CacheSettingsEventType.CLEAR_IMAGE_CACHE:
        this.clearImageCache((event.param as Record<string, string>)['category'] ?? '');
        break;
      case CacheSettingsEventType.CLEAR_ALL_IMAGE_CACHE:
        this.clearAllImageCache();
        break;
      case CacheSettingsEventType.CLEAR_NOVEL_CACHE:
        this.clearNovelCache();
        break;
    }
  }

  async initCache(): Promise<void> {
    const ctx = AppStorage.get<common.UIAbilityContext>('appContext');
    if (ctx) {
      await pixivCacheDB.init(ctx);
    }
    await this.refreshCacheInfo();
  }

  async refreshCacheInfo(): Promise<void> {
    const state = this.state;
    state.isLoadingCache = true;
    try {
      const results = await Promise.all([
        PixivService.getCategoryCacheInfo('illust_'),
        PixivService.getCategoryCacheInfo('novel_'),
        PixivService.getCategoryCacheInfo('user_'),
        PixivService.getCategoryCacheInfo('avatar_'),
        pixivCacheDB.getCachedNovelCount()
      ]);
      const illust = results[0];
      const novelCover = results[1];
      const user = results[2];
      const avatar = results[3];
      const novelCount = results[4];
      state.illustCacheSize = illust.size;
      state.illustCacheCount = illust.count;
      state.novelCoverCacheSize = novelCover.size;
      state.novelCoverCacheCount = novelCover.count;
      state.avatarCacheSize = user.size + avatar.size;
      state.avatarCacheCount = user.count + avatar.count;
      state.totalCacheSize = illust.size + novelCover.size + user.size + avatar.size;
      state.cachedNovelCount = novelCount;
    } catch (err) {
      console.error('获取缓存信息失败:', err);
    }
    state.isLoadingCache = false;
  }

  async clearImageCache(category: string): Promise<void> {
    try {
      if (category === 'illust') {
        await PixivService.clearCategoryCache('illust_');
      } else if (category === 'novel') {
        await PixivService.clearCategoryCache('novel_');
      } else if (category === 'avatar') {
        await PixivService.clearCategoryCache('user_');
        await PixivService.clearCategoryCache('avatar_');
      }
      await this.refreshCacheInfo();
    } catch (err) {
      console.error('清除缓存失败:', err);
    }
  }

  async clearAllImageCache(): Promise<void> {
    try {
      await PixivService.clearAllImageCache();
      await this.refreshCacheInfo();
    } catch (err) {
      console.error('清除全部图片缓存失败:', err);
    }
  }

  async clearNovelCache(): Promise<void> {
    try {
      await pixivCacheDB.deleteAllCachedNovels();
      await this.refreshCacheInfo();
    } catch (err) {
      console.error('清除小说缓存失败:', err);
    }
  }
}
