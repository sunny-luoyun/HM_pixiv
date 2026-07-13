import promptAction from '@ohos.promptAction';
import common from '@ohos.app.ability.common';
import { curves } from '@kit.ArkUI';
import { PixivService } from '../../services/PixivService';
import { IllustBookmark, NovelBookmark, BrowseHistoryRecord, BookmarkData, NovelSeries } from '../../models/PixivModels';
import { IllustCard } from '../../components/IllustCard';
import { NovelCard } from '../../components/NovelCard';
import { SegmentedTabBar } from '../../components/SegmentedTabBar';
import { getColumnsTemplate, getNovelColumnsTemplate } from '../../common/utils/BreakpointManager';
import { pixivCacheDB } from '../../database/PixivCacheDB';
import { PageContext } from '../../common/utils/PageContext';

const PAGE_SIZE = 30;
const PRELOAD_THRESHOLD = 1500;

interface DateGroup {
  dateKey: string;
  dateLabel: string;
  records: BrowseHistoryRecord[];
}

function getDateKey(isoStr: string): string {
  if (!isoStr) return '';
  return isoStr.substring(0, 10);
}

function formatDateLabel(dateKey: string): string {
  if (!dateKey) return '';
  const parts = dateKey.split('-');
  if (parts.length < 3) return dateKey;
  const year = parseInt(parts[0]);
  const month = parseInt(parts[1]);
  const dayNum = parseInt(parts[2]);
  const now = new Date();
  const yNow = now.getFullYear();
  const mNow = now.getMonth() + 1;
  const dNow = now.getDate();

  if (year === yNow && month === mNow && dayNum === dNow) {
    return '今天';
  }
  const yesterdayDate = new Date(now);
  yesterdayDate.setDate(now.getDate() - 1);
  if (year === yesterdayDate.getFullYear() && month === (yesterdayDate.getMonth() + 1) && dayNum === yesterdayDate.getDate()) {
    return '昨天';
  }
  if (year === yNow) {
    return month + '月' + dayNum + '日';
  }
  return year + '年' + month + '月' + dayNum + '日';
}

function groupByDate(records: BrowseHistoryRecord[]): DateGroup[] {
  const map = new Map<string, BrowseHistoryRecord[]>();
  for (let i = 0; i < records.length; i++) {
    const rec = records[i];
    const key = getDateKey(rec.viewedAt);
    const existing = map.get(key);
    if (existing !== undefined) {
      existing.push(rec);
    } else {
      map.set(key, [rec]);
    }
  }
  const groups: DateGroup[] = [];
  const keys: string[] = [];
  map.forEach((_value: BrowseHistoryRecord[], key: string) => {
    keys.push(key);
  });
  keys.sort();
  keys.reverse();
  for (let i = 0; i < keys.length; i++) {
    const k = keys[i];
    const recs = map.get(k);
    if (recs !== undefined) {
      groups.push({
        dateKey: k,
        dateLabel: formatDateLabel(k),
        records: recs
      });
    }
  }
  return groups;
}

function filterRecords(records: BrowseHistoryRecord[], query: string): BrowseHistoryRecord[] {
  if (!query) return records;
  const q = query.toLowerCase();
  const result: BrowseHistoryRecord[] = [];
  for (let i = 0; i < records.length; i++) {
    if (records[i].title.toLowerCase().includes(q)) {
      result.push(records[i]);
    }
  }
  return result;
}

function toIllustBookmark(rec: BrowseHistoryRecord): IllustBookmark {
  const tags: string[] = rec.tags;
  return {
    id: rec.contentId,
    title: rec.title,
    illustType: 0,
    url: rec.coverUrl,
    tags: tags,
    userId: rec.userId,
    userName: rec.userName,
    width: 0,
    height: 0,
    pageCount: rec.pageCount,
    bookmarkData: { id: '', private: false, userId: '' } as BookmarkData,
    profileImageUrl: '',
    createDate: rec.createDate
  };
}

