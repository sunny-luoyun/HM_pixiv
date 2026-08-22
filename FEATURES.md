# HPixiv 功能基线清单

> 本文档记录项目的所有功能模块及其涉及的核心文件。
> **每次新增或修改功能后必须同步更新本文档。**
> 改完代码后请按底部的「手工验证清单」逐项自检。

---

## F01 - 登录/登出（OAuth2）

- **描述**：Pixiv OAuth2 PKCE 登录流程，Bearer Token 认证与管理，自动 Token 刷新；同时保留 PHPSESSID Cookie 供 Web Ajax 端点使用
- **页面**：`entry/src/main/ets/pages/login/LoginPage.ets`
- **逻辑**：`entry/src/main/ets/pages/login/LoginPageViewModel.ets`、`entry/src/main/ets/services/LoginService.ets`
- **认证核心**：`entry/src/main/ets/services/PixivAuth.ets` — OAuth2 Token 管理、登录、刷新、持久化（Preferences: app_auth）
- **状态**：`entry/src/main/ets/store/AppState.ets`
- **Cookie**：`entry/src/main/ets/services/CookieManager.ets`、`entry/src/main/ets/common/utils/CookieStorage.ets`（Web Ajax 端点专用）
- **入口**：`entry/src/main/ets/entryability/EntryAbility.ets`（初始化时加载 Token、验证登录态、自动刷新）
- **App API 认证**：`entry/src/main/ets/services/AppApiService.ets`（使用 Bearer Token，自动 401 刷新）
- **工具**：`entry/src/main/ets/common/utils/MD5.ets`、`entry/src/main/ets/common/utils/TimeUtils.ets`

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

## F04 - 多维度搜索（含过滤条件 + 詳細検索条件）

- **描述**：按插画/小说/用户多维度搜索，支持排序、匹配模式、内容类型、R18 筛选、以及详细搜索条件（收藏数范围、投稿日期范围、AI生成过滤、宽高比、作品语言、原创过滤等）
- **页面**：`entry/src/main/ets/pages/search/SearchPage.ets`
- **API**：`entry/src/main/ets/services/PixivApiService.ets`（`searchIllusts`、`searchNovels`、`searchUsers`）
- **组件**：`entry/src/main/ets/components/SegmentedTabBar.ets`、`entry/src/main/ets/components/AdvancedSearchDialog.ets`
- **模型**：`entry/src/main/ets/models/SearchModels.ets`（`SearchCondition` 接口、`searchConditionToQueryString` 序列化、`isSearchConditionActive` 状态判断）
- **测试**：`entry/src/test/SearchCondition.test.ets`
- **过滤参数**（2025-06-23 新增）：
  - `sortOrder`：`date_d`(最新)/`date`(最旧)/`popular_d`(最多收藏)
  - `searchMode`：`s_tag`(标签部分)/`s_tag_full`(标签完全)/`s_tc`(标题说明)
  - `contentType`：`illust_and_ugoira`(全部)/`illust`(插画)/`ugoira`(动图)/`manga`(漫画)
  - `r18Mode`：`all`(全部)/`safe`(全年龄)/`r18`(R-18)
  - **詳細検索条件**（2026-07-12 新增）：
    - `bookmark_num_min` / `bookmark_num_max` — 收藏数範囲指定
    - `start_date` / `end_date` — 投稿日範囲指定（YYYY-MM-DD）
    - `ai_type` — AI生成フィルター（0=全表示/1=AIのみ/2=非AIのみ）
    - `ratio` — 作品の縦横比（''=指定なし/0.6=横長/1.0=正方形/1.5=縦長）
    - `work_lang` — 作品言語（''=指定なし/ja/zh/en）
    - `is_original` — オリジナルのみ（0=すべて/1=オリジナルのみ）
    - `duration` — 投稿期間（''=指定なし/within_last_week/within_last_month/within_last_year）

---

## F05 - 插画详情与评论

- **描述**：查看插画大图、标题、作者、标签；浏览/删除/发表评论（OAuth2 Bearer Token 认证已接入）；支持展开查看评论回复（楼中楼）
- **页面**：`entry/src/main/ets/pages/illust/IllustDetailPage.ets`、`entry/src/main/ets/pages/illust/IllustCommentsPage.ets`
- **API**：`entry/src/main/ets/services/PixivApiService.ets`（`getIllustDetail`、`getIllustComments`、`getIllustCommentReplies`）、`entry/src/main/ets/services/AppApiService.ets`（`postIllustComment`、`deleteIllustComment`）
- **组件**：`entry/src/main/ets/components/CommentsComponent.ets`（含发表输入框、回复展开/收起、回复发表）

---

## F06 - 小说阅读器与系列

