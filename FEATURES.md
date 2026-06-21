# HPixiv 功能基线清单

> 本文档记录项目的所有功能模块及其涉及的核心文件。
> **每次新增或修改功能后必须同步更新本文档。**
> 改完代码后请按底部的「手工验证清单」逐项自检。

---

## F01 - 登录/登出（OAuth）

- **描述**：Pixiv OAuth 登录流程，Cookie 收集与持久化，登录态验证
- **页面**：`entry/src/main/ets/pages/login/LoginPage.ets`
- **逻辑**：`entry/src/main/ets/services/LoginService.ets`
- **状态**：`entry/src/main/ets/store/AppState.ets`
- **Cookie**：`entry/src/main/ets/services/CookieManager.ets`、`entry/src/main/ets/common/utils/CookieStorage.ets`
- **入口**：`entry/src/main/ets/entryability/EntryAbility.ets`（初始化时验证登录态）

---

## F02 - 发现页推荐流

- **描述**：Pixiv 首页推荐插画和小说，瀑布流布局
- **页面**：`entry/src/main/ets/pages/home/HomePage.ets`
- **API**：`entry/src/main/ets/services/PixivApiService.ets`（`getDiscoveryIllusts`、`getDiscoveryNovels`）
- **组件**：`entry/src/main/ets/components/IllustCard.ets`、`entry/src/main/ets/components/NovelCard.ets`、`entry/src/main/ets/components/PullToRefresh.ets`、`entry/src/main/ets/components/ShimmerLoading.ets`

---

## F03 - 最新作品流（关注）

- **描述**：查看已关注用户的最新投稿，支持插画和小说双 Tab
- **页面**：`entry/src/main/ets/pages/latest/LatestPage.ets`
- **API**：`entry/src/main/ets/services/PixivApiService.ets`（`getFollowLatestIllusts`、`getFollowLatestNovels`）
- **组件**：`entry/src/main/ets/components/SegmentedTabBar.ets`

---

## F04 - 多维度搜索

- **描述**：按插画/小说/用户多维度搜索，含搜索建议
- **页面**：`entry/src/main/ets/pages/search/SearchPage.ets`
- **API**：`entry/src/main/ets/services/PixivApiService.ets`（`searchIllusts`、`searchNovels`、`searchUsers`）
- **组件**：`entry/src/main/ets/components/SegmentedTabBar.ets`

---

## F05 - 插画详情与评论

- **描述**：查看插画大图、标题、作者、标签；浏览/发表评论
- **页面**：`entry/src/main/ets/pages/illust/IllustDetailPage.ets`、`entry/src/main/ets/pages/illust/IllustCommentsPage.ets`
- **API**：`entry/src/main/ets/services/PixivApiService.ets`（`getIllustDetail`、`getIllustComments`）

---

## F06 - 小说阅读器与系列

- **描述**：全功能小说阅读（书签、自动阅读）、小说系列导航、评论
- **页面**：`entry/src/main/ets/pages/novel/NovelReaderPage.ets`、`entry/src/main/ets/pages/novel/NovelSeriesPage.ets`、`entry/src/main/ets/pages/novel/NovelCommentsPage.ets`
- **API**：`entry/src/main/ets/services/PixivApiService.ets`（`fetchNovelDetail`、`fetchNovelText`、`fetchSeriesNovels`、`getNovelComments`）
- **缓存**：`entry/src/main/ets/database/PixivCacheDB.ets`、`entry/src/main/ets/database/NovelCacheDao.ets`
- **翻译**：`entry/src/main/ets/services/TranslationController.ets`
- **回调**：`EntryAbility`（后台保存阅读进度）

---

## F07 - 用户主页

- **描述**：查看用户个人资料、插画作品、小说作品
- **页面**：`entry/src/main/ets/pages/user/UserProfilePage.ets`
- **API**：`entry/src/main/ets/services/PixivService.ets`（`fetchUserDetail`、`fetchUserIllusts`、`fetchUserNovels`）

---

## F08 - 收藏管理

- **描述**：查看与管理已收藏插画和小说，支持公开/私密标记
- **页面**：`entry/src/main/ets/pages/favorites/FavoritesPage.ets`
- **API**：`entry/src/main/ets/services/PixivService.ets`（`fetchBookmarkedIllusts`、`fetchBookmarkedNovels`、`addBookmark`、`deleteBookmark`）

---

## F09 - 内置代理（Mihomo）

- **描述**：内置 Clash.Meta 代理核心，导入机场订阅链接实现应用内翻墙
- **逻辑**：`entry/src/main/ets/services/ProxyService.ets`
- **原生桥接**：`entry/src/main/cpp/napi_init.cpp`、`entry/libs/arm64-v8a/libmihomocore.so`
- **Go 桥接**：`mihomo_bridge/`
- **HAR 模块**：`proxy_core/`
- **订阅解析**：`entry/src/main/ets/services/SubscriptionService.ets`

---

## F10 - 机场订阅解析

