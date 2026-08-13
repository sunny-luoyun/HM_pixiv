# 设计文档：自定义翻译模型接入 + 自定义翻译提示词

- 日期：2026-08-13
- 状态：已确认设计
- 关联功能：FEATURES.md F11（AI 翻译 DeepSeek）

## 背景与目标

当前小说/标题翻译硬编码接入 DeepSeek API（`DeepSeekService.ets`），用户无法更换为其他 OpenAI 兼容模型，也无法自定义翻译提示词。目标：

1. 支持两档提供商：预设 DeepSeek / 自定义 OpenAI 兼容 API（可配置 API 地址、模型名、API Key）
2. 支持自定义翻译提示词（标题 / 全文分开设置 + 统一开关 + 恢复默认模板）
3. 自定义模型模式下隐藏 DeepSeek 专属能力：余额查询、费用估算、token 估算、校准比例

## 现有实现要点

- `DeepSeekService.ets`（584 行）：OpenAI 兼容 `/chat/completions` 请求，硬编码 baseUrl（`ApiConfig.DEEPSEEK_API`）、model=`deepseek-v4-flash`、`thinking:{type:'disabled'}`、temperature（标题 0.8/全文 0.3）、max_tokens（标题 100/全文 131072）；含 tokenizer 估算、费用/耗时估算、自适应并发、余额查询（`/user/balance`）
- `TranslationStorage.ets`：preferences `app_translation` 文件，API key 经 `encryptAesGcm` 加密存储，运行时放 AppStorage `deepseekApiKey`
- 调用方：`TranslationController`（标题/全文翻译入口）、`NovelCard`（列表标题翻译，直调 service）、`TranslationSettingsSection`/`TranslationSettingsViewModel`（设置页）、`EntryAbility`（启动恢复 key）
- 测试：`DeepSeekService.test.ets`、`DeepSeekTokenizer.test.ets`、`TranslationStorage.test.ets`（概念性校验）

## 设计方案（方案 B：抽象服务层）

### 1. 服务层架构

```
services/
├── LlmProvider.ets           # 新增：抽象基类 BaseLlmService + 工厂 getLlmService()
├── DeepSeekService.ets       # 保留：继承基类，现有公开方法签名全部不变
└── OpenAiCompatService.ets   # 新增：自定义 OpenAI 兼容模型
```

**`BaseLlmService`（抽象基类，LlmProvider.ets）**，抽取通用逻辑：

- `translateText(text, isTitle)`：OpenAI 兼容请求核心（错误码处理、usage 统计）
- `translateLongText(text, onProgress)`：长文分段（10 万 tokens 阈值）
- `translateParagraphs(paragraphs, onProgress)`：自适应并发控制
- `buildSystemPrompt(isTitle)`：prompt 构建（默认模板 / 自定义 / 统一开关）
- 可配置项（子类构造注入）：`baseUrl`、`apiKey`、`model`、`supportsThinking`、`maxTokens`

**`DeepSeekService extends BaseLlmService`**：

- 保留全部现有公开方法：`updateApiKey`、`hasValidKey`、`getStats`、`initTokenizer`、`estimateTokens`、`getAdaptiveRatio`、`getRatioCount`、`loadRatio`、`resetAdaptiveRatio`、`recordUsage`、`estimateCost`、`estimateTime`、`fetchBalance`、`translateText`、`translateLongText`、`translateParagraphs`
- `supportsThinking = true`（保留 `thinking` 字段）、`maxTokens` 标题 100/全文 131072
- tokenizer 估算、费用/耗时估算、余额查询、自适应校准逻辑留在本类

**`OpenAiCompatService extends BaseLlmService`**：

- 构造读配置：`custom_api_base`、`custom_model`、`custom_api_key`
- `supportsThinking = false`（不发送 `thinking` 字段，避免非 DeepSeek 模型 400）
- `maxTokens` 用保守值 8192（DeepSeek 的 131072 其他模型不支持）
- `estimateTokens` 降级为字符 × 0.68（无 tokenizer）
- 无 `fetchBalance`、`estimateCost` 等 DeepSeek 专属能力
- `estimateTime` 用基础速度常量（无校准数据）

**工厂**：

- 新增 `getLlmService()`：按 TranslationStorage `llm_provider` 配置返回对应单例（deepseek → DeepSeekService，custom → OpenAiCompatService）
- 调用方迁移：`TranslationController`、`NovelCard` 改用 `getLlmService()`
- `getDeepSeekService()` 保留，设置页余额/校准继续使用

### 2. 配置存储（TranslationStorage 扩展）

