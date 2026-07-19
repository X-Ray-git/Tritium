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
- 主导航仅包含“内容”和“设置”。
- 不新增点赞、关注、回复、收藏、私信、发现或 AI 功能；公开数量可以展示。
- 品牌色固定为 `#3961FF`，不从启动图标或系统动态取色。
- Android 包名为 `io.github.xraygit.tritium`。
- Hydrogen 仅作功能模块参考，Auto Folo 仅作设计、维护和发布参考；不修改参考工程。
- 不在日志、文档或仓库中记录 Cookie、签名参数、完整登录 URL 或密钥。
- 除非用户明确要求发布版本，否则不要创建 tag 或 GitHub Release。
- 交付前按[测试约定](docs/operations/testing.md)完成静态检查、测试和 Android 构建。