function toNovelBookmark(rec: BrowseHistoryRecord): NovelBookmark {
  const tags: string[] = rec.tags;
  let series: NovelSeries | undefined = undefined;
  if (rec.seriesId) {
    series = { id: Number(rec.seriesId), title: rec.seriesTitle, order: 0 };
  }
  return {
    id: rec.contentId,
    title: rec.title,
    tags: tags,
    userId: rec.userId,
    userName: rec.userName,
    bookmarkData: null,
    profileImageUrl: '',
    createDate: rec.createDate,
    updateDate: rec.updateDate,
    textCount: rec.wordCount,
    wordCount: rec.wordCount,
    characterCount: 0,
    readingTime: 0,
    useWordCount: false,
    url: rec.coverUrl,
    description: '',
    pageCount: rec.pageCount,
    width: 0,
    height: 0,
    restrict: 0,
    xRestrict: 0,
    sl: 0,
    isBookmarkable: false,
    isUnlisted: false,
    isMasked: false,
    bookmarkCount: rec.bookmarkCount,
    commentCount: 0,
    markerCount: 0,
    series: series,
    seriesId: rec.seriesId ? Number(rec.seriesId) : undefined,
    seriesTitle: rec.seriesTitle || undefined,
    seriesContentOrder: undefined,
    seriesOrder: undefined,
    originalWork: false,
    aiType: 0,
    titleTranslated: undefined,
    hasTitleTranslation: false
  };
}

@Component
export struct BrowseHistoryPage {
  @StorageLink('currentBreakpoint') currentBp: string = 'sm';
  private isActive: boolean = true;
  @State currentTab: number = 0;
  @State swipeProgress: number = 0;
  @State isAnimationStarted: boolean = false;
  private swiperController: SwiperController = new SwiperController();
  private swiperWidth: number = 0;
  private animStartIndex: number = 0;
  @State isLoadingIllust: boolean = true;
  @State isLoadingNovel: boolean = false;
  @State isLoadingMoreIllust: boolean = false;
  @State isLoadingMoreNovel: boolean = false;
  @State hasMoreIllust: boolean = true;
  @State hasMoreNovel: boolean = true;
  @State illustGroups: DateGroup[] = [];
  @State novelGroups: DateGroup[] = [];
  private illustOffset: number = 0;
  private novelOffset: number = 0;
  @State illustAllRecords: BrowseHistoryRecord[] = [];
  @State novelAllRecords: BrowseHistoryRecord[] = [];
  @State illustRefreshKey: number = 0;
  @State novelRefreshKey: number = 0;
  @State isSearching: boolean = false;
  @State searchQuery: string = '';
  private lastPreloadY: number = -1;
  private listContentHeight: number = 0;
  private listContainerHeight: number = 0;

  aboutToDisappear() {
    this.isActive = false;
  }

  async aboutToAppear() {
    await this.loadIllustHistory();
  }

