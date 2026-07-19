# AGENTS.md - AI 协作规范

## 核心规则（必须遵守）

### 0. 每次会话开始先做自检

执行以下命令检查是否有未完成的变更：
```bash
git status --short | grep -E 'entry/src/main/ets|entry/src/test'
```

**如果发现未提交变更**：
1. 按规则 4 步骤 B 检查测试覆盖
2. 如有新增源文件缺少测试 → 先补测试，再继续新任务
3. 如一切正常 → 继续

### 0.5 `@skip-test` 注释机制

如果用户明确要求跳过测试（如"不用写测试"），按以下流程处理：
1. 确认用户意图："确定跳过吗？下次扩展时可能需要补测试。"
2. 如果用户坚持，在源文件头部添加注释：`// @skip-test: <理由>`
3. 步骤 B 检测到 `@skip-test` 注释的文件会跳过测试覆盖检查

### 1. 改动前必读
- 修改任何文件前，必须先用 Read 工具**完整阅读该文件**
- 涉及多个文件时，先读所有相关文件再动手
- 不要凭猜测改动代码

### 2. 公共接口不可破坏
- **禁止删除或重命名**已有类的 public 方法
- **禁止修改**已有方法的参数签名
- **禁止修改**已有数据模型的字段名和类型
- 如需变更接口，先询问用户确认

### 3. 每个代码变更必须附带或更新测试

**适用范围**（满足任一即触发）：
- 在 `entry/src/main/ets/` 下新增 `.ets` 源文件
- 修改已有 `.ets` 源文件（纯注释/格式化除外）
- 从已有文件中拆分/提取出新文件
- 新增或修改导出的函数/类/接口

**测试规则**：
- 测试文件放在 `entry/src/test/` 目录下
- 测试框架：`@ohos/hypium`（已安装 v1.0.25）
- 测试文件命名：`<模块名>.test.ets`（与源文件一一对应）
- 新测试必须在 `entry/src/test/List.test.ets` 中注册
- 测试目标：覆盖核心逻辑分支、边界输入、空值兜底、异常路径

**例外清单**（以下类别自动豁免，无需创建测试）：
- `pages/` 下所有文件（`@Component` 无法在 hypium 中实例化）
- `components/` 下所有文件（`@Component`）
- `entryability/`、`entrybackupability/`、`entryworkability/`（Ability 生命周期类）
- `viewmodel/` 下所有文件（`@Observed`，强耦合状态管理系统）
- `notification/`、`push/`（系统 API，无 mock 框架）
- 纯 `interface`/`type` 定义的文件（仅有类型声明，无 `function`/`class`/`enum` 实现）
- 纯 `static readonly` 常量定义文件

> 遇到不可测文件时，在 commit 信息中用 `test: <模块名> — not testable (<原因>)` 标注

### 3.5 重构必须同步拆分测试

当从已有源文件中拆分/提取出新文件时，必须同步拆分对应的测试文件：

1. 检查源文件是否有测试：
   ```bash
   if [ -f "entry/src/test/$(basename 源文件 .ets).test.ets" ]; then
     echo "有测试 → 需同步拆分"
   else
     echo "无测试 → 先补源文件测试再拆分"
   fi
   ```
2. 如果源文件已有 `.test.ets` → 将拆出的子文件对应的测试逻辑移到新的 `.test.ets`
3. 如果源文件没有 `.test.ets` → 先为源文件补充测试，再拆分
4. 拆分后所有 `.test.ets` 必须在 `List.test.ets` 中注册

**示例**：从 `PixivModels.ets`（有 `PixivModels.test.ets`）拆出 `NovelModels.ets`
→ 应创建 `NovelModels.test.ets`，将小说模型相关测试移入
→ `PixivModels.test.ets` 保留通用模型测试
→ 两个文件都在 `List.test.ets` 中注册

### 4. 改完必须验证（AI 自动执行，无需用户介入）

**每次代码修改完成后，AI 必须按以下四个步骤执行验证**：

#### 步骤 A：静态检查
```bash
arkts_check 检查所有新增/修改的 `.ets` 文件
```

