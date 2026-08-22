# 缓存小说排序功能 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 CachedNovelsPage 的三个层级（作者组、作者内、系列内）添加排序切换功能，支持按缓存时间/名字/最后阅读时间等字段排序，各有升降序。

**Architecture:** 数据层新增批量查询 lastReadAt 的方法；UI 层新建通用 SortPopupMenu 组件；CachedNovelsPage 集成排序状态和逻辑，偏好通过 preferences 持久化。

**Tech Stack:** ArkTS (HarmonyOS NEXT API 12+)、@ohos.data.relationalStore、@ohos.data.preferences、@ohos/hypium

## Global Constraints

- HarmonyOS NEXT (API 12+) ArkTS 项目，Stage 模型
- 构建系统：Hvigor（非 npm/webpack）
- UI 框架：ArkUI 声明式（@Component、@State、@Prop 等）
- 持久化：@ohos.data.relationalStore（SQLite）、@ohos.data.preferences
- 测试框架：@ohos/hypium v1.0.25
- pages/、components/ 下的 @Component 文件属于测试例外清单，无需创建测试
- 数据库操作依赖 relationalStore，单元测试只测纯逻辑

---

## File Structure

| 文件 | 操作 | 职责 |
|------|------|------|
| `entry/src/main/ets/models/NovelModels.ets` | 修改 | PixivNovel 接口新增 `lastReadAt?` 字段 |
| `entry/src/main/ets/database/NovelCacheDao.ets` | 修改 | 新增 `getLastReadTimes()` 批量查询方法 |
| `entry/src/main/ets/database/PixivCacheDB.ets` | 修改 | 透传 `getLastReadTimes()` |
| `entry/src/main/ets/components/SortPopupMenu.ets` | **新建** | 通用排序弹出菜单组件 |
| `entry/src/main/ets/pages/settings/CachedNovelsPage.ets` | 修改 | 集成排序逻辑、状态管理、偏好持久化、UI |
| `entry/src/test/SortUtils.test.ets` | **新建** | 排序纯函数单元测试 |
| `entry/src/test/List.test.ets` | 修改 | 注册新测试文件 |

---

### Task 1: PixivNovel 模型新增 lastReadAt 字段

**Files:**
- Modify: `entry/src/main/ets/models/NovelModels.ets:10-37`

**Interfaces:**
- Produces: `PixivNovel.lastReadAt?: string`

- [ ] **Step 1: 在 PixivNovel 接口添加 lastReadAt 字段**

在 `NovelModels.ets` 第 29 行 `fullText?: string;` 之后添加：

```typescript
  lastReadAt?: string;
```

完整 PixivNovel 接口（关键变化在 fullText 之后）：

```typescript
export interface PixivNovel {
  id: string;
  title: string;
  caption: string;
  author: string;
  authorId: string;
  coverUrl: string;
  tags: PixivTag[];
  textLength: number;
  pageCount: number;
  createDate: string;
  updateDate: string;
  series?: PixivSeries;
  bookmarkData?: BookmarkData | null;
  bookmarkCount: number;
  viewCount: number;
  commentCount: number;
  cacheStatus: CacheStatus;
  cachedAt?: string;
  fullText?: string;

  lastReadAt?: string;  // ← 新增

  titleTranslated?: string;
  hasTitleTranslation?: boolean;
  fullTextTranslated?: string;
  hasFullTranslation?: boolean;
  translationProgress?: number;
  translationStatus?: 'none' | 'in_progress' | 'completed' | 'failed';
}
```

- [ ] **Step 2: 验证编译通过**

Run: `hvigorw assembleHap 2>&1 | grep -E 'ERROR|BUILD|FAIL'`
Expected: BUILD SUCCESSFUL, grep ERROR 0 results

- [ ] **Step 3: Commit**

```bash
git add entry/src/main/ets/models/NovelModels.ets
git commit -m "feat: add lastReadAt field to PixivNovel model"
```

---

### Task 2: NovelCacheDao 新增批量查询 lastReadAt

**Files:**
- Modify: `entry/src/main/ets/database/NovelCacheDao.ets`（文件末尾追加方法）

