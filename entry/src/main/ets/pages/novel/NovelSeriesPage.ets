import promptAction from '@ohos.promptAction';
import common from '@ohos.app.ability.common';
import { curves } from '@kit.ArkUI';
import {
  PixivNovel,
  CacheStatus,
  PixivSeriesResult
} from '../../models/PixivModels';
import { PixivService } from '../../services/PixivService';
import { NovelBookmark, NovelSeries } from '../../models/PixivModels';
import { pixivCacheDB } from '../../database/PixivCacheDB';
import { NovelCard } from '../../components/NovelCard';
import { PageContext } from '../../common/utils/PageContext';
import { PageEnum } from '../../common/constants/PageEnum';
import { UserProfileParam } from '../../common/constants/PageParamTypes';

interface RouterParams {
  seriesId: string;
  seriesTitle?: string;
}

function pixivNovelToBookmark(novel: PixivNovel, seriesTitle: string): NovelBookmark {
  return {
    id: novel.id,
    title: novel.title,
    tags: novel.tags.map(t => t.name),
    userId: novel.authorId,
    userName: novel.author,
    bookmarkData: novel.bookmarkData ?? null,
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
    seriesTitle: novel.series?.title || seriesTitle,
    series: novel.series ? { id: Number(novel.series.id), title: novel.series.title || seriesTitle, order: novel.series.order } as NovelSeries : undefined,
    originalWork: false,
    aiType: 0,
    titleTranslated: novel.titleTranslated,
    hasTitleTranslation: novel.hasTitleTranslation
  };
}

@Component
struct NovelSeriesPage {
  @State navParams: Record<string, Object> = {};
  private isActive: boolean = true;
  @State seriesId: string = '';
  @State seriesTitle: string = '系列详情';
  @State seriesCaption: string = '';
  @State authorName: string = '';
  @State seriesNovels: PixivNovel[] = [];
  @State bookmarks: NovelBookmark[] = [];
  @State isLoading: boolean = false;
  @State currentPage: number = 1;
  @State hasMore: boolean = false;
  @State isOfflineMode: boolean = false;
  @State offlineCachedCount: number = 0;
  @State isHeaderExpanded: boolean = true;
  @State isHeaderVisible: boolean = true;
  private lastScrollY: number = 0;

  private configChangeCallback: () => void = () => {};
  private configCallbackId: number = -1;

  async aboutToAppear(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext;
    this.configChangeCallback = () => {};
    this.configCallbackId = ctx.getApplicationContext().on('environment', {
      onConfigurationUpdated: this.configChangeCallback,
      onMemoryLevel: (_level: number) => {}
    });
  }

  aboutToDisappear(): void {
    this.isActive = false;
    const ctx = getContext(this) as common.UIAbilityContext;
    if (ctx && this.configCallbackId !== -1) {
      ctx.getApplicationContext().off('environment', this.configCallbackId);
    }
  }

  private async loadCachedSeriesNovels(): Promise<void> {
    this.isOfflineMode = true;
    const cached = await pixivCacheDB.getNovelsBySeriesId(this.seriesId);
    if (!this.isActive) return;
    cached.sort((a: PixivNovel, b: PixivNovel): number => {
      const orderA = a.series?.order ?? parseInt(a.id, 10);
      const orderB = b.series?.order ?? parseInt(b.id, 10);
      return orderA - orderB;
    });
    this.seriesNovels = cached;
    this.bookmarks = cached.map(n => pixivNovelToBookmark(n, this.seriesTitle));
    this.offlineCachedCount = cached.length;
    this.hasMore = false;
  }

