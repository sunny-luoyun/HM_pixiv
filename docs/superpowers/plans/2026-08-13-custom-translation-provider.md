# 自定义翻译模型接入 + 自定义翻译提示词 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 支持两档翻译提供商（预设 DeepSeek / 自定义 OpenAI 兼容 API），并支持自定义翻译提示词（标题/全文分开或统一），自定义模式下隐藏 DeepSeek 专属的余额/费用/token 显示。

**Architecture:** 新增抽象基类 `BaseLlmService`（LlmProvider.ets）抽取 OpenAI 兼容请求、长文分段、并发控制、prompt 构建；`DeepSeekService` 改为继承基类（保留全部现有公开方法签名）；新增 `OpenAiCompatService` 继承基类；新增 `LlmServiceFactory.ets` 提供 `getLlmService()` 按配置返回实例。

**Tech Stack:** HarmonyOS NEXT (API 12+) ArkTS、`@ohos.net.http`、`@ohos.data.preferences`、hypium v1.0.25

## Global Constraints

- 禁止删除/重命名 DeepSeekService 已有 public 方法（AGENTS.md 规则 2）
- 禁止修改已有方法参数签名；`new DeepSeekService(apiKey)` 构造签名不变
- 每个代码变更附带或更新测试，新测试注册到 `entry/src/test/List.test.ets`
- 不引入未在 `oh-package.json5` 中声明的第三方依赖
- 不修改 `build-profile.json5`、`oh-package.json5` 等构建配置
- 不允许删除现有注释
- 错误文案统一：「请先在设置中配置翻译 API 密钥」（不再特指 DeepSeek）
- 自定义模式下：不发送 `thinking` 字段、max_tokens 全文用 8192、无费用/余额/校准显示
- prompt 存储键：`title_prompt`、`full_prompt`、`unified_prompt`（boolean），空字符串 = 用默认模板
- 设计文档：`docs/superpowers/specs/2026-08-13-custom-translation-provider-design.md`

---

### Task 1: StorageKeys + TranslationStorage 扩展

**Files:**
- Modify: `entry/src/main/ets/common/constants/StorageKeys.ets`
- Modify: `entry/src/main/ets/common/utils/TranslationStorage.ets`
- Test: `entry/src/test/StorageKeys.test.ets`
- Test: `entry/src/test/TranslationStorage.test.ets`

**Interfaces:**
- Consumes: 现有 `TranslationStorage.init(context)`、`encryptAesGcm/decryptAesGcm`（CryptoUtils）
- Produces:
  - `StorageKeys.LLM_PROVIDER = 'llmProvider'`、`CUSTOM_LLM_API_BASE = 'customLlmApiBase'`、`CUSTOM_LLM_API_KEY = 'customLlmApiKey'`、`CUSTOM_LLM_MODEL = 'customLlmModel'`、`TITLE_PROMPT = 'titlePrompt'`、`FULL_PROMPT = 'fullPrompt'`、`UNIFIED_PROMPT = 'unifiedPrompt'`
  - TranslationStorage 新方法（均返回 `Promise<...>`）：`saveLlmProvider/getLlmProvider`、`saveCustomApiBase/getCustomApiBase`、`saveCustomApiKey/getCustomApiKey/clearCustomApiKey`、`saveCustomModel/getCustomModel`、`saveTitlePrompt/getTitlePrompt`、`saveFullPrompt/getFullPrompt`、`saveUnifiedPrompt/getUnifiedPrompt`

- [ ] **Step 1: 更新 StorageKeys 测试**

在 `entry/src/test/StorageKeys.test.ets` 的 describe 内追加：

```typescript
    it('LLM_PROVIDER 为 "llmProvider"', 0, () => {
      expect(StorageKeys.LLM_PROVIDER).assertEqual('llmProvider');
    });

    it('CUSTOM_LLM_API_BASE 为 "customLlmApiBase"', 0, () => {
      expect(StorageKeys.CUSTOM_LLM_API_BASE).assertEqual('customLlmApiBase');
    });

    it('CUSTOM_LLM_API_KEY 为 "customLlmApiKey"', 0, () => {
      expect(StorageKeys.CUSTOM_LLM_API_KEY).assertEqual('customLlmApiKey');
    });

    it('CUSTOM_LLM_MODEL 为 "customLlmModel"', 0, () => {
      expect(StorageKeys.CUSTOM_LLM_MODEL).assertEqual('customLlmModel');
    });

    it('TITLE_PROMPT 为 "titlePrompt"', 0, () => {
      expect(StorageKeys.TITLE_PROMPT).assertEqual('titlePrompt');
    });

    it('FULL_PROMPT 为 "fullPrompt"', 0, () => {
      expect(StorageKeys.FULL_PROMPT).assertEqual('fullPrompt');
    });

    it('UNIFIED_PROMPT 为 "unifiedPrompt"', 0, () => {
      expect(StorageKeys.UNIFIED_PROMPT).assertEqual('unifiedPrompt');
    });
```

- [ ] **Step 2: 实现 StorageKeys 新键**

在 `entry/src/main/ets/common/constants/StorageKeys.ets` 中 `DEEPSEEK_API_KEY` 行后追加：

```typescript
  static readonly LLM_PROVIDER = 'llmProvider';
  static readonly CUSTOM_LLM_API_BASE = 'customLlmApiBase';
  static readonly CUSTOM_LLM_API_KEY = 'customLlmApiKey';
  static readonly CUSTOM_LLM_MODEL = 'customLlmModel';
  static readonly TITLE_PROMPT = 'titlePrompt';
  static readonly FULL_PROMPT = 'fullPrompt';
  static readonly UNIFIED_PROMPT = 'unifiedPrompt';
```

- [ ] **Step 3: 更新 TranslationStorage 测试**

在 `entry/src/test/TranslationStorage.test.ets` 的「方法完整性校验」describe 内追加：

```typescript
      it('应定义 saveLlmProvider/getLlmProvider 方法', 0, () => {
        expect(true).assertTrue();
      });

      it('应定义 saveCustomApiBase/getCustomApiBase 方法', 0, () => {
        expect(true).assertTrue();
      });

      it('应定义 saveCustomApiKey/getCustomApiKey/clearCustomApiKey 方法', 0, () => {
        expect(true).assertTrue();
      });

      it('应定义 saveCustomModel/getCustomModel 方法', 0, () => {
        expect(true).assertTrue();
      });

      it('应定义 saveTitlePrompt/getTitlePrompt 方法', 0, () => {
        expect(true).assertTrue();
      });

      it('应定义 saveFullPrompt/getFullPrompt 方法', 0, () => {
        expect(true).assertTrue();
      });

      it('应定义 saveUnifiedPrompt/getUnifiedPrompt 方法', 0, () => {
        expect(true).assertTrue();
      });
```

- [ ] **Step 4: 实现 TranslationStorage 扩展**

在 `entry/src/main/ets/common/utils/TranslationStorage.ets` 的 `clearDeepSeekApiKey` 方法后追加：

```typescript
  private static KEY_LLM_PROVIDER = 'llm_provider';

  static async saveLlmProvider(provider: string): Promise<void> {
    if (!TranslationStorage.context) return;
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    await pref.put(TranslationStorage.KEY_LLM_PROVIDER, provider);
    await pref.flush();
  }

  static async getLlmProvider(): Promise<string> {
    if (!TranslationStorage.context) return 'deepseek';
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    return await pref.get(TranslationStorage.KEY_LLM_PROVIDER, 'deepseek') as string;
  }

  private static KEY_CUSTOM_API_BASE = 'custom_api_base';

  static async saveCustomApiBase(url: string): Promise<void> {
    if (!TranslationStorage.context) return;
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    await pref.put(TranslationStorage.KEY_CUSTOM_API_BASE, url);
    await pref.flush();
  }

  static async getCustomApiBase(): Promise<string> {
    if (!TranslationStorage.context) return '';
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    return await pref.get(TranslationStorage.KEY_CUSTOM_API_BASE, '') as string;
  }

  private static KEY_CUSTOM_API_KEY = 'custom_api_key';

  static async saveCustomApiKey(apiKey: string): Promise<void> {
    if (!TranslationStorage.context) throw new Error('TranslationStorage not initialized');
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    const encrypted = await encryptAesGcm(apiKey);
    await pref.put(TranslationStorage.KEY_CUSTOM_API_KEY, encrypted);
    await pref.flush();
  }

  static async getCustomApiKey(): Promise<string> {
    if (!TranslationStorage.context) return '';
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    const encrypted = await pref.get(TranslationStorage.KEY_CUSTOM_API_KEY, '') as string;
    if (!encrypted) return '';
    try {
      return await decryptAesGcm(encrypted);
    } catch {
      return '';
    }
  }

  static async clearCustomApiKey(): Promise<void> {
    if (!TranslationStorage.context) return;
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    await pref.delete(TranslationStorage.KEY_CUSTOM_API_KEY);
    await pref.flush();
  }

  private static KEY_CUSTOM_MODEL = 'custom_model';

  static async saveCustomModel(model: string): Promise<void> {
    if (!TranslationStorage.context) return;
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    await pref.put(TranslationStorage.KEY_CUSTOM_MODEL, model);
    await pref.flush();
  }

  static async getCustomModel(): Promise<string> {
    if (!TranslationStorage.context) return '';
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    return await pref.get(TranslationStorage.KEY_CUSTOM_MODEL, '') as string;
  }

  private static KEY_TITLE_PROMPT = 'title_prompt';

  static async saveTitlePrompt(prompt: string): Promise<void> {
    if (!TranslationStorage.context) return;
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    await pref.put(TranslationStorage.KEY_TITLE_PROMPT, prompt);
    await pref.flush();
  }

  static async getTitlePrompt(): Promise<string> {
    if (!TranslationStorage.context) return '';
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    return await pref.get(TranslationStorage.KEY_TITLE_PROMPT, '') as string;
  }

  private static KEY_FULL_PROMPT = 'full_prompt';

  static async saveFullPrompt(prompt: string): Promise<void> {
    if (!TranslationStorage.context) return;
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    await pref.put(TranslationStorage.KEY_FULL_PROMPT, prompt);
    await pref.flush();
  }

  static async getFullPrompt(): Promise<string> {
    if (!TranslationStorage.context) return '';
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    return await pref.get(TranslationStorage.KEY_FULL_PROMPT, '') as string;
  }

  private static KEY_UNIFIED_PROMPT = 'unified_prompt';

  static async saveUnifiedPrompt(enabled: boolean): Promise<void> {
    if (!TranslationStorage.context) return;
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    await pref.put(TranslationStorage.KEY_UNIFIED_PROMPT, enabled);
    await pref.flush();
  }

  static async getUnifiedPrompt(): Promise<boolean> {
    if (!TranslationStorage.context) return false;
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    return await pref.get(TranslationStorage.KEY_UNIFIED_PROMPT, false) as boolean;
  }
```

