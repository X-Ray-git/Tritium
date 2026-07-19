# 网络与登录

## 请求层

`lib/http/init.dart` 提供 Dio 单例和 Cookie 拦截器，业务端点按领域放在
`lib/http/*_http.dart`。请求失败转换成包含状态码和用户可读信息的结果，页面负责
区分首次加载、刷新和加载更多失败。

## 域名策略

- `api.zhihu.com` 使用知乎 Android 客户端兼容请求头，可在有登录态时附加 Cookie。
- `www.zhihu.com` 在有 Cookie 时生成 Web 端 ZSE96 请求头。
- 其他知乎子域只允许附加 Cookie，不套用 API 或 Web 签名策略。
- 非知乎域名绝不附加 Cookie。

TLS 由系统 `HttpClient` 校验，不设置 `badCertificateCallback`。

## WebView 登录

登录页打开 `https://www.zhihu.com/signin`，通过 `z_c0` 判断是否取得登录态，再调用
当前用户接口验证 Cookie。验证失败时不会把无效 Cookie 保存在本地。

Debug 构建的登录日志统一使用 `TritiumLogin` 前缀，只记录事件顺序、安全 URL、
HTTP 状态和 Cookie 存在性。加载进度到 100% 但缺少 `onLoadStop` 时，500ms 后移除
遮罩；单次导航超过 12 秒也会移除遮罩并记录 `loading-timeout`。

## 上游风险

知乎接口、ZSE96 规则、WebView 登录页面和风控均不是公开稳定 API。遇到失败时先按
[故障排查](../operations/troubleshooting.md)收集状态，再区分客户端状态机和上游变化。