| 键 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `llm_provider` | string | `'deepseek'` | `'deepseek'` / `'custom'` |
| `custom_api_base` | string | `''` | 自定义 API 地址（OpenAI 兼容） |
| `custom_api_key` | string | `''` | 自定义 key（AES-GCM 加密，与 DeepSeek key 分开） |
| `custom_model` | string | `''` | 模型名称 |
| `title_prompt` | string | `''` | 自定义标题 prompt（空 = 默认模板） |
| `full_prompt` | string | `''` | 自定义全文 prompt（空 = 默认模板） |
| `unified_prompt` | boolean | `false` | 统一 prompt 开关（开启后标题/全文共用 title_prompt） |

- 新增方法：`saveLlmProvider/getLlmProvider`、`saveCustomApiBase/getCustomApiBase`、`saveCustomApiKey/getCustomApiKey/clearCustomApiKey`、`saveCustomModel/getCustomModel`、`saveTitlePrompt/getTitlePrompt`、`saveFullPrompt/getFullPrompt`、`saveUnifiedPrompt/getUnifiedPrompt`
- AppStorage 新增 `llmProvider`；`EntryAbility` 启动恢复 provider + 自定义配置 + 对应 key

### 3. 设置页 UI（TranslationSettingsSection + ViewModel）

1. 顶部「翻译服务」选择：DeepSeek / 自定义模型（Radio 或 Select）
2. DeepSeek 模式：现有 UI 不动（key 输入、验证、余额、校准比例）
3. 自定义模式：
   - API 地址输入（placeholder：OpenAI 兼容格式示例 `https://api.openai.com/v1/chat/completions`）
   - 模型名称输入
   - API Key 输入（密码模式，独立存储，可显示/隐藏/清除）
   - 隐藏余额查询、校准比例卡片
4. 新增「翻译提示词」卡片（两种模式共用）：
   - 标题 prompt / 全文 prompt 两个多行 TextArea
   - 「统一 prompt」开关：开启后仅显示一个输入框（编辑 title_prompt，full_prompt 忽略）
   - 「恢复默认」按钮：清空 title_prompt/full_prompt 回到内置模板（带确认框）

### 4. 行为变更

- `TranslationController.prepareFullTranslation`：自定义模式下 estimateInfo 不含 token/费用/校准比行（仅字符数 + 耗时估计）
- 错误文案统一：「请先在设置中填入 DeepSeek API 密钥」→「请先在设置中配置翻译 API 密钥」（TranslationController 2 处、NovelCard 1 处、DeepSeekService 1 处）
- `getDeepSeekService()` 工厂内从 AppStorage 读 key 的逻辑不变，DeepSeek 模式行为完全不变

## 测试计划

| 文件 | 内容 |
|---|---|
| 新增 `LlmProvider.test.ets` | BaseLlmService：prompt 构建（默认/自定义/统一开关）、请求体构建（自定义模式无 thinking 字段） |
| 新增 `OpenAiCompatService.test.ets` | 配置加载、估算降级（字符×0.68）、无费用估算、hasValidKey |
| 更新 `DeepSeekService.test.ets` | 继承基类后现有测试全部通过；补自定义 prompt 断言 |
| 更新 `TranslationStorage.test.ets` | 新键读写接口校验 |
| 更新 `List.test.ets` | 注册新增测试 |

## 涉及文件

新增：
- `entry/src/main/ets/services/LlmProvider.ets`
- `entry/src/main/ets/services/OpenAiCompatService.ets`
- `entry/src/test/LlmProvider.test.ets`
- `entry/src/test/OpenAiCompatService.test.ets`

修改：
- `entry/src/main/ets/services/DeepSeekService.ets`
- `entry/src/main/ets/common/utils/TranslationStorage.ets`
- `entry/src/main/ets/services/TranslationController.ets`
- `entry/src/main/ets/components/NovelCard.ets`
- `entry/src/main/ets/pages/settings/TranslationSettingsSection.ets`
- `entry/src/main/ets/viewmodel/TranslationSettingsViewModel.ets`
- `entry/src/main/ets/entryability/EntryAbility.ets`
- `entry/src/main/ets/common/constants/StorageKeys.ets`
- `entry/src/test/DeepSeekService.test.ets`
- `entry/src/test/TranslationStorage.test.ets`
- `entry/src/test/List.test.ets`
- `FEATURES.md`

## 不做的事（YAGNI）

- 不做自定义 temperature/max_tokens 配置（固定保守值）
- 不做多提供商并存同时可用（只支持单一切换）
- 不做术语表/词典替换（用户明确需求为自定义 prompt）
- 不做自定义模型余额/配额查询（无通用标准）
