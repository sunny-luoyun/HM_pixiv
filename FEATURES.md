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

## F04 - 多维度搜索（含过滤条件）

- **描述**：按插画/小说/用户多维度搜索，支持排序（最新/最早/最多收藏）、匹配模式（标签部分/完全/标题说明）、内容类型（插画/动图/漫画）、R18 筛选
- **页面**：`entry/src/main/ets/pages/search/SearchPage.ets`
- **API**：`entry/src/main/ets/services/PixivApiService.ets`（`searchIllusts`、`searchNovels`、`searchUsers`）
- **组件**：`entry/src/main/ets/components/SegmentedTabBar.ets`
- **过滤参数**（2025-06-23 新增）：
  - `sortOrder`：`date_d`(最新)/`date`(最旧)/`popular_d`(最多收藏)
  - `searchMode`：`s_tag`(标签部分)/`s_tag_full`(标签完全)/`s_tc`(标题说明)
  - `contentType`：`illust_and_ugoira`(全部)/`illust`(插画)/`ugoira`(动图)/`manga`(漫画)
  - `r18Mode`：`all`(全部)/`safe`(全年龄)/`r18`(R-18)

---

## F05 - 插画详情与评论

- **描述**：查看插画大图、标题、作者、标签；浏览/删除评论（发表评论暂不可用，待 OAuth2 接入后恢复）
- **页面**：`entry/src/main/ets/pages/illust/IllustDetailPage.ets`、`entry/src/main/ets/pages/illust/IllustCommentsPage.ets`
- **API**：`entry/src/main/ets/services/PixivApiService.ets`（`getIllustDetail`、`getIllustComments`）、`entry/src/main/ets/services/AppApiService.ets`（`deleteIllustComment`，`postIllustComment` 保留代码待 OAuth 启用）
- **组件**：`entry/src/main/ets/components/CommentsComponent.ets`
- **已知限制**：发表评论需 Pixiv OAuth2 Bearer Token 认证，当前仅使用 PHPSESSID Cookie，评论接口返回 400 OAuth error。发表 UI 已临时移除，`AppApiService.ts` 中 `Content-Type` 头修复已保留

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

## F22 - 沉浸光感改造（第一阶段）

- **描述**：基于华为 HDS 沉浸光感规范，将主 Tab 框架从原生 Tabs 迁移至 HdsNavigation + HdsTabs，启用窗口全屏沉浸式和底部页签系统材质效果
- **SDK 升级**：`build-profile.json5`（targetSdk 6.0.2→6.1.0）、`oh-package.json5`（modelVersion 6.0.2→6.1.0）、`hvigor/hvigor-config.json5`（modelVersion 6.0.2→6.1.0）
- **窗口沉浸式**：`entry/src/main/ets/entryability/EntryAbility.ets`（setWindowLayoutFullScreen + 透明系统栏）
- **主框架**：`entry/src/main/ets/pages/Index.ets`（HdsNavigation + HdsTabs + barFloatingStyle.systemMaterialEffect + 设备能力探测降级）
- **依赖**：`@kit.UIDesignKit`（HdsTabs、HdsTabsController、hdsMaterial）
- **Tab 图标**：原生 `BottomTabBarStyle` + `SymbolGlyphModifier` 系统符号（house/clock/magnifyingglass/person）
- **底部避让**：动态读取系统导航指示条高度作为 `barBottomMargin`
- **内容适配**：`SettingPage.ets` 底部 padding 80vp，其余 3 个 Tab 页已有 120vp 底部留白

---

## F26 - 卡片一镜到底转场动画

- **描述**：点击插画卡片进入详情页时，使用 `componentSnapshot` + `customNavContentTransition` 实现一镜到底的转场动画。卡片截图从原位置平滑缩放至全屏，同时详情内容淡入。返回时动画反向播放。
- **核心机制**：
  - `componentSnapshot.get()` 截取卡片图像容器为 PixelMap
  - `CustomTransition` 单例注册动画回调
  - `Navigation.customNavContentTransition()` 拦截转场提供自定义动画
  - `LongTakeAnimationProperties`（@Observed）驱动截图的位置/大小/透明度动画