- **描述**：全功能小说阅读（书签、自动阅读）、小说系列导航、评论（含楼中楼回复）
- **页面**：`entry/src/main/ets/pages/novel/NovelReaderPage.ets`、`entry/src/main/ets/pages/novel/NovelSeriesPage.ets`、`entry/src/main/ets/pages/novel/NovelCommentsPage.ets`
- **API**：`entry/src/main/ets/services/PixivApiService.ets`（`fetchNovelDetail`、`fetchNovelText`、`fetchSeriesNovels`、`getNovelComments`、`getNovelCommentReplies`）
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

## F11 - AI 翻译（DeepSeek + 自定义模型）

- **描述**：通过 DeepSeek API 或自定义 OpenAI 兼容 API 对日文小说进行标题/全文中文翻译，支持自定义翻译提示词（标题/全文分开或统一）、自定义模型下隐藏费用/token 估算
- **API**：`entry/src/main/ets/services/DeepSeekService.ets`
- **分词器**：`entry/src/main/ets/services/DeepSeekTokenizer.ets`
- **翻译缓存**：`entry/src/main/ets/common/utils/TranslationStorage.ets`
- **扩展（2026-08-13）**：新增自定义翻译提供商/提示词存储键与存储方法（为自定义模型接入打基础）
  - `StorageKeys.ets` — 新增 `LLM_PROVIDER`、`CUSTOM_LLM_API_BASE`、`CUSTOM_LLM_API_KEY`、`CUSTOM_LLM_MODEL`、`TITLE_PROMPT`、`FULL_PROMPT`、`UNIFIED_PROMPT`
  - `TranslationStorage.ets` — 新增 `saveLlmProvider/getLlmProvider`、`saveCustomApiBase/getCustomApiBase`、`saveCustomApiKey/getCustomApiKey/clearCustomApiKey`、`saveCustomModel/getCustomModel`、`saveTitlePrompt/getTitlePrompt`、`saveFullPrompt/getFullPrompt`、`saveUnifiedPrompt/getUnifiedPrompt`
  - **测试**：`entry/src/test/StorageKeys.test.ets`、`entry/src/test/TranslationStorage.test.ets`
- **扩展（2026-08-13）**：抽象 LLM 基类 + 自定义 OpenAI 兼容模型服务
  - `LlmProvider.ets` — 抽象基类 `BaseLlmService`（`LlmConfig` 配置、请求体构建、错误处理、并发控制）
  - `OpenAiCompatService.ets` — 用户自定义 OpenAI 兼容端点的模型服务（`constructor(baseUrl, apiKey, model)`、`updateConfig`，无 thinking/费用估算，全文 max_tokens 8192）
  - **测试**：`entry/src/test/LlmProvider.test.ets`、`entry/src/test/OpenAiCompatService.test.ets`
- **扩展（2026-08-13）**：LLM 服务工厂，按 provider 分发
  - `LlmServiceFactory.ets` — `getLlmService()` 按 AppStorage `llmProvider` 返回 DeepSeekService/OpenAiCompatService 单例并同步 prompts；`resetLlmServiceInstance()` 清单例供切换 provider；每次调用都从 AppStorage 刷新 apiKey/自定义配置（updateConfig/updateApiKey），设置修改即时生效
  - `TranslationController.ets`、`NovelCard.ets` — 调用方从 `getDeepSeekService()` 迁移到 `getLlmService()`（DeepSeek 特有 tokenizer/费用估算以 instanceof 守卫保留），错误文案统一为「请先在设置中配置翻译 API 密钥」
  - **测试**：`entry/src/test/LlmServiceFactory.test.ets`
- **扩展（2026-08-13）**：自定义模型模式隐藏费用/token 估算信息
  - `TranslationController.ets` — 新增纯函数 `buildEstimateInfo(...)`，按 `service.supportsCostEstimate` 组装确认对话框估算文案：DeepSeek 模式显示 字符/tokens/费用/校准比；自定义模式仅显示字符数+预计耗时
  - **测试**：`entry/src/test/TranslationController.test.ets`
- **扩展（2026-08-13）**：设置页翻译服务切换、自定义模型配置与翻译提示词编辑
  - `TranslationSettingsSection.ets` — 顶部新增「翻译服务」Radio 组（DeepSeek 预设/自定义模型）；自定义模式显示 API 地址/模型名称/API Key 输入区；余额/校准区域仅 DeepSeek 模式且有密钥时显示；DeepSeek 密钥输入区仅 DeepSeek 模式显示；新增「翻译提示词」卡片（统一提示词 Toggle + 标题/全文 TextArea + 恢复默认确认对话框），两种 provider 均显示
  - **测试**：无（`pages/settings/` 属 AGENTS.md 例外清单，不可测）