  private async loadSeriesNovels(page: number): Promise<void> {
    if (!this.seriesId) return;
    this.isLoading = true;
    const result: PixivSeriesResult | null = await PixivService.fetchSeriesNovels(this.seriesId, page);
    if (!this.isActive) return;

    if (result) {
      this.isOfflineMode = false;
      const apiSeriesTitle = result.seriesTitle || '';
      const apiAuthorName = result.authorName || '';

      result.novels.forEach((novel: PixivNovel) => {
        if (!novel.author && apiAuthorName) {
          novel.author = apiAuthorName;
        }
        if (!novel.series) {
          novel.series = { id: this.seriesId, title: apiSeriesTitle || this.seriesTitle, order: 0 };
        } else {
          if (!novel.series.id) novel.series.id = this.seriesId;
          if (!novel.series.title && (apiSeriesTitle || this.seriesTitle)) {
            novel.series.title = apiSeriesTitle || this.seriesTitle;
          }
        }
      });

      if (page === 1) {
        this.seriesNovels = result.novels;
        if (apiSeriesTitle && this.seriesTitle === '系列详情') {
          this.seriesTitle = apiSeriesTitle;
        }
        this.seriesCaption = result.seriesCaption || '';
        this.authorName = apiAuthorName;
      } else {
        this.seriesNovels = this.seriesNovels.concat(result.novels);
      }
      this.bookmarks = this.seriesNovels.map(n => pixivNovelToBookmark(n, this.seriesTitle));
      this.hasMore = result.hasMore;
      this.currentPage = page;

      for (const novel of result.novels) {
        if (!this.isActive) return;
        await pixivCacheDB.saveNovelMeta(novel);
      }
    } else {
      console.warn('[NovelSeriesPage] 网络请求失败，尝试加载本地缓存');
      await this.loadCachedSeriesNovels();
      if (!this.isActive) return;
      if (this.bookmarks.length === 0) {
        promptAction.showToast({ message: '无网络且暂无缓存，请联网后重试' });
      }
    }

    this.isLoading = false;
  }

  private loadMore(): void {
    if (!this.hasMore || this.isLoading) return;
    this.loadSeriesNovels(this.currentPage + 1);
  }

  private openAuthorPage(): void {
    if (!this.seriesNovels.length) return;
    const authorId = this.seriesNovels[0]?.authorId;
    if (authorId) {
      const pageCtx = AppStorage.get<PageContext>('rootPageContext');
      if (pageCtx) {
        const params: UserProfileParam = {
          userId: authorId,
          userName: this.authorName || this.seriesNovels[0].author
        };
        pageCtx.openPage(PageEnum.USER_PROFILE, params as Object);
      }
    }
  }

  handleHeaderScroll(yOffset: number) {
    const delta = yOffset - this.lastScrollY;
    this.lastScrollY = yOffset;

    if (delta > 0 && this.isHeaderVisible && yOffset > 5) {
      animateTo({ curve: curves.springMotion(0.45, 0.7) }, () => {
        this.isHeaderVisible = false;
      });
    } else if (delta < -3 && !this.isHeaderVisible) {
      animateTo({ curve: curves.springMotion(0.45, 0.7) }, () => {
        this.isHeaderVisible = true;
      });
    }
  }

  handleHeaderReachStart() {
    if (!this.isHeaderVisible) {
      animateTo({ curve: curves.springMotion(0.45, 0.7) }, () => {
        this.isHeaderVisible = true;
      });
    }
  }

