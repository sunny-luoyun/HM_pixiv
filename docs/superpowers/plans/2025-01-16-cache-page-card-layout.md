# 缓存页面卡片化重构实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将"我的缓存小说"页面从单列列表重构为三列网格卡片布局

**Architecture:** 使用 ArkUI 的 `Grid` + `GridItem` 替代 `List` + `ListItem`，实现三列等宽网格布局。卡片内容精简为作者名+数量，删除交互改为长按弹出确认对话框。

**Tech Stack:** ArkUI 声明式 UI、TypeScript、HarmonyOS NEXT API 12+

## Global Constraints

- HarmonyOS NEXT (API 12+) ArkTS 项目
- UI 框架：ArkUI 声明式（@Component、@State、@Prop 等装饰器）
- 构建系统：Hvigor
- 测试框架：@ohos/hypium
- 页面文件位于 `entry/src/main/ets/pages/` 下，属于例外清单，无需创建测试

---

## File Structure

| 文件 | 职责 | 操作 |
|------|------|------|
| `entry/src/main/ets/pages/settings/CachedNovelsPage.ets` | 缓存页面主组件 | 修改 |

---

## Task 1: 重构布局为 Grid 网格

**Files:**
- Modify: `entry/src/main/ets/pages/settings/CachedNovelsPage.ets:307-318`

**Interfaces:**
- Consumes: `this.authorGroups` (AuthorGroup[])
- Produces: 三列网格布局

- [ ] **Step 1: 将 List 替换为 Grid**

找到第 307-318 行的 List 组件：

```typescript
// 当前代码
List({ space: 10 }) {
  ForEach(this.authorGroups, (ag: AuthorGroup) => {
    ListItem() {
      this.AuthorCard(ag)
    }
  }, (ag: AuthorGroup): string => ag.authorId)
}
.width('100%')
.layoutWeight(1)
.edgeEffect(EdgeEffect.Spring)
.padding({ left: 16, right: 16, top: 8, bottom: 16 })
```

替换为：

```typescript
Grid() {
  ForEach(this.authorGroups, (ag: AuthorGroup) => {
    GridItem() {
      this.AuthorCard(ag)
    }
  }, (ag: AuthorGroup): string => ag.authorId)
}
.columnsTemplate('1fr 1fr 1fr')
.columnsGap(10)
.rowsGap(10)
.width('100%')
.layoutWeight(1)
.edgeEffect(EdgeEffect.Spring)
.padding({ left: 16, right: 16, top: 8, bottom: 16 })
```

- [ ] **Step 2: 验证编译**

Run: `hvigorw assembleHap 2>&1 | grep -E 'ERROR|BUILD|FAIL'`
Expected: BUILD SUCCESSFUL, no errors

- [ ] **Step 3: Commit**

```bash
git add entry/src/main/ets/pages/settings/CachedNovelsPage.ets
git commit -m "refactor: 将缓存页面布局从 List 改为 Grid 三列网格"
```

---

## Task 2: 精简卡片内容

**Files:**
- Modify: `entry/src/main/ets/pages/settings/CachedNovelsPage.ets:346-419`

**Interfaces:**
- Consumes: `ag` (AuthorGroup)
- Produces: 精简版 AuthorCard Builder

- [ ] **Step 1: 重构 AuthorCard Builder**

找到第 346-419 行的 AuthorCard Builder，将其从横向布局改为纵向卡片布局：

```typescript
@Builder
AuthorCard(ag: AuthorGroup) {
  Column() {
    // 圆形头像
    Column() {
      Text(ag.authorName.charAt(0).toUpperCase())
        .fontSize(18)
        .fontColor(Color.White)
        .fontWeight(FontWeight.Bold)
    }
    .width(46).height(46)
    .borderRadius(23)
    .backgroundColor($r('app.color.tab_selected'))
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)

    // 作者名
    Text(ag.authorName)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.user_name'))
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .width('100%')
      .textAlign(TextAlign.Center)
      .margin({ top: 8 })

    // 小说数量
    Text(`${ag.totalCount} 本`)
      .fontSize(12)
      .fontColor($r('app.color.text_secondary'))
      .margin({ top: 4 })
  }
  .width('100%')
  .padding(12)
  .backgroundColor($r('app.color.card_bg'))
  .borderRadius(12)
  .shadow({ radius: 4, color: $r('app.color.card_shadow'), offsetY: 1 })
  .alignItems(HorizontalAlign.Center)
}
```

- [ ] **Step 2: 验证编译**

Run: `hvigorw assembleHap 2>&1 | grep -E 'ERROR|BUILD|FAIL'`
Expected: BUILD SUCCESSFUL, no errors