- **新增文件**：
  - `entry/src/main/ets/common/utils/SnapShotImage.ets` — PixelMap 持有者
  - `entry/src/main/ets/common/utils/CustomTransitionUtils.ets` — 动画回调注册单例
  - `entry/src/main/ets/common/utils/LongTakeAnimationProperties.ets` — @Observed 动画属性类
- **修改文件**：
  - `entry/src/main/ets/components/IllustCard.ets` — 图像容器加 `.id()`，onClick 截图并传递参数，转场期间隐藏卡片
  - `entry/src/main/ets/pages/illust/IllustDetailPage.ets` — onReady 注册自定义转场，叠加截图层，动画驱动
  - `entry/src/main/ets/pages/Index.ets` — Navigation 添加 `.customNavContentTransition()`，存储 UIContext 到 AppStorage
  - `entry/src/main/ets/common/constants/PageParamTypes.ets` — 新增 `IllustDetailAnimParam` 接口
- **测试**：`entry/src/test/CustomTransitionUtils.test.ets`
- **退路**：截图失败时自动降级为默认导航转场（无动画）；`getRectangleById` 获取卡片位置失败时自动降级
- **参考项目**：`transitions-collection`（HarmonyOS Samples）中的 `CardLongTakeTransition`

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
| 6 | 插画评论 | 插画详情页 → 点击评论 → 评论列表正常（发表暂不可用） | ☐ |
| 7 | 小说阅读器 | 点击任意小说 → 正文加载 → 自动阅读/书签保存 | ☐ |
| 8 | 小说系列 | 小说详情页 → 点击系列 → 系列列表正常 | ☐ |
| 9 | 小说评论 | 小说详情页 → 点击评论 → 评论列表正常（发表暂不可用） | ☐ |
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
| 22 | 沉浸光感 | 底部 TabBar 毛玻璃效果正常、深浅色切换稳定、滑动流畅 | ☐ |
| 23 | 状态栏深浅适配 | 切换系统深色/浅色模式后，状态栏时钟和图标颜色随背景自动变为白色/黑色，可清晰辨识 | ☐ |
| 24 | 卡片一镜到底（进入） | 在任意列表页点击插画卡片 → 卡片截图平滑缩放至全屏 → 详情内容淡入 | ☐ |
| 25 | 卡片一镜到底（返回） | 在详情页点击返回 → 详情内容淡出 → 截图平滑缩放回卡片位置 | ☐ |
| 26 | 截图失败降级 | 截图失败时（如图片未加载）→ 直接进入详情无动画 | ☐ |
| 27 | 多页作品 | 进入多页作品详情 → 滑动到非首页 → 返回时动画仍正常工作 | ☐ |

---

## F23 - ArkUI 动画与列表规范修复

- **描述**：按 ArkUI 官方规范修复动画 API 和列表渲染的不合规用法
- **涉及文件**：
  - `entry/src/main/ets/common/utils/BasicDataSource.ets`（新增，LazyForEach 通用数据源）
  - `entry/src/main/ets/components/ShimmerLoading.ets` — 递归动画改为 setInterval + 可见性管理
  - `entry/src/main/ets/components/SegmentedTabBar.ets` — 移除脆弱标志位，改用值比较跳过重复动画
  - `entry/src/main/ets/components/IllustCard.ets` — 收藏动画 3 段式简化为 2 段式
  - `entry/src/main/ets/pages/novel/NovelReaderPage.ets` — transition 配合 animateTo
  - `entry/src/main/ets/pages/illust/IllustDetailPage.ets` — 收藏动画简化、Swiper cachedCount
  - `entry/src/main/ets/pages/home/HomePage.ets` — onScroll animateTo 加防护、LazyForEach
  - `entry/src/main/ets/pages/latest/LatestPage.ets` — onScroll animateTo 加防护、LazyForEach
  - `entry/src/main/ets/pages/search/SearchPage.ets` — LazyForEach
  - `entry/src/main/ets/pages/user/UserProfilePage.ets` — LazyForEach (4 个 Tab)
  - `entry/src/main/ets/pages/favorites/FavoritesPage.ets` — LazyForEach
  - `entry/src/main/ets/pages/setting/FollowingPage.ets` — LazyForEach
  - `entry/src/main/ets/components/CommentsComponent.ets` — LazyForEach