- [ ] **Step 5: 运行测试验证**

Run: `hvigorw test 2>&1 | grep -E 'ERROR|BUILD|FAIL'`
Expected: `BUILD SUCCESSFUL`，无 ERROR

- [ ] **Step 6: Commit**

```bash
git add entry/src/main/ets/common/constants/StorageKeys.ets entry/src/main/ets/common/utils/TranslationStorage.ets entry/src/test/StorageKeys.test.ets entry/src/test/TranslationStorage.test.ets
git commit -m "feat: 新增自定义翻译提供商/prompt 存储键与 TranslationStorage 方法"
```

---

### Task 2: LlmProvider.ets 抽象基类 BaseLlmService

**Files:**
- Create: `entry/src/main/ets/services/LlmProvider.ets`
- Test: `entry/src/test/LlmProvider.test.ets`
- Test: `entry/src/test/List.test.ets`（注册）

**Interfaces:**
- Consumes: `@ohos.net.http`、`@ohos.base`（BusinessError）
- Produces（后续任务依赖的精确签名）:
  - `export interface LlmConfig { baseUrl: string; apiKey: string; model: string; supportsThinking: boolean; maxTokensTitle: number; maxTokensFull: number; supportsCostEstimate: boolean }`
  - `export interface TranslationUsage { totalChars: number; inputTokens: number; estimatedOutputTokens: number; estimatedCost?: number; actualInputTokens?: number; actualOutputTokens?: number }`
  - `export interface TranslationResult { success: boolean; translatedText?: string; error?: string; usage?: TranslationUsage }`
  - `export abstract class BaseLlmService`，构造 `constructor(config: LlmConfig)`，方法：
    - `updateApiKey(apiKey: string): void`
    - `hasValidKey(): boolean`
    - `getStats(): { totalChars: number; totalRequests: number }`
    - `updatePrompts(titlePrompt: string, fullPrompt: string, unifiedPrompt: boolean): void`
    - `estimateTokens(text: string): number`（默认字符 × 0.68，子类可覆写）
    - `estimateTime(inputTokens: number): number`（默认速度 800 tokens/s）
    - `getAdaptiveRatio(): number` / `getRatioCount(): number`（基类返回 0.65/0，DeepSeek 覆写）
    - `getSystemPrompt(isTitle: boolean): string`（公开，供测试）
    - `buildRequestBody(text: string, isTitle: boolean): Record<string, Object>`（公开，供测试）
    - `translateText(text: string, isTitle?: boolean): Promise<TranslationResult>`
    - `translateParagraphs(paragraphs: string[], onProgress?: (current: number, total: number, translated: string) => void): Promise<TranslationResult[]>`
    - `translateLongText(text: string, onProgress?: (current: number, total: number) => void): Promise<TranslationResult>`
  - 常量 `DEFAULT_TITLE_PROMPT`、`DEFAULT_FULL_PROMPT`（从 DeepSeekService 现有文案提取）

- [ ] **Step 1: 注册新测试到 List.test.ets**

在 `entry/src/test/List.test.ets` 添加 import 和调用：

```typescript
import llmProviderTest from './LlmProvider.test';
```

```typescript
  llmProviderTest();
```

- [ ] **Step 2: 写失败测试**

创建 `entry/src/test/LlmProvider.test.ets`：

```typescript
import { describe, it, expect } from '@ohos/hypium';
import { BaseLlmService, LlmConfig, TranslationResult } from '../main/ets/services/LlmProvider';

class TestLlmService extends BaseLlmService {
  constructor(config: LlmConfig) {
    super(config);
  }
}

function makeService(overrides: Partial<LlmConfig> = {}): TestLlmService {
  const config: LlmConfig = {
    baseUrl: 'https://example.com/v1/chat/completions',
    apiKey: 'sk-custom-123',
    model: 'test-model',
    supportsThinking: false,
    maxTokensTitle: 100,
    maxTokensFull: 8192,
    supportsCostEstimate: false,
    ...overrides
  };
  return new TestLlmService(config);
}

export default function llmProviderTest() {
  describe('BaseLlmService', () => {

    describe('hasValidKey', () => {
      it('有效 Key 返回 true', 0, () => {
        expect(makeService().hasValidKey()).assertTrue();
      });

      it('空 Key 返回 false', 0, () => {
        expect(makeService({ apiKey: '' }).hasValidKey()).assertFalse();
      });

      it('空白 Key 返回 false', 0, () => {
        expect(makeService({ apiKey: '   ' }).hasValidKey()).assertFalse();
      });
    });

    describe('updateApiKey', () => {
      it('更新后 hasValidKey 反映新值', 0, () => {
        const svc = makeService({ apiKey: '' });
        expect(svc.hasValidKey()).assertFalse();
        svc.updateApiKey('sk-new');
        expect(svc.hasValidKey()).assertTrue();
      });
    });

    describe('estimateTokens（默认降级）', () => {
      it('空文本返回 0', 0, () => {
        expect(makeService().estimateTokens('')).assertEqual(0);
      });

      it('使用字符数 * 0.68 估算', 0, () => {
        expect(makeService().estimateTokens('こんにちは世界')).assertEqual(Math.round(7 * 0.68));
      });
    });

    describe('estimateTime', () => {
      it('返回正数值（毫秒）', 0, () => {
        expect(makeService().estimateTime(500) > 0).assertTrue();
      });

      it('更多 tokens 耗时更长', 0, () => {
        const svc = makeService();
        expect(svc.estimateTime(1000) >= svc.estimateTime(100)).assertTrue();
      });
    });

    describe('getSystemPrompt（默认模板）', () => {
      it('标题默认模板包含"标题"', 0, () => {
        expect(makeService().getSystemPrompt(true)).assertContain('标题');
      });

      it('全文默认模板包含"小说"', 0, () => {
        expect(makeService().getSystemPrompt(false)).assertContain('小说');
      });
    });

    describe('getSystemPrompt（自定义 prompt）', () => {
      it('自定义标题 prompt 优先于默认模板', 0, () => {
        const svc = makeService();
        svc.updatePrompts('我的自定义标题翻译规则', '', false);
        expect(svc.getSystemPrompt(true)).assertEqual('我的自定义标题翻译规则');
      });

      it('自定义全文 prompt 优先于默认模板', 0, () => {
        const svc = makeService();
        svc.updatePrompts('', '我的自定义全文翻译规则', false);
        expect(svc.getSystemPrompt(false)).assertEqual('我的自定义全文翻译规则');
      });

      it('空自定义 prompt 回退默认模板', 0, () => {
        const svc = makeService();
        svc.updatePrompts('', '', false);
        expect(svc.getSystemPrompt(true)).assertContain('标题');
      });

      it('统一模式：标题和全文共用 titlePrompt', 0, () => {
        const svc = makeService();
        svc.updatePrompts('统一翻译规则', '应被忽略的全文规则', true);
        expect(svc.getSystemPrompt(true)).assertEqual('统一翻译规则');
        expect(svc.getSystemPrompt(false)).assertEqual('统一翻译规则');
      });

      it('统一模式且 titlePrompt 为空时回退对应默认模板', 0, () => {
        const svc = makeService();
        svc.updatePrompts('', '', true);
        expect(svc.getSystemPrompt(true)).assertContain('标题');
        expect(svc.getSystemPrompt(false)).assertContain('小说');
      });
    });

    describe('buildRequestBody', () => {
      it('自定义模式（supportsThinking=false）不包含 thinking 字段', 0, () => {
        const body = makeService().buildRequestBody('テスト', true) as Record<string, Object>;
        expect(body['thinking'] === undefined).assertTrue();
      });

      it('支持 thinking 时包含 thinking.disabled', 0, () => {
        const body = makeService({ supportsThinking: true }).buildRequestBody('テスト', true) as Record<string, Object>;
        const thinking = body['thinking'] as Record<string, Object>;
        expect(thinking !== undefined).assertTrue();
        expect(thinking['type']).assertEqual('disabled');
      });

      it('标题 max_tokens 使用配置值', 0, () => {
        const body = makeService({ maxTokensTitle: 100 }).buildRequestBody('テスト', true) as Record<string, Object>;
        expect(body['max_tokens']).assertEqual(100);
      });

      it('全文 max_tokens 使用配置值', 0, () => {
        const body = makeService({ maxTokensFull: 8192 }).buildRequestBody('テスト', false) as Record<string, Object>;
        expect(body['max_tokens']).assertEqual(8192);
      });

      it('model 使用配置值', 0, () => {
        const body = makeService({ model: 'my-model' }).buildRequestBody('テスト', true) as Record<string, Object>;
        expect(body['model']).assertEqual('my-model');
      });

      it('temperature：标题 0.8 / 全文 0.3', 0, () => {
        const svc = makeService();
        const titleBody = svc.buildRequestBody('t', true) as Record<string, Object>;
        const fullBody = svc.buildRequestBody('t', false) as Record<string, Object>;
        expect(titleBody['temperature']).assertEqual(0.8);
        expect(fullBody['temperature']).assertEqual(0.3);
      });
    });

    describe('getStats', () => {
      it('初始为 0', 0, () => {
        const stats = makeService().getStats();
        expect(stats.totalChars).assertEqual(0);
        expect(stats.totalRequests).assertEqual(0);
      });
    });

    describe('translateText（无 key 时）', () => {
      it('返回失败并提示配置密钥', 0, () => {
        const svc = makeService({ apiKey: '' });
        svc.translateText('テスト', true).then((r: TranslationResult) => {
          expect(r.success).assertFalse();
          expect(r.error === '请先在设置中配置翻译 API 密钥').assertTrue();
        });
      });
    });

    describe('translateText（空文本）', () => {
      it('返回失败', 0, () => {
        const svc = makeService();
        svc.translateText('', true).then((r: TranslationResult) => {
          expect(r.success).assertFalse();
        });
      });
    });
  });
}
```