  async loadIllustHistory(): Promise<void> {
    this.isLoadingIllust = true;
    this.illustOffset = 0;
    this.hasMoreIllust = true;
    this.illustAllRecords = [];
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const records = await pixivCacheDB.getAllIllustBrowseHistory(ctx, PAGE_SIZE, 0);
      if (!this.isActive) return;
      this.illustAllRecords = records;
      this.illustOffset = records.length;
      this.illustGroups = groupByDate(this.illustAllRecords);
      const total = await pixivCacheDB.getBrowseHistoryCount(ctx, 'illust');
      if (this.illustOffset >= total) {
        this.hasMoreIllust = false;
      }
    } catch (err) {
      if (!this.isActive) return;
      console.error('加载插画浏览历史失败:', err);
    }
    this.isLoadingIllust = false;
  }

  async loadMoreIllustHistory(): Promise<void> {
    if (this.isLoadingMoreIllust || !this.hasMoreIllust) return;
    this.isLoadingMoreIllust = true;
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const records = await pixivCacheDB.getAllIllustBrowseHistory(ctx, PAGE_SIZE, this.illustOffset);
      if (!this.isActive) return;
      if (records.length > 0) {
        this.illustAllRecords = this.illustAllRecords.concat(records);
        this.illustOffset += records.length;
        this.illustGroups = groupByDate(this.illustAllRecords);
        const total = await pixivCacheDB.getBrowseHistoryCount(ctx, 'illust');
        if (this.illustOffset >= total) {
          this.hasMoreIllust = false;
        }
      } else {
        this.hasMoreIllust = false;
      }
    } catch (err) {
      if (!this.isActive) return;
      console.error('加载更多插画浏览历史失败:', err);
    }
    this.isLoadingMoreIllust = false;
    if (this.listContainerHeight > 0 && this.hasMoreIllust) {
      const remaining = this.listContentHeight - this.listContainerHeight - Math.max(this.lastPreloadY, 0);
      if (remaining < PRELOAD_THRESHOLD) {
        this.loadMoreIllustHistory();
      }
    }
  }

  async loadNovelHistory(): Promise<void> {
    this.isLoadingNovel = true;
    this.novelOffset = 0;
    this.hasMoreNovel = true;
    this.novelAllRecords = [];
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const records = await pixivCacheDB.getAllNovelBrowseHistory(ctx, PAGE_SIZE, 0);
      if (!this.isActive) return;
      this.novelAllRecords = records;
      this.novelOffset = records.length;
      this.novelGroups = groupByDate(this.novelAllRecords);
      const total = await pixivCacheDB.getBrowseHistoryCount(ctx, 'novel');
      if (this.novelOffset >= total) {
        this.hasMoreNovel = false;
      }
    } catch (err) {
      if (!this.isActive) return;
      console.error('加载小说浏览历史失败:', err);
    }
    this.isLoadingNovel = false;
  }

  async loadMoreNovelHistory(): Promise<void> {
    if (this.isLoadingMoreNovel || !this.hasMoreNovel) return;
    this.isLoadingMoreNovel = true;
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const records = await pixivCacheDB.getAllNovelBrowseHistory(ctx, PAGE_SIZE, this.novelOffset);
      if (!this.isActive) return;
      if (records.length > 0) {
        this.novelAllRecords = this.novelAllRecords.concat(records);
        this.novelOffset += records.length;
        this.novelGroups = groupByDate(this.novelAllRecords);
        const total = await pixivCacheDB.getBrowseHistoryCount(ctx, 'novel');
        if (this.novelOffset >= total) {
          this.hasMoreNovel = false;
        }
      } else {
        this.hasMoreNovel = false;
      }
    } catch (err) {
      if (!this.isActive) return;
      console.error('加载更多小说浏览历史失败:', err);
    }
    this.isLoadingMoreNovel = false;
    if (this.listContainerHeight > 0 && this.hasMoreNovel) {
      const remaining = this.listContentHeight - this.listContainerHeight - Math.max(this.lastPreloadY, 0);
      if (remaining < PRELOAD_THRESHOLD) {
        this.loadMoreNovelHistory();
      }
    }
  }

  async deleteRecord(record: BrowseHistoryRecord): Promise<void> {
    const result = await promptAction.showDialog({
      title: '删除历史记录',
      message: `确定要删除「${record.title}」的浏览记录吗？`,
      buttons: [
        { text: '取消', color: '#666666' },
        { text: '删除', color: '#FF4D4F' }
      ]
    });
    if (result.index !== 1) return;

    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      await pixivCacheDB.deleteBrowseHistory(ctx, record.id);

      let removed: boolean = false;
      if (this.illustAllRecords.some((r: BrowseHistoryRecord): boolean => r.id === record.id)) {
        this.illustAllRecords = this.illustAllRecords.filter(
          (r: BrowseHistoryRecord): boolean => r.id !== record.id);
        this.illustOffset = Math.max(0, this.illustOffset - 1);
        this.illustGroups = groupByDate(this.illustAllRecords);
        this.illustRefreshKey++;
        removed = true;
      }
      if (this.novelAllRecords.some((r: BrowseHistoryRecord): boolean => r.id === record.id)) {
        this.novelAllRecords = this.novelAllRecords.filter(
          (r: BrowseHistoryRecord): boolean => r.id !== record.id);
        this.novelOffset = Math.max(0, this.novelOffset - 1);
        this.novelGroups = groupByDate(this.novelAllRecords);
        this.novelRefreshKey++;
        removed = true;
      }

      if (removed) {
        promptAction.showToast({ message: '已删除' });
      }
    } catch (err) {
      console.error('删除浏览历史失败:', err);
      promptAction.showToast({ message: '删除失败' });
    }
  }

  async deleteRecordsInGroup(dateKey: string, contentType: string, groupLabel: string): Promise<void> {
    const typeLabel: string = contentType === 'illust' ? '插画' : '小说';
    const result = await promptAction.showDialog({
      title: '删除当日记录',
      message: `确定要删除${groupLabel}的所有${typeLabel}浏览记录吗？`,
      buttons: [
        { text: '取消', color: '#666666' },
        { text: '删除', color: '#FF4D4F' }
      ]
    });
    if (result.index !== 1) return;

    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const deletedCount = await pixivCacheDB.deleteBrowseHistoryByDate(ctx, dateKey, contentType);

      if (deletedCount > 0) {
        if (contentType === 'illust') {
          this.illustAllRecords = this.illustAllRecords.filter(
            (r: BrowseHistoryRecord): boolean => !r.viewedAt.startsWith(dateKey));
          this.illustGroups = groupByDate(this.illustAllRecords);
          this.illustRefreshKey++;
        } else {
          this.novelAllRecords = this.novelAllRecords.filter(
            (r: BrowseHistoryRecord): boolean => !r.viewedAt.startsWith(dateKey));
          this.novelGroups = groupByDate(this.novelAllRecords);
          this.novelRefreshKey++;
        }
        promptAction.showToast({ message: `已删除${deletedCount}条记录` });
      }
    } catch (err) {
      console.error('删除日期浏览历史失败:', err);
      promptAction.showToast({ message: '删除失败' });
    }
  }

  getDisplayIllustGroups(): DateGroup[] {
    if (!this.searchQuery) {
      return this.illustGroups;
    }
    return groupByDate(filterRecords(this.illustAllRecords, this.searchQuery));
  }

  getDisplayNovelGroups(): DateGroup[] {
    if (!this.searchQuery) {
      return this.novelGroups;
    }
    return groupByDate(filterRecords(this.novelAllRecords, this.searchQuery));
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.Friction })
      .slide(SlideEffect.Right)
    PageTransitionExit({ duration: 300, curve: Curve.Friction })
      .slide(SlideEffect.Right)
  }

  @Builder
  DateHeader(title: string, dateKey: string, contentType: string) {
    Text(title)
      .fontSize(16)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.user_name'))
      .width('100%')
      .padding({ left: 16, top: 12, bottom: 10 })
      .backgroundColor($r('app.color.page_background'))
      .gesture(
        LongPressGesture({ repeat: false, duration: 500 })
          .onAction(() => {
            this.deleteRecordsInGroup(dateKey, contentType, title);
          })
      )
  }

  @Builder
  SearchBar() {
    Row() {
      Row() {
        Text('🔍')
          .fontSize(16)
          .margin({ left: 12, right: 4 })
        TextInput({ placeholder: '搜索历史记录...' })
          .layoutWeight(1)
          .height(40)
          .fontSize(15)
          .backgroundColor(Color.Transparent)
          .enterKeyType(EnterKeyType.Search)
          .onChange((value: string) => {
            this.searchQuery = value;
          })
      }
      .height(40)
      .borderRadius(20)
      .backgroundColor($r('app.color.card_bg'))
      .layoutWeight(1)

      Blank()
        .width(8)
      Text('取消')
        .fontSize(15)
        .fontColor($r('app.color.tab_selected'))
        .onClick(() => {
          this.isSearching = false;
          this.searchQuery = '';
        })
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.page_background'))
  }

  build() {
    NavDestination() {
      Column() {
        this.TopBar()
        if (this.isSearching) {
          this.SearchBar()
        }
        this.TabsSection()
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_background'))
    }
    .onBackPressed(() => {
      const pageCtx = AppStorage.get<PageContext>('rootPageContext');
      if (pageCtx) { pageCtx.popPage(); }
      return true;
    })
    .hideTitleBar(true)
  }

  @Builder
  TopBar() {
    Row() {
      Text('‹')
        .fontSize(28)
        .fontColor($r('app.color.tab_selected'))
        .onClick(() => {
          const ctx = AppStorage.get<PageContext>('rootPageContext');
          if (ctx) { ctx.popPage(); }
        })
      if (!this.isSearching) {
        Text('浏览历史')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .margin({ left: 12 })
      }
      Blank()
      Text(this.isSearching ? '✕' : '🔍')
        .fontSize(20)
        .fontColor($r('app.color.tab_selected'))
        .onClick(() => {
          if (this.isSearching) {
            this.isSearching = false;
            this.searchQuery = '';
          } else {
            this.isSearching = true;
          }
        })
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.glass_bg'))
  }

  @Builder
  TabsSection() {
    Column() {
      SegmentedTabBar({
        tabs: ['插画', '小说'],
        currentIndex: this.currentTab,
        swipeProgress: this.swipeProgress,
        onChange: (index: number) => {
          this.currentTab = index;
          if (index === 1 && this.novelAllRecords.length === 0 && !this.isLoadingNovel) {
            this.loadNovelHistory();
          }
        }
      })
      .padding({ left: 16, right: 16, top: 8, bottom: 4 })

      Swiper(this.swiperController) {
        Column() {
          if (this.isLoadingIllust) {
            LoadingProgress().width(40).height(40).margin({ top: 100 })
          } else if (this.illustAllRecords.length === 0) {
            Text('暂无插画浏览记录')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 100 })
          } else {
            List() {
              ForEach(this.getDisplayIllustGroups(), (group: DateGroup) => {
                ListItemGroup({ header: this.DateHeader(group.dateLabel, group.dateKey, 'illust') }) {
                  ListItem() {
                    Grid() {
                      ForEach(group.records, (record: BrowseHistoryRecord, idx: number) => {
                        GridItem() {
                          IllustCard({ item: toIllustBookmark(record), index: idx,
                            onLongPress: (): void => { this.deleteRecord(record); }
                          })
                        }
                      }, (record: BrowseHistoryRecord) => record.id)
                    }
                    .columnsTemplate(getColumnsTemplate(this.currentBp))
                    .columnsGap(8)
                    .rowsGap(8)
                    .padding({ left: 12, right: 12 })
                    .width('100%')
                  }
                }
              }, (group: DateGroup) => group.dateKey + '_' + this.searchQuery + '_i' + this.illustRefreshKey)

              if (this.illustAllRecords.length > 0 && this.getDisplayIllustGroups().length === 0) {
                ListItem() {
                  Text('未找到匹配的记录')
                    .fontSize(14)
                    .fontColor($r('app.color.text_secondary'))
                    .width('100%')
                    .textAlign(TextAlign.Center)
                    .margin({ top: 40, bottom: 40 })
                }
              }

              if (this.isLoadingMoreIllust) {
                ListItem() {
                  LoadingProgress().width(30).height(30).margin({ top: 8, bottom: 16 })
                }
              }
              if (!this.isLoadingMoreIllust && !this.hasMoreIllust && this.illustAllRecords.length > 0) {
                ListItem() {
                  Text('- 已显示全部记录 -')
                    .fontSize(12)
                    .fontColor($r('app.color.text_secondary'))
                    .width('100%')
                    .textAlign(TextAlign.Center)
                    .margin({ top: 8, bottom: 24 })
                }
              }
            }
            .width('100%')
            .sticky(StickyStyle.Header)
            .edgeEffect(EdgeEffect.Spring)
            .onReachEnd(() => {
              if (this.hasMoreIllust && !this.isLoadingMoreIllust) {
                this.loadMoreIllustHistory();
              }
            })
            .onScroll((_xOffset: number, yOffset: number) => {
              if (this.listContainerHeight > 0) {
                const remaining = this.listContentHeight - this.listContainerHeight - yOffset;
                if (yOffset > this.lastPreloadY && remaining < PRELOAD_THRESHOLD && this.hasMoreIllust && !this.isLoadingMoreIllust) {
                  this.loadMoreIllustHistory();
                }
              }
              this.lastPreloadY = yOffset;
            })
            .onAreaChange((_old: Area, area: Area) => {
              this.listContainerHeight = area.height as number;
            })
          }
        }
        .width('100%')

        Column() {
          if (this.isLoadingNovel) {
            LoadingProgress().width(40).height(40).margin({ top: 100 })
          } else if (this.novelAllRecords.length === 0) {
            Text('暂无小说浏览记录')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 100 })
          } else {
            List() {
              ForEach(this.getDisplayNovelGroups(), (group: DateGroup) => {
                ListItemGroup({ header: this.DateHeader(group.dateLabel, group.dateKey, 'novel') }) {
                  ListItem() {
                    Grid() {
                      ForEach(group.records, (record: BrowseHistoryRecord, idx: number) => {
                        GridItem() {
                          NovelCard({ item: toNovelBookmark(record), index: idx,
                            onLongPress: (): void => { this.deleteRecord(record); }
                          })
                        }
                      }, (record: BrowseHistoryRecord) => record.id)
                    }
                    .columnsTemplate(getNovelColumnsTemplate(this.currentBp))
                    .columnsGap(8)
                    .rowsGap(8)
                    .padding({ left: 12, right: 12 })
                    .width('100%')
                  }
                }
              }, (group: DateGroup) => group.dateKey + '_' + this.searchQuery + '_n' + this.novelRefreshKey)

              if (this.novelAllRecords.length > 0 && this.getDisplayNovelGroups().length === 0) {
                ListItem() {
                  Text('未找到匹配的记录')
                    .fontSize(14)
                    .fontColor($r('app.color.text_secondary'))
                    .width('100%')
                    .textAlign(TextAlign.Center)
                    .margin({ top: 40, bottom: 40 })
                }
              }

              if (this.isLoadingMoreNovel) {
                ListItem() {
                  LoadingProgress().width(30).height(30).margin({ top: 8, bottom: 16 })
                }
              }
              if (!this.isLoadingMoreNovel && !this.hasMoreNovel && this.novelAllRecords.length > 0) {
                ListItem() {
                  Text('- 已显示全部记录 -')
                    .fontSize(12)
                    .fontColor($r('app.color.text_secondary'))
                    .width('100%')
                    .textAlign(TextAlign.Center)
                    .margin({ top: 8, bottom: 24 })
                }
              }
            }
            .width('100%')
            .sticky(StickyStyle.Header)
            .edgeEffect(EdgeEffect.Spring)
            .onReachEnd(() => {
              if (this.hasMoreNovel && !this.isLoadingMoreNovel) {
                this.loadMoreNovelHistory();
              }
            })
            .onScroll((_xOffset: number, yOffset: number) => {
              if (this.listContainerHeight > 0) {
                const remaining = this.listContentHeight - this.listContainerHeight - yOffset;
                if (yOffset > this.lastPreloadY && remaining < PRELOAD_THRESHOLD && this.hasMoreNovel && !this.isLoadingMoreNovel) {
                  this.loadMoreNovelHistory();
                }
              }
              this.lastPreloadY = yOffset;
            })
            .onAreaChange((_old: Area, area: Area) => {
              this.listContainerHeight = area.height as number;
            })
          }
        }
        .width('100%')
      }
      .indicator(false)
      .loop(false)
      .vertical(false)
      .cachedCount(1)
      .onGestureSwipe((index: number, extraInfo: SwiperAnimationEvent) => {
        if ((index === 0 && extraInfo.currentOffset > 0) ||
          (index === 1 && extraInfo.currentOffset < 0)) {
          this.swipeProgress = 0;
          return;
        }
        const w = this.swiperWidth > 0 ? this.swiperWidth : 1;
        const ratio = Math.abs(extraInfo.currentOffset) / w;
        this.swipeProgress = extraInfo.currentOffset < 0 ? ratio : -ratio;
      })
      .onAnimationStart((index: number, _targetIndex: number) => {
        this.isAnimationStarted = true;
        this.animStartIndex = index;
      })
      .onContentDidScroll((_selectedIndex: number, index: number, position: number, mainAxisLength: number) => {
        this.swiperWidth = mainAxisLength;
        if (!this.isAnimationStarted || index !== this.animStartIndex) return;
        const targetIndex = position < 0 ? index + 1 : index - 1;
        if (targetIndex < 0 || targetIndex >= 2) return;
        const dir = targetIndex > index ? 1 : -1;
        this.swipeProgress = dir * Math.abs(Math.min(Math.max(position, -1), 1));
      })
      .onAnimationEnd((index: number) => {
        this.isAnimationStarted = false;
        this.swipeProgress = 0;
        this.currentTab = index;
        if (index === 1 && this.novelAllRecords.length === 0 && !this.isLoadingNovel) {
          this.loadNovelHistory();
        }
      })
      .index(this.currentTab)
      .layoutWeight(1)
      .onAreaChange((_old: Area, area: Area) => {
        this.swiperWidth = area.width as number;
      })
    }
    .width('100%')
  }
}

@Builder
export function BrowseHistoryBuilder(): void {
  BrowseHistoryPage()
}