- **修复项**：
  1. onScroll 高频回调内 animateTo 添加目标值防护，避免重复创建动画
  2. ShimmerLoading 递归 setTimeout 改为 setInterval + onVisibleAreaChange 可见性管理
  3. transition 转场动效配合 animateTo 包装状态变更
  4. 收藏按钮动画三段嵌套 setTimeout 简化为两段
  5. SegmentedTabBar 移除 updatingFromClick 标志位，用 animIndex===currentIndex 跳过重复
  6. 7 个列表页/组件的 ForEach 迁移为 LazyForEach + BasicDataSource
  7. IllustDetailPage Swiper 添加 cachedCount(1) 预加载相邻页

---

## F24 - 状态栏颜色深浅适配

- **描述**：状态栏内容颜色（时钟/图标）跟随深色/浅色模式动态切换，避免浅色模式下白色图标与白色背景重叠不可读
- **涉及文件**：
  - `entry/src/main/ets/entryability/EntryAbility.ets` — `onWindowStageCreate` 和 `onConfigurationUpdate` 中根据 `isDarkMode` 动态设置 `statusBarContentColor` / `navigationBarContentColor`
- **测试**：`entry/src/test/StatusBarTheme.test.ets`
- **规则**：深色模式 → `#FFFFFF`，浅色模式 → `#000000`

---

## F25 - SegmentedTabBar 跟手滑动动画

- **描述**：页内分段 Tab 栏（插画/小说切换等）的 pill 指示器支持跟手滑动。滑动内容区域时，pill 实时跟随手指移动，不再等到切换完成才跳变。pill 在中途还会弹性伸缩，文字高亮在滑动过半时切换
- **核心组件**：`entry/src/main/ets/components/SegmentedTabBar.ets` — 新增 `swipeProgress` 参数，pill 位置支持线性插值
- **内容容器改造**：5 个页面的 `Tabs` 组件替换为 `Swiper`，通过 `onGestureSwipe` / `onContentDidScroll` / `onAnimationEnd` 回调驱动 `swipeProgress`
- **涉及页面**：
  - `entry/src/main/ets/pages/home/HomePage.ets`
  - `entry/src/main/ets/pages/latest/LatestPage.ets`
  - `entry/src/main/ets/pages/search/SearchPage.ets`
  - `entry/src/main/ets/pages/favorites/FavoritesPage.ets`
  - `entry/src/main/ets/pages/user/UserProfilePage.ets`
- **测试**：`entry/src/test/SegmentedTabBar.test.ets`
- **规则**：pill 偏移 = `clamp(currentIndex + swipeProgress, 0, maxIndex) * pillWidth`；活动 tab 判定在 `|swipeProgress| >= 0.5` 时切换

---

> 最后更新：F26 卡片一镜到底转场动画，基于 2026-06-23

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

### 路由迁移：router.pushUrl → PageContext.openPage
- **PageContext**：`entry/src/main/ets/common/utils/PageContext.ets` — 封装 NavPathStack 替代 @ohos.router
- **PageEnum**：`entry/src/main/ets/common/constants/PageEnum.ets` — 页面路由枚举
- **PageParamTypes**：`entry/src/main/ets/common/constants/PageParamTypes.ets` — 页面参数类型定义
- **涉及文件**：IllustCard、NovelCard、UserCard、IllustDetailPage、NovelReaderPage、NovelSeriesPage、SettingPage、BlockedContentPage、AuthorDetailPage、CacheSettingsSection、CachedNovelsPage、SeriesDetailPage（共 12 个文件）
- **说明**：所有 router.pushUrl 调用已替换为 PageContext.openPage，通过 AppStorage 获取 rootPageContext，使用具名路由和类型化参数接口

