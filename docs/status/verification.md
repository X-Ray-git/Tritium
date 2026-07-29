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

仍未覆盖的项目集中在[真机验收清单](device-acceptance.md)。

## 2026-07-19：GitHub 正式签名构建

- Tritium 仓库已配置四项 Android 签名 Secrets，值不写入仓库或日志。
- GitHub Actions run `29691980662`：版本校验、分析、13 项测试、签名、Release APK
  构建和 artifact 上传全部通过。
- APK 证书 SHA-256 为
  `C677B8C96FE220664BBA662E0ED7F645691C027167997261C1ABFD6E34DC43A3`，与 Auto Folo
  本地 keystore 证书一致。
- 本次为 `workflow_dispatch` 内部构建，没有创建 tag 或 GitHub Release。

## 2026-07-22：阅读交互与刷新验收

- `dart analyze`：通过，无诊断。
- `flutter test`：22 项通过，覆盖回答横滑、HTML 分块、评论预加载、图片缩放平移、
  下拉刷新状态机及 AppBar 边界。
- `flutter build apk --debug`：通过。
- 真机确认下拉刷新反悔时圆环能够沿 Auto Folo 的路径回到 AppBar 边界，问题已解决。
- 真机确认回答正文深度阅读后反向滚动不会提前展开标题，固定 AppBar 不再出现边界
  弹性抖动。
- 真机确认设置页首张卡片使用正确的 AppBar 顶部安全距离，不再被顶栏遮挡。

## 2026-07-22：v0.2.0 发布流程诊断

- tag 工作流 run `29896803970` 在准备 Android job 时失败，未进入分析、签名或构建。
- 原因是参考工程当时使用的 `actions/setup-java@v6` 在 GitHub Actions 中不存在。
- Tritium 恢复使用已验证可用的 `actions/setup-java@v5`；发布结构继续参考 Auto Folo，
  但第三方 action 版本必须以 Tritium 的实际 CI 验证结果为准。

## 2026-07-22：v0.2.1 正式发布

- GitHub Actions run `29897040318`：版本校验、分析、22 项测试、正式签名、Release
  APK 构建、artifact 上传和 GitHub Release 发布全部通过。
- Release：`v0.2.1`，版本号 `0.2.1+3`，非草稿、非预发布。
- APK：`Tritium-android-v0.2.1.apk`，SHA-256 为
  `bcccd61dd83de9601bd2a4f758dd9cf6e8e74228d8fd2097b8d7347922fb4596`。

## 2026-07-29：阅读能力、导航、图标与评论预览整合

- `dart analyze`：通过，无诊断。
- `flutter test`：35 项通过。新增覆盖内容链接外部兜底、本地阅读历史与进度、
  `<figure>` 图片宽度、长正文稳定布局，以及缩略跟评的方括号/HTML 表情加载与
  普通附件过滤。
- `flutter build apk --debug`：通过。
- `flutter build apk --release`：通过，产物 65.6MB；本地使用 debug 签名回退，
  本次普通提交不创建 tag 或 GitHub Release。
- Debug APK 已检查只包含五档静态 `mipmap/ic_launcher.png`，不包含 Adaptive Icon
  XML、foreground 或 background 资源。
- 真机确认多图文章的阅读进度条不再随滚动逐块跳动。

本轮仍需真机覆盖外部链接冷启动/运行中复用、阅读位置恢复、缩略跟评表情、新导航
在不同系统栏模式下的阴影，以及不同启动器的静态图标处理；详见
[真机验收清单](device-acceptance.md)。

## 2026-07-29：阅读进度终点语义

- `dart analyze`：通过，无诊断。
- `flutter test`：37 项通过。
- 新增 Widget 测试确认：正文末尾对齐视口下边缘时进度为 100%，此时评论仍可继续
  滚动；评论高度变化不改变中途进度；正文初始已完整位于视口内时直接为 100%。
- `flutter build apk --debug`：通过。
- 长短正文的实际 AppBar 视觉与保存位置恢复仍保留在真机验收清单中。