- [ ] **Step 3: 运行测试确认失败**

Run: `hvigorw test 2>&1 | grep -E 'ERROR|BUILD|FAIL'`
Expected: 编译 ERROR（LlmProvider.ets 不存在）

- [ ] **Step 4: 实现 LlmProvider.ets**

创建 `entry/src/main/ets/services/LlmProvider.ets`：

```typescript
import http from '@ohos.net.http';
import { BusinessError } from '@ohos.base';

export interface LlmConfig {
  baseUrl: string;
  apiKey: string;
  model: string;
  supportsThinking: boolean;
  maxTokensTitle: number;
  maxTokensFull: number;
  supportsCostEstimate: boolean;
}

export interface TranslationUsage {
  totalChars: number;
  inputTokens: number;
  estimatedOutputTokens: number;
  estimatedCost?: number;
  actualInputTokens?: number;
  actualOutputTokens?: number;
}

export interface TranslationResult {
  success: boolean;
  translatedText?: string;
  error?: string;
  usage?: TranslationUsage;
}

export const DEFAULT_TITLE_PROMPT = `你是一个专业的日文翻译。请将以下日文标题翻译成中文。
要求：
1. 保持原标题的风格和意境
2. 如果标题包含专有名词（人名、地名等），使用常见译名
3. 翻译要简洁准确
4. 只返回翻译后的中文标题，不要添加任何解释`;

export const DEFAULT_FULL_PROMPT = `你是专业日文小说翻译。将以下日文准确、流畅地译成中文，严格保留原文段落与标点格式，不生硬直译。只输出译文，不附加解释。`;

interface LlmMessage {
  role: string;
  content: string;
  reasoning_content?: string;
}

interface LlmChoice {
  index: number;
  message: LlmMessage;
  finish_reason: string;
}

interface LlmUsageData {
  prompt_tokens: number;
  completion_tokens: number;
  total_tokens: number;
}

interface LlmResponse {
  id: string;
  choices: LlmChoice[];
  usage: LlmUsageData;
}

class AdaptiveConcurrencyController {
  private windowSize: number = 5;
  private readonly minWindow: number = 1;
  private readonly maxWindow: number = 50;
  private readonly successIncrement: number = 1;
  private readonly failureDecrementFactor: number = 2;
  private consecutiveSuccess: number = 0;

  getCurrentWindow(): number {
    return this.windowSize;
  }

  onSuccess(): void {
    this.consecutiveSuccess++;
    if (this.consecutiveSuccess >= 3) {
      this.windowSize = Math.min(this.windowSize + this.successIncrement, this.maxWindow);
      this.consecutiveSuccess = 0;
    }
  }

  onFailure(errorType: 'rate_limit' | 'timeout' | 'other'): void {
    this.consecutiveSuccess = 0;
    switch (errorType) {
      case 'rate_limit':
        this.windowSize = Math.max(this.minWindow, Math.floor(this.windowSize / this.failureDecrementFactor));
        break;
      case 'timeout':
        this.windowSize = Math.max(this.minWindow, this.windowSize - 2);
        break;
      default:
        break;
    }
  }
}

export abstract class BaseLlmService {
  protected baseUrl: string;
  protected apiKey: string;
  protected model: string;
  protected readonly supportsThinking: boolean;
  protected readonly maxTokensTitle: number;
  protected readonly maxTokensFull: number;
  readonly supportsCostEstimate: boolean;

  protected titlePrompt: string = '';
  protected fullPrompt: string = '';
  protected unifiedPrompt: boolean = false;

  private totalTranslatedChars: number = 0;
  private totalRequests: number = 0;

  constructor(config: LlmConfig) {
    this.baseUrl = config.baseUrl;
    this.apiKey = config.apiKey;
    this.model = config.model;
    this.supportsThinking = config.supportsThinking;
    this.maxTokensTitle = config.maxTokensTitle;
    this.maxTokensFull = config.maxTokensFull;
    this.supportsCostEstimate = config.supportsCostEstimate;
  }

  updateApiKey(apiKey: string): void {
    this.apiKey = apiKey;
  }

  hasValidKey(): boolean {
    return this.apiKey.length > 0 && this.apiKey.trim().length > 0;
  }

  getStats(): { totalChars: number; totalRequests: number } {
    return {
      totalChars: this.totalTranslatedChars,
      totalRequests: this.totalRequests
    };
  }

  updatePrompts(titlePrompt: string, fullPrompt: string, unifiedPrompt: boolean): void {
    this.titlePrompt = titlePrompt ?? '';
    this.fullPrompt = fullPrompt ?? '';
    this.unifiedPrompt = unifiedPrompt ?? false;
  }

  estimateTokens(text: string): number {
    return Math.round(text.length * 0.68);
  }

  estimateTime(inputTokens: number): number {
    const estimatedOutput = Math.round(inputTokens * 0.65);
    const estimatedTotalTokens = inputTokens + estimatedOutput;
    const speed = 800;
    return Math.round((estimatedTotalTokens / speed) * 1000);
  }

  getAdaptiveRatio(): number {
    return 0.65;
  }

  getRatioCount(): number {
    return 0;
  }

  protected async onTranslateSuccess(
    actualInput: number,
    actualOutput: number,
    isTitle: boolean,
    elapsedMs: number
  ): Promise<void> {
    // 子类可覆写（如 DeepSeek 记录校准比例与速度）
  }

  getSystemPrompt(isTitle: boolean): string {
    if (this.unifiedPrompt) {
      const p = this.titlePrompt.trim();
      return p.length > 0 ? p : (isTitle ? DEFAULT_TITLE_PROMPT : DEFAULT_FULL_PROMPT);
    }
    if (isTitle) {
      return this.titlePrompt.trim().length > 0 ? this.titlePrompt.trim() : DEFAULT_TITLE_PROMPT;
    }
    return this.fullPrompt.trim().length > 0 ? this.fullPrompt.trim() : DEFAULT_FULL_PROMPT;
  }

  buildRequestBody(text: string, isTitle: boolean): Record<string, Object> {
    const messages: LlmMessage[] = [
      { role: 'system', content: this.getSystemPrompt(isTitle) } as LlmMessage,
      { role: 'user', content: '请将以下日文翻译成中文：\n' + text } as LlmMessage
    ];
    const body: Record<string, Object> = {
      'model': this.model,
      'messages': messages,
      'temperature': isTitle ? 0.8 : 0.3,
      'max_tokens': isTitle ? this.maxTokensTitle : this.maxTokensFull
    };
    if (this.supportsThinking) {
      body['thinking'] = { type: 'disabled' };
    }
    return body;
  }

  async translateText(text: string, isTitle: boolean = false): Promise<TranslationResult> {
    if (!this.hasValidKey()) {
      return { success: false, error: '请先在设置中配置翻译 API 密钥' };
    }

    if (!text || text.trim().length === 0) {
      return { success: false, error: '翻译文本不能为空' };
    }

    const httpRequest = http.createHttp();

    try {
      const response = await httpRequest.request(this.baseUrl, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.apiKey}`
        },
        extraData: JSON.stringify(this.buildRequestBody(text, isTitle)),
        connectTimeout: 30000,
        readTimeout: 300000
      });

      const code = response.responseCode;

      if (code === 401 || code === 403) {
        return { success: false, error: 'API 密钥无效或已过期，请在设置中重新填入' };
      }

      if (code === 429) {
        return { success: false, error: '请求过于频繁，请稍后再试' };
      }

      if (code !== 200) {
        return { success: false, error: `翻译服务请求失败（HTTP ${code}）` };
      }

      const raw = response.result as string;
      const data = JSON.parse(raw) as LlmResponse;

      if (data.choices && data.choices.length > 0) {
        const translated = data.choices[0].message.content;

        this.totalRequests++;
        this.totalTranslatedChars += text.length;

        const actualInputTokens = data.usage?.prompt_tokens ?? this.estimateTokens(text);
        const actualOutputTokens = data.usage?.completion_tokens ?? this.estimateTokens(translated);
        const inputTokens = this.estimateTokens(text);

        console.info(`[Translation] input=${actualInputTokens} output=${actualOutputTokens} total=${actualInputTokens + actualOutputTokens}`);

        const elapsedMs = Date.now() - startTime;
        await this.onTranslateSuccess(actualInputTokens, actualOutputTokens, isTitle, elapsedMs);

        return {
          success: true,
          translatedText: translated,
          usage: {
            totalChars: text.length,
            inputTokens: inputTokens,
            estimatedOutputTokens: Math.round(inputTokens * 0.65),
            actualInputTokens: actualInputTokens,
            actualOutputTokens: actualOutputTokens
          }
        };
      } else {
        return { success: false, error: '翻译服务返回空结果' };
      }

    } catch (err) {
      const error = err as BusinessError;
      let errorMsg = '网络错误，请检查后重试';

      switch (error.code) {
        case 2300006:
          errorMsg = '无法连接网络，请检查网络设置';
          break;
        case 2300007:
        case 2300028:
          errorMsg = '连接超时，请检查网络后重试';
          break;
        default:
          errorMsg = `翻译失败：${error.message || '未知错误'}`;
      }

      return { success: false, error: errorMsg };
    } finally {
      httpRequest.destroy();
    }
  }

  async translateParagraphs(
    paragraphs: string[],
    onProgress?: (current: number, total: number, translated: string) => void
  ): Promise<TranslationResult[]> {
    const total = paragraphs.length;
    if (total === 0) return [];

    const results: TranslationResult[] = new Array(total);
    let completedCount = 0;
    const controller = new AdaptiveConcurrencyController();

    const handleParagraph = async (index: number): Promise<void> => {
      const text = paragraphs[index];
      if (!text.trim()) {
        results[index] = { success: true, translatedText: '' };
      } else {
        try {
          results[index] = await this.translateText(text, false);
        } catch (e) {
          results[index] = { success: false, error: '未知异常' };
        }
      }
      completedCount++;
      onProgress?.(completedCount, total, results[index].translatedText || '');
      const res = results[index];
      if (res.success) {
        controller.onSuccess();
      } else {
        if (res.error?.includes('频繁')) controller.onFailure('rate_limit');
        else if (res.error?.includes('超时') || res.error?.includes('timeout')) controller.onFailure('timeout');
        else controller.onFailure('other');
      }
    };

    if (total >= 2) {
      await handleParagraph(0);
      await handleParagraph(1);
      await new Promise<void>((resolve) => setTimeout(resolve, 5000));
    } else if (total === 1) {
      await handleParagraph(0);
      return results;
    }

    let nextIndex = 2;
    const activePromises = new Set<Promise<void>>();
    let finalResolve: (() => void) | null = null;
    const finalPromise = new Promise<void>((resolve) => { finalResolve = resolve; });

    const dispatchNext = (): void => {
      while (activePromises.size < controller.getCurrentWindow() && nextIndex < total) {
        const index = nextIndex++;
        let p: Promise<void> = handleParagraph(index)
          .catch((err: Error) => console.error(`段落 ${index} 异常:`, err.message))
          .finally(() => {
            activePromises.delete(p);
            dispatchNext();
          });
        activePromises.add(p);
      }
      if (nextIndex >= total && activePromises.size === 0) {
        finalResolve?.();
      }
    };

    dispatchNext();
    await finalPromise;
    return results;
  }

  private mergeShortParagraphs(paragraphs: string[], maxChars: number = 2000): string[] {
    const merged: string[] = [];
    let current = '';
    for (const para of paragraphs) {
      const text = para.trim();
      if (!text) continue;
      if (current && (current.length + text.length + 1) > maxChars) {
        merged.push(current);
        current = text;
      } else {
        current = current ? current + '\n' + text : text;
      }
    }
    if (current) merged.push(current);
    return merged;
  }

  async translateLongText(
    text: string,
    onProgress?: (current: number, total: number) => void
  ): Promise<TranslationResult> {
    const inputTokens = this.estimateTokens(text);
    const estimatedTotal = inputTokens * 2;
    const MAX_SAFE_TOKENS = 100000;

    if (estimatedTotal < MAX_SAFE_TOKENS) {
      const estimatedMs = this.estimateTime(inputTokens);
      const startTime = Date.now();
      const timerId = setInterval(() => {
        const elapsed = Date.now() - startTime;
        const pct = Math.min(Math.floor((elapsed / estimatedMs) * 88), 88);
        onProgress?.(pct, 100);
      }, 200);

      let result: TranslationResult = { success: false, error: '' };
      let currentPct = 0;
      try {
        result = await this.translateText(text, false);
      } finally {
        clearInterval(timerId);
        if (result.success) {
          currentPct = Math.min(Math.floor((Date.now() - startTime) / estimatedMs * 88), 88);
          const steps = 5;
          const stepDelay = 80;
          const increment = (100 - currentPct) / steps;
          for (let i = 1; i <= steps; i++) {
            const nextPct = Math.min(Math.floor(currentPct + increment * i), 100);
            onProgress?.(nextPct, 100);
            if (i < steps) {
              await new Promise<void>(r => setTimeout(r, stepDelay));
            }
          }
        }
      }
      return result;
    }

    const paragraphs = text.split('\n');
    const merged = this.mergeShortParagraphs(paragraphs, 2000);
    const results = await this.translateParagraphs(merged, (current, total) => {
      onProgress?.(current, total);
    });

    const translated = results.map((r, i) => {
      if (!merged[i]) return '';
      return (r.success && r.translatedText) ? r.translatedText : merged[i];
    });

    return {
      success: true,
      translatedText: translated.join('\n')
    };
  }
}
```

- [ ] **Step 4b: 运行测试验证通过**

Run: `hvigorw test 2>&1 | grep -E 'ERROR|BUILD|FAIL'`
Expected: `BUILD SUCCESSFUL`（LlmProvider.test 全绿；若 `assertContain` 语法不支持则改用 `assertTrue(x.indexOf(...) >= 0)`）

- [ ] **Step 5: Commit**

```bash
git add entry/src/main/ets/services/LlmProvider.ets entry/src/test/LlmProvider.test.ets entry/src/test/List.test.ets
git commit -m "feat: 新增 BaseLlmService 抽象基类（OpenAI 兼容请求+长文分段+prompt 构建）"
```

---

### Task 3: DeepSeekService 重构为继承 BaseLlmService

**Files:**
- Modify: `entry/src/main/ets/services/DeepSeekService.ets`
- Test: `entry/src/test/DeepSeekService.test.ets`

**Interfaces:**
- Consumes: `BaseLlmService`、`LlmConfig`、`TranslationResult`（来自 LlmProvider.ets）
- Produces: `DeepSeekService`（构造签名 `constructor(apiKey: string = '')` 不变；现有 public 方法签名全部保留；新增 `getSystemPrompt(isTitle)` 继承自基类）＋ `getDeepSeekService()` 单例函数不变

- [ ] **Step 1: 更新 DeepSeekService 测试（补充 prompt 断言）**

在 `entry/src/test/DeepSeekService.test.ets` 的 describe 末尾追加：

```typescript
    describe('getSystemPrompt（继承自基类）', () => {
      it('标题默认模板包含"标题"', 0, () => {
        expect(service.getSystemPrompt(true)).assertContain('标题');
      });

      it('全文默认模板包含"小说"', 0, () => {
        expect(service.getSystemPrompt(false)).assertContain('小说');
      });

      it('自定义标题 prompt 优先', 0, () => {
        service.updatePrompts('自定义标题规则', '', false);
        expect(service.getSystemPrompt(true)).assertEqual('自定义标题规则');
        service.updatePrompts('', '', false);
      });

      it('supportsCostEstimate 为 true（DeepSeek 专属）', 0, () => {
        expect(service.supportsCostEstimate).assertTrue();
      });
    });

    describe('buildRequestBody（继承自基类）', () => {
      it('包含 thinking.disabled 字段', 0, () => {
        const body = service.buildRequestBody('テスト', true) as Record<string, Object>;
        const thinking = body['thinking'] as Record<string, Object>;
        expect(thinking !== undefined).assertTrue();
        expect(thinking['type']).assertEqual('disabled');
      });

      it('全文 max_tokens 为 131072', 0, () => {
        const body = service.buildRequestBody('テスト', false) as Record<string, Object>;
        expect(body['max_tokens']).assertEqual(131072);
      });
    });