---

## F24 - 项目标准化改造（对标官方 HarmonyOS 示例）

### 全局状态管理：globalThis → AppStorage
- **修改文件**：EntryAbility、SubscriptionService、ImageCacheService、TranslationController、BlockedContentPage、NovelReaderPage、SearchPage、AuthorDetailPage、CachedNovelsSimplePage、CacheSettingsSection、CachedNovelsPage、ProxySettingsSection、SeriesDetailPage、TranslationSettingsSection（共 14 个文件）
- **说明**：清除全部 26 处 globalThis 引用，统一使用 AppStorage 管理全局状态。appContext 通过 `AppStorage.setOrCreate('appContext', context)` 存储，isDarkMode 通过 `AppStorage.setOrCreate('isDarkMode', value)` 管理
- **StorageKeys**：`entry/src/main/ets/common/constants/StorageKeys.ets` — AppStorage 键名常量

### MVVM 架构引入
- **BaseState**：`entry/src/main/ets/viewmodel/BaseState.ets` — State 基类
- **BaseVM**：`entry/src/main/ets/viewmodel/BaseVM.ets` — ViewModel 抽象基类（含事件分发）
- **LoadingModel**：`entry/src/main/ets/models/LoadingModel.ets` — 统一加载状态模型（LoadingStatus 枚举 + @Observed）
- **PageLoadModel**：分页加载状态模型（PageStatus 枚举 + @Observed）
- **ViewModel 文件**（22 个）：HomeViewModel、LatestViewModel、SearchViewModel、FavoritesViewModel、IllustDetailViewModel、NovelReaderViewModel、NovelSeriesViewModel、UserProfileViewModel、FollowingViewModel、BlockedContentViewModel、SettingsViewModel、AuthorDetailViewModel、CachedNovelsViewModel、SeriesDetailViewModel、CacheSettingsViewModel、TranslationSettingsViewModel、ProxySettingsViewModel、CommentsViewModel、LoginViewModel、CardViewModels

### 图片组件标准化
- **ImageComponent**：`entry/src/main/ets/components/ImageComponent.ets` — @Reusable 统一图片组件，封装网络下载缓存、ShimmerLoading 占位、失败兜底
- **替换文件**：IllustCard、NovelCard、UserCard、CommentsComponent（4 个组件中的直接 Image 用法）
- **@Require 添加**：IllustCard.index、NovelCard.index、UserCard.index、SegmentedTabBar.currentIndex/swipeProgress（6 处 @Prop）

### 路由架构：router.pushUrl → Navigation + NavPathStack
- **Index.ets 重构**：外层包裹 Navigation(rootStack)，添加 navDestination 路由分发（pagesBuilder），15 个页面路由注册
- **@Entry 移除**：IllustDetailPage、IllustCommentsPage、NovelReaderPage、NovelSeriesPage、NovelCommentsPage、UserProfilePage、LoginPage、FavoritesPage、FollowingPage、BlockedContentPage、SettingsPage、AuthorDetailPage、CachedNovelsPage、CachedNovelsSimplePage、SeriesDetailPage（共 15 个页面）
- **@Builder 导出**：每个页面添加对应的 Builder 导出函数
- **参数获取**：router.getParams() → NavDestinationContext.onReady()
- **返回操作**：router.back() → PageContext.popPage()
- **main_pages.json**：仅保留 pages/Index，其余 15 个页面从配置中移除

### 测试新增
- **PageContext.test.ets**：NavPathStack 封装测试
- **LoadingModel.test.ets**：加载状态模型测试
- **BaseVM.test.ets**：ViewModel 基类事件分发测试
- **Constants.test.ets**：PageEnum + StorageKeys 常量验证
- **List.test.ets**：注册 4 个新测试套件

### 修复
- **EntryAbility.ets**：AppStorage.SetOrCreate → setOrCreate（API 大小写修正）
- **CMake 缓存清理**：删除 entry/.cxx 确保原生构建通过