  build() {
    NavDestination() {
    Column() {
      if (this.isHeaderVisible) {
      Row() {
        Text('‹')
          .fontSize(28)
          .fontColor($r('app.color.tab_selected'))
          .onClick(() => { const ctx = AppStorage.get<PageContext>('rootPageContext'); if (ctx) { ctx.popPage(); } })
        Text(this.seriesTitle)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .margin({ left: 12 })
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Blank()
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .backgroundColor($r('app.color.loading_card'))
      .transition(TransitionEffect.translate({ y: -48 })
        .combine(TransitionEffect.OPACITY)
        .animation({ curve: curves.springMotion(0.45, 0.7) }))

      if (this.isOfflineMode) {
        Row() {
          Text('📴').fontSize(14)
          Text(this.offlineCachedCount > 0
            ? `  离线模式 · ${this.offlineCachedCount} 部已缓存`
            : '  离线模式 · 暂无缓存')
            .fontSize(13)
            .fontColor($r('app.color.warning'))
            .layoutWeight(1)
          Text('重试')
            .fontSize(13)
            .fontColor($r('app.color.tab_selected'))
            .padding({ left: 12, top: 4, bottom: 4 })
            .onClick((): void => {
              this.isOfflineMode = false;
              this.loadSeriesNovels(1);
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .backgroundColor($r('app.color.warning_bg'))
        .transition(TransitionEffect.translate({ y: -48 })
          .combine(TransitionEffect.OPACITY)
          .animation({ curve: curves.springMotion(0.45, 0.7) }))
      }

      Column() {
        Text(this.seriesTitle)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.tab_selected'))
          .width('100%')
          .textAlign(TextAlign.Center)

        if (this.authorName) {
          Text(`作者: ${this.authorName}`)
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 8 })
            .onClick(() => this.openAuthorPage())
        }

        if (this.seriesCaption) {
          Text(this.seriesCaption)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 8 })
            .maxLines(this.isHeaderExpanded ? 999 : 3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.isHeaderExpanded ? '收起' : '展开全文')
            .fontSize(12)
            .fontColor($r('app.color.tab_selected'))
            .margin({ top: 4 })
            .onClick(() => {
              this.isHeaderExpanded = !this.isHeaderExpanded;
            })
        }

        Text(`共 ${this.bookmarks.length} 部作品${this.isOfflineMode ? '（已缓存）' : ''}`)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 8 })
      }
      .width('92%')
      .padding(16)
      .backgroundColor($r('app.color.loading_card'))
      .borderRadius(12)
      .margin({ top: 12, bottom: 12 })
      .alignSelf(ItemAlign.Center)
      .transition(TransitionEffect.translate({ y: -48 })
        .combine(TransitionEffect.OPACITY)
        .animation({ curve: curves.springMotion(0.45, 0.7) }))
      }

      if (this.isLoading && this.bookmarks.length === 0) {
        Column() {
          LoadingProgress().width(48).height(48).color($r('app.color.tab_selected'))
          Text('正在加载系列作品...')
            .fontSize(14).fontColor($r('app.color.text_secondary')).margin({ top: 12 })
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.bookmarks.length > 0) {
        Scroll() {
          Column() {
            ForEach(this.bookmarks, (item: NovelBookmark, index?: number): void => {
              NovelCard({ item: item, index: index ?? 0 })
            }, (item: NovelBookmark): string => item.id)

            if (this.hasMore) {
              Button(this.isLoading ? '加载中...' : '加载更多')
                .width('100%').height(44).fontSize(14)
                .fontColor($r('app.color.tab_selected'))
                .backgroundColor($r('app.color.surface_secondary'))
                .borderRadius(12)
                .enabled(!this.isLoading)
                .onClick((): void => { this.loadMore() })
            } else {
              Text(this.isOfflineMode ? '— 以上为本系列所有缓存作品 —' : '— 已加载全部作品 —')
                .fontSize(12).fontColor($r('app.color.text_secondary'))
                .width('100%').textAlign(TextAlign.Center)
                .padding({ top: 8, bottom: 24 })
            }
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 12, bottom: 120 })
        }
        .width('100%')
        .layoutWeight(1)
        .edgeEffect(EdgeEffect.Spring)
        .onReachStart(() => { this.handleHeaderReachStart(); })
        .onScroll((_xOffset: number, yOffset: number) => {
          this.handleHeaderScroll(yOffset);
        })
        .onReachEnd(() => {
          if (this.hasMore && !this.isLoading) {
            this.loadMore();
          }
        })
      } else {
        Column() {
          Text('📚').fontSize(60).margin({ bottom: 16 })
          Text(this.isOfflineMode ? '本系列暂无缓存作品' : '暂无作品')
            .fontSize(16).fontColor($r('app.color.text_secondary'))
          Text(this.isOfflineMode ? '请联网后访问以加载完整列表' : '')
            .fontSize(12).fontColor($r('app.color.text_secondary')).margin({ top: 8 })
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
    }
    .onReady((ctx: NavDestinationContext) => {
      this.navParams = ctx.pathInfo.param as Record<string, Object> ?? {};
      const params = this.navParams as Record<string, Object>;
      if (params['seriesId']) {
        this.seriesId = params['seriesId'] as string;
        if (params['seriesTitle']) {
          this.seriesTitle = params['seriesTitle'] as string;
        }
        const uiCtx = getContext(this) as common.UIAbilityContext;
        pixivCacheDB.init(uiCtx).then(() => {
          this.loadSeriesNovels(1);
        });
      }
    })
    .onBackPressed(() => {
      const pageCtx = AppStorage.get<PageContext>('rootPageContext');
      if (pageCtx) { pageCtx.popPage(); }
      return true;
    })
    .hideTitleBar(true)
  }
}

@Builder
export function NovelSeriesBuilder(): void {
  NovelSeriesPage()
}
