# 自定义模型翻译「走应用内代理」开关 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在翻译服务设置的「自定义模型」区块新增开关；开启后自定义模型（OpenAiCompatService）的翻译请求在应用内代理运行时经其转发，否则自动直连。DeepSeek 路径行为不变。

**Architecture:** 开关值持久化到 preferences 并镜像 AppStorage；`LlmServiceFactory.getLlmService()` 每次调用经新纯函数 `shouldUseInAppProxy(provider, toggle)` 判定后用 setter 注入 `BaseLlmService` 实例；`translateText()` 发请求前按注入标志调用现有 `ProxyService.getRequestProxyConfig()`，非 null 则给请求 options 加 `usingProxy`。

**Tech Stack:** HarmonyOS NEXT (API 12+) / ArkTS Stage 模型 / `@ohos.net.http`（`HttpProxy`、`HttpRequestOptions.usingProxy`）/ `@ohos.data.preferences` / `@ohos/hypium` v1.0.25

**Spec:** `docs/superpowers/specs/2026-08-23-custom-llm-in-app-proxy-design.md`

## Global Constraints

- 遵守项目 `AGENTS.md`：公共接口只增不改；改动必须带测试；每任务独立 commit，格式 `<type>: <描述>`
- ArkTS 严格模式：不使用非空断言 `!` 后缀（用比较表达式或 `??` 兜底）；对象字面量必须有标注类型
- 不引入任何新第三方依赖；不改 `build-profile.json5`、`oh-package.json5`
- 不修改 `ProxyService.ets` 本身（复用其 `static getRequestProxyConfig(): Promise<http.HttpProxy | null>`）
- DeepSeek 路径不得引入任何代理逻辑分支（工厂层恒传 false）
- 测试命令统一：`hvigorw test 2>&1 | grep -E 'ERROR|BUILD|FAIL'`，判定标准含 `BUILD SUCCESSFUL` 且无 `Error in`
- `pages/settings/` 与纯常量文件测试豁免（AGENTS.md 规则 3 例外清单）
- **Spec 修正说明**：spec 中"新建 LlmProvider.test.ets / LlmServiceFactory.test.ets"实际两者已存在且已在 `List.test.ets` 注册（L45-47/L96-98），任务为**扩展**，无需改 List.test.ets

## File Structure

| 文件 | 动作 | 职责 |
|---|---|---|
| `entry/src/main/ets/common/constants/StorageKeys.ets` | 修改 | 新增 AppStorage 键常量 |
| `entry/src/main/ets/common/utils/TranslationStorage.ets` | 修改 | 开关持久化存取 |
| `entry/src/main/ets/services/LlmProvider.ets` | 修改 | 标志字段 + setter/getter + 决策纯函数 + translateText 接线 |
| `entry/src/main/ets/services/LlmServiceFactory.ets` | 修改 | 判定纯函数 + 每次调用同步 |
| `entry/src/main/ets/pages/settings/TranslationSettingsSection.ets` | 修改 | 开关 UI（豁免单测） |
| `entry/src/test/TranslationStorage.test.ets` | 修改 | 默认值 + 方法完整性用例 |
| `entry/src/test/StorageKeys.test.ets` | 修改 | 新键名断言 |
| `entry/src/test/LlmProvider.test.ets` | 修改 | 标志切换 + 三分支决策用例 |
| `entry/src/test/LlmServiceFactory.test.ets` | 修改 | 判定纯函数 + 工厂同步用例 |
| `FEATURES.md` | 修改 | 追加 F38 |

---

### Task 1: 数据层 —— StorageKeys 键 + TranslationStorage 存取

**Files:**
- Modify: `entry/src/main/ets/common/constants/StorageKeys.ets:13`（`CUSTOM_LLM_MODEL` 行之后）
- Modify: `entry/src/main/ets/common/utils/TranslationStorage.ets:113`（`getCustomModel()` 方法之后）
- Test: `entry/src/test/StorageKeys.test.ets`（`CUSTOM_LLM_MODEL` 用例之后追加）
- Test: `entry/src/test/TranslationStorage.test.ets`（两处追加）

