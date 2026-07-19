# 隐私与安全

## 本地数据

Hive 使用 `settings`、`user` 和 `cache` 三个 Box。登录 Cookie 和用户信息仅保存在
应用本地 `user` Box；退出登录会清空用户数据。

## 网络边界

- Cookie 只附加到 `zhihu.com` 及其子域请求，禁止发送给外部站点。
- TLS 使用系统信任链，不绕过证书校验。
- 外部链接由系统浏览器处理，不在 Tritium 的登录 WebView 中长期浏览。

## 日志规则

禁止记录 Cookie 值、Authorization、签名参数、完整请求头、带查询参数的登录 URL
和真实密钥。登录 Debug 检查点只能记录安全 URL、状态码、Cookie 数量以及关键
Cookie 是否存在。

## 仓库与 CI

`android/key.properties`、keystore、构建产物和本地日志均不得提交。正式签名只通过
本地忽略文件或 GitHub Actions Secrets 注入。
