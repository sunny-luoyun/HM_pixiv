# HPixiv

基于 HarmonyOS 的第三方 Pixiv 精简客户端。

## 功能

- **发现页** — 浏览 Pixiv 推荐插画与小说
- **最新作品** — 查看关注用户的最新投稿
- **搜索** — 支持插画、小说、用户多维度搜索
- **用户主页** — 查看用户的插画、小说作品列表及个人资料
- **插画详情** — 查看插画大图及相关信息
- **小说阅读器** — 全功能小说阅读，支持自动阅读、阅读进度保存
- **小说系列** — 浏览小说系列作品
- **收藏管理** — 查看与管理已收藏的插画和小说
- **关注管理** — 查看关注列表
- **屏蔽管理** — 无需会员屏蔽不感兴趣小说
- **离线缓存** — 小说内容 SQLite 缓存，支持离线阅读
- **AI 翻译** — 集成 DeepSeek API，支持日文小说标题与全文的中文翻译
- **深色模式** — 跟随系统自动切换明暗主题
- **内置代理** — 导入机场链接即可实现应用内翻墙（妈妈再也不用担心我梯子出问题了）

## 食用方法

您可以使用[Auto-installer](https://github.com/likuai2010/auto-installer/)或[DevEcho Testing](https://developer.huawei.com/consumer/cn/deveco-testing/)进行安装。

## 使用环境
HarmonyOS 6.1.0（23）

## 开发环境

1. 复制 `build-profile.json5.template` 为 `build-profile.json5`
2. 在 DevEco Studio 中打开项目，`Build > Config > Signing` 配置签名
3. 配置后签名信息会自动写入 `build-profile.json5`（该文件已被 `.gitignore` 忽略，不会提交）

## 免责声明

本项目为个人学习用途的第三方客户端，与 Pixiv Inc. 无关。所有内容版权归原作者所有。请合理使用，遵守 Pixiv 服务条款。


