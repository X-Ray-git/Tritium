# 故障排查

## 登录页持续加载

1. 使用 Debug 构建复现，筛选控制台中的 `TritiumLogin`。
2. 从 `page-init` 开始保留到 `loading-finished`、`loading-timeout`、错误事件或
   `page-dispose`。
3. `main-frame-http-error` 表示主文档收到 HTTP 错误；`main-frame-error` 表示 WebView
   网络层失败；`loading-timeout` 表示 12 秒内没有可靠的结束事件。
4. `manual-cookie-read` / `auto-cookie-read` 中 `has_z_c0=false` 表示 WebView 尚未取得
   关键登录 Cookie；`account-check-finished success=false` 表示 Cookie 已取得但用户
   接口没有接受它。

不要粘贴 Cookie 值、请求头或带查询参数的完整登录地址。

## 内容列表加载失败

- 先区分首次加载、刷新和加载更多；已有数据仍在时不要按整页失败处理。
- 记录页面、登录状态、HTTP 状态码和是否能稳定复现。
- 推荐流检查预加载缓存是否携带 `nextUrl/isEnd`；分页重复时检查刷新代次和加载锁。
- 热榜优先验证 `api.zhihu.com/topstory/hot-lists/total` 是否仍返回兼容结构。

## 构建与发布失败

- Flutter/JDK 版本先与[发布文档](release-build.md)一致。
- CI 停在签名步骤通常表示四个 Android Secrets 至少缺少一个。
- tag 校验失败时检查 `vX.Y.Z` 是否与 `pubspec.yaml` 的 `X.Y.Z+build` 对齐。
- Release 拒绝轻量 tag 是预期保护；统一使用 `scripts/release.sh` 创建 annotated tag。