**Interfaces:**
- Consumes: 无
- Produces: `StorageKeys.CUSTOM_LLM_USE_PROXY: string`（值 `'customLlmUseProxy'`）；`TranslationStorage.saveCustomUseProxy(enabled: boolean): Promise<void>`；`TranslationStorage.getCustomUseProxy(): Promise<boolean>`（未初始化 context 时返回 `false`）

- [ ] **Step 1: 写失败测试**

`entry/src/test/StorageKeys.test.ets` 中在 `CUSTOM_LLM_MODEL 为 "customLlmModel"` 用例（L42-44）之后追加：

```typescript
    it('CUSTOM_LLM_USE_PROXY 为 "customLlmUseProxy"', 0, () => {
      expect(StorageKeys.CUSTOM_LLM_USE_PROXY).assertEqual('customLlmUseProxy');
    });
```

`entry/src/test/TranslationStorage.test.ets` 中：

① 「默认值」describe（L10-20）内追加：

```typescript
      it('getCustomUseProxy 默认 false', 0, async () => {
        const v = await TranslationStorage.getCustomUseProxy();
        expect(v).assertFalse();
      });
```

② 「方法完整性校验」describe 内（`saveCustomModel/getCustomModel` 用例之后）追加：

```typescript
      it('应定义 saveCustomUseProxy/getCustomUseProxy 方法', 0, () => {
        expect(typeof TranslationStorage.saveCustomUseProxy === 'function').assertTrue();
        expect(typeof TranslationStorage.getCustomUseProxy === 'function').assertTrue();
      });
```

- [ ] **Step 2: 运行验证失败**

Run: `hvigorw test 2>&1 | grep -E 'ERROR|BUILD|FAIL'`
Expected: 编译报错（`CUSTOM_LLM_USE_PROXY`/`getCustomUseProxy` 不存在），BUILD FAILED

- [ ] **Step 3: 最小实现**

`entry/src/main/ets/common/constants/StorageKeys.ets` L13 `CUSTOM_LLM_MODEL` 之后加一行：

```typescript
  static readonly CUSTOM_LLM_USE_PROXY = 'customLlmUseProxy';
```

`entry/src/main/ets/common/utils/TranslationStorage.ets` 在 `getCustomModel()` 方法结束（原 L113）之后插入：

```typescript
  private static KEY_CUSTOM_USE_PROXY = 'custom_use_proxy';

  static async saveCustomUseProxy(enabled: boolean): Promise<void> {
    if (!TranslationStorage.context) return;
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    await pref.put(TranslationStorage.KEY_CUSTOM_USE_PROXY, enabled);
    await pref.flush();
  }

  static async getCustomUseProxy(): Promise<boolean> {
    if (!TranslationStorage.context) return false;
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    return await pref.get(TranslationStorage.KEY_CUSTOM_USE_PROXY, false) as boolean;
  }
```

- [ ] **Step 4: 运行验证通过**

Run: `hvigorw test 2>&1 | grep -E 'ERROR|BUILD|FAIL'`
Expected: `BUILD SUCCESSFUL`，无 `Error in`

- [ ] **Step 5: Commit**

```bash
git add entry/src/main/ets/common/constants/StorageKeys.ets entry/src/main/ets/common/utils/TranslationStorage.ets entry/src/test/StorageKeys.test.ets entry/src/test/TranslationStorage.test.ets
git commit -m "feat: 自定义模型代理开关的数据层（StorageKeys 键 + TranslationStorage 存取）"
```

---

### Task 2: 服务层 —— BaseLlmService 代理标志 + resolveRequestProxy 纯函数

