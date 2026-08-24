import common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import preferences from '@ohos.data.preferences';
import { pixivCacheDB } from '../../database/PixivCacheDB';
import { PixivNovel } from '../../models/PixivModels';
import { PageContext } from '../../common/utils/PageContext';
import { PageEnum } from '../../common/constants/PageEnum';
import { AuthorDetailParam } from '../../common/constants/PageParamTypes';
import { SortPopupMenu, SortOption } from '../../components/SortPopupMenu';
import { sortAuthorGroups, SortField, SortPreference } from '../../common/utils/SortUtils';

const AUTHOR_GROUP_SORT_OPTIONS: SortOption[] = [
  { label: '作者名', value: 'authorName' },
  { label: '缓存时间', value: 'cachedAt' },
  { label: '小说数量', value: 'novelCount' },
  { label: '最后阅读', value: 'lastReadAt' },
];

const PREFS_NAME = 'cached_novels_sort';
const PREFS_KEY_AGP = 'author_group_sort';

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

  // 系列内按章节顺序排列（默认，不可更改）
  for (const ag of authorMap.values()) {
    for (const sg of ag.seriesMap.values()) {
      sg.novels.sort((a, b) => (a.series?.order ?? 0) - (b.series?.order ?? 0));
    }
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

  // 排序状态（仅作者组排序）
  @State authorGroupSortField: SortField = 'authorName';
  @State authorGroupSortAsc: boolean = true;
  @State lastReadMap: Map<string, string> = new Map();

  // 菜单状态
  @State showSortMenu: boolean = false;
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
    } catch (err) {
      console.error('加载排序偏好失败:', err);
    }
  }

  async saveSortPreference(field: SortField, ascending: boolean) {
    try {
      const ctx = AppStorage.get<common.UIAbilityContext>('appContext');
      if (!ctx) return;
      const pref = await preferences.getPreferences(ctx, PREFS_NAME);
      await pref.put(PREFS_KEY_AGP, JSON.stringify({ field, ascending }));
      await pref.flush();
    } catch (err) {
      console.error('保存排序偏好失败:', err);
    }
  }

  openSortMenu() {
    this.sortMenuCurrentSort = this.authorGroupSortField;
    this.sortMenuSortAsc = this.authorGroupSortAsc;
    this.showSortMenu = true;
  }

  onSortSelect(value: string) {
    const field = value as SortField;
    if (this.authorGroupSortField === field) {
      this.authorGroupSortAsc = !this.authorGroupSortAsc;
    } else {
      this.authorGroupSortField = field;
      this.authorGroupSortAsc = (field === 'authorName' || field === 'novelCount');
    }
    this.saveSortPreference(this.authorGroupSortField, this.authorGroupSortAsc);
    this.applySorting();
  }

  onSortToggleDirection() {
    this.authorGroupSortAsc = !this.authorGroupSortAsc;
    this.sortMenuSortAsc = this.authorGroupSortAsc;
    this.saveSortPreference(this.authorGroupSortField, this.authorGroupSortAsc);
    this.applySorting();
  }

  getSortLabel(field: SortField): string {
    if (field === 'authorName') return '作者名';
    if (field === 'cachedAt') return '缓存时间';
    if (field === 'novelCount') return '数量';
    if (field === 'lastReadAt') return '最后阅读';
    return field;
  }

  showDeleteConfirm(ag: AuthorGroup) {
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
      Stack() {
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
            .onClick(() => { this.openSortMenu(); })
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
          Grid() {
            ForEach(this.authorGroups, (ag: AuthorGroup) => {
              GridItem() {
                this.AuthorCard(ag)
              }
            }, (ag: AuthorGroup): string => ag.authorId)
          }
          .columnsTemplate('1fr 1fr 1fr')
          .columnsGap(10)
          .rowsGap(10)
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
          sortOptions: AUTHOR_GROUP_SORT_OPTIONS,
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
    .onBackPressed(() => {
      const pageCtx = AppStorage.get<PageContext>('rootPageContext');
      if (pageCtx) { pageCtx.popPage(); }
      return true;
    })
    .hideTitleBar(true)
  }

  @Builder
  AuthorCard(ag: AuthorGroup) {
    Column() {
      // 圆形头像
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

      // 作者名
      Text(ag.authorName)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.user_name'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ top: 8 })

      // 小说数量
      Text(`${ag.totalCount} 本`)
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 4 })
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(12)
    .shadow({ radius: 4, color: $r('app.color.card_shadow'), offsetY: 1 })
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .gesture(
      LongPressGesture()
        .onAction(() => {
          this.showDeleteConfirm(ag);
        })
    )
    .onClick(() => {
      this.openAuthorDetail(ag);
    })
  }
}

@Builder
export function CachedNovelsBuilder(): void {
  CachedNovelsPage()
}
