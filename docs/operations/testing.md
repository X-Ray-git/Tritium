# 测试约定

## 工具链基线

- Flutter `3.47.0`、Dart `3.13.x`。
- Android 构建使用 JDK 21；GitHub Actions 使用 Temurin 21，本机标准
  `flutter build` 使用 Android Studio 内置 JDK 21。
- `pubspec.lock` 必须由 Flutter 3.47 生成。升级 Flutter 时应在同一提交中同步 CI
  固定版本和锁文件，升级前不得用新 SDK 单独提交锁文件。
- 日常 Android 构建统一从 `flutter build` 进入。直接运行 `./gradlew` 可能改用系统
  `JAVA_HOME`；该路径不是当前验证基线。

Flutter 3.47 已对 Gradle 8.14、Android Gradle Plugin 8.11.1 和 Kotlin 2.2.20
给出“即将停止支持”预警，但三者当前仍可完成 Debug/Release 构建。构建链的大版本
升级单独规划和验证，不与 Flutter SDK 适配混在同一次变更中。

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

Android Debug 构建使用 `io.github.xraygit.tritium.debug` 和 “Tritium Debug” 名称，
可与正式版并行安装。涉及正式版本地历史、签名覆盖或线上数据对比的真机诊断，应优先
使用并行 Debug 包，避免为了 `flutter run` 卸载正式版并丢失本地状态。

## 当前自动测试覆盖

- `PagingInfo` 对下一页、末页和缺失分页字段的处理。
- 主导航只展示推荐、热榜和设置，并保持页面状态。
- 评论点赞数保持可见但不可操作。
- 下拉刷新反悔阶段的列表锁定、真实状态机拖拽量及 AppBar 边界。
- 图片双击缩放后的实际矩阵倍率和平移能力。
- 深度阅读后反向滚动时的标题显隐，以及设置页首屏与 AppBar 的安全距离。
- 知乎内容链接的识别、应用内路由与外部回退。
- 本地阅读历史的去重、进度保留、单项删除和清空。
- 阅读进度条值更新、正文末尾对齐视口下边缘时满格、短正文初始满格，以及长正文
  所有语义块使用单个稳定 Sliver 一次布局。
- 正文 `<figure>` 不产生固定横向留白，显式图片宽度仍然生效。
- 缩略跟评直接创建方括号/HTML 表情图片，同时过滤普通图片附件。
- 用户回答/文章分页合并、并发锁、旧请求失效和失败保留。
- 评论自动加载：长内容真实父滚动触发、短内容首帧补页、视口几何、重复游标停止、
  加载更多错误在排序成功后清理，以及排序玻璃弹层的 Material/Ink 层级。
- 应用版本迁移与本地存储兼容规则。

## 手势测试约定

页面切换等带有停稳语义的操作使用带速度的 `fling`；需要精确验证滚动距离和标题
阈值时使用分帧的 `timedDrag`。直接通过 `TestGesture` 验证同一手势内的状态变化时，
必须逐帧递增时间戳并先越过手势阈值，不能把整段位移作为时间戳为零的单个事件。
这既更接近真机输入，也避免 Flutter 手势仲裁升级后产生没有业务意义的假失败。

## 真机边界

WebView Cookie、真实知乎风控、高刷新率、系统浏览器/相册联动以及复杂屏幕布局无法由
桌面测试完全替代，统一记录在[真机验收清单](../status/device-acceptance.md)。

验证完成后在[验证记录](../status/verification.md)记录日期、命令和仍未覆盖的边界。