**Files:**
- Modify: `entry/src/main/ets/services/LlmProvider.ets`（import 区 L1-2、常量区 L46 后、字段区 L118 后、方法区 L152 后）
- Test: `entry/src/test/LlmProvider.test.ets`（import 区 L2、文件末尾 describe 前）

**Interfaces:**
- Consumes: 无（本任务自包含）
- Produces:
  - `BaseLlmService.updateUseInAppProxy(enabled: boolean): void`
  - `BaseLlmService.getUseInAppProxy(): boolean`（默认 `false`）
  - 导出纯函数 `resolveRequestProxy(enabled: boolean, proxyConfig: http.HttpProxy | null): http.HttpProxy | null`

- [ ] **Step 1: 写失败测试**

`entry/src/test/LlmProvider.test.ets`：

① import 区 L2 改为：

```typescript
import { BaseLlmService, LlmConfig, TranslationResult, resolveRequestProxy } from '../main/ets/services/LlmProvider';
import http from '@ohos.net.http';
```

② 在最后一个 describe（`translateText（空文本）`）之后、最外层 `});` 之前插入两个 describe：

```typescript
    describe('updateUseInAppProxy / getUseInAppProxy', () => {
      it('默认关闭', 0, () => {
        expect(makeService().getUseInAppProxy()).assertFalse();
      });

      it('开启后读取为 true', 0, () => {
        const svc = makeService();
        svc.updateUseInAppProxy(true);
        expect(svc.getUseInAppProxy()).assertTrue();
      });

      it('再次调用可关闭', 0, () => {
        const svc = makeService();
        svc.updateUseInAppProxy(true);
        svc.updateUseInAppProxy(false);
        expect(svc.getUseInAppProxy()).assertFalse();
      });
    });

    describe('resolveRequestProxy', () => {
      const proxy: http.HttpProxy = { host: '127.0.0.1', port: 7890, exclusionList: [] };

      it('开启且有配置 → 返回该配置', 0, () => {
        const r = resolveRequestProxy(true, proxy);
        expect(r !== null && r.host === '127.0.0.1' && r.port === 7890).assertTrue();
      });

      it('开启但配置为 null → 返回 null（直连）', 0, () => {
        expect(resolveRequestProxy(true, null) === null).assertTrue();
      });

      it('关闭 → 即使有配置也返回 null（直连）', 0, () => {
        expect(resolveRequestProxy(false, proxy) === null).assertTrue();
      });
    });
```

- [ ] **Step 2: 运行验证失败**

Run: `hvigorw test 2>&1 | grep -E 'ERROR|BUILD|FAIL'`
Expected: 编译报错（`resolveRequestProxy` 未导出 / `updateUseInAppProxy` 不存在），BUILD FAILED

- [ ] **Step 3: 最小实现**

`entry/src/main/ets/services/LlmProvider.ets` 四处修改：

① 字段：`protected unifiedPrompt: boolean = false;`（L118）之后加：

```typescript
  protected useInAppProxy: boolean = false;
```

② 方法：`updatePrompts(...)` 方法结束（L152）之后加：

```typescript
  updateUseInAppProxy(enabled: boolean): void {
    this.useInAppProxy = enabled ?? false;
  }

  getUseInAppProxy(): boolean {
    return this.useInAppProxy;
  }
```

③ 导出纯函数：`DEFAULT_FULL_PROMPT` 常量（L46）之后加：

```typescript
/**
 * 代理附加决策：仅当开关开启且拿到了代理配置时才返回配置，其余情况直连。
 */
export function resolveRequestProxy(enabled: boolean, proxyConfig: http.HttpProxy | null): http.HttpProxy | null {
  return enabled ? proxyConfig : null;
}
```

- [ ] **Step 4: 运行验证通过**

Run: `hvigorw test 2>&1 | grep -E 'ERROR|BUILD|FAIL'`
Expected: `BUILD SUCCESSFUL`，无 `Error in`

- [ ] **Step 5: Commit**