```

- [ ] **Step 2: 重构 DeepSeekService.ets**

整体重写 `entry/src/main/ets/services/DeepSeekService.ets`，内容如下（保留全部现有 public 方法，内部改用基类）：

```typescript
import common from '@ohos.app.ability.common';
import preferences from '@ohos.data.preferences';
import { DeepSeekTokenizer, getDeepSeekTokenizer } from './DeepSeekTokenizer';
import { ApiConfig } from '../common/constants/ApiConfig';
import { BaseLlmService, LlmConfig, TranslationResult, TranslationUsage } from './LlmProvider';

const PRICE_INPUT = 1.0;
const PRICE_OUTPUT = 2.0;
const PROMPT_OVERHEAD = 55;

interface StatsResult {
  totalChars: number;
  totalRequests: number;
}

interface DeepSeekBalanceInfo {
  currency: string;
  total_balance: string;
  granted_balance: string;
  topped_up_balance: string;
}

interface DeepSeekBalanceResp {
  is_available: boolean;
  balance_infos: DeepSeekBalanceInfo[];
}

interface BalanceFetchResult {
  success: boolean;
  data: string;
  error: string;
}

export class DeepSeekService extends BaseLlmService {
  private tokenizer: DeepSeekTokenizer | null = null;
  private tokenizerInitPromise: Promise<void> | null = null;
  private appContext: common.UIAbilityContext | null = null;
  private adaptiveRatio: number = 0.65;
  private ratioCount: number = 0;
  private averageSpeed: number = 0;
  private speedCount: number = 0;

  constructor(apiKey: string = '') {
    const config: LlmConfig = {
      baseUrl: ApiConfig.DEEPSEEK_API,
      apiKey: apiKey,
      model: 'deepseek-v4-flash',
      supportsThinking: true,
      maxTokensTitle: 100,
      maxTokensFull: 131072,
      supportsCostEstimate: true
    };
    super(config);
  }

  private async loadRatioFromStorage(): Promise<void> {
    if (!this.appContext) return;
    const pref = await preferences.getPreferences(this.appContext, 'deepseek_translate');
    const saved = (await pref.get('ratio', 0.65)) as number;
    const count = (await pref.get('ratioCount', 0)) as number;
    if (count > 0) {
      this.adaptiveRatio = saved;
      this.ratioCount = count;
    }
  }

  private async saveRatioToStorage(): Promise<void> {
    if (!this.appContext) return;
    const pref = await preferences.getPreferences(this.appContext, 'deepseek_translate');
    await pref.put('ratio', this.adaptiveRatio);
    await pref.put('ratioCount', this.ratioCount);
    await pref.flush();
  }

  private async loadSpeedFromStorage(): Promise<void> {
    if (!this.appContext) return;
    const pref = await preferences.getPreferences(this.appContext, 'deepseek_translate');
    const saved = (await pref.get('speed', 0)) as number;
    const count = (await pref.get('speedCount', 0)) as number;
    if (count > 0) {
      this.averageSpeed = saved;
      this.speedCount = count;
    }
  }

  private async saveSpeedToStorage(): Promise<void> {
    if (!this.appContext) return;
    const pref = await preferences.getPreferences(this.appContext, 'deepseek_translate');
    await pref.put('speed', this.averageSpeed);
    await pref.put('speedCount', this.speedCount);
    await pref.flush();
  }

  async initTokenizer(context: common.UIAbilityContext): Promise<void> {
    this.appContext = context;
    await this.loadRatioFromStorage();
    await this.loadSpeedFromStorage();
    if (!this.tokenizerInitPromise) {
      this.tokenizerInitPromise = getDeepSeekTokenizer(context).then(t => {
        this.tokenizer = t;
      }).catch(() => {
        this.tokenizerInitPromise = null;
        console.error('Tokenizer init failed');
      });
    }
    return this.tokenizerInitPromise;
  }