- [ ] **Step 3: Commit**

```bash
git add entry/src/main/ets/pages/settings/CachedNovelsPage.ets
git commit -m "refactor: 精简作者卡片内容为作者名+数量"
```

---

## Task 3: 添加长按删除交互

**Files:**
- Modify: `entry/src/main/ets/pages/settings/CachedNovelsPage.ets:346-419`

**Interfaces:**
- Consumes: `ag` (AuthorGroup)
- Produces: 长按手势 + 删除确认对话框

- [ ] **Step 1: 添加长按手势到 AuthorCard**

在 AuthorCard Builder 的 Column 组件上添加长按手势：

```typescript
@Builder
AuthorCard(ag: AuthorGroup) {
  Column() {
    // ... 卡片内容（同 Task 2）
  }
  .width('100%')
  .padding(12)
  .backgroundColor($r('app.color.card_bg'))
  .borderRadius(12)
  .shadow({ radius: 4, color: $r('app.color.card_shadow'), offsetY: 1 })
  .alignItems(HorizontalAlign.Center)
  .gesture(
    LongPressGesture()
      .onAction(() => {
        this.showDeleteConfirm(ag);
      })
  )
  .onClick(() => {
    this.openAuthorDetail(ag);
  })
}
```

- [ ] **Step 2: 重命名删除方法**

将现有的 `deleteAuthorCache` 方法重命名为 `showDeleteConfirm`，并更新其实现：

```typescript
showDeleteConfirm(ag: AuthorGroup) {
  AlertDialog.show({
    title: '删除作者缓存',
    message: `确定删除「${ag.authorName}」的全部 ${ag.totalCount} 本缓存吗？`,
    autoCancel: true,
    primaryButton: {
      value: '取消',
      action: () => {}
    },
    secondaryButton: {
      value: '删除',
      fontColor: '#FF4D4F',
      action: async () => {
        const all: PixivNovel[] = [
          ...ag.standaloneNovels,
          ...Array.from(ag.seriesMap.values()).flatMap(sg => sg.novels),
        ];
        for (const n of all) {
          await pixivCacheDB.deleteCachedText(n.id);
        }
        promptAction.showToast({ message: `已删除「${ag.authorName}」的全部缓存` });
        await this.loadCachedNovels();
      }
    }
  });
}
```

- [ ] **Step 3: 删除旧的 deleteAuthorCache 方法调用**

删除原 AuthorCard 中第 398-404 行的删除按钮代码：

```typescript
// 删除以下代码
Row({ space: 8 }) {
  Button() {
    Text('🗑').fontSize(15)
  }
  .width(34).height(34)
  .backgroundColor($r('app.color.danger_bg'))
  .borderRadius(17)
  .onClick(() => { this.deleteAuthorCache(ag) })

  Text('›')
    .fontSize(24)
    .fontColor($r('app.color.text_secondary'))
}
```

- [ ] **Step 4: 验证编译**

Run: `hvigorw assembleHap 2>&1 | grep -E 'ERROR|BUILD|FAIL'`
Expected: BUILD SUCCESSFUL, no errors

- [ ] **Step 5: Commit**

```bash
git add entry/src/main/ets/pages/settings/CachedNovelsPage.ets
git commit -m "feat: 添加长按删除交互，移除卡片内删除按钮"
```

---

## Task 4: 验证与清理

**Files:**
- Verify: `entry/src/main/ets/pages/settings/CachedNovelsPage.ets`

**Interfaces:**
- 验证所有功能正常工作

- [ ] **Step 1: 完整编译验证**

Run: `hvigorw assembleHap 2>&1 | grep -E 'ERROR|BUILD|FAIL'`
Expected: BUILD SUCCESSFUL, no errors

- [ ] **Step 2: 检查代码规范**

确认：
- 无未使用的导入
- 无未使用的变量
- 代码格式一致

- [ ] **Step 3: 最终 Commit（如有格式修复）**

```bash
git add entry/src/main/ets/pages/settings/CachedNovelsPage.ets
git commit -m "style: 代码格式清理"
```

---

## 手工验证清单

完成所有 Task 后，请在设备上验证：

- [ ] 三列网格布局正确显示
- [ ] 卡片内容精简（作者名+数量）
- [ ] 点击卡片进入作者详情
- [ ] 长按弹出删除确认对话框
- [ ] 删除后列表刷新
- [ ] 排序功能正常
- [ ] 不同屏幕尺寸适配良好
- [ ] 空列表显示"暂无已缓存的小说"
- [ ] 加载中显示 LoadingProgress