```bash
git add entry/src/main/ets/services/LlmProvider.ets entry/src/test/LlmProvider.test.ets
git commit -m "feat: BaseLlmService 应用内代理标志与 resolveRequestProxy 决策纯函数"
```

---

### Task 3: 服务层 —— translateText() 注入 usingProxy

**Files:**
- Modify: `entry/src/main/ets/services/LlmProvider.ets`（`translateText()` 内 L215-237 区段）

**Interfaces:**
- Consumes: Task 2 的 `this.useInAppProxy`、`resolveRequestProxy()`；既有的 `ProxyService.getRequestProxyConfig(): Promise<http.HttpProxy | null>`
- Produces: `translateText()` 行为变化——标志开启时代理转发/直连回退（无网络环境的单测无法覆盖 HTTP 路径，由 Task 2 单测 + 本任务的静态检查与回归套件保障）

- [ ] **Step 1: 加 import**

`entry/src/main/ets/services/LlmProvider.ets` 文件头（L2 之后）加：

```typescript
import { ProxyService } from './ProxyService';
```

（依赖方向检查：ProxyService 仅依赖 preferences/AppStorage/libproxy_core.so，无循环依赖。）

- [ ] **Step 2: 改写请求构造段**

将 `translateText()` 中从 `const httpRequest = http.createHttp();` 到 `const response = await httpRequest.request(this.baseUrl, { ... });` 的整段（现 L224-237）替换为：

```typescript
    const httpRequest = http.createHttp();
    const startTime = Date.now();

    // 仅当用户为自定义模型开启了「走应用内代理」时解析代理；
    // 代理关闭或内核未就绪时 getRequestProxyConfig 返回 null → 自动直连。
    let usingProxy: http.HttpProxy | null = null;
    if (this.useInAppProxy) {
      const proxyConfig = await ProxyService.getRequestProxyConfig();
      usingProxy = resolveRequestProxy(true, proxyConfig);
      if (usingProxy) {
        console.info(`[Translation] 经应用内代理 ${usingProxy.host}:${usingProxy.port} 请求翻译服务`);
      } else {
        console.warn('[Translation] 应用内代理未就绪，翻译请求直连');
      }
    }

    try {
      const requestOptions: http.HttpRequestOptions = {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.apiKey}`
        },
        extraData: JSON.stringify(this.buildRequestBody(text, isTitle)),
        connectTimeout: 30000,
        readTimeout: 300000
      };
      if (usingProxy) {
        requestOptions.usingProxy = usingProxy;
      }
      const response = await httpRequest.request(this.baseUrl, requestOptions);
