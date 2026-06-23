import { BaseState } from './BaseState';
import { BaseVM, BaseVMEvent } from './BaseVM';
import { pixivCacheDB } from '../database/PixivCacheDB';
import { PixivNovel } from '../models/PixivModels';
import common from '@ohos.app.ability.common';

export class SeriesDetailEventType {
  static readonly LOAD_SERIES = 'LOAD_SERIES';
}

@Observed
export class SeriesDetailState extends BaseState {
  seriesId: string = '';
  seriesTitle: string = '';
  authorName: string = '';
  novels: PixivNovel[] = [];
  isLoading: boolean = true;
}

export class SeriesDetailViewModel extends BaseVM<SeriesDetailState> {
  private static instance: SeriesDetailViewModel;

  static getInstance(): SeriesDetailViewModel {
    if (!SeriesDetailViewModel.instance) {
      SeriesDetailViewModel.instance = new SeriesDetailViewModel();
    }
    return SeriesDetailViewModel.instance;
  }

  private constructor() {
    super(new SeriesDetailState());
  }

  sendEvent(event: BaseVMEvent): void {
    switch (event.type) {
      case SeriesDetailEventType.LOAD_SERIES:
        this.loadSeriesNovels();
        break;
    }
  }

  setSeries(seriesId: string, seriesTitle: string, authorName: string): void {
    this.state.seriesId = seriesId;
    this.state.seriesTitle = seriesTitle;
    this.state.authorName = authorName;
  }

  async loadSeriesNovels(): Promise<void> {
    const state = this.state;
    state.isLoading = true;
    try {
      const ctx = AppStorage.get<common.UIAbilityContext>('appContext');
      if (!ctx) return;
      await pixivCacheDB.init(ctx);
      state.novels = await pixivCacheDB.getNovelsBySeriesId(state.seriesId);
    } catch (err) {
      console.error('获取系列小说失败:', err);
    }
    state.isLoading = false;
  }
}