- **描述**：解析机场订阅链接（Base64 解码、URI 提取）
- **逻辑**：`entry/src/main/ets/services/SubscriptionService.ets`

---

## F11 - AI 翻译（DeepSeek）

- **描述**：通过 DeepSeek API 对日文小说进行标题/全文中文翻译，含本地分词
- **API**：`entry/src/main/ets/services/DeepSeekService.ets`
- **分词器**：`entry/src/main/ets/services/DeepSeekTokenizer.ets`
- **翻译缓存**：`entry/src/main/ets/common/utils/TranslationStorage.ets`

---

## F12 - 离线小说缓存

- **描述**：小说内容和翻译结果 SQLite 离线缓存，支持离线阅读
- **数据库**：`entry/src/main/ets/database/PixivCacheDB.ets`
- **页面**：`entry/src/main/ets/pages/settings/CachedNovelsPage.ets`、`entry/src/main/ets/pages/settings/CachedNovelsSimplePage.ets`

---

## F13 - 设置与屏蔽管理

- **描述**：应用设置（代理、翻译、主题）、关注列表、屏蔽标签/用户
- **页面**：`entry/src/main/ets/pages/setting/SettingPage.ets`、`entry/src/main/ets/pages/setting/FollowingPage.ets`、`entry/src/main/ets/pages/setting/BlockedContentPage.ets`、`entry/src/main/ets/pages/settings/SettingsPage.ets`
- **数据库**：`entry/src/main/ets/database/PixivCacheDB.ets`（屏蔽数据存储）

---

## F14 - 下拉刷新

- **描述**：自定义下拉刷新组件，支持「旧内容保持可见」体验
- **组件**：`entry/src/main/ets/components/PullToRefresh.ets`

---

## F15 - 骨架屏加载

- **描述**：内容加载时的 Shimmer 骨架屏占位动画
- **组件**：`entry/src/main/ets/components/ShimmerLoading.ets`

---

## F16 - 深色模式

- **描述**：跟随系统自动切换明暗主题
- **入口**：`entry/src/main/ets/entryability/EntryAbility.ets`

---

## F17 - 动态端口分配

- **描述**：启动代理时自动检测端口占用，在 7890-7899 范围内分配可用端口
- **逻辑**：`entry/src/main/ets/services/ProxyService.ets`
- **原生**：`entry/src/main/cpp/napi_init.cpp`（`checkPort`）

---

## F18 - 作者/系列详情页

- **描述**：作者详情页（插画+小说列表）、系列详情页（含简介展开/收起）
- **页面**：`entry/src/main/ets/pages/settings/AuthorDetailPage.ets`、`entry/src/main/ets/pages/settings/SeriesDetailPage.ets`

---

## F19 - API URL 常量集中管理

- **描述**：将散落在各服务的 Pixiv/DeepSeek API 端点 URL 集中到统一配置类，消除重复硬编码
- **配置**：`entry/src/main/ets/common/constants/ApiConfig.ets`
- **涉及文件**：`PixivService.ets`、`AppApiService.ets`、`CookieManager.ets`、`DeepSeekService.ets`、`AppState.ets`、`LoginPage.ets`、`SettingsPage.ets`
- **测试**：`entry/src/test/ApiConfig.test.ets`

---

## F20 - 公共三态 UI 组件

- **描述**：提取 Loading、Error、Empty 三种通用状态为独立可复用组件，消除页面间重复样板代码
- **组件**：
  - `entry/src/main/ets/components/LoadingView.ets`（加载进度 + 可选提示文字）
  - `entry/src/main/ets/components/ErrorView.ets`（错误信息 + 重试按钮回调）
  - `entry/src/main/ets/components/EmptyView.ets`（空状态提示，默认"暂无数据"）
- **测试**：`entry/src/test/LoadingView.test.ets`、`entry/src/test/ErrorView.test.ets`、`entry/src/test/EmptyView.test.ets`

---

## F21 - 类型定义统一收敛

- **描述**：将 PixivService（55+ 类型）和 AppApiService（15+ 类型）中分散的接口定义迁移至 `PixivModels.ets`，统一数据模型层
- **模型**：`entry/src/main/ets/models/PixivModels.ets`（从 188 行扩展至 786 行）
- **服务精简**：`PixivService.ets`（从 1,348 行缩减至 780 行，-42%）、`AppApiService.ets`（从 436 行缩减至 280 行，-36%）
- **涉及文件**：16 个页面/组件/测试文件的 import 路径更新

---

## 手工验证清单

> 每次修改代码后，请逐项检查以下功能是否正常：