**Interfaces:**
- Produces: `NovelCacheDao.getLastReadTimes(novelIds: string[]): Promise<Map<string, string>>`

- [ ] **Step 1: 在 NovelCacheDao 类末尾（deleteReadingProgress 方法之后）新增 getLastReadTimes 方法**

在 `NovelCacheDao.ets` 文件末尾的 `}` 之前添加：

```typescript
  static async getLastReadTimes(novelIds: string[]): Promise<Map<string, string>> {
    const map = new Map<string, string>();
    if (!DatabaseCore.isReady() || novelIds.length === 0) return map;
    const store = DatabaseCore.getStore()!;
    try => {
      // 一次查出所有有阅读记录的小说的 last_read_at
      const placeholders = novelIds.map(() => '?').join(',');
      const sql = `SELECT novel_id, last_read_at FROM ${DatabaseCore.TableProgress}
                   WHERE novel_id IN (${placeholders})
                   AND is_translated = 0`;
      const result = await store.querySql(sql, novelIds);
      while (result.goToNextRow()) {
        const nid = result.getString(result.getColumnIndex('novel_id'));
        const lra = result.getString(result.getColumnIndex('last_read_at'));
        if (nid && lra) {
          map.set(nid, lra);
        }
      }
      result.close();
    } catch (err) {
      console.error(`[NovelCacheDao] getLastReadTimes 失败: ${JSON.stringify(err)}`);
    }
    return map;
  }
```

注意：需要在文件顶部确认已导入 `relationalStore`（已有）。`DatabaseCore.TableProgress` 对应 `'reading_progress'` 表名。

- [ ] **Step 2: 在 PixivCacheDB 中透传该方法**

在 `PixivCacheDB.ets` 的 `deleteReadingProgress` 方法之后添加：

```typescript
  async getLastReadTimes(novelIds: string[]): Promise<Map<string, string>> {
    return NovelCacheDao.getLastReadTimes(novelIds);
  }
```

- [ ] **Step 3: 验证编译通过**

Run: `hvigorw assembleHap 2>&1 | grep -E 'ERROR|BUILD|FAIL'`
Expected: BUILD SUCCESSFUL

- [ ] **Step 4: Commit**

```bash
git add entry/src/main/ets/database/NovelCacheDao.ets entry/src/main/ets/database/PixivCacheDB.ets
git commit -m "feat: add getLastReadTimes batch query for reading progress"
```

---

### Task 3: 新建 SortPopupMenu 通用组件

**Files:**
- Create: `entry/src/main/ets/components/SortPopupMenu.ets`

**Interfaces:**
- Consumes: 无外部依赖
- Produces: `SortPopupMenu` @Component，接收 sortOptions/currentSort/sortAscending/onSelect/onToggleDirection

- [ ] **Step 1: 创建 SortPopupMenu 组件**

```typescript
import promptAction from '@ohos.promptAction';

export interface SortOption {
  label: string;       // 显示文本，如 '缓存时间'
  value: string;       // 排序字段标识，如 'cachedAt'
}

@Component
export struct SortPopupMenu {
  @Prop visible: boolean = false;
  @Prop sortOptions: SortOption[] = [];
  @Prop currentSort: string = '';
  @Prop sortAscending: boolean = true;
  onSelect: (value: string) => void = () => {};
  onToggleDirection: () => void = () => {};
  onDismiss: () => void = () => {};

  build() {
    if (this.visible) {
      Column() {
        // 半透明遮罩
        Column()
          .width('100%')
          .layoutWeight(1)
          .backgroundColor('rgba(0,0,0,0.4)')
          .onClick(() => { this.onDismiss(); })

        // 底部弹出面板
        Column() {
          // 标题栏
          Row() {
            Text('排序方式')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.user_name'))
            Blank()
            Text(this.sortAscending ? '↑ 升序' : '↓ 降序')
              .fontSize(13)
              .fontColor($r('app.color.tab_selected'))
              .onClick(() => { this.onToggleDirection(); })
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 16, bottom: 12 })

          Divider().color($r('app.color.divider'))

          // 选项列表
          ForEach(this.sortOptions, (option: SortOption) => {
            Row() {
              Text(option.label)
                .fontSize(15)
                .fontColor(this.currentSort === option.value
                  ? $r('app.color.tab_selected')
                  : $r('app.color.user_name'))
                .fontWeight(this.currentSort === option.value ? FontWeight.Medium : FontWeight.Normal)
              Blank()
              if (this.currentSort === option.value) {
                Text('●')
                  .fontSize(14)
                  .fontColor($r('app.color.tab_selected'))
              }
            }
            .width('100%')
            .height(48)
            .padding({ left: 20, right: 20 })
            .onClick(() => {
              this.onSelect(option.value);
              this.onDismiss();
            })
          }, (option: SortOption): string => option.value)

          // 底部安全区
          Column()
            .height(20)
        }
        .width('100%')
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius({ topLeft: 16, topRight: 16 })
      }
      .width('100%')
      .height('100%')
    }
  }
}
```