```

注意：`try {` 块及后续所有代码（responseCode 处理等）保持不变，仅请求构造方式如上。

- [ ] **Step 3: 回归验证**

Run: `hvigorw test 2>&1 | grep -E 'ERROR|BUILD|FAIL'`
Expected: `BUILD SUCCESSFUL`，无 `Error in`（既有 `translateText（无 key/空文本）` 用例必须仍通过，证明 guard 分支未被破坏）

- [ ] **Step 4: Commit**

```bash
git add entry/src/main/ets/services/LlmProvider.ets
git commit -m "feat: translateText 支持注入应用内代理（未就绪时自动直连）"
```

---

### Task 4: 工厂层 —— shouldUseInAppProxy 判定 + 每次调用同步

**Files:**
- Modify: `entry/src/main/ets/services/LlmServiceFactory.ets`（import L4、getLlmService 内 L39-40 之间）
- Test: `entry/src/test/LlmServiceFactory.test.ets`（import L2、文件末尾）

**Interfaces:**
- Consumes: Task 1 的 `StorageKeys.CUSTOM_LLM_USE_PROXY`；Task 2 的 `BaseLlmService.updateUseInAppProxy()/getUseInAppProxy()`
- Produces: 导出纯函数 `shouldUseInAppProxy(provider: string, toggle: boolean | undefined): boolean`

- [ ] **Step 1: 写失败测试**

`entry/src/test/LlmServiceFactory.test.ets`：

① import 区 L2 改为：

```typescript
import { getLlmService, resetLlmServiceInstance, shouldUseInAppProxy } from '../main/ets/services/LlmServiceFactory';
```

② 最外层 `describe('LlmServiceFactory', ...)` 结束前插入：

```typescript
    describe('shouldUseInAppProxy', () => {
      it('custom 且开关开 → true', 0, () => {
        expect(shouldUseInAppProxy('custom', true)).assertTrue();
      });

      it('custom 且开关关 → false', 0, () => {
        expect(shouldUseInAppProxy('custom', false)).assertFalse();
      });

      it('custom 且开关未设置(undefined) → false', 0, () => {
        expect(shouldUseInAppProxy('custom', undefined)).assertFalse();
      });

      it('deepseek 且开关开 → false（DeepSeek 恒直连）', 0, () => {
        expect(shouldUseInAppProxy('deepseek', true)).assertFalse();
      });
    });

    describe('useInAppProxy 工厂同步', () => {
      function setupCustom(): void {
        AppStorage.setOrCreate('llmProvider', 'custom');
        AppStorage.setOrCreate('customLlmApiBase', 'https://example.com/v1');
        AppStorage.setOrCreate('customLlmApiKey', 'sk-custom');
        AppStorage.setOrCreate('customLlmModel', 'my-model');
      }

      it('provider=custom 且开关开 → 实例启用代理', 0, () => {
        setupCustom();
        AppStorage.setOrCreate('customLlmUseProxy', true);
        resetLlmServiceInstance();
        expect(getLlmService().getUseInAppProxy()).assertTrue();
      });

      it('provider=deepseek 即使开关开也不启用', 0, () => {
        AppStorage.setOrCreate('llmProvider', 'deepseek');
        AppStorage.setOrCreate('customLlmUseProxy', true);
        resetLlmServiceInstance();
        expect(getLlmService().getUseInAppProxy()).assertFalse();
      });

      it('开关关 → 实例不启用', 0, () => {
        setupCustom();
        AppStorage.setOrCreate('customLlmUseProxy', false);
        resetLlmServiceInstance();
        expect(getLlmService().getUseInAppProxy()).assertFalse();
      });

      it('开关未设置(undefined) → 实例不启用', 0, () => {
        setupCustom();
        resetLlmServiceInstance();
        expect(getLlmService().getUseInAppProxy()).assertFalse();
      });
    });
```

- [ ] **Step 2: 运行验证失败**

Run: `hvigorw test 2>&1 | grep -E 'ERROR|BUILD|FAIL'`
Expected: 编译报错（`shouldUseInAppProxy` 未导出），BUILD FAILED

- [ ] **Step 3: 最小实现**

`entry/src/main/ets/services/LlmServiceFactory.ets`：

① 在 `resetLlmServiceInstance()` 函数之前加导出纯函数：

```typescript
/** 仅 custom 提供方允许启用应用内代理；DeepSeek 恒直连。 */
export function shouldUseInAppProxy(provider: string, toggle: boolean | undefined): boolean {
  return provider === 'custom' && (toggle ?? false);
}
```

② `getLlmService()` 内 `_llmInstance.updatePrompts(...)` 调用块（L35-39）之后、`return _llmInstance;` 之前加：

```typescript
  _llmInstance.updateUseInAppProxy(
    shouldUseInAppProxy(provider, AppStorage.get<boolean>(StorageKeys.CUSTOM_LLM_USE_PROXY))
  );
```

- [ ] **Step 4: 运行验证通过**

Run: `hvigorw test 2>&1 | grep -E 'ERROR|BUILD|FAIL'`
Expected: `BUILD SUCCESSFUL`，无 `Error in`

- [ ] **Step 5: Commit**

```bash
git add entry/src/main/ets/services/LlmServiceFactory.ets entry/src/test/LlmServiceFactory.test.ets
git commit -m "feat: LlmServiceFactory 按开关同步自定义模型应用内代理标志"
```

---

### Task 5: UI 层 —— 设置页自定义模型区块开关

**Files:**
- Modify: `entry/src/main/ets/pages/settings/TranslationSettingsSection.ets`（@State 区 L22 后、aboutToAppear L38 后、处理方法 L108 后、build 自定义区块 L429-431 之间）

**Interfaces:**
- Consumes: Task 1 的 `TranslationStorage.saveCustomUseProxy()`；AppStorage 键 `'customLlmUseProxy'`
- Produces: 用户可见开关；写入 AppStorage `'customLlmUseProxy'`（工厂每次翻译重读 → 即时生效）
- 测试豁免依据：AGENTS.md 规则 3 例外清单（pages/ 下组件）

- [ ] **Step 1: 状态与方法**

① @State 区（L22 `@State customApiKey` 之后）加：

```typescript
  @State customUseProxy: boolean = false;
```

② `aboutToAppear()` 内 `this.customApiKey = ...`（L38）之后加：

```typescript
    this.customUseProxy = AppStorage.get<boolean>('customLlmUseProxy') ?? false;
```

③ 处理方法区（`onProviderChange` 方法之前或之后）加：

```typescript
  private onCustomUseProxyChange(enabled: boolean): void {
    this.customUseProxy = enabled;
    AppStorage.setOrCreate('customLlmUseProxy', enabled);
    TranslationStorage.saveCustomUseProxy(enabled);
  }
```

- [ ] **Step 2: build 插入开关 UI**

在自定义模型区块中，「API Key」TextInput 的 `.onChange(...)` 结束（L429）之后、「自定义模型仅显示字符数…」说明 Text（L431）之前插入：

```typescript
        Row() {
          Toggle({ type: ToggleType.Switch, isOn: this.customUseProxy })
            .onChange((isOn: boolean) => {
              this.onCustomUseProxyChange(isOn);
            })
          Text('走应用内代理')
            .fontSize(13)
            .fontColor($r('app.color.user_name'))
            .margin({ left: 8 })
        }
        .width('100%')
        .margin({ top: 12 })

        Text('开启后自定义模型请求经应用内代理转发；代理关闭或未运行时自动直连')
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 6 })
```

（样式对齐既有「标题与全文使用统一提示词」开关行。）

- [ ] **Step 3: 构建验证**

Run: `hvigorw assembleHap 2>&1 | grep -E 'ERROR|BUILD|FAIL'`
Expected: `BUILD SUCCESSFUL`，无 `ERROR`

- [ ] **Step 4: Commit**

```bash
git add entry/src/main/ets/pages/settings/TranslationSettingsSection.ets
git commit -m "feat: 设置页自定义模型区块新增「走应用内代理」开关"
```

---

### Task 6: AGENTS.md 步骤 A–D 全量验证 + FEATURES.md

**Files:**
- Modify: `FEATURES.md`（末尾追加 F38 + 更新底部日期）
- Verify: 全部前序任务产物

**Interfaces:**
- Consumes: Task 1-5 全部产出
- Produces: 验证通过的交付状态 + F38 功能记录

- [ ] **Step 1: 步骤 A 静态检查**

Run: `arkts_check entry/src/main/ets/common/constants/StorageKeys.ets entry/src/main/ets/common/utils/TranslationStorage.ets entry/src/main/ets/services/LlmProvider.ets entry/src/main/ets/services/LlmServiceFactory.ets entry/src/main/ets/pages/settings/TranslationSettingsSection.ets`
Expected: 无错误（如工具不支持多文件参数则逐个执行）

- [ ] **Step 2: 步骤 B 测试覆盖自动检查**

运行 AGENTS.md 规则 4 步骤 B 的完整脚本。
Expected: `✅ 测试覆盖检查通过`（本次改动源文件均有对应测试更新；`TranslationSettingsSection.ets` 属 pages/ 豁免）

- [ ] **Step 3: 步骤 C 编译与测试**

Run: `hvigorw test 2>&1 | grep -E 'ERROR|BUILD|FAIL' && hvigorw assembleHap 2>&1 | grep -E 'ERROR|BUILD|FAIL'`
Expected: 两条命令均 `BUILD SUCCESSFUL` 且 grep `Error in` 结果为 0

- [ ] **Step 4: 步骤 D 更新 FEATURES.md**

在文件末尾（F37 之后）追加：

```markdown
---

