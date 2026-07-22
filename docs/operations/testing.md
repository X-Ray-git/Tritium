# 测试约定

## 日常改动

先格式化本次修改的 Dart 文件，然后执行：

```bash
dart analyze
flutter test
flutter build apk --debug
```

涉及签名、Gradle、包名、Manifest、依赖或发布工作流时，再执行：

```bash
flutter build apk --release
```

## 当前自动测试覆盖

- `PagingInfo` 对下一页、末页和缺失分页字段的处理。
- 主导航只展示推荐、热榜和设置，并保持页面状态。
- 评论点赞数保持可见但不可操作。
- 下拉刷新反悔阶段的列表锁定、真实状态机拖拽量及 AppBar 边界。
- 图片双击缩放后的实际矩阵倍率和平移能力。
- 深度阅读后反向滚动时的标题显隐，以及设置页首屏与 AppBar 的安全距离。
- 知乎内容链接的识别、应用内路由与外部回退。
- 用户回答/文章分页合并、并发锁、旧请求失效和失败保留。
- 应用版本迁移与本地存储兼容规则。

## 真机边界

WebView Cookie、真实知乎风控、高刷新率、系统浏览器/相册联动以及复杂屏幕布局无法由
桌面测试完全替代，统一记录在[真机验收清单](../status/device-acceptance.md)。

验证完成后在[验证记录](../status/verification.md)记录日期、命令和仍未覆盖的边界。
