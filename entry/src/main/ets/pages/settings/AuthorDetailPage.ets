import common from '@ohos.app.ability.common';
import preferences from '@ohos.data.preferences';
import { pixivCacheDB } from '../../database/PixivCacheDB';
import { PixivNovel, formatTextLength, formatPixivDate } from '../../models/PixivModels';
import { PageContext } from '../../common/utils/PageContext';
import { PageEnum } from '../../common/constants/PageEnum';
import { NovReaderParam, SeriesDetailParam, UserProfileParam } from '../../common/constants/PageParamTypes';
import { SortPopupMenu, SortOption } from '../../components/SortPopupMenu';
import { sortNovels, SortField, SortPreference } from '../../common/utils/SortUtils';

const AUTHOR_NOVEL_SORT_OPTIONS: SortOption[] = [
  { label: '小说名', value: 'title' },
  { label: '缓存时间', value: 'cachedAt' },
  { label: '最后阅读', value: 'lastReadAt' },
];

const SERIES_SORT_OPTIONS: SortOption[] = [
  { label: '章节顺序', value: 'seriesOrder' },
  { label: '小说名', value: 'title' },
  { label: '缓存时间', value: 'cachedAt' },
  { label: '最后阅读', value: 'lastReadAt' },
];

const PREFS_NAME = 'cached_novels_sort';
const PREFS_KEY_ANP = 'author_novel_sort';
const PREFS_KEY_SSP = 'series_sort';

interface SeriesGroup {
  seriesId: string;
  seriesTitle: string;
  novels: PixivNovel[];
}

interface AuthorGroup {
  authorId: string;
  authorName: string;
  standaloneNovels: PixivNovel[];
  seriesMap: Map<string, SeriesGroup>;
  totalCount: number;
}

function groupNovels(novels: PixivNovel[]): AuthorGroup[] {
  const authorMap = new Map<string, AuthorGroup>();
  for (const novel of novels) {
    let group = authorMap.get(novel.authorId);
    if (!group) {
      group = {
        authorId: novel.authorId,
        authorName: novel.author,
        standaloneNovels: [],
        seriesMap: new Map(),
        totalCount: 0,
      };
      authorMap.set(novel.authorId, group);
    }
    if (novel.series) {
      const sid = novel.series.id;
      let sg = group.seriesMap.get(sid);
      if (!sg) {
        sg = { seriesId: sid, seriesTitle: novel.series.title, novels: [] };
        group.seriesMap.set(sid, sg);
      }
      sg.novels.push(novel);
    } else {
      group.standaloneNovels.push(novel);
    }
    group.totalCount++;
  }
  for (const ag of authorMap.values()) {
    for (const sg of ag.seriesMap.values()) {
      sg.novels.sort((a, b) => (a.series?.order ?? 0) - (b.series?.order ?? 0));
    }
  }
  return Array.from(authorMap.values()).sort((a, b) =>
    a.authorName.localeCompare(b.authorName)
  );
}

@Component
export struct AuthorDetailPage {
  @State navParams: Record<string, Object> = {};
  private authorId: string = '';
  private authorName: string = '';
  @State authorGroup: AuthorGroup | null = null;
  @State isLoading: boolean = true;

  // 排序状态
  @State authorNovelSortField: SortField = 'title';
  @State authorNovelSortAsc: boolean = true;
  @State seriesSortField: SortField = 'seriesOrder';
  @State seriesSortAsc: boolean = true;
  @State lastReadMap: Map<string, string> = new Map();

  // 菜单状态
  @State showSortMenu: boolean = false;
  @State sortMenuTarget: string = '';
  @State sortMenuOptions: SortOption[] = [];
  @State sortMenuCurrentSort: string = '';
  @State sortMenuSortAsc: boolean = true;

  aboutToAppear() {
    // 参数由 onReady 获取
  }

  async loadAuthorNovels() {
    this.isLoading = true;
    try {
      const ctx = AppStorage.get<common.UIAbilityContext>('appContext');
      if (ctx) {
        await pixivCacheDB.init(ctx);
        await this.loadSortPreferences(ctx);
      }
      const novels = await pixivCacheDB.getAllCachedNovels();
      const filtered = novels.filter(n => n.authorId === this.authorId && n.cacheStatus === 'cached');
      // 批量获取 lastReadAt
      const ids = filtered.map(n => n.id);
      this.lastReadMap = await pixivCacheDB.getLastReadTimes(ids);
      for (const n of filtered) {
        const lra = this.lastReadMap.get(n.id);
        if (lra) n.lastReadAt = lra;
      }
      const groups = groupNovels(filtered);
      this.authorGroup = groups.length > 0 ? groups[0] : null;
      this.applySorting();
    } catch (err) {
      console.error('获取作者缓存失败:', err);
    }
    this.isLoading = false;
  }

