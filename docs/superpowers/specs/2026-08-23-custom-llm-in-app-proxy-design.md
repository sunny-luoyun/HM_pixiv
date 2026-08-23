# 设计：自定义模型翻译「走应用内代理」开关

- 日期：2026-08-23
- 状态：已确认（用户批准方案 A 与整体设计）
- 关联：`docs/superpowers/specs/2026-08-13-custom-translation-provider-design.md`（自定义模型功能）

## 1. 背景与目标

当前 AI 翻译请求（`BaseLlmService.translateText()`，位于 `entry/src/main/ets/services/LlmProvider.ets`）发起 HTTP 请求时不传 `usingProxy`，始终直连。App 内已有基于 mihomo 内核的代理体系（`services/ProxyService.ets` + `libproxy_core.so`），pixiv 相关请求均通过 `ProxyService.getRequestProxyConfig()` 接入。

用户使用自定义 OpenAI 兼容模型时，若 API 地址为境外端点，直连会失败。本设计在设置页「自定义模型」区块增加开关：**开启后，自定义模型的翻译请求在应用内代理处于运行状态时经由该代理转发；代理关闭或未运行时自动直连**。DeepSeek 预设路径不受影响（国内可直连）。

## 2. 方案选型

采用**方案 A：配置注入服务实例**。

- `translateText()` 不直接读存储；开关值经 `LlmServiceFactory.getLlmService()` 每次调用时同步到服务实例（新增 setter），与现有 `updateApiKey()` / `updatePrompts()` 的同步机制同构。
- 否决方案 B（基类直接读 AppStorage）：耦合存储键名与 provider 语义、破坏注入模式、难以单测。
- 否决方案 C（仅 OpenAiCompatService 覆写 translateText）：复制整段 HTTP 代码，双份维护。

## 3. 改动清单

### 3.1 数据层

| 文件 | 改动 |
|---|---|
| `entry/src/main/ets/common/constants/StorageKeys.ets` | 新增 `static readonly CUSTOM_LLM_USE_PROXY = 'customLlmUseProxy'` |
| `entry/src/main/ets/common/utils/TranslationStorage.ets` | 新增 `KEY_CUSTOM_USE_PROXY = 'custom_use_proxy'`、`saveCustomUseProxy(enabled: boolean)`、`getCustomUseProxy(): Promise<boolean>`（默认 `false`），模式对齐既有 `saveUnifiedPrompt/getUnifiedPrompt` |

### 3.2 服务层

`entry/src/main/ets/services/LlmProvider.ets`（`BaseLlmService`）：

- 新增受保护字段 `useInAppProxy: boolean = false`。
- 新增公开方法 `updateUseInAppProxy(enabled: boolean): void` 与公开读取器 `getUseInAppProxy(): boolean`（供单元测试断言状态切换）。
- 导出纯函数 `resolveRequestProxy(enabled: boolean, proxyConfig: http.HttpProxy | null): http.HttpProxy | null`：返回 `enabled ? proxyConfig : null`，封装决策分支供单元测试。
- `translateText()` 内构建请求前：
  - 若 `this.useInAppProxy === true` → `const proxyConfig = await ProxyService.getRequestProxyConfig();` 经 `resolveRequestProxy` 得非 null 则加入请求 options `usingProxy: proxyConfig` 并打 info 日志；为 null 则打 warn 日志后直连。
  - 标志为 false → 不调用 ProxyService，行为与现状完全一致。

`entry/src/main/ets/services/LlmServiceFactory.ets`（`getLlmService()`）：

新增导出纯函数并接入：

```typescript
export function shouldUseInAppProxy(provider: string, toggle: boolean | undefined): boolean {
  return provider === 'custom' && (toggle ?? false);
}
```

在现有 `updateApiKey/updatePrompts` 同步点追加：

```typescript
_llmInstance.updateUseInAppProxy(
  shouldUseInAppProxy(provider, AppStorage.get<boolean>(StorageKeys.CUSTOM_LLM_USE_PROXY))
);
```

