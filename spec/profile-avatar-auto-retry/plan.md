# Implementation Plan: 个人中心头像自动补抓

**Input**: Feature specification from `spec/profile-avatar-auto-retry/spec.md`

## Summary

在用户每次切换到「我的」标签页（SettingPage）时，检查本地头像缓存文件 `avatar_{userId}.jpg` 是否存在。若不存在，则通过 `AppState.refreshUserInfo()` 调用 Pixiv API 获取用户头像 URL 并下载到本地缓存，确保用户始终能看到自己的头像。

## Technical Context

**Language/Version**: ArkTS (HarmonyOS NEXT API 12+, Stage Model)  
**Primary Dependencies**: `@ohos.file.fs` (文件访问/检查), Pixiv OAuth API (`/v2/user/detail`)  
**Storage**: 本地文件系统缓存 (`{cacheDir}/avatar_{userId}.jpg`), `@ohos.data.preferences` (头像 URL 持久化)  
**Testing**: `@ohos/hypium` (单元测试), `hvigorw test` / `hvigorw assembleHap` (构建验证)  
**Target Platform**: HarmonyOS NEXT (API 12+), 手机  
**Project Type**: 已有 HarmonyOS/ArkTS 移动应用 (Pixiv 第三方客户端)  
**Performance Goals**: 头像检查为同步文件探测（毫秒级），网络请求仅在缺失时触发；不影响页面渲染速度  
**Constraints**: 
- 不阻塞 UI 渲染（异步网络请求）
- 未登录时零网络请求
- 网络失败不崩溃、不弹错  
**Scale/Scope**: 仅在「我的」标签页生效，单文件修改，零新增文件

## Project Structure

### Documentation (this feature)

```text
spec/profile-avatar-auto-retry/
├── spec.md              # Feature specification (Phase 1)
└── plan.md              # This file (Phase 2)
```

### Source Code (仓库根目录)

```text
entry/src/main/ets/pages/setting/
└── SettingPage.ets       # 主要改动文件

entry/src/main/ets/store/
└── AppState.ets          # 已有方法 refreshUserInfo() / cacheAvatar() — 复用，无需改动
```

**Structure Decision**: 本项目为已有 HarmonyOS/ArkTS 项目，遵循现有项目架构，不做 MVVM 迁移。本 feature 仅为单文件的逻辑增强，不新增任何文件或目录。

## Complexity Tracking

无违规项。本 feature 复杂度低，仅在现有单文件内添加约 10-15 行逻辑。

## Research & Decisions

### Decision: 使用 `refreshUserInfo()` 而非 `cacheAvatar()` 作为补抓入口

- **Decision**: 在 `SettingPage.aboutToAppear()` 中，当检测到本地无头像缓存时，调用 `AppState.refreshUserInfo()` 触发补抓。
- **Rationale**: `cacheAvatar()` 依赖 `CookieManager.getAvatarUrl()` 返回已有的远程 URL，而问题场景恰恰是 URL 未保存（登录时 DOM 提取失败）。`refreshUserInfo()` 会调用 Pixiv API 重新获取完整的用户资料（含头像 URL），保存后再调用 `cacheAvatar()` 下载，完整覆盖「URL 缺失」和「文件未下载」两种场景。
- **Alternatives considered**: 
  1. 直接调用 `cacheAvatar()` — 如果 `pixiv_avatar_url` 为空则无效。
  2. 在 `cacheAvatar()` 内增加 fallback 逻辑 — 会引入更复杂的改动，且 `cacheAvatar()` 的职责应保持单一。

### Decision: 检查头像存在的方式

- **Decision**: 复用现有 `getAvatarUrl()` 方法的逻辑 — 通过 `fileIo.openSync()` 探测 `avatar_{userId}.jpg` 是否存在。
- **Rationale**: 与现有代码保持一致的检测方式。该方法已经正确处理了未登录、目录不存在、文件不存在等边界情况。
- **Alternatives considered**: 检查 `appState.avatarUrl` 属性 — 但该属性可能存有远程 URL（非 file:// 协议），不表示文件已实际缓存。

### Decision: 异步非阻塞调用

- **Decision**: 在 `aboutToAppear()` 中发起异步调用但不 `await` 其完成。
- **Rationale**: `aboutToAppear()` 是生命周期钩子，不应阻塞页面渲染。补抓过程在后台执行，完成后再触发 UI 刷新。
- **Implementation**: 
  ```typescript
  aboutToAppear() {
    this.checkAndRefetchAvatar();
  }
  
  private async checkAndRefetchAvatar(): Promise<void> {
    if (!this.appState.isLoggedIn || !this.appState.userId) return;
    if (this.getAvatarUrl()) return; // 已有缓存
    try {
      await this.appState.refreshUserInfo();
    } catch (_) {
      // 静默失败，下次进入自动重试
    }
  }
  ```

## Data Model

无新增数据模型。所有数据结构复用现有：
- `AppState.isLoggedIn` / `userId` / `avatarUrl`
- `CookieStorage` 中的 `pixiv_avatar_url`
- 文件系统 `{cacheDir}/avatar_{userId}.jpg`

## Contracts & Interfaces

### 内部接口（不新增对外公开接口）

| 方法 | 源文件 | 用途 |
|------|--------|------|
| `SettingPage.checkAndRefetchAvatar()` | `SettingPage.ets` | **新增**，`aboutToAppear` 内部调用的异步方法，检查并补抓头像 |
| `AppState.refreshUserInfo()` | `AppState.ets` | **已有**，通过 Pixiv API 获取用户资料并缓存头像 |

### 调用流程

```
aboutToAppear()
  └─ checkAndRefetchAvatar()
       ├─ isLoggedIn? → No: return
       ├─ getAvatarUrl() 非空? → Yes: return (已有本地缓存)
       └─ refreshUserInfo()
            ├─ PixivService.getUserProfile(userId) → 获取资料
            ├─ CookieManager.saveAvatarUrl(imageUrl) → 保存 URL
            ├─ cacheAvatar() → 下载文件到本地
            └─ UI 自动刷新 (Observed 机制)
```