- [ ] **Step 2: 验证编译通过**

Run: `hvigorw assembleHap 2>&1 | grep -E 'ERROR|BUILD|FAIL'`
Expected: BUILD SUCCESSFUL

- [ ] **Step 3: Commit**

```bash
git add entry/src/main/ets/components/SortPopupMenu.ets
git commit -m "feat: add SortPopupMenu reusable component"
```

---

### Task 4: 新建排序纯函数 + 单元测试

**Files:**
- Create: `entry/src/main/ets/common/utils/SortUtils.ets`
- Create: `entry/src/test/SortUtils.test.ets`
- Modify: `entry/src/test/List.test.ets`

**Interfaces:**
- Produces: `sortNovels(novels, field, ascending): PixivNovel[]`
- Produces: `sortAuthorGroups(groups, field, ascending, lastReadMap): AuthorGroup[]`
- Produces: `sortSeriesNovels(novels, field, ascending): PixivNovel[]`

- [ ] **Step 1: 创建 SortUtils.ets 纯函数**

```typescript
import { PixivNovel } from '../../models/PixivModels';

export type SortField = 'cachedAt' | 'title' | 'authorName' | 'lastReadAt' | 'seriesOrder' | 'novelCount';

/**
 * 按 lastReadAt 排序的比较函数：空值（未阅读）排最前面
 */
function compareLastRead(a: string | undefined, b: string | undefined, ascending: boolean): number {
  const aEmpty = !a;
  const bEmpty = !b;
  if (aEmpty && bEmpty) return 0;
  if (aEmpty) return ascending ? -1 : 1;  // 未读排最前
  if (bEmpty) return ascending ? 1 : -1;
  const cmp = a!.localeCompare(b!);
  return ascending ? cmp : -cmp;
}

/**
 * 排序独立小说列表
 */
export function sortNovels(novels: PixivNovel[], field: SortField, ascending: boolean): PixivNovel[] {
  const sorted = [...novels];
  sorted.sort((a, b) => {
    switch (field) {
      case 'cachedAt': {
        const cmp = (a.cachedAt ?? '').localeCompare(b.cachedAt ?? '');
        return ascending ? cmp : -cmp;
      }
      case 'title': {
        const cmp = a.title.localeCompare(b.title);
        return ascending ? cmp : -cmp;
      }
      case 'lastReadAt':
        return compareLastRead(a.lastReadAt, b.lastReadAt, ascending);
      case 'seriesOrder': {
        const cmp = (a.series?.order ?? 0) - (b.series?.order ?? 0);
        return ascending ? cmp : -cmp;
      }
      default:
        return 0;
    }
  });
  return sorted;
}

export interface SortableAuthorGroup {
  authorId: string;
  authorName: string;
  standaloneNovels: PixivNovel[];
  seriesMap: Map<string, { seriesId: string; seriesTitle: string; novels: PixivNovel[] }>;
  totalCount: number;
}

/**
 * 排序作者组列表
 * field 为 'cachedAt' / 'lastReadAt' 时，取该作者下最新/最后的时间
 */
export function sortAuthorGroups(
  groups: SortableAuthorGroup[],
  field: SortField,
  ascending: boolean,
  lastReadMap?: Map<string, string>
): SortableAuthorGroup[] {
  const sorted = [...groups];
  sorted.sort((a, b) => {
    switch (field) {
      case 'authorName': {
        const cmp = a.authorName.localeCompare(b.authorName);
        return ascending ? cmp : -cmp;
      }
      case 'novelCount': {
        const cmp = a.totalCount - b.totalCount;
        return ascending ? cmp : -cmp;
      }
      case 'cachedAt': {
        // 取该作者下最新的一篇 cachedAt
        const aLatest = getLatestCachedAt(a);
        const bLatest = getLatestCachedAt(b);
        const cmp = aLatest.localeCompare(bLatest);
        return ascending ? cmp : -cmp;
      }
      case 'lastReadAt': {
        const aLatest = getLatestLastReadAt(a, lastReadMap);
        const bLatest = getLatestLastReadAt(b, lastReadMap);
        return compareLastRead(aLatest, bLatest, ascending);
      }
      default:
        return 0;
    }
  });
  return sorted;
}

function getLatestCachedAt(group: SortableAuthorGroup): string {
  let latest = '';
  for (const n of group.standaloneNovels) {
    if (n.cachedAt && n.cachedAt > latest) latest = n.cachedAt;
  }
  for (const sg of group.seriesMap.values()) {
    for (const n of sg.novels) {
      if (n.cachedAt && n.cachedAt > latest) latest = n.cachedAt;
    }
  }
  return latest;
}

function getLatestLastReadAt(group: SortableAuthorGroup, map?: Map<string, string>): string | undefined {
  if (!map) return undefined;
  let latest: string | undefined;
  const check = (nid: string) => {
    const t = map.get(nid);
    if (t && (!latest || t > latest)) latest = t;
  };
  for (const n of group.standaloneNovels) check(n.id);
  for (const sg of group.seriesMap.values()) {
    for (const n of sg.novels) check(n.id);
  }
  return latest;
}
```

