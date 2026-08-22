import common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import preferences from '@ohos.data.preferences';
import { pixivCacheDB } from '../../database/PixivCacheDB';
import { PixivNovel } from '../../models/PixivModels';
import { PageContext } from '../../common/utils/PageContext';
import { PageEnum } from '../../common/constants/PageEnum';
import { AuthorDetailParam } from '../../common/constants/PageParamTypes';
import { SortPopupMenu, SortOption } from '../../components/SortPopupMenu';
import { sortNovels, sortAuthorGroups, SortField, SortPreference } from '../../common/utils/SortUtils';

const AUTHOR_GROUP_SORT_OPTIONS: SortOption[] = [
  { label: '作者名', value: 'authorName' },
  { label: '缓存时间', value: 'cachedAt' },
  { label: '小说数量', value: 'novelCount' },
  { label: '最后阅读', value: 'lastReadAt' },
];

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
const PREFS_KEY_AGP = 'author_group_sort';
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

function groupNovels(
  novels: PixivNovel[],
  authorSortField: SortField,
  authorSortAsc: boolean,
  novelSortField: SortField,
  novelSortAsc: boolean,
  seriesSortField: SortField,
  seriesSortAsc: boolean,
  lastReadMap: Map<string, string>
): AuthorGroup[] {
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

  // 排序系列内小说
  for (const ag of authorMap.values()) {
    for (const sg of ag.seriesMap.values()) {
      sg.novels = sortNovels(sg.novels, seriesSortField, seriesSortAsc);
    }
    // 排序作者内独立小说
    ag.standaloneNovels = sortNovels(ag.standaloneNovels, novelSortField, novelSortAsc);
  }

  // 排序作者组
  return sortAuthorGroups(
    Array.from(authorMap.values()),
    authorSortField,
    authorSortAsc,
    lastReadMap
  );
}

@Component
export struct CachedNovelsPage {
  @State cachedNovels: PixivNovel[] = [];
  @State authorGroups: AuthorGroup[] = [];
  @State isLoading: boolean = true;

  // 排序状态
  @State authorGroupSortField: SortField = 'authorName';
  @State authorGroupSortAsc: boolean = true;
  @State authorNovelSortField: SortField = 'title';
  @State authorNovelSortAsc: boolean = true;
  @State seriesSortField: SortField = 'seriesOrder';
  @State seriesSortAsc: boolean = true;
  @State lastReadMap: Map<string, string> = new Map();

  // 菜单状态
  @State showSortMenu: boolean = false;
  @State sortMenuTarget: string = ''; // 'authorGroup' | 'authorNovel' | 'series'
  @State sortMenuOptions: SortOption[] = [];
  @State sortMenuCurrentSort: string = '';
  @State sortMenuSortAsc: boolean = true;

  aboutToAppear() {
    this.loadCachedNovels();
  }

  async loadCachedNovels() {
    this.isLoading = true;
    try {
      const ctx = AppStorage.get<common.UIAbilityContext>('appContext');
      if (ctx) {
        await pixivCacheDB.init(ctx);
        // 加载排序偏好
        await this.loadSortPreferences(ctx);
      }
      const novels = await pixivCacheDB.getAllCachedNovels();
      // 批量获取 lastReadAt
      const ids = novels.map(n => n.id);
      this.lastReadMap = await pixivCacheDB.getLastReadTimes(ids);
      // 给每篇小说填充 lastReadAt
      for (const n of novels) {
        const lra = this.lastReadMap.get(n.id);
        if (lra) n.lastReadAt = lra;
      }
      this.cachedNovels = novels;
      this.applySorting();
    } catch (err) {
      console.error('获取缓存小说列表失败:', err);
    }
    this.isLoading = false;
  }

  applySorting() {
    this.authorGroups = groupNovels(
      this.cachedNovels,
      this.authorGroupSortField,
      this.authorGroupSortAsc,
      this.authorNovelSortField,
      this.authorNovelSortAsc,
      this.seriesSortField,
      this.seriesSortAsc,
      this.lastReadMap
    );
  }