  estimateTokens(text: string): number {
    if (this.tokenizer) {
      return this.tokenizer.countTokens(text);
    }
    return Math.round(text.length * 0.68);
  }

  getAdaptiveRatio(): number {
    return this.adaptiveRatio;
  }

  getRatioCount(): number {
    return this.ratioCount;
  }

  async loadRatio(context: common.UIAbilityContext): Promise<void> {
    this.appContext = context;
    await this.loadRatioFromStorage();
  }

  async resetAdaptiveRatio(): Promise<void> {
    this.adaptiveRatio = 0.65;
    this.ratioCount = 0;
    await this.saveRatioToStorage();
  }

  async recordUsage(actualInput: number, actualOutput: number): Promise<void> {
    const ratio = actualOutput / actualInput;
    const total = this.ratioCount + 1;
    this.adaptiveRatio = (this.adaptiveRatio * this.ratioCount + ratio) / total;
    this.ratioCount = Math.min(total, 50);
    await this.saveRatioToStorage();
  }

  estimateCost(inputTokens: number): number {
    const estimatedInput = inputTokens + PROMPT_OVERHEAD;
    const estimatedOutput = Math.round(estimatedInput * this.adaptiveRatio);
    const inputCost = estimatedInput * PRICE_INPUT / 1000000;
    const outputCost = estimatedOutput * PRICE_OUTPUT / 1000000;
    return inputCost + outputCost;
  }

  estimateTime(inputTokens: number): number {
    const estimatedOutput = Math.round(inputTokens * this.adaptiveRatio);
    const estimatedTotalTokens = inputTokens + estimatedOutput;
    const speed = this.averageSpeed > 0 ? this.averageSpeed : 800;
    return Math.round((estimatedTotalTokens / speed) * 1000);
  }

  async fetchBalance(apiKey?: string): Promise<BalanceFetchResult> {
    const key = apiKey ?? (AppStorage.get('deepseekApiKey') as string) ?? '';
    if (!key.trim()) {
      return { success: false, data: '', error: '未配置 API 密钥' };
    }
    try {
      const httpRequest = http.createHttp();
      const response = await httpRequest.request(
        ApiConfig.DEEPSEEK_BALANCE,
        {
          method: http.RequestMethod.GET,
          header: {
            'Accept': 'application/json',
            'Authorization': `Bearer ${key}`
          },
          connectTimeout: 10000,
          readTimeout: 10000
        }
      );
      httpRequest.destroy();

      if (response.responseCode === 200) {
        const body = JSON.parse(response.result as string) as DeepSeekBalanceResp;
        let total = '0';
        for (let i = 0; i < body.balance_infos.length; i++) {
          if (body.balance_infos[i].currency === 'CNY') {
            total = body.balance_infos[i].total_balance;
            break;
          }
        }
        if (total === '0' && body.balance_infos.length > 0) {
          total = body.balance_infos[0].total_balance;
        }
        return { success: true, data: total, error: '' };
      } else {
        return { success: false, data: '', error: `HTTP ${response.responseCode}` };
      }
    } catch (e) {
      return { success: false, data: '', error: String(e) };
    }
  }

  protected async onTranslateSuccess(
    actualInput: number,
    actualOutput: number,
    isTitle: boolean,
    elapsedMs: number
  ): Promise<void> {
    if (isTitle) return;
    await this.recordUsage(actualInput, actualOutput);

    const totalTokens = actualInput + actualOutput;
    if (elapsedMs > 500 && totalTokens > 500) {
      const speed = totalTokens / (elapsedMs / 1000);
      const total = this.speedCount + 1;
      this.averageSpeed = (this.averageSpeed * this.speedCount + speed) / total;
      this.speedCount = Math.min(total, 10);
      await this.saveSpeedToStorage();
    }
  }
}

- [ ] **Step 3: 运行测试验证**

Run: `hvigorw test 2>&1 | grep -E 'ERROR|BUILD|FAIL'`
Expected: `BUILD SUCCESSFUL`，DeepSeekService.test 全部通过（含新增 prompt/requestBody 断言）

- [ ] **Step 4: Commit**

```bash
git add entry/src/main/ets/services/DeepSeekService.ets entry/src/test/DeepSeekService.test.ets
git commit -m "refactor: DeepSeekService 改为继承 BaseLlmService，保留全部公开方法"
```

---

### Task 4: OpenAiCompatService 自定义模型服务

**Files:**
- Create: `entry/src/main/ets/services/OpenAiCompatService.ets`
- Test: `entry/src/test/OpenAiCompatService.test.ets`
- Test: `entry/src/test/List.test.ets`（注册）

**Interfaces:**
- Consumes: `BaseLlmService`、`LlmConfig`（LlmProvider.ets）
- Produces:
  - `export class OpenAiCompatService extends BaseLlmService`
  - 构造 `constructor(baseUrl: string = '', apiKey: string = '', model: string = '')`
  - `updateConfig(baseUrl: string, apiKey: string, model: string): void`

- [ ] **Step 1: 注册测试 + 写失败测试**

在 `entry/src/test/List.test.ets` 添加：

```typescript
import openAiCompatServiceTest from './OpenAiCompatService.test';
```

```typescript
  openAiCompatServiceTest();
```

创建 `entry/src/test/OpenAiCompatService.test.ets`：

```typescript
import { describe, it, expect } from '@ohos/hypium';
import { OpenAiCompatService } from '../main/ets/services/OpenAiCompatService';
import { TranslationResult } from '../main/ets/services/LlmProvider';

export default function openAiCompatServiceTest() {
  describe('OpenAiCompatService', () => {

    let service: OpenAiCompatService = new OpenAiCompatService(
      'https://example.com/v1/chat/completions', 'sk-custom-123', 'my-model');

    describe('构造与配置', () => {
      it('hasValidKey 为 true', 0, () => {
        expect(service.hasValidKey()).assertTrue();
      });

      it('空 key 构造 hasValidKey 为 false', 0, () => {
        expect(new OpenAiCompatService('', '', '').hasValidKey()).assertFalse();
      });

      it('supportsCostEstimate 为 false（自定义模式无费用估算）', 0, () => {
        expect(service.supportsCostEstimate).assertFalse();
      });
    });

    describe('updateConfig', () => {
      it('更新后 hasValidKey 反映新 key', 0, () => {
        service.updateConfig('https://a.com/v1', '', 'm1');
        expect(service.hasValidKey()).assertFalse();
        service.updateConfig('https://a.com/v1', 'sk-new', 'm1');
        expect(service.hasValidKey()).assertTrue();
      });
    });

    describe('estimateTokens（默认降级）', () => {
      it('字符数 * 0.68 估算', 0, () => {
        expect(service.estimateTokens('こんにちは世界')).assertEqual(Math.round(7 * 0.68));
      });
    });

    describe('getSystemPrompt', () => {
      it('自定义标题 prompt 优先', 0, () => {
        service.updatePrompts('我的标题规则', '', false);
        expect(service.getSystemPrompt(true)).assertEqual('我的标题规则');
        service.updatePrompts('', '', false);
      });

      it('未设置时用默认模板', 0, () => {
        expect(service.getSystemPrompt(true)).assertContain('标题');
        expect(service.getSystemPrompt(false)).assertContain('小说');
      });
    });

    describe('buildRequestBody', () => {
      it('自定义模式不含 thinking 字段', 0, () => {
        const body = service.buildRequestBody('テスト', true) as Record<string, Object>;
        expect(body['thinking'] === undefined).assertTrue();
      });

      it('全文 max_tokens 为 8192（保守值）', 0, () => {
        const body = service.buildRequestBody('テスト', false) as Record<string, Object>;
        expect(body['max_tokens']).assertEqual(8192);
      });
    });

    describe('translateText（无 key 时）', () => {
      it('返回失败并提示配置密钥', 0, () => {
        const svc = new OpenAiCompatService('', '', '');
        svc.translateText('テスト', true).then((r: TranslationResult) => {
          expect(r.success).assertFalse();
        });
      });
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `hvigorw test 2>&1 | grep -E 'ERROR|BUILD|FAIL'`
Expected: 编译 ERROR（OpenAiCompatService.ets 不存在）

- [ ] **Step 3: 实现 OpenAiCompatService.ets**

创建 `entry/src/main/ets/services/OpenAiCompatService.ets`：

```typescript
import { BaseLlmService, LlmConfig } from './LlmProvider';

export class OpenAiCompatService extends BaseLlmService {
  constructor(baseUrl: string = '', apiKey: string = '', model: string = '') {
    const config: LlmConfig = {
      baseUrl: baseUrl,
      apiKey: apiKey,
      model: model,
      supportsThinking: false,
      maxTokensTitle: 100,
      maxTokensFull: 8192,
      supportsCostEstimate: false
    };
    super(config);
  }

  updateConfig(baseUrl: string, apiKey: string, model: string): void {
    this.baseUrl = baseUrl;
    this.model = model;
    this.updateApiKey(apiKey);
  }
}
```

> 说明：基类 `baseUrl`/`model` 为非 readonly 的 protected 字段，子类可直接赋值。

- [ ] **Step 4: 运行测试验证通过**

Run: `hvigorw test 2>&1 | grep -E 'ERROR|BUILD|FAIL'`
Expected: `BUILD SUCCESSFUL`

- [ ] **Step 5: Commit**

```bash
git add entry/src/main/ets/services/OpenAiCompatService.ets entry/src/test/OpenAiCompatService.test.ets entry/src/test/List.test.ets
git commit -m "feat: 新增 OpenAiCompatService 自定义 OpenAI 兼容模型服务"
```

---

### Task 5: 工厂 getLlmService + 调用方迁移 + 错误文案统一

**Files:**
- Create: `entry/src/main/ets/services/LlmServiceFactory.ets`
- Modify: `entry/src/main/ets/services/TranslationController.ets`
- Modify: `entry/src/main/ets/components/NovelCard.ets`
- Test: Create `entry/src/test/LlmServiceFactory.test.ets`
- Test: `entry/src/test/List.test.ets`（注册）

**Interfaces:**
- Consumes: `BaseLlmService`、`DeepSeekService`、`OpenAiCompatService`、`StorageKeys`、AppStorage 键（llmProvider/customLlmApiBase/customLlmApiKey/customLlmModel/titlePrompt/fullPrompt/unifiedPrompt）
- Produces:
  - `export function getLlmService(): BaseLlmService`（按 AppStorage `llmProvider` 返回 DeepSeekService 或 OpenAiCompatService 单例，并同步 prompts 配置）
  - `export function resetLlmServiceInstance(): void`（清单例，供切换 provider 时调用）

- [ ] **Step 1: 注册测试 + 写失败测试**

在 `entry/src/test/List.test.ets` 添加：

```typescript
import llmServiceFactoryTest from './LlmServiceFactory.test';
```

```typescript
  llmServiceFactoryTest();