- **修复（2026-08-14）**：长文翻译截断、DeepSeek 双实例状态分叉
  - `LlmProvider.ets` — `translateLongText` 分段阈值由硬编码 100000 改为 `getMaxSafeTokens()`（`min(100000, maxTokensFull * 2)`），自定义模式（8192）单次调用输出上限不会超过响应 max_tokens
  - `LlmServiceFactory.ets` — deepseek 分支复用 `getDeepSeekService()` 单例，设置页校准重置与翻译路径共享同一 adaptiveRatio/averageSpeed 状态
  - `TranslationSettingsViewModel.ets` — 删除无消费者的 `updateLlmProvider`/`updateCustomConfig`/`updateTitlePrompt`/`updateFullPrompt`/`updateUnifiedPrompt`/`resetPrompts` 与 7 个对应状态字段（设置页沿用内联 @State + AppStorage + TranslationStorage 模式）
  - `DeepSeekService.ets` — 移除未使用的 `StatsResult` 接口；`NovelReaderPage.ets` — 移除未使用的 `getDeepSeekService` 导入
  - **测试**：`entry/src/test/LlmProvider.test.ets`（getMaxSafeTokens × 2）、`entry/src/test/TranslationStorage.test.ets`（默认值断言 × 2）

---

## F12 - 离线小说缓存

- **描述**：小说内容和翻译结果 SQLite 离线缓存，支持离线阅读
- **数据库**：`entry/src/main/ets/database/PixivCacheDB.ets`
- **页面**：`entry/src/main/ets/pages/settings/CachedNovelsPage.ets`、`entry/src/main/ets/pages/settings/CachedNovelsSimplePage.ets`

---

## F13 - 设置与屏蔽管理

