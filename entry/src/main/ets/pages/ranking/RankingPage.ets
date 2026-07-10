import { curves } from '@kit.ArkUI';
import { PixivService } from '../../services/PixivService';
import { IllustBookmark, NovelBookmark, BookmarkData, RankingContentItem, NovelRankItem } from '../../models/PixivModels';
import { IllustCard } from '../../components/IllustCard';
import { NovelCard } from '../../components/NovelCard';
import { PullToRefresh } from '../../components/PullToRefresh';
import { SegmentedTabBar } from '../../components/SegmentedTabBar';
import { BasicDataSource } from '../../common/utils/BasicDataSource';
import { getColumnsTemplate, getNovelColumnsTemplate } from '../../common/utils/BreakpointManager';

interface RankingMode {
  key: string;
  label: string;
  needLogin: boolean;
}

interface RankingCategory {
  label: string;
  content: string;
  isNovel: boolean;
}

const CATEGORIES: RankingCategory[] = [
  { label: '综合', content: 'all', isNovel: false },
  { label: '插画', content: 'illust', isNovel: false },
  { label: '漫画', content: 'manga', isNovel: false },
  { label: '小说', content: '', isNovel: true },
];

const ILLUST_MODES: RankingMode[] = [
  { key: 'daily', label: '每日', needLogin: false },
  { key: 'weekly', label: '每周', needLogin: false },
  { key: 'monthly', label: '每月', needLogin: false },
  { key: 'rookie', label: '新人', needLogin: false },
  { key: 'daily_r18', label: 'R18', needLogin: true },
  { key: 'weekly_r18', label: 'R18周', needLogin: true },
];

const ALL_MODES: RankingMode[] = [
  { key: 'daily', label: '每日', needLogin: false },
  { key: 'weekly', label: '每周', needLogin: false },
  { key: 'monthly', label: '每月', needLogin: false },
  { key: 'rookie', label: '新人', needLogin: false },
  { key: 'original', label: '原创', needLogin: false },
  { key: 'daily_ai', label: 'AI每日', needLogin: false },
  { key: 'daily_r18', label: 'R18', needLogin: true },
  { key: 'weekly_r18', label: 'R18周', needLogin: true },
];

const NOVEL_MODES: RankingMode[] = [
  { key: 'daily', label: '每日', needLogin: false },
  { key: 'weekly', label: '每周', needLogin: false },
  { key: 'monthly', label: '每月', needLogin: false },
  { key: 'rookie', label: '新人', needLogin: false },
  { key: 'weekly_original', label: '原创', needLogin: false },
  { key: 'weekly_ai', label: 'AI', needLogin: false },
  { key: 'male', label: '男性', needLogin: false },
  { key: 'female', label: '女性', needLogin: false },
  { key: 'daily_r18', label: 'R18', needLogin: true },
  { key: 'weekly_r18', label: 'R18周', needLogin: true },
];

const PRELOAD_THRESHOLD = 1500;

function mapRankingToIllust(item: RankingContentItem): IllustBookmark {
  return {
    id: String(item.illust_id),
    title: item.title,
    illustType: parseInt(item.illust_type),
    url: item.url,
    tags: item.tags,
    userId: String(item.user_id),
    userName: item.user_name,
    width: item.width,
    height: item.height,
    pageCount: parseInt(item.illust_page_count) || 1,
    bookmarkData: { id: '', private: false, userId: '' },
    profileImageUrl: item.profile_img,
    createDate: item.date,
  };
}

function mapNovelRankItemToNovelBookmark(item: NovelRankItem): NovelBookmark {
  return {
    id: item.id,
    title: item.title,
    tags: item.tag_a,
    userId: item.user_id,
    userName: item.user_name,
    bookmarkData: null,
    profileImageUrl: item.profile_img,
    createDate: item.create_date,
    updateDate: item.create_date,
    textCount: parseInt(item.character_count) || 0,
    wordCount: parseInt(item.word_count) || 0,
    characterCount: parseInt(item.character_count) || 0,
    readingTime: item.reading_time,
    useWordCount: true,
    url: item.url,
    description: item.comment,
    pageCount: 1,
    width: 0,
    height: 0,
    restrict: parseInt(item.restrict) || 0,
    xRestrict: parseInt(item.x_restrict) || 0,
    sl: 0,
    isBookmarkable: true,
    isUnlisted: false,
    isMasked: false,
    bookmarkCount: item.bookmark_count,
    commentCount: 0,
    markerCount: 0,
    seriesId: item.series_id ?? undefined,
    seriesTitle: item.series_title ?? undefined,
    originalWork: item.is_original === '1',
    aiType: parseInt(item.ai_type) || 0,
  };
}

