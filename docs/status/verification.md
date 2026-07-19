# 验证记录

## 2026-07-19：真机验收前基线

- `dart analyze`：通过，无诊断。
- `flutter test`：13 项通过。
- `flutter build apk --debug`：通过。
- `flutter build apk --release`：通过，产物约 63.1MB；本地使用 debug 签名回退。
- `scripts/release.sh`：在隔离的临时 Git 仓库验证版本递增、历史记录、版本提交和
  annotated tag，未在真实仓库创建 tag。
- GitHub Actions 引用的 action 主版本 tag 已逐项在官方远端确认存在。
- 登录页 Debug 检查点未输出 Cookie 值或 URL 查询参数。

仍未覆盖的项目集中在[真机验收清单](device-acceptance.md)。GitHub Actions 的正式
签名构建还取决于仓库中四个 Android Secrets 是否已经配置。