- [ ] **Step 2: 创建 SortUtils.test.ets**

```typescript
import { describe, it, expect } from '@ohos/hypium';
import { sortNovels, SortField } from '../main/ets/common/utils/SortUtils';
import { PixivNovel, CacheStatus } from '../main/ets/models/PixivModels';

function makeNovel(overrides: Partial<PixivNovel>): PixivNovel {
  return {
    id: '0', title: '', caption: '', author: '', authorId: '',
    coverUrl: '', tags: [], textLength: 0, pageCount: 1,
    createDate: '', updateDate: '', bookmarkCount: 0,
    viewCount: 0, commentCount: 0,
    cacheStatus: CacheStatus.CACHED,
    ...overrides,
  };
}

export default function sortUtilsTest() {
  describe('SortUtils', () => {
    describe('sortNovels by title', () => {
      it('升序：A 在 B 前', 0, () => {
        const novels = [
          makeNovel({ id: '1', title: 'Banana' }),
          makeNovel({ id: '2', title: 'Apple' }),
        ];
        const result = sortNovels(novels, 'title', true);
        expect(result[0].title).assertEqual('Apple');
        expect(result[1].title).assertEqual('Banana');
      });

      it('降序：B 在 A 前', 0, () => {
        const novels = [
          makeNovel({ id: '1', title: 'Apple' }),
          makeNovel({ id: '2', title: 'Banana' }),
        ];
        const result = sortNovels(novels, 'title', false);
        expect(result[0].title).assertEqual('Banana');
        expect(result[1].title).assertEqual('Apple');
      });
    });

    describe('sortNovels by cachedAt', () => {
      it('降序：最新缓存在前', 0, () => {
        const novels = [
          makeNovel({ id: '1', cachedAt: '2025-01-01' }),
          makeNovel({ id: '2', cachedAt: '2025-06-01' }),
        ];
        const result = sortNovels(novels, 'cachedAt', false);
        expect(result[0].id).assertEqual('2');
        expect(result[1].id).assertEqual('1');
      });

      it('空 cachedAt 排最后', 0, () => {
        const novels = [
          makeNovel({ id: '1', cachedAt: '' }),
          makeNovel({ id: '2', cachedAt: '2025-06-01' }),
        ];
        const result = sortNovels(novels, 'cachedAt', false);
        expect(result[0].id).assertEqual('2');
      });
    });

    describe('sortNovels by lastReadAt', () => {
      it('未阅读排最前（升序）', 0, () => {
        const novels = [
          makeNovel({ id: '1', lastReadAt: '2025-06-01' }),
          makeNovel({ id: '2' }),  // 无 lastReadAt
        ];
        const result = sortNovels(novels, 'lastReadAt', true);
        expect(result[0].id).assertEqual('2');  // 未读排最前
        expect(result[1].id).assertEqual('1');
      });

      it('未阅读排最后（降序）', 0, () => {
        const novels = [
          makeNovel({ id: '1', lastReadAt: '2025-06-01' }),
          makeNovel({ id: '2' }),  // 无 lastReadAt
        ];
        const result = sortNovels(novels, 'lastReadAt', false);
        expect(result[0].id).assertEqual('1');
        expect(result[1].id).assertEqual('2');  // 未读排最后
      });
    });

    describe('sortNovels by seriesOrder', () => {
      it('按章节序号排序', 0, () => {
        const novels = [
          makeNovel({ id: '1', series: { id: 's1', title: '系列', order: 3 } }),
          makeNovel({ id: '2', series: { id: 's1', title: '系列', order: 1 } }),
        ];
        const result = sortNovels(novels, 'seriesOrder', true);
        expect(result[0].id).assertEqual('2');
        expect(result[1].id).assertEqual('1');
      });
    });
  });
}
```