@Component
export struct RankingPage {
  @StorageLink('isLoggedIn') isLoggedIn: boolean = false;
  @StorageLink('currentBreakpoint') currentBp: string = 'sm';
  @State currentCategory: number = 0;
  @State currentMode: string = 'daily';
  @State isLoading: boolean = true;
  @State isRefreshing: boolean = false;
  @State isLoadingMore: boolean = false;
  @State errorMessage: string = '';
  @State swipeProgress: number = 0;
  private illustSource: BasicDataSource<IllustBookmark> = new BasicDataSource();
  private novelSource: BasicDataSource<NovelBookmark> = new BasicDataSource();
  private ranks: number[] = [];
  private nextPage: number | boolean = false;
  private novelCurrentPage: number = 1;
  private novelHasMore: boolean = true;
  private scrollContainerHeight: number = 0;
  private scrollContentHeight: number = 0;
  private lastPreloadY: number = -1;
  private lastLoadMoreTime: number = 0;
  private lastScrollY: number = 0;

  aboutToAppear() {
    this.loadRanking();
  }

  private getAvailableModes(): RankingMode[] {
    const cat = this.currentCategory;
    let modes: RankingMode[];
    if (cat === 0) {
      modes = ALL_MODES;
    } else if (cat === 1 || cat === 2) {
      modes = ILLUST_MODES;
    } else {
      modes = NOVEL_MODES;
    }
    return modes.filter(m => !m.needLogin || this.isLoggedIn);
  }

  async loadRanking() {
    this.isRefreshing = true;
    if ((CATEGORIES[this.currentCategory]?.isNovel ?? false)) {
      if (this.novelSource.totalCount() === 0) {
        this.isLoading = true;
      }
    } else {
      if (this.illustSource.totalCount() === 0) {
        this.isLoading = true;
      }
    }
    this.errorMessage = '';
    this.nextPage = false;
    this.novelCurrentPage = 1;
    this.lastScrollY = 0;

    if ((CATEGORIES[this.currentCategory]?.isNovel ?? false)) {
      await this.loadNovelRanking();
    } else {
      await this.loadIllustRanking();
    }
    this.isLoading = false;
    this.isRefreshing = false;
  }

  async loadIllustRanking() {
    try {
      const res = await PixivService.getRanking(this.currentMode, 1, (CATEGORIES[this.currentCategory]?.content ?? 'all'));
      const rawIllusts = res.contents ?? [];
      if (rawIllusts.length === 0) {
        this.errorMessage = '暂无排行作品';
      } else {
        const mapped: IllustBookmark[] = [];
        const rankArr: number[] = [];
        for (let i = 0; i < rawIllusts.length; i++) {
          mapped.push(mapRankingToIllust(rawIllusts[i]));
          rankArr.push(rawIllusts[i].rank);
        }
        this.ranks = rankArr;
        this.illustSource.reset(mapped);
        this.nextPage = res.next;
      }
    } catch (err) {
      console.error('加载排行榜失败:', err);
      this.errorMessage = '加载失败，请检查网络';
    }
  }

  async loadNovelRanking() {
    try {
      const res = await PixivService.getNovelRanking(this.currentMode, 1);
      if (res.error) {
        this.errorMessage = '加载失败';
        return;
      }
      const rawNovels = res.body?.display_a?.rank_a ?? [];
      if (rawNovels.length === 0) {
        this.errorMessage = '暂无排行作品';
      } else {
        const mapped: NovelBookmark[] = [];
        for (let i = 0; i < rawNovels.length; i++) {
          mapped.push(mapNovelRankItemToNovelBookmark(rawNovels[i]));
        }
        this.novelSource.reset(mapped);
        this.novelCurrentPage = 1;
        this.novelHasMore = res.body?.display_a?.next !== null;
      }
    } catch (err) {
      console.error('加载小说排行榜失败:', err);
      this.errorMessage = '加载失败，请检查网络';
    }
  }