效果：DeepSeek 单例恒收到 `false`；每次翻译操作都重读 AppStorage，开关改动即时生效。

### 3.3 UI 层（测试豁免：pages/settings/）

`entry/src/main/ets/pages/settings/TranslationSettingsSection.ets`：

- 新增 `@State customUseProxy: boolean`，`aboutToAppear()` 中从 AppStorage 读取（默认 false）。
- 在「API Key」输入框之后、「自定义模型仅显示字符数…」说明文字之前插入：

```text
[Switch] 走应用内代理
开启后自定义模型请求经应用内代理转发；代理关闭或未运行时自动直连
```

- Switch onChange：更新 `@State` → `AppStorage.setOrCreate('customLlmUseProxy', v)` → `TranslationStorage.saveCustomUseProxy(v)`。样式对齐「标题与全文使用统一提示词」开关行。

## 4. 行为矩阵

| 场景 | 行为 |
|---|---|
| 开关关 | 直连（现状不变） |
| 开关开 + 代理模式 off | 直连 |
| 开关开 + 手动代理已配置 | 走手动 host:port |
| 开关开 + 订阅模式内核就绪 | 走 127.0.0.1:动态端口 |
| 开关开 + 订阅内核启动中 | `getRequestProxyConfig` 最多等 5 秒后返回 null → 自动直连 |
| 代理连接失败 | 走现有 catch 分支错误文案（2300006 无法连接网络 / 2300007、2300028 连接超时等） |

不新增任何用户可见的错误弹窗；代理不可用一律静默回退直连并记录日志。

## 5. 测试计划（AGENTS.md 步骤 A–D）

1. 扩展 `entry/src/test/TranslationStorage.test.ets`：`saveCustomUseProxy/getCustomUseProxy` 存取往返用例 + 未初始化 context 时默认 `false` 用例。
2. 扩展既有 `entry/src/test/LlmProvider.test.ets`（已注册于 List.test.ets，无需新增注册）：
   - `updateUseInAppProxy(true/false)` 后经 `getUseInAppProxy()` 断言状态正确切换；
   - `resolveRequestProxy` 三分支：`(true, config) → config`、`(true, null) → null`、`(false, config) → null`。
3. 扩展既有 `entry/src/test/LlmServiceFactory.test.ets`：`shouldUseInAppProxy` 用例——`('custom', true) → true`、`('custom', false/undefined) → false`、`('deepseek', true) → false`。
5. `arkts_check` 全部改动 `.ets` 文件。
6. 测试覆盖自动检查（步骤 B 脚本）；源文件修改对应测试文件需同步更新。
7. `hvigorw test` 与 `hvigorw assembleHap` 均须 BUILD SUCCESSFUL。
8. `FEATURES.md` 追加功能记录（编号、描述、涉及文件、测试引用）并更新底部日期。

## 6. 明确不做（YAGNI）

- 不给 DeepSeek 提供代理选项。
- 不做"代理不可用"的用户提醒 UI。
- 不修改 `ProxyService` 本身（复用现有 `getRequestProxyConfig()`）。
- 不做按域名智能分流（全部自定义模型流量统一处理）。

## 7. 影响面

- 公共接口均为**新增**（新常量键、新存储方法、新服务方法、新纯函数），无删除或签名变更，符合 AGENTS.md 规则 2。
- 触发 AGENTS.md 规则 3 的文件均有对应测试：`TranslationStorage.ets`（扩展既有测试）、`LlmProvider.ets`（新建测试）、`LlmServiceFactory.ets`（新建测试，覆盖纯函数 `shouldUseInAppProxy`；`getLlmService()` 主体依赖 AppStorage/原生单例态，不在 hypium 中实例化断言）、`StorageKeys.ets`（豁免：纯常量）、`TranslationSettingsSection.ets`（豁免：pages/settings/ 组件）。