- **描述**：应用设置（代理、翻译、主题）、关注列表、屏蔽标签/用户；设置页改为菜单入口，各模块独立二级页面
- **页面**：`entry/src/main/ets/pages/setting/SettingPage.ets`、`entry/src/main/ets/pages/setting/FollowingPage.ets`、`entry/src/main/ets/pages/setting/BlockedContentPage.ets`、`entry/src/main/ets/pages/settings/SettingsPage.ets`
- **二级页面（2026-08-13）**：翻译服务 `SettingsTranslationPage.ets`、代理设置 `SettingsProxyPage.ets`、缓存管理 `SettingsCachePage.ets`、过滤设置 `SettingsFilterPage.ets`、阅读器设置 `SettingsReaderPage.ets`
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
| 6 | 插画评论 | 插画详情页 → 点击评论 → 评论列表正常（发表可用） | ☐ |
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
| 28 | OAuth2 登录 | 退出登录 → 点击登录 → WebView 打开 Pixiv OAuth 页 → 登录成功 → Token 自动刷新 | ☐ |
| 29 | 收藏/关注 | 在插画/小说详情 → 点击收藏 → 状态正确切换（走 Bearer Token API） | ☐ |
| 30 | 评论发表 | 插画/小说评论页 → 输入评论 → 点击发送 → 评论成功发表 | ☐ |
| 31 | 评论回复展开 | 插画/小说评论页 → 点击「查看回复」→ 回复列表展开显示 | ☐ |
| 32 | 评论回复收起 | 点击「收起回复」→ 回复列表收起 | ☐ |
| 33 | 发表回复 | 点击评论旁的「回复」→ 输入框变为「回复 @用户名」模式 → 发送成功 → 评论列表刷新 | ☐ |
| 34 | 排行榜浏览 | 切换到「排行」Tab → 默认显示每日排行 → 切换模式（每周/每月/新人等） → 列表正常加载 → 下拉刷新 → 翻页到末尾 | ☐ |
| 35 | 排名角标 | 排行榜卡片左上角显示 `#1` `#2` 等排名数字 | ☐ |
| 36 | 排行榜 R18 | 登录前 R18/R18周 模式按钮隐藏 → 登录后可见 | ☐ |
| 37 | 评论表情显示 | 评论内容中 `(heart)` 正确显示为 ❤️，`(laugh)` 为 😄，未知关键词保持原样 | ☐ |
| 38 | Stamp 贴图 | 含有 Stamp 的评论显示对应的贴图图片（48×48） | ☐ |
| 39 | 浏览历史入口 | 「我的」页面菜单栏显示「🕐 浏览历史」项并点击可进入 | ☐ |
| 40 | 插画历史记录 | 打开插画详情页返回后 → 浏览历史「插画」Tab 显示该插画卡片 | ☐ |
| 41 | 小说历史记录 | 打开已缓存小说阅读后返回 → 浏览历史「小说」Tab 显示该小说卡片 | ☐ |
| 42 | 历史页卡片可点击 | 浏览历史页中点击插画/小说卡片 → 正常跳转至详情/阅读页 | ☐ |
| 43 | 双 Tab 切换 | 浏览历史页切换插画/小说 Tab → 列表正常切换 | ☐ |
| 44 | 重复浏览更新 | 多次浏览同一作品 → 仅保留一条记录 | ☐ |
| 45 | 浏览历史日期显示 | 历史页每张卡片上方显示浏览时间（如「7月12日 14:30」） | ☐ |
| 46 | 浏览历史翻页加载 | 列表滚到底部自动加载更多，底部有 loading 和「已显示全部记录」提示 | ☐ |
| 47 | 动图播放 | 打开动图作品 ID（如 147154771） → 动图正常循环播放 | ☐ |
| 48 | 动图暂停/播放 | 动图播放时点击右下角按钮 → 暂停/恢复播放切换正常 | ☐ |
| 49 | 动图卡片标识 | 动图作品卡片左上角显示「动图」徽标（白点+文字） | ☐ |
| 50 | 动图下载 | 动图详情页点击下载按钮 → 弹出"正在生成动图" → 生成完成后保存到相册 | ☐ |
| 51 | 自定义模型翻译 | 设置页切换到「自定义模型」→ 填入 API 地址/模型名/Key → 小说标题与全文翻译可用 | ☐ |
| 52 | 自定义模型隐藏费用 | 自定义模型下不显示账户余额/校准比例/DeepSeek 密钥输入 → 全文翻译确认框无 token/费用行 | ☐ |
| 53 | 自定义提示词 | 自定义标题/全文提示词后翻译风格随之变化 → 恢复默认后回到内置模板 | ☐ |
| 54 | 统一提示词 | 统一提示词开关开启后 → 标题与全文翻译使用同一提示词 | ☐ |
| 55 | 切回 DeepSeek | 切换回 DeepSeek 后 → 余额/校准/费用显示恢复 | ☐ |
| 56 | 设置二级页面 | 设置页显示 5 个菜单项 → 点击分别进入翻译/代理/缓存/过滤/阅读器页面 → 返回正常 | ☐ |
| 57 | 阅读器简介/评论入口 | 小说阅读器点击屏幕呼出菜单栏 → 切到「简介/评论」子面板 → 点击「查看简介/评论」→ 进入小说评论页 | ☐ |
| 58 | 小说简介显示 | 评论页顶部显示该小说的「作品简介」（作者写的本作简介，非系列简介）→ 下方自然衔接评论列表 | ☐ |
| 59 | 阅读器顶栏去评论按钮 | 小说阅读器最上栏不再显示「评论」按钮（入口已移入呼出菜单） | ☐ |
| 60 | 缓存小说作者组排序 | 缓存小说页标题栏右侧显示排序图标（如 `↕ 作者名`）→ 点击弹出菜单 → 选择「缓存时间」→ 作者组按最新缓存时间重排 | ☐ |
| 61 | 作者详情页排序 | 进入作者详情页 → 系列/独立小说区域有排序图标 → 点击可排序 | ☐ |
| 62 | 系列详情页排序 | 进入系列详情页 → 标题栏有排序图标 → 点击可按章节顺序/小说名/缓存时间/最后阅读排序 | ☐ |
| 63 | 排序升降序切换 | 排序菜单标题栏右侧显示「↑ 升序/↓ 降序」→ 点击切换方向 → 列表顺序反转 | ☐ |
| 64 | 排序偏好持久化 | 设置排序后退出页面 → 重新进入 → 排序方式和方向保持上次设置 | ☐ |
| 65 | 未阅读小说排序 | 按「最后阅读」排序时 → 从未打开过的小说排在最前面 | ☐ |

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

## F27 - 关注更新通知推送

- **描述**：当关注画师发布新插画或小说时，通过系统通知推送提醒用户。支持前台轮询（5分钟间隔）和后台 WorkScheduler（30分钟间隔）两种检测方式
- **通知渠道**：`illust_update`（插画更新）、`novel_update`（小说更新），类型为 SERVICE_INFORMATION
- **通知内容**：每条作品独立通知，按插画/小说类型分组折叠；标题格式为「插画更新 - {作者名}」/「小说更新 - {作者名}」
- **通知交互**：点击通知跳转至「最新」Tab
- **首次启动**：首次打开 App 时弹窗请求通知权限；首次检查仅保存状态不推送
- **新增文件**：
  - `entry/src/main/ets/notification/NotificationHelper.ets` — 通知渠道创建、权限请求、通知发布封装
  - `entry/src/main/ets/services/LatestCheckService.ets` — 核心检查逻辑（ID 对比、偏好存储、通知触发）
  - `entry/src/main/ets/entryworkability/EntryWorkAbility.ets` — WorkScheduler 后台任务回调