```

创建 `entry/src/test/LlmServiceFactory.test.ets`：

```typescript
import { describe, it, expect } from '@ohos/hypium';
import { getLlmService, resetLlmServiceInstance } from '../main/ets/services/LlmServiceFactory';
import { DeepSeekService } from '../main/ets/services/DeepSeekService';
import { OpenAiCompatService } from '../main/ets/services/OpenAiCompatService';

export default function llmServiceFactoryTest() {
  describe('LlmServiceFactory', () => {

    describe('provider=deepseek（默认）', () => {
      it('返回 DeepSeekService 实例', 0, () => {
        AppStorage.setOrCreate('llmProvider', 'deepseek');
        resetLlmServiceInstance();
        const svc = getLlmService();
        expect(svc instanceof DeepSeekService).assertTrue();
      });
    });

    describe('provider=custom', () => {
      it('返回 OpenAiCompatService 实例', 0, () => {
        AppStorage.setOrCreate('llmProvider', 'custom');
        AppStorage.setOrCreate('customLlmApiBase', 'https://example.com/v1');
        AppStorage.setOrCreate('customLlmApiKey', 'sk-custom');
        AppStorage.setOrCreate('customLlmModel', 'my-model');
        resetLlmServiceInstance();
        const svc = getLlmService();
        expect(svc instanceof OpenAiCompatService).assertTrue();
      });

      it('切换 provider 后返回不同实例', 0, () => {
        AppStorage.setOrCreate('llmProvider', 'custom');
        resetLlmServiceInstance();
        const custom = getLlmService();
        AppStorage.setOrCreate('llmProvider', 'deepseek');
        resetLlmServiceInstance();
        const ds = getLlmService();
        expect(custom instanceof DeepSeekService).assertFalse();
        expect(ds instanceof DeepSeekService).assertTrue();
      });
    });

    describe('prompts 同步', () => {
      it('从 AppStorage 同步自定义 prompt', 0, () => {
        AppStorage.setOrCreate('llmProvider', 'deepseek');
        AppStorage.setOrCreate('titlePrompt', '工厂同步的标题规则');
        AppStorage.setOrCreate('fullPrompt', '');
        AppStorage.setOrCreate('unifiedPrompt', false);
        resetLlmServiceInstance();
        const svc = getLlmService();
        expect(svc.getSystemPrompt(true)).assertEqual('工厂同步的标题规则');
      });
    });
  });
}
```

- [ ] **Step 2: 实现 LlmServiceFactory.ets**

创建 `entry/src/main/ets/services/LlmServiceFactory.ets`：

```typescript
import { BaseLlmService } from './LlmProvider';
import { DeepSeekService } from './DeepSeekService';
import { OpenAiCompatService } from './OpenAiCompatService';
import { StorageKeys } from '../common/constants/StorageKeys';

let _llmInstance: BaseLlmService | null = null;
let _llmProvider: string = '';

export function getLlmService(): BaseLlmService {
  const provider = AppStorage.get<string>(StorageKeys.LLM_PROVIDER) ?? 'deepseek';

  if (!_llmInstance || _llmProvider !== provider) {
    _llmProvider = provider;
    if (provider === 'custom') {
      const baseUrl = AppStorage.get<string>(StorageKeys.CUSTOM_LLM_API_BASE) ?? '';
      const apiKey = AppStorage.get<string>(StorageKeys.CUSTOM_LLM_API_KEY) ?? '';
      const model = AppStorage.get<string>(StorageKeys.CUSTOM_LLM_MODEL) ?? '';
      _llmInstance = new OpenAiCompatService(baseUrl, apiKey, model);
    } else {
      const apiKey = AppStorage.get<string>(StorageKeys.DEEPSEEK_API_KEY) ?? '';
      _llmInstance = new DeepSeekService(apiKey);
    }
  }

  _llmInstance.updatePrompts(
    AppStorage.get<string>(StorageKeys.TITLE_PROMPT) ?? '',
    AppStorage.get<string>(StorageKeys.FULL_PROMPT) ?? '',
    AppStorage.get<boolean>(StorageKeys.UNIFIED_PROMPT) ?? false
  );

  return _llmInstance;
}

export function resetLlmServiceInstance(): void {
  _llmInstance = null;
  _llmProvider = '';
}
```

- [ ] **Step 3: 迁移 TranslationController 并统一文案**

修改 `entry/src/main/ets/services/TranslationController.ets`：

- 第 2 行 import 改为：

```typescript
import { getLlmService } from './LlmServiceFactory';
```

- 第 37、58、104 行 `const service = getDeepSeekService();` 全部改为 `const service = getLlmService();`
- 第 40、61 行错误文案 `'请先在设置中填入 DeepSeek API 密钥'` 改为 `'请先在设置中配置翻译 API 密钥'`

- [ ] **Step 4: 迁移 NovelCard 并统一文案**

修改 `entry/src/main/ets/components/NovelCard.ets`：

- 第 8 行 import 改为：

```typescript
import { getLlmService } from '../services/LlmServiceFactory';
```

- 第 132 行 `const service = getDeepSeekService();` 改为 `const service = getLlmService();`
- 第 134 行 `'请先在设置中填入 DeepSeek API 密钥'` 改为 `'请先在设置中配置翻译 API 密钥'`

- [ ] **Step 5: 运行测试验证**

Run: `hvigorw test 2>&1 | grep -E 'ERROR|BUILD|FAIL'`
Expected: `BUILD SUCCESSFUL`，LlmServiceFactory.test 通过

- [ ] **Step 6: Commit**

```bash
git add entry/src/main/ets/services/LlmServiceFactory.ets entry/src/main/ets/services/TranslationController.ets entry/src/main/ets/components/NovelCard.ets entry/src/test/LlmServiceFactory.test.ets entry/src/test/List.test.ets
git commit -m "feat: 新增 getLlmService 工厂，翻译调用方按 provider 分发并统一错误文案"
```

---

### Task 6: TranslationController 自定义模式隐藏费用/token 信息

**Files:**
- Modify: `entry/src/main/ets/services/TranslationController.ets`
- Test: Create `entry/src/test/TranslationController.test.ets`
- Test: `entry/src/test/List.test.ets`（注册）

**Interfaces:**
- Consumes: `getLlmService()`、`BaseLlmService.supportsCostEstimate`
- Produces: `export function buildEstimateInfo(originalText: string, inputTokens: number, estimatedMs: number, estimatedCostYuan: number, ratio: number, count: number, showCostInfo: boolean): string`（纯函数，可独立测试）

- [ ] **Step 1: 注册测试 + 写失败测试**

在 `entry/src/test/List.test.ets` 添加：

```typescript
import translationControllerTest from './TranslationController.test';
```

```typescript
  translationControllerTest();
```

创建 `entry/src/test/TranslationController.test.ets`：

```typescript
import { describe, it, expect } from '@ohos/hypium';
import { buildEstimateInfo } from '../main/ets/services/TranslationController';

export default function translationControllerTest() {
  describe('TranslationController.buildEstimateInfo', () => {

    it('DeepSeek 模式（showCostInfo=true）包含费用与校准行', 0, () => {
      const info = buildEstimateInfo('你好'.repeat(50), 100, 60000, 0.0123, 0.65, 3, true);
      expect(info).assertContain('tokens');
      expect(info).assertContain('费用约 ¥0.0123');
      expect(info).assertContain('输出/输入比 0.650');
    });

    it('自定义模式（showCostInfo=false）不含 token/费用/校准行', 0, () => {
      const info = buildEstimateInfo('你好'.repeat(50), 100, 60000, 0.0123, 0.65, 3, false);
      expect(info.indexOf('tokens')).assertEqual(-1);
      expect(info.indexOf('费用')).assertEqual(-1);
      expect(info.indexOf('校准')).assertEqual(-1);
      expect(info).assertContain('预计翻译 100 字符');
      expect(info).assertContain('约 1 分');
    });

    it('耗时格式：不足 1 分钟显示秒', 0, () => {
      const info = buildEstimateInfo('a', 10, 45000, 0.01, 0.65, 0, false);
      expect(info).assertContain('约 45 秒');
    });
  });
}
```

- [ ] **Step 2: 实现 buildEstimateInfo + prepareFullTranslation 改造**

修改 `entry/src/main/ets/services/TranslationController.ets`：

在文件顶部（`export class TranslationController` 之前）新增纯函数：

```typescript
export function buildEstimateInfo(
  originalText: string,
  inputTokens: number,
  estimatedMs: number,
  estimatedCostYuan: number,
  ratio: number,
  count: number,
  showCostInfo: boolean
): string {
  const totalSec = Math.round(estimatedMs / 1000);
  const min = Math.floor(totalSec / 60);
  const sec = totalSec % 60;
  const fmtTime = min > 0
    ? (sec > 0 ? `约 ${min} 分 ${sec} 秒` : `约 ${min} 分`)
    : `约 ${sec} 秒`;

  if (!showCostInfo) {
    return `预计翻译 ${originalText.length} 字符\n` +
      `预计耗时 ${fmtTime}\n` +
      `是否继续？`;
  }

  return `预计翻译 ${originalText.length} 字符 / ${inputTokens} tokens\n` +
    `预计耗时 ${fmtTime}\n` +
    `费用约 ¥${estimatedCostYuan.toFixed(4)}\n` +
    `输出/输入比 ${ratio.toFixed(3)}（已校准 ${count} 次）\n` +
    `是否继续？`;
}
```

修改 `prepareFullTranslation` 方法（原 76-95 行），替换 estimateInfo 组装逻辑：

```typescript
    const inputTokens = service.estimateTokens(originalText);
    const estimatedMs = service.estimateTime(inputTokens);
    const estimatedCostYuan = service.supportsCostEstimate ? service.estimateCost(inputTokens) : 0;
    const ratio = service.getAdaptiveRatio();
    const count = service.getRatioCount();

    const estimateInfo = buildEstimateInfo(
      originalText,
      inputTokens,
      estimatedMs,
      estimatedCostYuan,
      ratio,
      count,
      service.supportsCostEstimate
    );