  async loadSortPreferences(ctx: common.UIAbilityContext) {
    try {
      const pref = await preferences.getPreferences(ctx, PREFS_NAME);
      const agp = await pref.get(PREFS_KEY_AGP, '') as string;
      if (agp) {
        const parsed = JSON.parse(agp) as SortPreference;
        this.authorGroupSortField = parsed.field;
        this.authorGroupSortAsc = parsed.ascending;
      }
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
    switch (target) {
      case 'authorGroup':
        this.sortMenuOptions = AUTHOR_GROUP_SORT_OPTIONS;
        this.sortMenuCurrentSort = this.authorGroupSortField;
        this.sortMenuSortAsc = this.authorGroupSortAsc;
        break;
      case 'authorNovel':
        this.sortMenuOptions = AUTHOR_NOVEL_SORT_OPTIONS;
        this.sortMenuCurrentSort = this.authorNovelSortField;
        this.sortMenuSortAsc = this.authorNovelSortAsc;
        break;
      case 'series':
        this.sortMenuOptions = SERIES_SORT_OPTIONS;
        this.sortMenuCurrentSort = this.seriesSortField;
        this.sortMenuSortAsc = this.seriesSortAsc;
        break;
    }
    this.showSortMenu = true;
  }

  onSortSelect(value: string) {
    const field = value as SortField;
    switch (this.sortMenuTarget) {
      case 'authorGroup':
        if (this.authorGroupSortField === field) {
          this.authorGroupSortAsc = !this.authorGroupSortAsc;
        } else {
          this.authorGroupSortField = field;
          // 名字类字段默认升序，时间类默认降序
          this.authorGroupSortAsc = (field === 'authorName' || field === 'novelCount');
        }
        this.saveSortPreference(PREFS_KEY_AGP, this.authorGroupSortField, this.authorGroupSortAsc);
        break;
      case 'authorNovel':
        if (this.authorNovelSortField === field) {
          this.authorNovelSortAsc = !this.authorNovelSortAsc;
        } else {
          this.authorNovelSortField = field;
          this.authorNovelSortAsc = (field === 'title');
        }
        this.saveSortPreference(PREFS_KEY_ANP, this.authorNovelSortField, this.authorNovelSortAsc);
        break;
      case 'series':
        if (this.seriesSortField === field) {
          this.seriesSortAsc = !this.seriesSortAsc;
        } else {
          this.seriesSortField = field;
          this.seriesSortAsc = (field === 'seriesOrder' || field === 'title');
        }
        this.saveSortPreference(PREFS_KEY_SSP, this.seriesSortField, this.seriesSortAsc);
        break;
    }
    this.applySorting();
  }

  onSortToggleDirection() {
    switch (this.sortMenuTarget) {
      case 'authorGroup':
        this.authorGroupSortAsc = !this.authorGroupSortAsc;
        this.sortMenuSortAsc = this.authorGroupSortAsc;
        this.saveSortPreference(PREFS_KEY_AGP, this.authorGroupSortField, this.authorGroupSortAsc);
        break;
      case 'authorNovel':
        this.authorNovelSortAsc = !this.authorNovelSortAsc;
        this.sortMenuSortAsc = this.authorNovelSortAsc;
        this.saveSortPreference(PREFS_KEY_ANP, this.authorNovelSortField, this.authorNovelSortAsc);
        break;
      case 'series':
        this.seriesSortAsc = !this.seriesSortAsc;
        this.sortMenuSortAsc = this.seriesSortAsc;
        this.saveSortPreference(PREFS_KEY_SSP, this.seriesSortField, this.seriesSortAsc);
        break;
    }
    this.applySorting();
  }

  getSortLabel(field: SortField): string {
    if (field === 'authorName') return '作者名';
    if (field === 'cachedAt') return '缓存时间';
    if (field === 'novelCount') return '数量';
    if (field === 'lastReadAt') return '最后阅读';
    if (field === 'title') return '小说名';
    if (field === 'seriesOrder') return '章节';
    return field;
  }

  async deleteAuthorCache(ag: AuthorGroup) {
    AlertDialog.show({
      title: '删除作者缓存',
      message: `确定删除「${ag.authorName}」的全部 ${ag.totalCount} 本缓存吗？`,
      autoCancel: true,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#FF4D4F',
        action: async () => {
          const all: PixivNovel[] = [
            ...ag.standaloneNovels,
            ...Array.from(ag.seriesMap.values()).flatMap(sg => sg.novels),
          ];
          for (const n of all) {
            await pixivCacheDB.deleteCachedText(n.id);
          }
          promptAction.showToast({ message: `已删除「${ag.authorName}」的全部缓存` });
          await this.loadCachedNovels();
        }
      }
    });
  }