- **修改文件**：
  - `entry/src/main/module.json5` — 注册 EntryWorkAbility extension
  - `entry/src/main/ets/entryability/EntryAbility.ets` — 通知初始化、WorkScheduler 注册、onNewWant 导航处理
  - `entry/src/main/ets/pages/TabsPage.ets` — 通知点击后自动切换到「最新」Tab
  - `entry/src/main/ets/pages/latest/LatestPage.ets` — 前台 5 分钟轮询
- **测试**：`entry/src/test/LatestCheck.test.ets`

---

## F28 - OAuth2 Bearer Token 认证切换

- **描述**：将登录方式从 Cookie (PHPSESSID) 全面切换为 OAuth2 PKCE + Bearer Token；App API 端点使用 Bearer Token（含自动 401 刷新），Web Ajax 端点保留 Cookie 认证；收藏/关注/评论等写操作统一走 AppApiService
- **新增文件**：
  - `entry/src/main/ets/services/PixivAuth.ets` — OAuth2 认证核心服务（PKCE 登录、Token 刷新、持久化）
  - `entry/src/main/ets/common/utils/MD5.ets` — MD5 哈希工具（OAuth 签名用）
  - `entry/src/main/ets/common/utils/TimeUtils.ets` — ISO8601 UTC 时间格式化
  - `entry/src/test/PixivAuth.test.ets` — 认证逻辑单测
  - `entry/src/test/TimeUtils.test.ets` — 时间格式化单测
  - `entry/src/test/CryptoUtils.test.ets` — AES-GCM 加密格式校验单测
- **修改文件**：
  - `entry/src/main/ets/pages/login/LoginPage.ets` — WebView URL 改为 PKCE OAuth，回调拦截 pixiv:// 协议
  - `entry/src/main/ets/pages/login/LoginPageViewModel.ets` — 登录流程改为 code 换 token
  - `entry/src/main/ets/services/AppApiService.ets` — Cookie → Bearer Token，新增 401 自动刷新
  - `entry/src/main/ets/services/PixivService.ets` — Bookmark 委托从 BookmarkService → AppApiService
  - `entry/src/main/ets/store/AppState.ets` — 登录状态检查从 Cookie → Token + 启动自动刷新
  - `entry/src/main/ets/entryability/EntryAbility.ets` — 初始化 PixivAuth
  - `entry/src/main/ets/common/constants/ApiConfig.ets` — 新增 OAuth/App API 常量
  - `entry/src/main/ets/components/CommentsComponent.ets` — 恢复评论发表 UI（TextInput + 发送按钮）
  - `entry/src/main/ets/pages/illust/IllustCommentsPage.ets` / `entry/src/main/ets/pages/novel/NovelCommentsPage.ets` — 传入 postComment 回调
  - `entry/src/test/List.test.ets` — 注册 PixivAuth 测试套件
- **删除文件**：
  - `entry/src/main/ets/services/BookmarkService.ets` — 已被 AppApiService 覆盖（Web Ajax + CSRF 方式废弃）
- **架构**：App API (app-api.pixiv.net) 使用 `Authorization: Bearer <token>`；Web Ajax (www.pixiv.net) 使用 `Cookie: PHPSESSID=<value>`；两者并存，互不干扰

---

## F29 - Pixiv 排行榜浏览

- **描述**：浏览 Pixiv 排行榜（每日/每周/每月/新人/原创/男性/女性/R18），支持模式切换、下拉刷新、分页加载
- **页面**：`entry/src/main/ets/pages/ranking/RankingPage.ets`
- **API**：`entry/src/main/ets/services/PixivApiService.ets`（`getRanking`）
- **模型**：`entry/src/main/ets/models/RankingModels.ets`
- **Tab 入口**：`entry/src/main/ets/pages/TabsPage.ets` — 第5个 Tab「排行」，图标 `sys.symbol.trophy`，位于「搜索」与「我的」之间
- **数据源**：`BasicDataSource<IllustBookmark>` + `rankMap` 记录排名信息
- **卡片**：复用 `IllustCard` 组件 + 排名角标（`#1`、`#2`...）
- **模式选择**：水平滚动的 pill 式模式选择器
- **R18 过滤**：R18 模式仅在登录后显示
- **测试**：`entry/src/test/RankingService.test.ets`
- **验证项**：切换到「排行」Tab → 默认显示每日排行 → 切换模式 → 排行榜列表正常加载 → 翻页正常 → R18 模式登录后可见

---

## F30 - 评论回复（楼中楼）

- **描述**：支持展开/收起评论回复内容（楼中楼），点击「查看回复」加载回复列表；支持对指定评论发表回复，底部输入框显示「回复 @用户名」模式
- **新增 API**：
  - `entry/src/main/ets/services/PixivApiService.ets` — `getIllustCommentReplies(commentId, page)`、`getNovelCommentReplies(commentId, page)`
  - `entry/src/main/ets/services/PixivService.ets` — 转发方法