| # | 验证项 | 操作 | 通过 |
|---|--------|------|------|
| 1 | 登录 | 打开 App → 点击登录 → 完成 OAuth → 看到「我的」页面 | ☐ |
| 2 | 发现页加载 | 切换到「发现」Tab → 插画和小说正常加载 | ☐ |
| 3 | 最新作品加载 | 切换到「最新」Tab → 切换插画/小说 Tab 正常 | ☐ |
| 4 | 搜索 | 切换到「搜索」Tab → 输入关键词 → 结果正常展示 | ☐ |
| 5 | 插画详情 | 点击任意插画 → 大图/标题/标签/作者正常展示 | ☐ |
| 6 | 插画评论 | 插画详情页 → 点击评论 → 评论列表正常 | ☐ |
| 7 | 小说阅读器 | 点击任意小说 → 正文加载 → 自动阅读/书签保存 | ☐ |
| 8 | 小说系列 | 小说详情页 → 点击系列 → 系列列表正常 | ☐ |
| 9 | 小说评论 | 小说详情页 → 点击评论 → 评论列表正常 | ☐ |
| 10 | 用户主页 | 点击任意作者头像 → 作品列表正常 | ☐ |
| 11 | 收藏管理 | 「我的」→ 收藏 → 列表正常加载 | ☐ |
| 12 | 代理启动 | 设置 → 导入订阅 → 开启代理 → 显示运行中 | ☐ |
| 13 | AI 翻译 | 打开小说 → 点击翻译按钮 → 翻译结果正常 | ☐ |
| 14 | 离线缓存 | 阅读小说后断网 → 再次打开该小说可离线阅读 | ☐ |
| 15 | 屏蔽管理 | 「我的」→ 屏蔽管理 → 添加/删除屏蔽项正常 | ☐ |
| 16 | 深色模式 | 系统切换深色模式 → App 跟随切换 | ☐ |
| 17 | 下拉刷新 | 在列表页下拉 → 内容刷新且旧内容不闪烁 | ☐ |
| 18 | 收藏按钮 | 插画详情/小说详情 → 点击收藏/取消收藏 → 状态正确切换 | ☐ |
| 19 | API 配置 | 各页面网络请求正常（涉及 URL 的服务均使用 ApiConfig） | ☐ |
| 20 | 三态组件 | Loading/Error/Empty 三种状态展示正常 | ☐ |
| 21 | 类型导入 | 所有页面编译无类型错误（类型集中在 PixivModels） | ☐ |

---

> 最后更新：F01-F21 + 架构重构，基于 2025-06-21 重构后基线

---

## 架构重构记录（2025-06-21）

### 服务层拆分
- **PixivApiService**：`entry/src/main/ets/services/PixivApiService.ets` — API 请求队列、CSRF、所有 Web API 方法
- **ImageCacheService**：`entry/src/main/ets/services/ImageCacheService.ets` — 图片下载/缓存/管理
- **BookmarkService**：`entry/src/main/ets/services/BookmarkService.ets` — 收藏/取消收藏
- **TranslationController**：`entry/src/main/ets/services/TranslationController.ets` — 翻译业务逻辑

### 数据库拆分
- **NovelCacheDao**：`entry/src/main/ets/database/NovelCacheDao.ets` — 小说 CRUD、阅读进度
- **BlockListDao**：`entry/src/main/ets/database/BlockListDao.ets` — 屏蔽作者/系列管理
- **TranslationCacheDao**：`entry/src/main/ets/database/TranslationCacheDao.ets` — 翻译缓存
- **DatabaseCore**：`entry/src/main/ets/database/DatabaseCore.ets` — 共享数据库连接与 schema

### 模型拆分
- **CommonModels**：`entry/src/main/ets/models/CommonModels.ets` — 通用类型（CacheStatus、PixivTag 等）
- **IllustModels**：`entry/src/main/ets/models/IllustModels.ets` — 插画相关类型
- **NovelModels**：`entry/src/main/ets/models/NovelModels.ets` — 小说相关类型
- **UserModels**：`entry/src/main/ets/models/UserModels.ets` — 用户相关类型
- **CommentModels**：`entry/src/main/ets/models/CommentModels.ets` — 评论相关类型
- **PixivModels**（Facade）：`entry/src/main/ets/models/PixivModels.ets` — 保留向后兼容的 re-export

### 组件提取
- **CommentsComponent**：`entry/src/main/ets/components/CommentsComponent.ets` — 通用评论组件（原 IllustCommentsPage + NovelCommentsPage 合并）
- **ProxySettingsSection**：`entry/src/main/ets/pages/settings/ProxySettingsSection.ets`
- **TranslationSettingsSection**：`entry/src/main/ets/pages/settings/TranslationSettingsSection.ets`
- **CacheSettingsSection**：`entry/src/main/ets/pages/settings/CacheSettingsSection.ets`

### 工具函数提取
- **FormatUtil**：`entry/src/main/ets/common/utils/FormatUtil.ets`
- **ThemeUtil**：`entry/src/main/ets/common/utils/ThemeUtil.ets`
- **NovelParser**：`entry/src/main/ets/common/utils/NovelParser.ets`

### 代码清理
- 删除死代码：`fetchUserName`、`deleteSingleNovelCover`、`getAllImageCacheInfo`
- 评论页面减少 ~300 行重复代码
- SettingsPage 从 1092 行降至 ~200 行骨架