- [ ] **Step 3: 在 List.test.ets 中注册新测试**

在 `entry/src/test/List.test.ets` 中追加一行：

```typescript
import sortUtilsTest from './SortUtils.test';
```

并在测试注册数组中添加对应条目（参照已有格式）。

- [ ] **Step 4: 运行测试验证通过**

Run: `hvigorw test 2>&1 | grep -E 'ERROR|BUILD|FAIL|PASS'`
Expected: BUILD SUCCESSFUL，SortUtils 相关测试全部 PASS

- [ ] **Step 5: Commit**

```bash
git add entry/src/main/ets/common/utils/SortUtils.ets entry/src/test/SortUtils.test.ets entry/src/test/List.test.ets
git commit -m "feat: add sort utility functions with unit tests"
```

---

### Task 5: CachedNovelsPage 集成排序功能

**Files:**
- Modify: `entry/src/main/ets/pages/settings/CachedNovelsPage.ets`

**Interfaces:**
- Consumes: `SortPopupMenu` from `../../components/SortPopupMenu`
- Consumes: `sortNovels`, `sortAuthorGroups` from `../../common/utils/SortUtils`
- Consumes: `pixivCacheDB.getLastReadTimes()`

- [ ] **Step 1: 添加 imports 和排序常量**

在 `CachedNovelsPage.ets` 顶部 import 区域追加：

```typescript
import { SortPopupMenu, SortOption } from '../../components/SortPopupMenu';
import { sortNovels, sortAuthorGroups, SortField } from '../../common/utils/SortUtils';
import preferences from '@ohos.data.preferences';
```

在 import 之后、`interface SeriesGroup` 之前，添加排序选项常量：

```typescript
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
```

- [ ] **Step 2: 修改 groupNovels 函数签名，接收排序参数**

将 `groupNovels` 函数改为接受排序参数：

```typescript
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
```

- [ ] **Step 3: 修改 CachedNovelsPage struct，添加排序状态**

在 `CachedNovelsPage` struct 的 `@State` 区域添加：

```typescript
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
```

- [ ] **Step 4: 修改 loadCachedNovels 方法，加载 lastReadAt 并应用排序**

替换现有的 `loadCachedNovels` 方法：

```typescript
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
```

- [ ] **Step 5: 添加排序偏好读写方法**

在 `CachedNovelsPage` struct 中 `applySorting` 方法之后添加：