- **组件改造**：
  - `entry/src/main/ets/components/CommentsComponent.ets` — 新增 `fetchReplies` 回调、`expandedReplies`(Map) / `repliesCache`(Map) / `replyTarget` 状态；「有回复」改为可点击展开/收起；每条评论增加「回复」按钮；底部输入框支持回复模式（传入 parentCommentId）
- **页面适配**：
  - `entry/src/main/ets/pages/illust/IllustCommentsPage.ets` — 传入 `fetchReplies` / 更新 `postComment` 签名支持 parentCommentId
  - `entry/src/main/ets/pages/novel/NovelCommentsPage.ets` — 同上
- **测试**：`entry/src/test/CommentsService.test.ets`

---

## F31 - 评论 Emoji 表情转换与 StampId 贴图渲染

- **描述**：将 Pixiv 评论 API 返回的表情关键词（如 `(heart)`、`(laugh)`、`(love2)`）转换为 Unicode Emoji（❤️、😄、🥰）；支持 `stampId` 字段的 Stamp 贴图渲染（如 stampId=302 显示对应贴图图片）
- **新增文件**：
  - `entry/src/main/ets/common/utils/EmojiUtil.ets` — Pixiv 表情映射表（120+ 条）、`convertPixivEmojis()` 函数、`getStampImageUrl()` 辅助函数
- **修改文件**：
  - `entry/src/main/ets/models/CommentModels.ets` — `stamp?: object` → `stampId?: string`（匹配实际 API 返回格式）
  - `entry/src/main/ets/components/CommentsComponent.ets` — 主评论与回复的 `Text` 渲染前调用 `convertPixivEmojis()`；在 `stampId` 存在时通过 `ImageComponent` 渲染贴图图片
- **测试**：`entry/src/test/EmojiUtil.test.ets`
- **验证项**：
  - 评论内容中 `(heart)` 显示为 ❤️，`(laugh)` 显示为 😄
  - 变体关键词 `(love2)` 显示为 🥰，`(heart_eyes)` 显示为 😍
  - 未知关键词如 `(unknown)` 保持原样
  - Stamp 贴图图片（基于 stampId）正常显示

---

## F34 - Ugoira 动图播放支持

- **描述**：支持 Pixiv 平台上的 ugoira（动画插画）作品。通过 `ugoira_meta` API 获取帧序列和延时数据，下载 ZIP 包提取帧图片，使用 Image 逐帧播放；支持保存为 GIF 动图到相册
- **新增文件**：
  - `entry/src/main/ets/models/UgoiraModels.ets` — `UgoiraFrame`、`UgoiraMetaBody`、`UgoiraMetaResponse` 接口定义
  - `entry/src/main/ets/services/UgoiraExtractor.ets` — ZIP 下载 + 二进制解析 + 帧图片提取到缓存目录
  - `entry/src/main/ets/services/GifEncoder.ets` — 纯 ArkTS GIF 编码器（LZW 压缩），将 JPEG 帧序列编码为动图
  - `entry/src/main/ets/components/UgoiraPlayer.ets` — 使用 Image 逐帧播放组件（支持播放/暂停控制）
- **修改文件**：
  - `entry/src/main/ets/models/IllustModels.ets` — `IllustDetailBody` 添加 `illustType` 字段
  - `entry/src/main/ets/models/PixivModels.ets` — `export * from './UgoiraModels'`
  - `entry/src/main/ets/services/PixivApiService.ets` — 新增 `getUgoiraMeta()` 方法
  - `entry/src/main/ets/services/PixivService.ets` — 桥接 `getUgoiraMeta()`
  - `entry/src/main/ets/pages/illust/IllustDetailPage.ets` — 检测 `illustType === 2` 时替换 Swiper 为 UgoiraPlayer
  - `entry/src/main/ets/components/IllustCard.ets` — 动图作品左上角添加"动图"徽标
- **测试**：`entry/src/test/UgoiraModels.test.ets`
- **验证项**：打开动图作品 → 动图正常循环播放 → 播放/暂停控制正常 → 卡片列表显示"动图"标识 → 普通插画不受影响

---

> 最后更新：F37 缓存小说排序（三级排序+升降序+偏好持久化），基于 2026-08-17

---

## F33 - 个人中心头像自动补抓

- **描述**：用户每次切换到「我的」页面时，自动检测本地头像缓存文件是否存在；若缺失则通过 Pixiv API (`refreshUserInfo()`) 获取头像 URL 并下载到本地缓存，确保已登录用户始终能看到自己的头像而非默认占位图
- **涉及文件**：
  - `entry/src/main/ets/pages/setting/SettingPage.ets` — 新增 `checkAndRefetchAvatar()` 私有方法，在 `aboutToAppear()` 中触发
  - `entry/src/main/ets/store/AppState.ets` — 复用已有 `refreshUserInfo()` / `cacheAvatar()` 方法