  openAuthorDetail(ag: AuthorGroup) {
    const pageCtx = AppStorage.get<PageContext>('rootPageContext');
    if (pageCtx) {
      const params: AuthorDetailParam = {
        authorId: ag.authorId,
        authorName: ag.authorName
      };
      pageCtx.openPage(PageEnum.AUTHOR_DETAIL, params as Object);
    }
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.Friction })
      .slide(SlideEffect.Right)
    PageTransitionExit({ duration: 300, curve: Curve.Friction })
      .slide(SlideEffect.Right)
  }

  build() {
    NavDestination() {
      Column() {
        Row() {
          Text('‹')
            .fontSize(28)
            .onClick(() => { const ctx = AppStorage.get<PageContext>('rootPageContext'); if (ctx) { ctx.popPage(); } })
          Text('我的缓存小说')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.user_name'))
            .margin({ left: 12 })
          // 作者组排序图标
          Text(`↕ ${this.getSortLabel(this.authorGroupSortField)}`)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .backgroundColor($r('app.color.loading_card'))
            .borderRadius(6)
            .padding({ left: 6, right: 6, top: 3, bottom: 3 })
            .onClick(() => { this.openSortMenu('authorGroup'); })
          Blank()
          Text(`${this.cachedNovels.length}`)
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .padding({ left: 16, right: 24, top: 16 })

        if (!this.isLoading && this.authorGroups.length > 0) {
          Row() {
            Text(`${this.authorGroups.length} 位作者 · ${this.cachedNovels.length} 本缓存`)
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 8, bottom: 4 })
        }

        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .width(40).height(40)
              .color($r('app.color.tab_selected'))
            Text('加载中...')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 12 })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.authorGroups.length === 0) {
          Column() {
            Text('暂无已缓存的小说')
              .fontSize(16)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 60 })
          }
          .width('100%')
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
        } else {
          List({ space: 10 }) {
            ForEach(this.authorGroups, (ag: AuthorGroup) => {
              ListItem() {
                this.AuthorCard(ag)
              }
            }, (ag: AuthorGroup): string => ag.authorId)
          }
          .width('100%')
          .layoutWeight(1)
          .edgeEffect(EdgeEffect.Spring)
          .padding({ left: 16, right: 16, top: 8, bottom: 16 })
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
    .onBackPressed(() => {
      const pageCtx = AppStorage.get<PageContext>('rootPageContext');
      if (pageCtx) { pageCtx.popPage(); }
      return true;
    })
    .hideTitleBar(true)
  }

  @Builder
  AuthorCard(ag: AuthorGroup) {
    Row() {
      Column() {
        Text(ag.authorName.charAt(0).toUpperCase())
          .fontSize(18)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Bold)
      }
      .width(46).height(46)
      .borderRadius(23)
      .backgroundColor($r('app.color.tab_selected'))
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .margin({ right: 12 })

      Column() {
        Text(ag.authorName)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.user_name'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        // 作者内排序图标
        Row({ space: 4 }) {
          Text(`↕ ${this.getSortLabel(this.authorNovelSortField)}`)
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
            .backgroundColor($r('app.color.loading_card'))
            .borderRadius(4)
            .padding({ left: 4, right: 4, top: 2, bottom: 2 })
            .onClick(() => { this.openSortMenu('authorNovel'); })

          if (ag.seriesMap.size > 0) {
            Text(`↕ ${this.getSortLabel(this.seriesSortField)}`)
              .fontSize(11)
              .fontColor($r('app.color.text_secondary'))
              .backgroundColor($r('app.color.loading_card'))
              .borderRadius(4)
              .padding({ left: 4, right: 4, top: 2, bottom: 2 })
              .onClick(() => { this.openSortMenu('series'); })
          }
        }
        .margin({ top: 4 })

        Row({ space: 6 }) {
          if (ag.seriesMap.size > 0) {
            Text(`📚 ${ag.seriesMap.size} 系列`)
              .fontSize(11)
              .fontColor($r('app.color.success'))
              .backgroundColor($r('app.color.success_bg'))
              .borderRadius(4)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          }
          if (ag.standaloneNovels.length > 0) {
            Text(`📄 ${ag.standaloneNovels.length} 独立`)
              .fontSize(11)
              .fontColor($r('app.color.tab_selected'))
              .backgroundColor($r('app.color.info_bg'))
              .borderRadius(4)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          }
          Text(`共 ${ag.totalCount} 本`)
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .margin({ top: 6 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Row({ space: 8 }) {
        Button() {
          Text('🗑').fontSize(15)
        }
        .width(34).height(34)
        .backgroundColor($r('app.color.danger_bg'))
        .borderRadius(17)
        .onClick(() => { this.deleteAuthorCache(ag) })

        Text('›')
          .fontSize(24)
          .fontColor($r('app.color.text_secondary'))
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(14)
    .shadow({ radius: 4, color: $r('app.color.card_shadow'), offsetY: 1 })
    .onClick(() => {
      this.openAuthorDetail(ag);
    })
  }
}

@Builder
export function CachedNovelsBuilder(): void {
  CachedNovelsPage()
}
