# ZhihuLite-HM（知乎Lite）

> **轻量级知乎第三方客户端 · HarmonyOS NEXT 原生版**
>
> 上游 [zhihu--](https://github.com/luckylew23/zhihu--)（v0.6.0，React Native / Expo）的完整原生移植：
> 复用上游纯 TypeScript 业务逻辑，UI 用 ArkTS 原生重写，界面与 Android 版一致。

[![版本](https://img.shields.io/badge/版本-v0.3.12-blue)](#版本历史) [![平台](https://img.shields.io/badge/平台-HarmonyOS%20NEXT-black)](#) [![架构](https://img.shields.io/badge/架构-原生ArkTS-green)](#架构概览)

---

## 简介

知乎Lite 是知乎的第三方鸿蒙客户端，主打**轻量、快速、功能完整**：

- **完整功能**：关注 / 推荐 / 热榜 / 日报 / 搜索 / 收藏 / 互动 / 创作（写回答、写文章、发想法、提问）
- **原生体验**：纯 ArkTS 重写，无 WebView 壳，点击响应快
- **界面一致**：对照 Android 版原样复制的深色主题与交互
- **独立身份**：应用名"知乎Lite"、独立包名 `com.zhihulite.hmos`，与原版互不冲突，可共存安装

## 特性速览

- **离线缓存**：热榜 / 日报进入即缓存，两天内断网也能看

| 模块 | 能力 |
|---|---|
| 首页栏目 | 关注 / 推荐 / 热榜 / 日报，可配置展示，默认推荐 |
| 内容详情 | 问题、回答、文章、想法、视频、专栏、话题（原生详情页） |
| 互动创作 | 点赞 / 收藏 / 关注 / 评论 / 写回答 / 写文章 / 发想法 / 提问 |
| 搜索 | 综合 / 用户双 tab，登录后使用 |
| 个人中心 | 我的收藏（内容+分类）、历史、通知、私信、赞同、他人主页 |
| 设置 | 主题（自动/浅色/深色）、栏目、默认首页、内容过滤 |
| 可发现性 | 包内搜索关键词（知乎/zhihu/lite/轻量/知乎第三方/知乎鸿蒙版等） |

## 更多文档

快速开始（环境/构建/安装）、架构概览、项目结构、文档索引、版本历史等详见 [projectdesign.md](projectdesign.md)（唯一事实来源）。

## 已知限制

- 富文本/LaTeX 正文为纯文本渲染（剥 HTML 标签）
- 私信为 HTTP 轮询降级（无 WebSocket）
- 发布图片上传 OSS 未实现
- 日报正文纯文本、设置部分静态
- 应用市场搜索关键词主配置需在 AGC 发布后台补充

## 致谢

- [zhihu--](https://github.com/luckylew23/zhihu--)：上游 React Native 知乎客户端（MIT）