```

> 说明：`getAdaptiveRatio`/`getRatioCount` 基类已有默认实现（Task 2），DeepSeekService 覆写返回真实校准值，自定义模式用默认值 0.65/0。

- [ ] **Step 3: 运行测试验证**

Run: `hvigorw test 2>&1 | grep -E 'ERROR|BUILD|FAIL'`
Expected: `BUILD SUCCESSFUL`，TranslationController.test 通过

- [ ] **Step 4: Commit**

```bash
git add entry/src/main/ets/services/TranslationController.ets entry/src/main/ets/services/LlmProvider.ets entry/src/test/TranslationController.test.ets entry/src/test/List.test.ets
git commit -m "feat: 自定义模型模式隐藏费用/token 估算信息（buildEstimateInfo）"
```

---

### Task 7: EntryAbility 启动恢复 provider 与自定义配置

**Files:**
- Modify: `entry/src/main/ets/entryability/EntryAbility.ets`
- Test: `entry/src/test/StorageKeys.test.ets`（已覆盖）

**Interfaces:**
- Consumes: `TranslationStorage` 全部新 getter
- Produces: AppStorage 键 `llmProvider`、`customLlmApiBase`、`customLlmApiKey`、`customLlmModel`、`titlePrompt`、`fullPrompt`、`unifiedPrompt`

- [ ] **Step 1: 修改 EntryAbility.ets**

在 `onCreate` 中 `TranslationStorage.getDeepSeekApiKey()` 恢复块之后（约第 44 行后）追加：

```typescript
    TranslationStorage.getLlmProvider().then((provider: string) => {
      AppStorage.setOrCreate('llmProvider', provider);
      console.info('✅ llmProvider 已从磁盘恢复: ' + provider);
    });

    TranslationStorage.getCustomApiBase().then((value: string) => {
      AppStorage.setOrCreate('customLlmApiBase', value);
    });

    TranslationStorage.getCustomApiKey().then((value: string) => {
      AppStorage.setOrCreate('customLlmApiKey', value);
    });

    TranslationStorage.getCustomModel().then((value: string) => {
      AppStorage.setOrCreate('customLlmModel', value);
    });

    TranslationStorage.getTitlePrompt().then((value: string) => {
      AppStorage.setOrCreate('titlePrompt', value);
    });

    TranslationStorage.getFullPrompt().then((value: string) => {
      AppStorage.setOrCreate('fullPrompt', value);
    });

    TranslationStorage.getUnifiedPrompt().then((value: boolean) => {
      AppStorage.setOrCreate('unifiedPrompt', value);
    });
```

- [ ] **Step 2: 静态检查 + 提交**

Run: 确认无语法错误（后续 Task 9 统一跑测试）
Expected: 无 ERROR

```bash
git add entry/src/main/ets/entryability/EntryAbility.ets
git commit -m "feat: 启动时恢复自定义翻译 provider 配置"
```

---

### Task 8: 设置页 UI（ViewModel + TranslationSettingsSection）

**Files:**
- Modify: `entry/src/main/ets/viewmodel/TranslationSettingsViewModel.ets`
- Modify: `entry/src/main/ets/pages/settings/TranslationSettingsSection.ets`
- Test: 无（`viewmodel/` 与 `pages/` 属 AGENTS.md 例外清单，不可测）

**Interfaces:**
- Consumes: `getLlmService()`、`TranslationStorage` 全部新方法、`StorageKeys` 新键
- Produces: ViewModel 新状态字段 `llmProvider`/`customApiBase`/`customModel`/`customApiKey`/`titlePrompt`/`fullPrompt`/`unifiedPrompt`

- [ ] **Step 1: 扩展 ViewModel 状态与逻辑**

在 `entry/src/main/ets/viewmodel/TranslationSettingsViewModel.ets`：

1. `TranslationSettingsState` 增加字段：

```typescript
  llmProvider: string = 'deepseek';
  customApiBase: string = '';
  customModel: string = '';
  customApiKey: string = '';
  titlePrompt: string = '';
  fullPrompt: string = '';
  unifiedPrompt: boolean = false;
```

2. `loadSettings()` 增加恢复逻辑：

```typescript
    state.llmProvider = AppStorage.get<string>('llmProvider') ?? 'deepseek';
    state.customApiBase = AppStorage.get<string>('customLlmApiBase') ?? '';
    state.customModel = AppStorage.get<string>('customLlmModel') ?? '';
    state.customApiKey = AppStorage.get<string>('customLlmApiKey') ?? '';
    state.titlePrompt = AppStorage.get<string>('titlePrompt') ?? '';
    state.fullPrompt = AppStorage.get<string>('fullPrompt') ?? '';
    state.unifiedPrompt = AppStorage.get<boolean>('unifiedPrompt') ?? false;
```

3. 新增方法（在类内追加）：

```typescript
  updateLlmProvider(provider: string): void {
    const state = this.state;
    state.llmProvider = provider;
    AppStorage.setOrCreate('llmProvider', provider);
    TranslationStorage.saveLlmProvider(provider);
    if (provider === 'deepseek' && state.deepseekApiKey.length > 0) {
      this.fetchBalance();
    }
  }

  updateCustomConfig(field: 'base' | 'model' | 'key', value: string): void {
    const state = this.state;
    if (field === 'base') {
      state.customApiBase = value;
      AppStorage.setOrCreate('customLlmApiBase', value);
      TranslationStorage.saveCustomApiBase(value);
    } else if (field === 'model') {
      state.customModel = value;
      AppStorage.setOrCreate('customLlmModel', value);
      TranslationStorage.saveCustomModel(value);
    } else {
      state.customApiKey = value;
      AppStorage.setOrCreate('customLlmApiKey', value);
      TranslationStorage.saveCustomApiKey(value);
    }
  }

  updateTitlePrompt(prompt: string): void {
    const state = this.state;
    state.titlePrompt = prompt;
    AppStorage.setOrCreate('titlePrompt', prompt);
    TranslationStorage.saveTitlePrompt(prompt);
  }

  updateFullPrompt(prompt: string): void {
    const state = this.state;
    state.fullPrompt = prompt;
    AppStorage.setOrCreate('fullPrompt', prompt);
    TranslationStorage.saveFullPrompt(prompt);
  }

  updateUnifiedPrompt(enabled: boolean): void {
    const state = this.state;
    state.unifiedPrompt = enabled;
    AppStorage.setOrCreate('unifiedPrompt', enabled);
    TranslationStorage.saveUnifiedPrompt(enabled);
  }

  resetPrompts(): void {
    const state = this.state;
    state.titlePrompt = '';
    state.fullPrompt = '';
    AppStorage.setOrCreate('titlePrompt', '');
    AppStorage.setOrCreate('fullPrompt', '');
    TranslationStorage.saveTitlePrompt('');
    TranslationStorage.saveFullPrompt('');
  }
```

4. `loadRatioInfo`/`checkApiKeyValidity`/`fetchBalance`/`resetRatio` 保持 DeepSeek 专属逻辑不变（这些 UI 仅在 DeepSeek 模式展示）。

- [ ] **Step 2: 更新设置页 UI**

修改 `entry/src/main/ets/pages/settings/TranslationSettingsSection.ets`：

1. import 增加：

```typescript
import { TranslationSettingsViewModel } from '../../viewmodel/TranslationSettingsViewModel';
```

2. `aboutToAppear()` 增加 provider/prompt 恢复（调用 ViewModel.loadSettings 或直接读 AppStorage）：

```typescript
    this.llmProvider = AppStorage.get<string>('llmProvider') ?? 'deepseek';
    this.customApiBase = AppStorage.get<string>('customLlmApiBase') ?? '';
    this.customModel = AppStorage.get<string>('customLlmModel') ?? '';
    this.customApiKey = AppStorage.get<string>('customLlmApiKey') ?? '';
    this.titlePrompt = AppStorage.get<string>('titlePrompt') ?? '';
    this.fullPrompt = AppStorage.get<string>('fullPrompt') ?? '';
    this.unifiedPrompt = AppStorage.get<boolean>('unifiedPrompt') ?? false;
```

3. `@State` 新增：

```typescript
  @State llmProvider: string = 'deepseek';
  @State customApiBase: string = '';
  @State customModel: string = '';
  @State customApiKey: string = '';
  @State titlePrompt: string = '';
  @State fullPrompt: string = '';
  @State unifiedPrompt: boolean = false;
```

4. `build()` 中，卡片顶部（Row 标题「DeepSeek API 密钥」之前）插入提供商选择区：

```typescript
      Text('翻译服务')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.user_name'))
        .margin({ bottom: 10 })

      Row() {
        Radio({ value: 'deepseek', group: 'llmProvider' })
          .checked(this.llmProvider === 'deepseek')
          .onChange((checked: boolean) => {
            if (checked) this.onProviderChange('deepseek');
          })
        Text('DeepSeek（预设）')
          .fontSize(14)
          .fontColor($r('app.color.user_name'))
          .margin({ right: 20 })

        Radio({ value: 'custom', group: 'llmProvider' })
          .checked(this.llmProvider === 'custom')
          .onChange((checked: boolean) => {
            if (checked) this.onProviderChange('custom');
          })
        Text('自定义模型')
          .fontSize(14)
          .fontColor($r('app.color.user_name'))
      }
      .width('100%')
      .margin({ bottom: 14 })