  async loadMoreRanking() {
    if (this.isLoadingMore) return;
    this.isLoadingMore = true;
    this.lastLoadMoreTime = Date.now();

    if ((CATEGORIES[this.currentCategory]?.isNovel ?? false)) {
      await this.loadMoreNovelRanking();
    } else {
      await this.loadMoreIllustRanking();
    }

    this.isLoadingMore = false;
    if (this.scrollContentHeight > 0 && this.hasMore()) {
      const remaining = this.scrollContentHeight - this.scrollContainerHeight - Math.max(this.lastPreloadY, 0);
      if (remaining < PRELOAD_THRESHOLD) {
        this.loadMoreRanking();
      }
    }
  }

  async loadMoreIllustRanking() {
    if (typeof this.nextPage !== 'number') return;
    try {
      const res = await PixivService.getRanking(this.currentMode, this.nextPage as number, (CATEGORIES[this.currentCategory]?.content ?? 'all'));
      const rawWorks = res.contents ?? [];
      for (const work of rawWorks) {
        const url = work.url;
        if (url) {
          PixivService.cacheImage(url, `illust_${work.illust_id}.jpg`).catch(() => {});
        }
      }
      const mapped: IllustBookmark[] = [];
      const rankArr: number[] = [];
      for (let i = 0; i < rawWorks.length; i++) {
        mapped.push(mapRankingToIllust(rawWorks[i]));
        rankArr.push(rawWorks[i].rank);
      }
      this.ranks = this.ranks.concat(rankArr);
      this.illustSource.batchPush(...mapped);
      this.nextPage = res.next;
    } catch (err) {
      console.error('加载更多排行作品失败:', err);
    }
  }

  async loadMoreNovelRanking() {
    const nextPage = this.novelCurrentPage + 1;
    try {
      const res = await PixivService.getNovelRanking(this.currentMode, nextPage);
      if (res.error) return;
      const rawWorks = res.body?.display_a?.rank_a ?? [];
      if (rawWorks.length === 0) return;
      const mapped: NovelBookmark[] = [];
      for (let i = 0; i < rawWorks.length; i++) {
        mapped.push(mapNovelRankItemToNovelBookmark(rawWorks[i]));
      }
      this.novelSource.batchPush(...mapped);
      this.novelCurrentPage = nextPage;
      this.novelHasMore = res.body?.display_a?.next !== null;
    } catch (err) {
      console.error('加载更多小说排行失败:', err);
    }
  }

  private hasMore(): boolean {
    if ((CATEGORIES[this.currentCategory]?.isNovel ?? false)) {
      return this.novelHasMore;
    }
    return typeof this.nextPage === 'number';
  }

  switchCategory(index: number) {
    if (index === this.currentCategory) return;
    this.currentCategory = index;
    this.currentMode = 'daily';
    this.ranks = [];
    this.illustSource.reset([]);
    this.novelSource.reset([]);
    this.loadRanking();
  }

  switchMode(mode: string) {
    if (mode === this.currentMode) return;
    this.currentMode = mode;
    this.loadRanking();
  }

