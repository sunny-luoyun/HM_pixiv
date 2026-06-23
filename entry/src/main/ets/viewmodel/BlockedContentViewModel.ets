import { BaseState } from './BaseState';
import { BaseVM, BaseVMEvent } from './BaseVM';
import { pixivCacheDB } from '../database/PixivCacheDB';
import { BlockedAuthor, BlockedSeries, BlockedSeriesTitle } from '../models/PixivModels';
import common from '@ohos.app.ability.common';

export class BlockedContentEventType {
  static readonly LOAD_BLOCKED = 'LOAD_BLOCKED';
  static readonly UNBLOCK_AUTHOR = 'UNBLOCK_AUTHOR';
  static readonly UNBLOCK_SERIES = 'UNBLOCK_SERIES';
  static readonly UNBLOCK_SERIES_TITLE = 'UNBLOCK_SERIES_TITLE';
}

@Observed
export class BlockedContentState extends BaseState {
  blockedAuthors: BlockedAuthor[] = [];
  blockedSeries: BlockedSeries[] = [];
  blockedSeriesTitles: BlockedSeriesTitle[] = [];
  isLoading: boolean = true;
}

export class BlockedContentViewModel extends BaseVM<BlockedContentState> {
  private static instance: BlockedContentViewModel;

  static getInstance(): BlockedContentViewModel {
    if (!BlockedContentViewModel.instance) {
      BlockedContentViewModel.instance = new BlockedContentViewModel();
    }
    return BlockedContentViewModel.instance;
  }

  private constructor() {
    super(new BlockedContentState());
  }

  sendEvent(event: BaseVMEvent): void {
    switch (event.type) {
      case BlockedContentEventType.LOAD_BLOCKED:
        this.loadBlockedContent();
        break;
      case BlockedContentEventType.UNBLOCK_AUTHOR:
        this.unblockAuthor((event.param as Record<string, string>)['authorId'] ?? '');
        break;
      case BlockedContentEventType.UNBLOCK_SERIES:
        this.unblockSeries((event.param as Record<string, string>)['seriesId'] ?? '');
        break;
      case BlockedContentEventType.UNBLOCK_SERIES_TITLE:
        this.unblockSeriesTitle((event.param as Record<string, string>)['title'] ?? '');
        break;
    }
  }

  async loadBlockedContent(): Promise<void> {
    const state = this.state;
    state.isLoading = true;
    try {
      const ctx = AppStorage.get<common.UIAbilityContext>('appContext');
      if (!ctx) return;
      await pixivCacheDB.init(ctx);
      const results = await Promise.all([
        pixivCacheDB.getAllBlockedAuthors(),
        pixivCacheDB.getAllBlockedSeries(),
        pixivCacheDB.getAllBlockedSeriesTitles()
      ]);
      state.blockedAuthors = results[0];
      state.blockedSeries = results[1];
      state.blockedSeriesTitles = results[2];
    } catch (err) {
      console.error('加载屏蔽内容失败:', err);
    }
    state.isLoading = false;
  }

  async unblockAuthor(authorId: string): Promise<void> {
    try {
      const ctx = AppStorage.get<common.UIAbilityContext>('appContext');
      if (!ctx) return;
      await pixivCacheDB.init(ctx);
      await pixivCacheDB.removeBlockedAuthor(authorId);
      this.state.blockedAuthors = this.state.blockedAuthors.filter(a => a.authorId !== authorId);
    } catch (err) {
      console.error('取消屏蔽作者失败:', err);
    }
  }

  async unblockSeries(seriesId: string): Promise<void> {
    try {
      const ctx = AppStorage.get<common.UIAbilityContext>('appContext');
      if (!ctx) return;
      await pixivCacheDB.init(ctx);
      await pixivCacheDB.removeBlockedSeries(seriesId);
      this.state.blockedSeries = this.state.blockedSeries.filter(s => s.seriesId !== seriesId);
    } catch (err) {
      console.error('取消屏蔽系列失败:', err);
    }
  }

  async unblockSeriesTitle(title: string): Promise<void> {
    try {
      const ctx = AppStorage.get<common.UIAbilityContext>('appContext');
      if (!ctx) return;
      await pixivCacheDB.init(ctx);
      await pixivCacheDB.removeBlockedSeriesTitle(title);
      this.state.blockedSeriesTitles = this.state.blockedSeriesTitles.filter(t => t.title !== title);
    } catch (err) {
      console.error('取消屏蔽系列名称失败:', err);
    }
  }
}
