import { BaseState } from './BaseState';
import { BaseVM, BaseVMEvent } from './BaseVM';
import { PixivNovel, NovelBookmark, PixivSeriesResult } from '../models/PixivModels';
import { PixivService } from '../services/PixivService';
import { pixivCacheDB } from '../database/PixivCacheDB';

export class NovelSeriesEventType {
  static readonly LOAD_SERIES = 'LOAD_SERIES';
  static readonly LOAD_MORE = 'LOAD_MORE';
  static readonly RETRY_ONLINE = 'RETRY_ONLINE';
}

@Observed
export class NovelSeriesState extends BaseState {
  seriesId: string = '';
  seriesTitle: string = '系列详情';
  seriesCaption: string = '';
  authorName: string = '';
  seriesNovels: PixivNovel[] = [];
  bookmarks: NovelBookmark[] = [];
  isLoading: boolean = false;
  currentPage: number = 1;
  hasMore: boolean = false;
  isOfflineMode: boolean = false;
  offlineCachedCount: number = 0;
  isHeaderExpanded: boolean = true;
}

export class NovelSeriesViewModel extends BaseVM<NovelSeriesState> {
  private static instance: NovelSeriesViewModel;

  static getInstance(): NovelSeriesViewModel {
    if (!NovelSeriesViewModel.instance) {
      NovelSeriesViewModel.instance = new NovelSeriesViewModel();
    }
    return NovelSeriesViewModel.instance;
  }

  private constructor() {
    super(new NovelSeriesState());
  }

  sendEvent(event: BaseVMEvent): void {
    switch (event.type) {
      case NovelSeriesEventType.LOAD_SERIES:
        this.loadSeriesNovels((event.param as Record<string, number>)['page'] ?? 1);
        break;
      case NovelSeriesEventType.LOAD_MORE:
        this.loadMore();
        break;
      case NovelSeriesEventType.RETRY_ONLINE:
        this.retryOnline();
        break;
    }
  }

  setSeriesId(seriesId: string, seriesTitle?: string): void {
    this.state.seriesId = seriesId;
    if (seriesTitle) this.state.seriesTitle = seriesTitle;
  }

  async loadSeriesNovels(page: number): Promise<void> {
    const state = this.state;
    if (!state.seriesId) return;
    state.isLoading = true;
    const result: PixivSeriesResult | null = await PixivService.fetchSeriesNovels(state.seriesId, page);
    if (result) {
      state.isOfflineMode = false;
      const apiSeriesTitle = result.seriesTitle || '';
      const apiAuthorName = result.authorName || '';
      result.novels.forEach((novel: PixivNovel) => {
        if (!novel.author && apiAuthorName) {
          novel.author = apiAuthorName;
        }
        if (!novel.series) {
          novel.series = { id: state.seriesId, title: apiSeriesTitle || state.seriesTitle, order: 0 };
        } else {
          if (!novel.series.id) novel.series.id = state.seriesId;
          if (!novel.series.title && (apiSeriesTitle || state.seriesTitle)) {
            novel.series.title = apiSeriesTitle || state.seriesTitle;
          }
        }
      });
      if (page === 1) {
        state.seriesNovels = result.novels;
        if (apiSeriesTitle && state.seriesTitle === '系列详情') {
          state.seriesTitle = apiSeriesTitle;
        }
        state.seriesCaption = result.seriesCaption || '';
        state.authorName = apiAuthorName;
      } else {
        state.seriesNovels = state.seriesNovels.concat(result.novels);
      }
      state.bookmarks = state.seriesNovels.map(n => this.mapToBookmark(n));
      state.hasMore = result.hasMore;
      state.currentPage = page;
      for (const novel of result.novels) {
        await pixivCacheDB.saveNovelMeta(novel);
      }
    } else {
      console.warn('[NovelSeriesViewModel] 网络请求失败，尝试加载本地缓存');
      await this.loadCachedSeriesNovels();
      if (state.bookmarks.length === 0) {
        // 由页面处理 toast
      }
    }
    state.isLoading = false;
  }

  loadMore(): void {
    const state = this.state;
    if (!state.hasMore || state.isLoading) return;
    this.loadSeriesNovels(state.currentPage + 1);
  }

  retryOnline(): void {
    this.state.isOfflineMode = false;
    this.loadSeriesNovels(1);
  }

  private async loadCachedSeriesNovels(): Promise<void> {
    const state = this.state;
    state.isOfflineMode = true;
    const cached = await pixivCacheDB.getNovelsBySeriesId(state.seriesId);
    cached.sort((a: PixivNovel, b: PixivNovel): number => {
      const orderA = a.series?.order ?? parseInt(a.id, 10);
      const orderB = b.series?.order ?? parseInt(b.id, 10);
      return orderA - orderB;
    });
    state.seriesNovels = cached;
    state.bookmarks = cached.map(n => this.mapToBookmark(n));
    state.offlineCachedCount = cached.length;
    state.hasMore = false;
  }

  private mapToBookmark(novel: PixivNovel): NovelBookmark {
    return {
      id: novel.id,
      title: novel.title,
      tags: novel.tags.map(t => t.name),
      userId: novel.authorId,
      userName: novel.author,
      bookmarkData: { id: '', private: false, userId: novel.authorId },
      profileImageUrl: '',
      createDate: novel.createDate,
      updateDate: novel.updateDate,
      textCount: novel.textLength,
      wordCount: novel.textLength,
      characterCount: 0,
      readingTime: 0,
      useWordCount: true,
      url: novel.coverUrl,
      description: novel.caption,
      pageCount: novel.pageCount,
      width: 0,
      height: 0,
      restrict: 0,
      xRestrict: 0,
      sl: 0,
      isBookmarkable: true,
      isUnlisted: false,
      isMasked: false,
      bookmarkCount: novel.bookmarkCount,
      commentCount: novel.commentCount,
      markerCount: 0,
      seriesId: novel.series ? Number(novel.series.id) : undefined,
      seriesTitle: novel.series?.title || this.state.seriesTitle,
      series: novel.series ? { id: Number(novel.series.id), title: novel.series.title || this.state.seriesTitle, order: novel.series.order } as NovelBookmark['series'] : undefined,
      originalWork: false,
      aiType: 0,
      titleTranslated: novel.titleTranslated,
      hasTitleTranslation: novel.hasTitleTranslation
    };
  }
}