  applySorting() {
    if (!this.authorGroup) return;
    // 排序系列内小说
    for (const sg of this.authorGroup.seriesMap.values()) {
      sg.novels = sortNovels(sg.novels, this.seriesSortField, this.seriesSortAsc);
    }
    // 排序独立小说
    this.authorGroup.standaloneNovels = sortNovels(
      this.authorGroup.standaloneNovels, this.authorNovelSortField, this.authorNovelSortAsc
    );
  }

  async loadSortPreferences(ctx: common.UIAbilityContext) {
    try {
      const pref = await preferences.getPreferences(ctx, PREFS_NAME);
      const anp = await pref.get(PREFS_KEY_ANP, '') as string;
      if (anp) {
        const parsed = JSON.parse(anp) as SortPreference;
        this.authorNovelSortField = parsed.field;
        this.authorNovelSortAsc = parsed.ascending;
      }
      const ssp = await pref.get(PREFS_KEY_SSP, '') as string;
      if (ssp) {
        const parsed = JSON.parse(ssp) as SortPreference;
        this.seriesSortField = parsed.field;
        this.seriesSortAsc = parsed.ascending;
      }
    } catch (err) {
      console.error('加载排序偏好失败:', err);
    }
  }

  async saveSortPreference(key: string, field: SortField, ascending: boolean) {
    try {
      const ctx = AppStorage.get<common.UIAbilityContext>('appContext');
      if (!ctx) return;
      const pref = await preferences.getPreferences(ctx, PREFS_NAME);
      await pref.put(key, JSON.stringify({ field, ascending }));
      await pref.flush();
    } catch (err) {
      console.error('保存排序偏好失败:', err);
    }
  }

  openSortMenu(target: string) {
    this.sortMenuTarget = target;
    if (target === 'authorNovel') {
      this.sortMenuOptions = AUTHOR_NOVEL_SORT_OPTIONS;
      this.sortMenuCurrentSort = this.authorNovelSortField;
      this.sortMenuSortAsc = this.authorNovelSortAsc;
    } else if (target === 'series') {
      this.sortMenuOptions = SERIES_SORT_OPTIONS;
      this.sortMenuCurrentSort = this.seriesSortField;
      this.sortMenuSortAsc = this.seriesSortAsc;
    }
    this.showSortMenu = true;
  }

  onSortSelect(value: string) {
    const field = value as SortField;
    if (this.sortMenuTarget === 'authorNovel') {
      if (this.authorNovelSortField === field) {
        this.authorNovelSortAsc = !this.authorNovelSortAsc;
      } else {
        this.authorNovelSortField = field;
        this.authorNovelSortAsc = (field === 'title');
      }
      this.saveSortPreference(PREFS_KEY_ANP, this.authorNovelSortField, this.authorNovelSortAsc);
    } else if (this.sortMenuTarget === 'series') {
      if (this.seriesSortField === field) {
        this.seriesSortAsc = !this.seriesSortAsc;
      } else {
        this.seriesSortField = field;
        this.seriesSortAsc = (field === 'seriesOrder' || field === 'title');
      }
      this.saveSortPreference(PREFS_KEY_SSP, this.seriesSortField, this.seriesSortAsc);
    }
    this.applySorting();
  }

  onSortToggleDirection() {
    if (this.sortMenuTarget === 'authorNovel') {
      this.authorNovelSortAsc = !this.authorNovelSortAsc;
      this.sortMenuSortAsc = this.authorNovelSortAsc;
      this.saveSortPreference(PREFS_KEY_ANP, this.authorNovelSortField, this.authorNovelSortAsc);
    } else if (this.sortMenuTarget === 'series') {
      this.seriesSortAsc = !this.seriesSortAsc;
      this.sortMenuSortAsc = this.seriesSortAsc;
      this.saveSortPreference(PREFS_KEY_SSP, this.seriesSortField, this.seriesSortAsc);
    }
    this.applySorting();
  }

  getSortLabel(field: SortField): string {
    if (field === 'title') return '小说名';
    if (field === 'cachedAt') return '缓存时间';
    if (field === 'lastReadAt') return '最后阅读';
    if (field === 'seriesOrder') return '章节';
    return field;
  }

