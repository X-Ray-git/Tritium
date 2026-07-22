# 发布与签名

发布流程与 Auto Folo 一致：版本提交、annotated tag、CI 校验、签名构建、GitHub
Release。当前只构建 Android APK。普通 `master` 推送不会发布版本；tag 推送或手动
运行工作流才会开始自动打包。

## 本地检查

```bash
# 先对本次修改的 Dart 文件执行 dart format
flutter analyze
flutter test
flutter build apk --debug
```

## Android 签名

本地正式签名在 `android/key.properties` 中配置：

```properties
storeFile=app/upload-keystore.jks
storePassword=...
keyAlias=...
keyPassword=...
```

以上文件和 keystore 均不得提交。GitHub Actions 需要配置：

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

## 创建版本

位于 `master` 且工作区干净时执行：

```bash
scripts/release.sh 0.2.0 -m $'- feat: ...\n- fix: ...' --push
```

脚本递增 build number、将命令写入 `docs/history/releases.md`、提交版本文件并创建
`v0.2.0` annotated tag；推送 tag 后 `.github/workflows/internal-release.yml` 会
校验、测试、签名构建并发布 APK。

本地未配置 `key.properties` 时会回退到 debug 证书，这种 APK 只能用于
验证构建。CI 会在签名 Secrets 缺失时直接失败，不会发布 debug 签名产物。

## 工作流产物

- 手动运行：上传 `tritium-android` Actions artifact，不创建 Release。
- 推送 `v*` annotated tag：上传 artifact，并以 tag 注释创建或更新 GitHub Release。
- APK 文件名为 `Tritium-android-<tag-or-ref>.apk`。

除非用户明确要求发布版本，否则只提交和推送代码，不创建 tag。

## 维护语义

用户要求“触发打包”时，含义固定为发布 Release：使用 `scripts/release.sh` 创建版本
提交和 annotated tag，推送后等待签名 APK 与 GitHub Release 发布完成。只有用户明确
要求“内部测试构建”时，才使用 `workflow_dispatch` 仅生成 Actions artifact。