#### 步骤 B：测试覆盖自动检查
```bash
echo "===== 步骤 B：测试覆盖自动检查 ====="

GIT_DIFF_OUTPUT=$(git diff --name-only --diff-filter=AMR HEAD -- 'entry/src/main/ets/*.ets' 2>/dev/null)
GIT_AVAILABLE=$?

if [ $GIT_AVAILABLE -ne 0 ]; then
  echo "ℹ️ git diff 不可用，使用 find 检查最近文件..."
  RECENT_FILES=$(find entry/src/main/ets/services entry/src/main/ets/models entry/src/main/ets/common/utils entry/src/main/ets/database -name '*.ets' -newer entry/src/test/List.test.ets -mmin -60 2>/dev/null)
  HAS_MISSING=0
  for f in $RECENT_FILES; do
    case "$f" in */pages/*|*/components/*|*/entryability/*|*/entrybackupability/*|*/entryworkability/*|*/notification/*|*/push/*|*/viewmodel/*) continue ;; esac
    BASENAME=$(basename "$f" .ets)
    TEST_FILE="entry/src/test/${BASENAME}.test.ets"
    if [ ! -f "$TEST_FILE" ]; then
      grep -q "export \(function\|class\|const\|enum\|var\|let\)" "$f" || continue
      if grep -q "@skip-test" "$f" 2>/dev/null; then continue; fi
      echo "❌ 可能缺少测试: $TEST_FILE (源文件: $f)"
      HAS_MISSING=1
    fi
  done
  if [ $HAS_MISSING -ne 0 ]; then exit 1; fi
else
  HAS_MISSING=0
  for f in $(git diff --name-only --diff-filter=AR HEAD -- 'entry/src/main/ets/*.ets'); do
    case "$f" in pages/*|components/*|entryability/*|entrybackupability/*|entryworkability/*|notification/*|push/*|viewmodel/*) continue ;; esac
    BASENAME=$(basename "$f" .ets)
    TEST_FILE="entry/src/test/${BASENAME}.test.ets"
    if [ ! -f "$TEST_FILE" ]; then
      grep -q "export \(function\|class\|const\|enum\|var\|let\)" "$f" || continue
      if grep -q "@skip-test" "$f" 2>/dev/null; then continue; fi
      echo "❌ 缺少测试文件: $TEST_FILE (源文件: $f)"
      HAS_MISSING=1
    fi
  done

  for f in $(git diff --name-only --diff-filter=M HEAD -- 'entry/src/main/ets/*.ets'); do
    case "$f" in pages/*|components/*|entryability/*|entrybackupability/*|entryworkability/*|notification/*|push/*|viewmodel/*) continue ;; esac
    BASENAME=$(basename "$f" .ets)
    TEST_FILE="entry/src/test/${BASENAME}.test.ets"
    if [ -f "$TEST_FILE" ]; then
      GIT_DIFF_TEST=$(git diff --name-only --diff-filter=M HEAD -- "$TEST_FILE")
      if [ -z "$GIT_DIFF_TEST" ]; then
        echo "⚠️ WARNING: $f 已修改，但 $TEST_FILE 未同步更新。请确认是否需更新测试。"
      fi
    fi
  done

  if [ $HAS_MISSING -ne 0 ]; then exit 1; fi
fi

for f in $(git diff --name-only --diff-filter=A HEAD -- 'entry/src/test/*.test.ets'); do
  BASENAME=$(basename "$f" .ets)
  if ! grep -q "from './${BASENAME}.test'" entry/src/test/List.test.ets; then
    echo "❌ 未在 List.test.ets 中注册: ${BASENAME}.test"
    exit 1
  fi
done

echo "✅ 测试覆盖检查通过"
```

> ⚠️ WARNING 处理规则：AI 收到 WARNING 后必须检查源文件的改动范围，判断是否需要更新测试。如果不需要，必须在回复中明确说"已确认无需更新测试"；如果需要，必须直接更新测试。未确认前不得继续提交。

#### 步骤 C：编译与测试
```bash
hvigorw test 2>&1 | grep -E 'ERROR|BUILD|FAIL'
hvigorw assembleHap 2>&1 | grep -E 'ERROR|BUILD|FAIL'
```

#### 步骤 D：更新 FEATURES.md
- 新增功能后必须在 `FEATURES.md` 中追加记录（功能编号、描述、涉及文件路径、测试引用）
- 删除/修改功能后必须同步更新
- 修改后更新底部"最后更新"日期

#### 判定标准
- 步骤 B：新增源文件必须有对应测试（或属于例外清单/有 `@skip-test` 注释）
- 步骤 C：`hvigorw test` 输出必须包含 `BUILD SUCCESSFUL` 且 grep `Error in` 结果为 0
- `hvigorw assembleHap` 输出必须包含 `BUILD SUCCESSFUL` 且 grep `ERROR` 结果为 0
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
├── pages/           # 页面（27 个 .ets 文件，12 个子目录）
│   ├── Index.ets    # 主 Tab
│   ├── home/        # 发现页
│   ├── latest/      # 最新作品
│   ├── search/      # 搜索
│   ├── illust/      # 插画详情+评论
│   ├── novel/       # 小说阅读+系列+评论
│   ├── user/        # 用户主页
│   ├── login/       # 登录
│   ├── favorites/   # 收藏
│   ├── ranking/     # 排行榜
│   ├── setting/     # 设置主页/关注/屏蔽
│   └── settings/    # 详细设置/缓存/作者详情/系列详情
├── components/      # 可复用组件（13 个）
├── services/        # 业务服务（15 个）
├── store/           # 全局状态（1 个）
├── models/          # 数据模型（10 个）
├── database/        # SQLite（6 个）
├── common/          # 公用
│   ├── constants/   # 常量（4 个）
│   └── utils/       # 工具（18 个）
├── viewmodel/       # ViewModel（22 个）
├── notification/    # 通知（1 个）
├── push/            # 推送（1 个）
├── entryability/    # 应用入口（1 个）
├── entrybackupability/ # 备份扩展（1 个）
└── entryworkability/ # 工作调度（1 个）

entry/src/test/      # 单元测试目录（46 个测试文件）
entry/src/ohosTest/  # 集成测试目录
```
