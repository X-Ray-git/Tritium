# Tritium 维护入口

本文档是后续维护者和 agent 的短入口。详细事实和操作流程位于
[`docs/`](docs/README.md) 维护型知识库。

接手时按以下顺序阅读：

1. [文档知识地图](docs/README.md)。
2. [当前状态](docs/status/current.md)与[待办](docs/status/pending.md)。
3. [测试约定](docs/operations/testing.md)。
4. 当前任务对应的架构、设计或故障排查页面。

## 不可回退的产品约束

- Tritium 是 Android 优先的知乎第三方只读客户端。
- 主导航仅包含“推荐”“热榜”和“设置”。
- 不新增点赞、关注、回复、收藏、私信、发现或 AI 功能；公开数量可以展示。
- 阅读历史和正文进度仅保存在本机，不得同步知乎服务器；页内查找当前不做。
- Android 外部链接、正文链接和历史入口必须共用 `ContentLinkService`，不另建
  平行路由表；没有原生只读页的知乎内容交给系统浏览器。
- 品牌色固定为 `#3961FF`，不从启动图标或系统动态取色。
- Android 包名为 `io.github.xraygit.tritium`。
- Hydrogen 仅作功能模块参考，Auto Folo 仅作设计、维护和发布参考；不修改参考工程。
  经用户确认需要完全一致的基础交互可以受控复用，当前例外是下拉刷新状态机。
- Hydrogen 的长期本地路径为 `reference/hydrogen/`。该目录是被根仓库忽略的独立
  Git 仓库，只读使用且可能包含签名文件；不得从 Tritium 根目录暂存、构建或发布。
  新环境缺少该目录不构成 Tritium 构建阻塞。
- Android 启动图标与 Auto Folo 一样只使用静态 `mipmap`。不要重新加入 Adaptive
  Icon，也不要把真机观察到的近似裁切范围直接当成缩放参数；详见
  [Android 设计语言](docs/design/android.md)和[决策日志](docs/history/decisions.md)。
- 文章/回答长正文必须通过 `SliverToBoxAdapter + Column` 一次布局所有语义块；
  不得在缺少稳定高度模型时恢复变量高度 `SliverList`，否则多图文章会持续修正
  正文终点并让进度条跳动。
- 根评论中的缩略跟评使用 `CompactHtmlPreview`：直接解析知乎表情，过滤普通附件，
  且不让链接接管“打开楼中楼”的整体点击行为。
- 不在日志、文档或仓库中记录 Cookie、签名参数、完整登录 URL 或密钥。
- 除非用户明确要求发布版本，否则不要创建 tag 或 GitHub Release；用户说“触发打包”
  即表示按 Auto Folo 流程创建版本提交、annotated tag 并发布 GitHub Release。
- 交付前按[测试约定](docs/operations/testing.md)完成静态检查、测试和 Android 构建。