- **测试**：`entry/src/test/AppState.test.ets` — 新增「头像自动补抓逻辑」测试套件

---

## F32 - 浏览历史

- **描述**：自动记录用户查看过的插画和小说，在「我的」页面新增「浏览历史」入口，按插画/小说 Tab 分类展示
- **新增文件**：
  - `entry/src/main/ets/database/BrowseHistoryDao.ets` — 浏览历史数据访问层（INSERT/UPDATE/QUERY）
  - `entry/src/main/ets/pages/settings/BrowseHistoryPage.ets` — 浏览历史页面（SegmentedTabBar + IllustCard/NovelCard + BasicDataSource）
- **修改文件**：
  - `entry/src/main/ets/database/DatabaseCore.ets` — 新增 `browse_history` 表（DB_VERSION 4→5）
  - `entry/src/main/ets/database/PixivCacheDB.ets` — 新增 `saveBrowseHistory` / `getAllIllustBrowseHistory` / `getAllNovelBrowseHistory`
  - `entry/src/main/ets/models/CommonModels.ets` — 新增 `BrowseHistoryRecord` 接口
  - `entry/src/main/ets/common/constants/PageEnum.ets` — 新增 `BROWSE_HISTORY` 路由名
  - `entry/src/main/ets/pages/Index.ets` — 注册 `BrowseHistoryBuilder`
  - `entry/src/main/ets/pages/setting/SettingPage.ets` — 添加「🕐 浏览历史」菜单项
  - `entry/src/main/ets/pages/illust/IllustDetailPage.ets` — 浏览插画详情时写入历史
  - `entry/src/main/ets/pages/novel/NovelReaderPage.ets` — 阅读小说时写入历史
- **数据存储**：本地 SQLite `browse_history` 表（id/content_type/content_id/title/cover_url/user_id/user_name/page_count/tags/bookmark_count/word_count/series_id/series_title/create_date/update_date/viewed_at）
- **历史记录规则**：同一作品重复浏览仅更新时间戳（UPSERT 语义）；纯本地，不依赖 Pixiv 服务端
- **测试**：`entry/src/test/BrowseHistoryDao.test.ets`

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
- **FormatUtil**：`entry/src/main/ets/common/utils/FormatUtil.ets`（测试：`entry/src/test/FormatUtil.test.ets`）
- **ThemeUtil**：`entry/src/main/ets/common/utils/ThemeUtil.ets`（测试：`entry/src/test/ThemeUtil.test.ets`）
- **NovelParser**：`entry/src/main/ets/common/utils/NovelParser.ets`（测试：`entry/src/test/NovelParser.test.ets`）

### 代码清理
- 删除死代码：`fetchUserName`、`deleteSingleNovelCover`、`getAllImageCacheInfo`
- 评论页面减少 ~300 行重复代码
- SettingsPage 从 1092 行降至 ~200 行骨架

### 路由迁移：router.pushUrl → PageContext.openPage
- **PageContext**：`entry/src/main/ets/common/utils/PageContext.ets` — 封装 NavPathStack 替代 @ohos.router
- **PageEnum**：`entry/src/main/ets/common/constants/PageEnum.ets` — 页面路由枚举（测试：`entry/src/test/PageEnum.test.ets`）
- **PageParamTypes**：`entry/src/main/ets/common/constants/PageParamTypes.ets` — 页面参数类型定义
- **涉及文件**：IllustCard、NovelCard、UserCard、IllustDetailPage、NovelReaderPage、NovelSeriesPage、SettingPage、BlockedContentPage、AuthorDetailPage、CacheSettingsSection、CachedNovelsPage、SeriesDetailPage（共 12 个文件）
- **说明**：所有 router.pushUrl 调用已替换为 PageContext.openPage，通过 AppStorage 获取 rootPageContext，使用具名路由和类型化参数接口

---

## F35 - 项目标准化改造（对标官方 HarmonyOS 示例）

### 全局状态管理：globalThis → AppStorage
- **修改文件**：EntryAbility、SubscriptionService、ImageCacheService、TranslationController、BlockedContentPage、NovelReaderPage、SearchPage、AuthorDetailPage、CachedNovelsSimplePage、CacheSettingsSection、CachedNovelsPage、ProxySettingsSection、SeriesDetailPage、TranslationSettingsSection（共 14 个文件）
- **说明**：清除全部 26 处 globalThis 引用，统一使用 AppStorage 管理全局状态。appContext 通过 `AppStorage.setOrCreate('appContext', context)` 存储，isDarkMode 通过 `AppStorage.setOrCreate('isDarkMode', value)` 管理
- **StorageKeys**：`entry/src/main/ets/common/constants/StorageKeys.ets` — AppStorage 键名常量（测试：`entry/src/test/StorageKeys.test.ets`）

