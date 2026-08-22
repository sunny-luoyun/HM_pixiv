# 缓存小说排序功能设计

## 概述

在 `CachedNovelsPage`（按作者分组视图）的三个层级添加排序切换功能：
- **作者组级别**：控制作者卡片的排列顺序
- **作者内级别**：控制某个作者下独立小说的排列顺序
- **系列内级别**：控制某个系列内章节的排列顺序

交互方式：每个层级右上角显示排序图标，点击弹出排序菜单，菜单内包含排序字段选项和升降序切换。

## 排序字段定义

### 作者组级别
| 字段 | 排序依据 | 说明 |
|------|---------|------|
| 作者名 | `authorName` | 字母序（localeCompare） |
| 缓存时间 | 该作者最新一篇的 `cachedAt` | 取作者下最新缓存的时间 |
| 小说数量 | `totalCount` | 作者下缓存的小说总数 |
| 最后阅读 | 该作者最新一篇的 `lastReadAt` | 取作者下最后阅读的时间 |

### 作者内级别（独立小说）
| 字段 | 排序依据 | 说明 |
|------|---------|------|
| 小说名 | `title` | 字母序 |
| 缓存时间 | `cachedAt` | 缓存时间 |
| 最后阅读 | `lastReadAt` | 阅读时间 |

### 系列内级别
| 字段 | 排序依据 | 说明 |
|------|---------|------|
| 章节顺序 | `series.order` | 系列原始章节序号 |
| 小说名 | `title` | 字母序 |
| 缓存时间 | `cachedAt` | 缓存时间 |
| 最后阅读 | `lastReadAt` | 阅读时间 |

### 升降序规则
- 默认：作者名/小说名/章节顺序 → 升序；缓存时间/最后阅读/数量 → 降序（最新的在前）
- 切换：点击升降序按钮反转当前方向

### 未阅读小说处理
`lastReadAt` 为空的小说在按「最后阅读时间」排序时排到**最前面**（用户选择）。

## 数据需求

### lastReadAt 字段
`PixivNovel` 模型当前没有 `lastReadAt` 字段。需要：

1. **PixivNovel 接口**：新增可选字段 `lastReadAt?: string`
2. **批量查询方法**：在 `NovelCacheDao` 新增 `getLastReadTimes(novelIds: string[]): Promise<Map<string, string>>`，一次查出所有缓存小说的 `last_read_at`
3. **getAllCachedNovels 增强**：在 `PixivCacheDB.getAllCachedNovels()` 中自动 JOIN reading_progress 表，或在页面加载后批量补全

推荐方案：页面加载后单独批量查 `last_read_at`，merge 到 novels 列表中，避免改动 getAllCachedNovels 的接口语义。

## UI 设计

### 排序图标
- 位置：每个层级区域的标题栏右侧
- 样式：文字图标 `↕`（16px），带当前排序字段的简短标签（如 `↕ 名字`）
- 点击：弹出排序菜单

### 排序菜单（SortPopupMenu）
弹出半透明遮罩 + 底部弹出面板，包含：

```
┌─────────────────────────────┐
│  排序方式              ↕ 升序 │  ← 标题栏，右侧切换升降序
├─────────────────────────────┤
│  ○ 作者名                  │  ← radio 选项
│  ○ 缓存时间                │
│  ○ 小说数量                │
│  ○ 最后阅读                │
├─────────────────────────────┤
│         关闭                │
└─────────────────────────────┘
```

- 当前选中项高亮（带 ● 标记）
- 选中后立即应用排序并关闭菜单
- 升降序按钮在标题栏右侧，显示当前方向箭头

### 组件拆分
新建 `components/SortPopupMenu.ets`：
- 通用排序弹出菜单组件
- Props：`sortOptions: string[]`, `currentSort: string`, `sortAscending: boolean`, `onSelect`, `onToggleDirection`
- 纯展示组件，排序逻辑由父组件处理

## 状态管理

### 新增状态字段（CachedNovelsPage 内部 @State）
```typescript
// 作者组排序
@State authorGroupSortField: string = 'authorName';
@State authorGroupSortAsc: boolean = true;

// 作者内排序（全局共享，所有作者下独立小说用同一排序）
@State authorNovelSortField: string = 'title';
@State authorNovelSortAsc: boolean = true;

// 系列内排序（全局共享）
@State seriesSortField: string = 'seriesOrder';
@State seriesSortAsc: boolean = true;

// 菜单显示状态
@State showSortMenu: boolean = false;
@State sortMenuTarget: string = ''; // 'authorGroup' | 'authorNovel' | 'series'
```

### 排序执行
排序在前端内存中完成（数据已在内存中），无需重新查数据库。

### 偏好持久化
使用 `@ohos.data.preferences` 按 key 存储：
- `cachedNovels_authorGroupSort` → JSON `{ field, ascending }`
- `cachedNovels_authorNovelSort` → JSON `{ field, ascending }`
- `cachedNovels_seriesSort` → JSON `{ field, ascending }`

页面加载时读取，排序切换时写入。

## 涉及文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `models/NovelModels.ets` | 修改 | PixivNovel 新增 `lastReadAt?` 字段 |
| `database/NovelCacheDao.ets` | 修改 | 新增 `getLastReadTimes()` 批量查询 |
| `database/PixivCacheDB.ets` | 修改 | 透传 `getLastReadTimes()` |
| `components/SortPopupMenu.ets` | **新建** | 通用排序弹出菜单组件 |
| `pages/settings/CachedNovelsPage.ets` | 修改 | 集成排序逻辑和 UI |

**不修改的文件**：
- `CachedNovelsViewModel.ets` — 该 ViewModel 未被 CachedNovelsPage 使用（Page 自带状态管理）
- `CachedNovelsSimplePage.ets` — 简单列表页，用户未要求修改

## 测试计划

- `SortPopupMenu` 是 @Component，属于例外清单，无需单元测试
- `NovelCacheDao.getLastReadTimes` 需要新增测试（数据库查询逻辑）
- 排序逻辑函数可提取为纯函数进行测试

## 验证项（手工）

- [ ] 作者组排序：切换各字段+升降序，确认顺序正确
- [ ] 作者内排序：切换各字段+升降序，确认独立小说顺序正确
- [ ] 系列内排序：切换各字段+升降序，确认章节顺序正确
- [ ] 最后阅读排序：有阅读记录 vs 无阅读记录的小说排列正确（未读排最前）
- [ ] 排序偏好持久化：退出重进后排序设置保留
- [ ] 空状态：无缓存小说时排序图标不显示