```typescript
  async loadSortPreferences(ctx: common.UIAbilityContext) {
    try {
      const pref = await preferences.getPreferences(ctx, PREFS_NAME);
      const agp = await pref.get(PREFS_KEY_AGP, '') as string;
      if (agp) {
        const parsed = JSON.parse(agp) as { field: SortField; ascending: boolean };
        this.authorGroupSortField = parsed.field;
        this.authorGroupSortAsc = parsed.ascending;
      }
      const anp = await pref.get(PREFS_KEY_ANP, '') as string;
      if (anp) {
        const parsed = JSON.parse(anp) as { field: SortField; ascending: boolean };
        this.authorNovelSortField = parsed.field;
        this.authorNovelSortAsc = parsed.ascending;
      }
      const ssp = await pref.get(PREFS_KEY_SSP, '') as string;
      if (ssp) {
        const parsed = JSON.parse(ssp) as { field: SortField; ascending: boolean };
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
```

- [ ] **Step 6: 添加排序菜单操作方法**

在 `saveSortPreference` 方法之后添加：

```typescript
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
    const map: Record<string, string> = {
      authorName: '作者名', cachedAt: '缓存时间', novelCount: '数量',
      lastReadAt: '最后阅读', title: '小说名', seriesOrder: '章节',
    };
    return map[field] ?? field;
  }
```

- [ ] **Step 7: 修改 build 方法，在标题栏添加排序图标 + SortPopupMenu**

在 `build()` 方法的 `Row()` 标题栏中，`Text('我的缓存小说')` 之后、`Blank()` 之前，添加排序图标区域：

```typescript
          // 作者组排序图标
          Text(`↕ ${this.getSortLabel(this.authorGroupSortField)}`)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .backgroundColor($r('app.color.loading_card'))
            .borderRadius(6)
            .padding({ left: 6, right: 6, top: 3, bottom: 3 })
            .onClick(() => { this.openSortMenu('authorGroup'); })
```

在 `build()` 方法的最外层 Column 之后、`.backgroundColor` 之前，添加 SortPopupMenu：

```typescript
        SortPopupMenu({
          visible: this.showSortMenu,
          sortOptions: this.sortMenuOptions,
          currentSort: this.sortMenuCurrentSort,
          sortAscending: this.sortMenuSortAsc,
          onSelect: (value: string) => { this.onSortSelect(value); },
          onToggleDirection: () => { this.onSortToggleDirection(); },
          onDismiss: () => { this.showSortMenu = false; },
        })
```

- [ ] **Step 8: 在 AuthorCard Builder 中添加作者内/系列内排序图标**

在 `AuthorCard` Builder 中，`Text(ag.authorName)` 之后、系列/独立标签 Row 之前，添加：

```typescript
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
```

- [ ] **Step 9: 验证编译通过**

Run: `hvigorw assembleHap 2>&1 | grep -E 'ERROR|BUILD|FAIL'`
Expected: BUILD SUCCESSFUL

- [ ] **Step 10: Commit**

```bash
git add entry/src/main/ets/pages/settings/CachedNovelsPage.ets
git commit -m "feat: integrate sorting with popup menu in CachedNovelsPage"
```

---

### Task 6: 更新 FEATURES.md

**Files:**
- Modify: `FEATURES.md`

- [ ] **Step 1: 在 FEATURES.md 中追加排序功能记录**

在功能清单中追加：

```markdown
### 缓存小说排序
- 功能编号：F-XX
- 描述：缓存小说页面支持按多种字段排序（作者名/缓存时间/小说数量/最后阅读/小说名/章节顺序），每种支持升降序切换，偏好持久化
- 涉及文件：
  - `entry/src/main/ets/models/NovelModels.ets`（lastReadAt 字段）
  - `entry/src/main/ets/database/NovelCacheDao.ets`（getLastReadTimes）
  - `entry/src/main/ets/database/PixivCacheDB.ets`（透传）
  - `entry/src/main/ets/components/SortPopupMenu.ets`（新建）
  - `entry/src/main/ets/common/utils/SortUtils.ets`（新建）
  - `entry/src/main/ets/pages/settings/CachedNovelsPage.ets`（排序集成）
  - `entry/src/test/SortUtils.test.ets`（新建）
- 测试引用：`entry/src/test/SortUtils.test.ets`
```

- [ ] **Step 2: 更新底部"最后更新"日期**

- [ ] **Step 3: Commit**

```bash
git add FEATURES.md
git commit -m "docs: update FEATURES.md with cached novels sorting feature"
```