  build() {
    Column() {
      SegmentedTabBar({
        tabs: CATEGORIES.map(c => c.label),
        currentIndex: this.currentCategory,
        swipeProgress: this.swipeProgress,
        onChange: (index: number): void => this.switchCategory(index),
      })
      .padding({ left: 16, right: 16, top: 8, bottom: 4 })

      this.ModeSelector()

      if (this.isLoading && this.totalCount() === 0) {
        LoadingProgress().width(40).height(40).margin({ top: 100 })
      } else if (this.totalCount() === 0 && this.errorMessage) {
        Column() {
          Text(this.errorMessage).fontSize(14).fontColor($r('app.color.text_secondary'))
          if (this.errorMessage.indexOf('登录') < 0) {
            Button('重试').margin({ top: 12 }).onClick(() => this.loadRanking())
          }
        }
        .margin({ top: 80 })
        .alignItems(HorizontalAlign.Center)
      } else if (this.totalCount() === 0) {
        Text('暂无排行作品').fontSize(14).fontColor($r('app.color.text_secondary')).margin({ top: 100 })
      } else {
        PullToRefresh({ refreshing: this.isRefreshing, onRefresh: (): Promise<void> => this.loadRanking() }) {
          Scroll() {
            Column() {
              if ((CATEGORIES[this.currentCategory]?.isNovel ?? false)) {
                this.NovelGrid()
              } else {
                this.IllustGrid()
              }
            }
            .width('100%')
            .padding({ bottom: 120 })
            .onAreaChange((_old: Area, area: Area) => {
              this.scrollContentHeight = area.height as number;
            })
          }
          .width('100%')
          .edgeEffect(EdgeEffect.Spring)
          .onReachEnd(() => {
            if (!this.isLoadingMore && this.hasMore()) {
              this.loadMoreRanking();
            }
          })
          .onScroll((_xOffset: number, yOffset: number) => {
            if (this.scrollContentHeight > 0) {
              const remaining = this.scrollContentHeight - this.scrollContainerHeight - yOffset;
              if (yOffset > this.lastPreloadY && remaining < PRELOAD_THRESHOLD && this.hasMore() && !this.isLoadingMore) {
                this.loadMoreRanking();
              }
            }
            this.lastPreloadY = yOffset;
          })
          .onAreaChange((_old: Area, area: Area) => {
            this.scrollContainerHeight = area.height as number;
          })
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  private totalCount(): number {
    return (CATEGORIES[this.currentCategory]?.isNovel ?? false) ? this.novelSource.totalCount() : this.illustSource.totalCount();
  }

  @Builder
  ModeSelector() {
    Scroll() {
      Row() {
        ForEach(this.getAvailableModes(), (mode: RankingMode) => {
          Text(mode.label)
            .fontSize(14)
            .fontWeight(mode.key === this.currentMode ? FontWeight.Medium : FontWeight.Regular)
            .fontColor(mode.key === this.currentMode ? Color.White : $r('app.color.user_name'))
            .padding({ left: 16, right: 16, top: 6, bottom: 6 })
            .backgroundColor(mode.key === this.currentMode ? $r('app.color.tab_selected') : $r('app.color.card_bg'))
            .borderRadius(16)
            .margin({ left: 4, right: 4 })
            .onClick(() => this.switchMode(mode.key))
        })
      }
      .padding({ left: 12, right: 12, top: 4, bottom: 8 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
  }

  @Builder
  IllustGrid() {
    Grid() {
      LazyForEach(this.illustSource, (item: IllustBookmark, index: number) => {
        GridItem() {
          Stack() {
            IllustCard({ item: item, index: index })
            if (index < this.ranks.length) {
              this.RankBadge(this.ranks[index])
            }
          }
          .width('100%')
        }
      }, (item: IllustBookmark) => item.id)
    }
    .columnsTemplate(getColumnsTemplate(this.currentBp))
    .columnsGap(8)
    .rowsGap(8)
    .padding(12)
    .width('100%')

    if (this.isLoadingMore) {
      LoadingProgress().width(30).height(30).margin({ top: 8, bottom: 16 })
    }
    if (!this.isLoadingMore && !this.hasMore() && this.illustSource.totalCount() > 0) {
      Text('- 已显示全部作品 -')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ top: 8, bottom: 24 })
    }
  }

  @Builder
  NovelGrid() {
    Grid() {
      LazyForEach(this.novelSource, (item: NovelBookmark, index: number) => {
        GridItem() {
          NovelCard({ item: item, index: index })
        }
      }, (item: NovelBookmark) => item.id)
    }
    .columnsTemplate(getNovelColumnsTemplate(this.currentBp))
    .columnsGap(8)
    .rowsGap(8)
    .padding(12)
    .width('100%')

    if (this.isLoadingMore) {
      LoadingProgress().width(30).height(30).margin({ top: 8, bottom: 16 })
    }
    if (!this.isLoadingMore && !this.hasMore() && this.novelSource.totalCount() > 0) {
      Text('- 已显示全部作品 -')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ top: 8, bottom: 24 })
    }
  }

  @Builder
  RankBadge(rank: number) {
    Text(`#${rank}`)
      .fontSize(11)
      .fontWeight(FontWeight.Bold)
      .fontColor(Color.White)
      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
      .backgroundColor($r('app.color.overlay_dark'))
      .borderRadius(8)
      .position({ top: 6, left: 6 })
  }
}