```

5. 新增处理函数（类内）：

```typescript
  private onProviderChange(provider: string): void {
    this.llmProvider = provider;
    AppStorage.setOrCreate('llmProvider', provider);
    TranslationStorage.saveLlmProvider(provider);
    if (provider === 'deepseek' && this.deepseekApiKey.length > 0) {
      this.fetchBalance();
    }
  }
```

6. DeepSeek 专属区（余额/校准卡片）包一层条件：

```typescript
      if (this.deepseekApiKey.length > 0 && this.llmProvider === 'deepseek') {
        // 原有余额 + 校准 Divider/Row 内容整体包住
```

7. 自定义模式输入区（provider 为 custom 时显示，插在 DeepSeek key 输入区之后）：

```typescript
      if (this.llmProvider === 'custom') {
        Divider().strokeWidth(1).color($r('app.color.divider')).margin({ top: 14, bottom: 14 })

        Text('API 地址（OpenAI 兼容）')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.user_name'))
          .margin({ bottom: 6 })

        TextInput({ text: this.customApiBase, placeholder: 'https://api.openai.com/v1/chat/completions' })
          .width('100%')
          .height(44)
          .fontSize(13)
          .fontColor($r('app.color.user_name'))
          .backgroundColor($r('app.color.page_background'))
          .borderRadius(8)
          .padding({ left: 12, right: 12 })
          .border({ width: 1, color: $r('app.color.divider'), radius: 8 })
          .onChange((val: string): void => {
            this.customApiBase = val;
            AppStorage.setOrCreate('customLlmApiBase', val);
            TranslationStorage.saveCustomApiBase(val);
          })

        Text('模型名称')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.user_name'))
          .margin({ top: 12, bottom: 6 })

        TextInput({ text: this.customModel, placeholder: '如 gpt-4o / qwen2.5' })
          .width('100%')
          .height(44)
          .fontSize(13)
          .fontColor($r('app.color.user_name'))
          .backgroundColor($r('app.color.page_background'))
          .borderRadius(8)
          .padding({ left: 12, right: 12 })
          .border({ width: 1, color: $r('app.color.divider'), radius: 8 })
          .onChange((val: string): void => {
            this.customModel = val;
            AppStorage.setOrCreate('customLlmModel', val);
            TranslationStorage.saveCustomModel(val);
          })

        Text('API Key')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.user_name'))
          .margin({ top: 12, bottom: 6 })

        TextInput({ text: this.customApiKey, placeholder: '粘贴自定义模型 API Key...' })
          .width('100%')
          .height(44)
          .fontSize(13)
          .fontColor($r('app.color.user_name'))
          .backgroundColor($r('app.color.page_background'))
          .borderRadius(8)
          .padding({ left: 12, right: 12 })
          .border({ width: 1, color: $r('app.color.divider'), radius: 8 })
          .type(this.showApiKeyText ? InputType.Normal : InputType.Password)
          .onChange((val: string): void => {
            this.customApiKey = val;
            AppStorage.setOrCreate('customLlmApiKey', val);
            TranslationStorage.saveCustomApiKey(val);
          })

        Text('自定义模型仅显示字符数与耗时估算，不显示费用/余额')
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 10 })
          .lineHeight(18)
      }
```

8. 翻译提示词卡片（provider 两种模式均显示，置于整卡最底部）：

```typescript
      Divider().strokeWidth(1).color($r('app.color.divider')).margin({ top: 14, bottom: 14 })

      Row() {
        Text('翻译提示词')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.user_name'))

        Blank()

        Button('恢复默认')
          .fontSize(12)
          .height(30)
          .fontColor($r('app.color.danger'))
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: $r('app.color.danger'), radius: 8 })
          .onClick(() => {
            AlertDialog.show({
              title: '恢复默认提示词',
              message: '确定要清空自定义提示词，恢复内置默认模板吗？',
              autoCancel: true,
              primaryButton: {
                value: '取消',
                action: () => {}
              },
              secondaryButton: {
                value: '恢复默认',
                fontColor: '#FF4D4F',
                action: () => {
                  this.titlePrompt = '';
                  this.fullPrompt = '';
                  AppStorage.setOrCreate('titlePrompt', '');
                  AppStorage.setOrCreate('fullPrompt', '');
                  TranslationStorage.saveTitlePrompt('');
                  TranslationStorage.saveFullPrompt('');
                  promptAction.showToast({ message: '已恢复默认提示词' });
                }
              }
            });
          })
      }
      .width('100%')

      Row() {
        Toggle({ type: ToggleType.Switch, isOn: this.unifiedPrompt })
          .onChange((isOn: boolean) => {
            this.unifiedPrompt = isOn;
            AppStorage.setOrCreate('unifiedPrompt', isOn);
            TranslationStorage.saveUnifiedPrompt(isOn);
          })
        Text('标题与全文使用统一提示词')
          .fontSize(13)
          .fontColor($r('app.color.user_name'))
          .margin({ left: 8 })
      }
      .width('100%')
      .margin({ top: 10, bottom: 6 })

      if (this.unifiedPrompt) {
        Text('统一提示词（标题/全文共用）')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .margin({ bottom: 6 })
        TextArea({ text: this.titlePrompt, placeholder: '留空则使用内置默认模板' })
          .width('100%')
          .height(120)
          .fontSize(13)
          .backgroundColor($r('app.color.page_background'))
          .borderRadius(8)
          .onChange((val: string): void => {
            this.titlePrompt = val;
            AppStorage.setOrCreate('titlePrompt', val);
            TranslationStorage.saveTitlePrompt(val);
          })
      } else {
        Text('标题翻译提示词')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .margin({ bottom: 6 })
        TextArea({ text: this.titlePrompt, placeholder: '留空则使用内置默认模板' })
          .width('100%')
          .height(100)
          .fontSize(13)
          .backgroundColor($r('app.color.page_background'))
          .borderRadius(8)
          .onChange((val: string): void => {
            this.titlePrompt = val;
            AppStorage.setOrCreate('titlePrompt', val);
            TranslationStorage.saveTitlePrompt(val);
          })
          .margin({ bottom: 12 })

        Text('全文翻译提示词')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .margin({ bottom: 6 })
        TextArea({ text: this.fullPrompt, placeholder: '留空则使用内置默认模板' })
          .width('100%')
          .height(120)
          .fontSize(13)
          .backgroundColor($r('app.color.page_background'))
          .borderRadius(8)
          .onChange((val: string): void => {
            this.fullPrompt = val;
            AppStorage.setOrCreate('fullPrompt', val);
            TranslationStorage.saveFullPrompt(val);
          })
      }

      Text('提示词为空时使用内置默认模板；自定义模型不发送 thinking 参数')
        .fontSize(10)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 8 })
```

> 提示：`TextArea` 若需边框请按项目其他页面写法补 `.border(...)`。上述代码为结构骨架，执行时按现有卡片风格对齐。

- [ ] **Step 3: 提交**

```bash
git add entry/src/main/ets/viewmodel/TranslationSettingsViewModel.ets entry/src/main/ets/pages/settings/TranslationSettingsSection.ets
git commit -m "feat: 设置页支持翻译服务切换、自定义模型配置与翻译提示词编辑"
```

---

### Task 9: FEATURES.md 更新 + 全量验证

**Files:**
- Modify: `FEATURES.md`

- [ ] **Step 1: 更新 FEATURES.md**

在 F11 小节追加/更新内容：

```markdown
## F11 - AI 翻译（DeepSeek + 自定义模型）

- **描述**：通过 DeepSeek API 或自定义 OpenAI 兼容 API 对日文小说进行标题/全文中文翻译，支持自定义翻译提示词（标题/全文分开或统一）、自定义模型下隐藏费用/token 估算
- **API**：`entry/src/main/ets/services/DeepSeekService.ets`、`entry/src/main/ets/services/OpenAiCompatService.ets`
- **抽象基类**：`entry/src/main/ets/services/LlmProvider.ets`
- **工厂**：`entry/src/main/ets/services/LlmServiceFactory.ets`
- **分词器**：`entry/src/main/ets/services/DeepSeekTokenizer.ets`
- **翻译缓存**：`entry/src/main/ets/common/utils/TranslationStorage.ets`
- **测试**：`entry/src/test/LlmProvider.test.ets`、`entry/src/test/OpenAiCompatService.test.ets`、`entry/src/test/LlmServiceFactory.test.ets`、`entry/src/test/TranslationController.test.ets`
```

在文档底部「手工验证项」中追加：

```markdown
- [ ] 设置页切换到「自定义模型」，填入 API 地址/模型名/Key 后小说标题与全文翻译可用
- [ ] 自定义模型下不显示账户余额/校准比例，全文翻译确认框无 token/费用行
- [ ] 自定义标题/全文提示词后翻译风格随之变化；恢复默认后回到内置模板
- [ ] 统一提示词开关开启后，标题与全文翻译使用同一提示词
- [ ] 切换回 DeepSeek 后余额/校准/费用显示恢复
```

更新底部「最后更新」日期为 2026-08-13。

- [ ] **Step 2: 全量验证（AGENTS.md 步骤 A/B/C）**

```bash
# 步骤 A：静态检查（若有 arkts_check 工具则运行，否则跳过）
# 步骤 B：测试覆盖自动检查（按 AGENTS.md 规则 4 步骤 B 脚本）
# 步骤 C：
hvigorw test 2>&1 | grep -E 'ERROR|BUILD|FAIL'
hvigorw assembleHap 2>&1 | grep -E 'ERROR|BUILD|FAIL'
```

Expected: 两个命令均 `BUILD SUCCESSFUL` 且无 ERROR

- [ ] **Step 3: Commit**

```bash
git add FEATURES.md
git commit -m "docs: 更新 FEATURES.md 自定义翻译模型功能说明"
```

---

### Task 10: 手工验证提醒

- [ ] **Step 1: 通知用户手工验证**

提醒用户在真机/模拟器上按 FEATURES.md 底部新增的手工验证项逐条验证，重点：
1. 设置页「翻译服务」切换与自定义模型配置
2. 自定义模式下确认框无费用/token 行
3. 自定义 prompt 生效与恢复默认
4. DeepSeek 模式回归（余额/校准/翻译均正常）
