# AGENTS.md - AI 协作规范

## 核心规则（必须遵守）

### 1. 改动前必读
- 修改任何文件前，必须先用 Read 工具**完整阅读该文件**
- 涉及多个文件时，先读所有相关文件再动手
- 不要凭猜测改动代码

### 2. 公共接口不可破坏
- **禁止删除或重命名**已有类的 public 方法
- **禁止修改**已有方法的参数签名
- **禁止修改**已有数据模型的字段名和类型
- 如需变更接口，先询问用户确认

### 3. 每个新功能必须附带测试
- 测试文件放在 `entry/src/test/` 目录下
- 测试框架：`@ohos/hypium`（已安装 v1.0.25）
- 测试文件命名：`<模块名>.test.ets`
- 在 `List.test.ets` 中注册新的测试套件
- 测试目标：覆盖核心逻辑分支、边界输入、空值兜底

### 4. 改完必须验证（AI 自动执行，无需用户介入）

- **每次代码修改完成后，AI 必须自动执行以下命令**：
  ```
  hvigorw test
  ```
- **判定标准**：输出必须包含 `BUILD SUCCESSFUL` 且 **0 Error**（grep `Error in` 结果为 0）
- 如有失败，AI 自行修复后重新运行，直到全部通过，**不可将未通过测试的代码交付用户**
- 如修改涉及 UI 页面，AI 应提醒用户过一遍 `FEATURES.md` 底部对应的手工验证项

### 5. 功能清单同步更新
- 新增功能后必须在 `FEATURES.md` 中追加记录
- 删除/修改功能后必须同步更新 `FEATURES.md`
- 记录格式：功能编号、描述、涉及文件路径

### 6. 禁止的行为
- 不允许未经用户确认的批量重构
- 不允许删除现有注释（除非用户要求）
- 不允许引入未在 `oh-package.json5` 中声明的第三方依赖
- 不允许修改 `build-profile.json5`、`oh-package.json5` 等构建配置

### 7. Git 提交规范
- 每个功能独立 commit
- 格式：`<type>: <简短描述>`
  - `feat:` 新功能
  - `fix:` 修复
  - `perf:` 性能优化
  - `test:` 测试相关
- 不要在一个 commit 中混合不相关的改动

### 8. 鸿蒙特有注意事项
- 这是一个 HarmonyOS NEXT (API 12+) ArkTS 项目，使用 Stage 模型
- 构建系统：Hvigor（非 npm/webpack）
- 原生代码在 `entry/src/main/cpp/`（NAPI 桥接）和 `mihomo_bridge/`（Go 编译的 .so）
- UI 框架：ArkUI 声明式（`@Component`、`@State`、`@Prop` 等装饰器）
- 持久化：`@ohos.data.relationalStore`（SQLite）、`@ohos.data.preferences`
- 网络：`@ohos.net.http`

## 项目结构速览

```
entry/src/main/ets/
├── pages/           # 页面（20 个 .ets 文件，12 个子目录）
│   ├── Index.ets    # 主 Tab
│   ├── home/        # 发现页
│   ├── latest/      # 最新作品
│   ├── search/      # 搜索
│   ├── illust/      # 插画详情+评论
│   ├── novel/       # 小说阅读+系列+评论
│   ├── user/        # 用户主页
│   ├── login/       # 登录
│   ├── favorites/   # 收藏
│   ├── setting/     # 设置主页/关注/屏蔽
│   └── settings/    # 详细设置/缓存/作者详情/系列详情
├── components/      # 可复用组件（6 个）
├── services/        # 业务服务（8 个）
├── store/           # 全局状态（1 个）
├── models/          # 数据模型（1 个）
├── database/        # SQLite（1 个）
├── common/utils/    # 工具（3 个）
├── entryability/    # 应用入口（1 个）
└── entrybackupability/ # 备份扩展（1 个）

entry/src/test/      # 单元测试目录
entry/src/ohosTest/  # 集成测试目录
```