  openReader(novel: PixivNovel) {
    const pageCtx = AppStorage.get<PageContext>('rootPageContext');
    if (pageCtx) {
      const params: NovReaderParam = {
        novelId: novel.id,
        title: novel.title,
        author: novel.author,
        cached: true,
        translatedTitle: novel.titleTranslated || '',
        hasTitleTranslation: !!novel.hasTitleTranslation
      };
      pageCtx.openPage(PageEnum.NOVEL_READER, params as Object);
    }
  }

  openSeries(sg: SeriesGroup) {
    const pageCtx = AppStorage.get<PageContext>('rootPageContext');
    if (pageCtx) {
      const params: SeriesDetailParam = {
        seriesId: sg.seriesId,
        seriesTitle: sg.seriesTitle,
        authorName: this.authorName
      };
      pageCtx.openPage(PageEnum.SERIES_DETAIL, params as Object);
    }
  }

  build() {
    NavDestination() {
      Stack() {
    Column() {
      Row() {
        Text('‹')
          .fontSize(28)
          .onClick(() => { const ctx = AppStorage.get<PageContext>('rootPageContext'); if (ctx) { ctx.popPage(); } })
        Text(this.authorName)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.user_name'))
          .margin({ left: 12 })
        Blank()
      }
      .width('100%')
      .padding({ left: 16, right: 24, top: 16 })

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(40).height(40)
            .color($r('app.color.tab_selected'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (!this.authorGroup) {
        Column() {
          Text('未找到该作者的缓存小说')
            .fontSize(16)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 60 })
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      } else {
        Scroll() {
          Column() {
            // Author info header
        Row() {
          Column() {
            Text(this.authorName.charAt(0).toUpperCase())
              .fontSize(22)
              .fontColor(Color.White)
              .fontWeight(FontWeight.Bold)
          }
          .width(52).height(52)
          .borderRadius(26)
          .backgroundColor($r('app.color.tab_selected'))
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .margin({ right: 14 })

          Column() {
            Text(this.authorName)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.user_name'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(`${this.authorGroup.totalCount} 本缓存  ·  ${this.authorGroup.seriesMap.size} 个系列`)
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text('›')
            .fontSize(22)
            .fontColor($r('app.color.text_secondary'))
            .margin({ left: 8 })
        }
        .width('100%')
        .padding(16)
        .backgroundColor($r('app.color.loading_card'))
        .borderRadius(12)
        .margin({ bottom: 8 })
        .onClick(() => {
          const pageCtx = AppStorage.get<PageContext>('rootPageContext');
          if (pageCtx) {
            const params: UserProfileParam = {
              userId: this.authorId,
              userName: this.authorName
            };
            pageCtx.openPage(PageEnum.USER_PROFILE, params as Object);
          }
        })

            // Series section
            if (this.authorGroup.seriesMap.size > 0) {
              Row() {
                Text('📚 系列')
                  .fontSize(13)
                  .fontColor($r('app.color.text_secondary'))
                  .fontWeight(FontWeight.Medium)
                Blank()
                Text(`↕ ${this.getSortLabel(this.seriesSortField)}`)
                  .fontSize(11)
                  .fontColor($r('app.color.text_secondary'))
                  .backgroundColor($r('app.color.loading_card'))
                  .borderRadius(4)
                  .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                  .onClick(() => { this.openSortMenu('series'); })
              }
              .width('100%')
              .padding({ left: 4, bottom: 8 })
              .margin({ top: 4 })

              Column({ space: 8 }) {
                ForEach(
                  Array.from(this.authorGroup.seriesMap.values()),
                  (sg: SeriesGroup) => {
                    this.SeriesCard(sg)
                  },
                  (sg: SeriesGroup): string => sg.seriesId
                )
              }
              .width('100%')
            }

              // Standalone novels section
              if (this.authorGroup.standaloneNovels.length > 0) {
                Row() {
                  Text('📄 独立小说')
                    .fontSize(13)
                    .fontColor($r('app.color.text_secondary'))
                    .fontWeight(FontWeight.Medium)
                  Blank()
                  Text(`↕ ${this.getSortLabel(this.authorNovelSortField)}`)
                    .fontSize(11)
                    .fontColor($r('app.color.text_secondary'))
                    .backgroundColor($r('app.color.loading_card'))
                    .borderRadius(4)
                    .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                    .onClick(() => { this.openSortMenu('authorNovel'); })
                }
                .width('100%')
                .padding({ left: 4, bottom: 8, top: this.authorGroup.seriesMap.size > 0 ? 12 : 4 })

                Column({ space: 8 }) {
                  ForEach(
                    this.authorGroup.standaloneNovels,
                    (novel: PixivNovel) => {
                      this.NovelCard(novel)
                    },
                    (novel: PixivNovel): string => novel.id
                  )
                }
                .width('100%')
              }
            }
            .width('100%')
            .constraintSize({ minHeight: '100%' })
            .justifyContent(FlexAlign.Start)
            .padding({ left: 16, right: 16, top: 8, bottom: 16 })
          }
          .edgeEffect(EdgeEffect.Spring)
          .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))

        SortPopupMenu({
          visible: this.showSortMenu,
          sortOptions: this.sortMenuOptions,
          currentSort: this.sortMenuCurrentSort,
          sortAscending: this.sortMenuSortAsc,
          onSelect: (value: string) => { this.onSortSelect(value); },
          onToggleDirection: () => { this.onSortToggleDirection(); },
          onDismiss: () => { this.showSortMenu = false; },
        })
      }
      .width('100%')
      .height('100%')
    }
    .onReady((ctx: NavDestinationContext) => {
      this.navParams = ctx.pathInfo.param as Record<string, Object> ?? {};
      this.authorId = (this.navParams['authorId'] as string) || '';
      this.authorName = (this.navParams['authorName'] as string) || '';
      this.loadAuthorNovels();
    })
    .onBackPressed(() => {
      const pageCtx = AppStorage.get<PageContext>('rootPageContext');
      if (pageCtx) { pageCtx.popPage(); }
      return true;
    })
    .hideTitleBar(true)
  }

  @Builder
  SeriesCard(sg: SeriesGroup) {
    Row() {
      Column() {
        Row() {
          Text('系列')
            .fontSize(10)
            .fontColor($r('app.color.success'))
            .backgroundColor($r('app.color.success_bg'))
            .borderRadius(4)
            .padding({ left: 5, right: 5, top: 2, bottom: 2 })
            .margin({ right: 8 })

          Text(sg.seriesTitle)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.user_name'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')

        Text(`共 ${sg.novels.length} 话已缓存`)
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 6 })

        if (sg.novels.length > 0) {
          Column() {
            ForEach(
              sg.novels.slice(0, 2),
              (n: PixivNovel) => {
                Text(`第${n.series?.order ?? '-'}话  ${(n.hasTitleTranslation && n.titleTranslated) ? n.titleTranslated : n.title}`)
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
                  .margin({ top: 3 })
              },
              (n: PixivNovel): string => n.id
            )
            if (sg.novels.length > 2) {
              Text(`…还有 ${sg.novels.length - 2} 话`)
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
                .margin({ top: 3 })
            }
          }
          .width('100%')
          .margin({ top: 6 })
          .padding({ left: 8, top: 6, bottom: 6, right: 8 })
          .backgroundColor($r('app.color.surface_secondary'))
          .borderRadius(6)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('›')
        .fontSize(22)
        .fontColor($r('app.color.text_secondary'))
        .margin({ left: 8 })
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.loading_card'))
    .borderRadius(12)
    .onClick(() => { this.openSeries(sg) })
  }

  @Builder
  NovelCard(novel: PixivNovel) {
    Row() {
      Column() {
        Text(
          (novel.hasTitleTranslation && novel.titleTranslated)
            ? novel.titleTranslated : novel.title
        )
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(
            (novel.hasTitleTranslation && novel.titleTranslated)
              ? $r('app.color.tab_selected') : $r('app.color.user_name')
          )
          .width('100%')

        Row() {
          Text(formatTextLength(novel.textLength))
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
          if (novel.cachedAt) {
            Text(' · 缓存于 ' + formatPixivDate(novel.cachedAt))
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
          }
        }
        .width('100%')
        .margin({ top: 5 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button('阅读')
        .fontSize(12)
        .height(30)
        .padding({ left: 14, right: 14 })
        .backgroundColor($r('app.color.tab_selected'))
        .fontColor(Color.White)
        .borderRadius(15)
        .margin({ left: 10 })
        .onClick(() => { this.openReader(novel) })
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.loading_card'))
    .borderRadius(12)
    .onClick(() => { this.openReader(novel) })
  }
}

@Builder
export function AuthorDetailBuilder(): void {
  AuthorDetailPage()
}