### MVVM 架构引入
- **BaseState**：`entry/src/main/ets/viewmodel/BaseState.ets` — State 基类（测试：`entry/src/test/BaseState.test.ets`）
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

### 测试新增（2026-07-19 全量补完）
- **PageContext.test.ets**：NavPathStack 封装测试
- **LoadingModel.test.ets**：加载状态模型测试
- **BaseVM.test.ets**：ViewModel 基类事件分发测试
- **BaseState.test.ets**：空基类实例化测试
- **Constants.test.ets**：PageEnum + StorageKeys 常量验证
- **FormatUtil.test.ets**：文件大小格式化纯函数测试（边界：0、1KB、1MB）
- **NovelParser.test.ets**：小说标记解析（[chapter]、[newpage]、[[rb:]]、[b]）
- **ThemeUtil.test.ets**：阅读器颜色配置（dark/light）
- **TimeUtils.test.ets**：UTC 与本地时间格式化
- **BreakpointManager.test.ets**：响应式断点映射（xs~xl 全部阈值）
- **PageEnum.test.ets**：页面路由名常量值验证
- **StorageKeys.test.ets**：AppStorage 键名常量验证
- **List.test.ets**：注册全量 46 个测试套件

#### 本次补完修复的现有测试
- **AppApiService.test.ets**：重写为 V3→Ajax 评论数据转换测试
- **CryptoUtils.test.ets**：重写为 AES-GCM 格式校验 + Base64 往返
- **EmptyView.test.ets** / **ErrorView.test.ets** / **LoadingView.test.ets**：重写为组件接口约束 + 条件渲染逻辑测试
- **CommentsService.test.ets**：重写为评论 API 路径 + AjaxComment 模型测试
- **LocalUnit.test.ets**：清理无意义骨架代码

### 修复
- **EntryAbility.ets**：AppStorage.SetOrCreate → setOrCreate（API 大小写修正）
- **CMake 缓存清理**：删除 entry/.cxx 确保原生构建通过

---

## F36 - 阅读器「简介/评论」入口 + 小说评论页展示本作简介

- **描述**：小说阅读器顶栏的「评论」按钮移入点击呼出的菜单栏（新增「简介/评论」子面板），评论页顶部新增该小说作者写的本作简介（非系列简介），简介下方自然衔接评论列表
- **页面**：
  - `entry/src/main/ets/pages/novel/NovelReaderPage.ets` — 顶栏移除评论按钮；呼出菜单栏新增「简介/评论」Tab；子面板提供「查看简介/评论」按钮并跳转评论页
  - `entry/src/main/ets/pages/novel/NovelCommentsPage.ets` — 读取本作简介（优先离线缓存 caption，缺失时网络 fetchNovelDetail）并传入评论组件
- **组件**：`entry/src/main/ets/components/CommentsComponent.ets` — 新增可选 `introTitle`/`introText`（@Prop，随父组件异步加载后刷新）；`entityId` 改为 `@Prop @Watch`，修复页面在 onReady 才拿到 ID 时评论不自动加载的问题；简介以列表首项渲染、随评论自然滚动
- **简介来源**：`PixivNovel.caption`（缓存库 `NovelCacheDao` 的 caption 字段 / `PixivApiService.fetchNovelDetail` 的 `b.description`）
- **验证项**：见「手工验证清单」第 57-59 项

---

## F37 - 缓存小说排序

- **描述**：缓存小说页面（CachedNovelsPage、AuthorDetailPage、SeriesDetailPage）支持按多种字段排序，三个层级独立控制：作者组（作者名/缓存时间/小说数量/最后阅读）、作者内独立小说（小说名/缓存时间/最后阅读）、系列内章节（章节顺序/小说名/缓存时间/最后阅读），每种支持升降序切换，偏好通过 Preferences 持久化
- **页面**：
  - `entry/src/main/ets/pages/settings/CachedNovelsPage.ets` — 作者组排序
  - `entry/src/main/ets/pages/settings/AuthorDetailPage.ets` — 作者内独立小说 + 系列排序
  - `entry/src/main/ets/pages/settings/SeriesDetailPage.ets` — 系列内章节排序
- **组件**：`entry/src/main/ets/components/SortPopupMenu.ets`（通用排序弹出菜单）
- **工具**：`entry/src/main/ets/common/utils/SortUtils.ets`（排序纯函数）
- **数据**：`entry/src/main/ets/models/NovelModels.ets`（PixivNovel.lastReadAt 字段）、`entry/src/main/ets/database/NovelCacheDao.ets`（getLastReadTimes 批量查询）
- **测试**：`entry/src/test/SortUtils.test.ets`