## F38 - 自定义模型翻译「走应用内代理」开关

- **描述**：翻译服务设置的「自定义模型」区块新增开关；开启后自定义模型的翻译请求在应用内代理（mihomo）处于运行状态时经其转发，代理关闭或未就绪时自动直连并记录日志；DeepSeek 预设路径恒直连不受影响；开关改动即时生效（工厂每次翻译重读 AppStorage）
- **常量**：`entry/src/main/ets/common/constants/StorageKeys.ets`（`CUSTOM_LLM_USE_PROXY`）
- **存储**：`entry/src/main/ets/common/utils/TranslationStorage.ets`（`saveCustomUseProxy/getCustomUseProxy`，preferences 键 `custom_use_proxy`）
- **服务**：`entry/src/main/ets/services/LlmProvider.ets`（`useInAppProxy` 标志、`updateUseInAppProxy/getUseInAppProxy`、`resolveRequestProxy` 纯函数、translateText 注入 `usingProxy`）、`entry/src/main/ets/services/LlmServiceFactory.ets`（`shouldUseInAppProxy` 纯函数 + 同步接线）
- **页面**：`entry/src/main/ets/pages/settings/TranslationSettingsSection.ets`（自定义模型区块 Switch + 说明文字）
- **测试**：`entry/src/test/StorageKeys.test.ets`、`entry/src/test/TranslationStorage.test.ets`、`entry/src/test/LlmProvider.test.ets`、`entry/src/test/LlmServiceFactory.test.ets`
- **设计文档**：`docs/superpowers/specs/2026-08-23-custom-llm-in-app-proxy-design.md`
- **手工验证项**：
  1. 设置 → 翻译服务 → 切到「自定义模型」，确认出现「走应用内代理」开关，默认关
  2. 开关开 + 代理设置页代理模式 off → 用海外 API 地址翻译应能直连成功或报网络错误（不挂起）
  3. 开关开 + 订阅模式内核就绪 → hilog 中可见「[Translation] 经应用内代理 …」日志
  4. 切回「DeepSeek（预设）」翻译 → 行为与此前完全一致（无代理日志）
```

并把底部「最后更新」日期改为 `2026-08-23`。

- [ ] **Step 5: Commit**

```bash
git add FEATURES.md
git commit -m "docs: FEATURES.md 记录 F38 自定义模型应用内代理开关"
```

---

## Self-Review 记录

- **Spec coverage**：spec §3.1→Task 1；§3.2 LlmProvider→Task 2/3；§3.2 Factory→Task 4；§3.3 UI→Task 5；§5 测试计划→各任务 TDD 步骤 + Task 6；§4 行为矩阵由 Task 2/3/4 的分支组合实现（回退直连=resolveRequestProxy null 分支）。§7 影响面与实际文件清单一致。✅
- **Placeholder scan**：所有代码步骤均含完整代码与精确插入位置，无 TBD/省略。✅
- **Type consistency**：`shouldUseInAppProxy(string, boolean | undefined): boolean` 在 Task 4 定义与测试一致；`resolveRequestProxy(boolean, http.HttpProxy | null): http.HttpProxy | null` 在 Task 2 定义、Task 3 消费一致；AppStorage 键名 `customLlmUseProxy`（Task 1 常量值 = Task 4/5 使用）三处一致。✅
