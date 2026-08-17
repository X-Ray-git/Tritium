# 验证记录

## 2026-08-17：Flutter 3.47 工具链适配

- 本机与发布工作流基线从 Flutter 3.44.6 对齐到 Flutter 3.47.0、Dart 3.13.x；CI
  Java 从 Temurin 17 对齐到 JDK 21，与本机标准 `flutter build` 使用的 Android
  Studio JDK 主版本一致。
- Flutter 3.47 严格解析旧锁文件会失败；已由新版 SDK 更新 `intl`、`matcher`、
  `meta`、`test_api` 和 `vector_math` 五个关联依赖，未连带升级其他业务依赖。
- 更新后的锁文件已通过 `flutter pub get --enforce-lockfile`，发布 CI 同步启用严格
  锁文件校验，SDK 与锁文件不一致时会在构建前明确失败。
- 新版 `flutter pub get` 生成的平台目录分析排除项已纳入 `analysis_options.yaml`，
  避免分析构建产物和平台生成目录。
- 原测试有 4 项稳定失败：回答横滑、标题滚动几何、图片横滑和下拉刷新反悔。
  最小 `PageView`/`ListView` 探针正常；页面切换改用带速度的 `fling`、精确滚动改用
  分帧 `timedDrag`、原始指针改用递增时间戳后全部通过。生产手势代码无需为测试
  合成事件调整。
- `dart format`：3 个测试文件无格式变化。
- `dart analyze`：通过，无诊断。
- `flutter test`：135 项全部通过。
- `flutter build apk --debug`：通过。
- `flutter build apk --release`：通过，产物 67.3MB；本地未配置正式密钥时继续使用
  既有 Debug 签名回退。
- `git diff --check`：通过。

Flutter 3.47 对 Gradle 8.14、AGP 8.11.1 和 Kotlin 2.2.20 给出未来停止支持预警，
但本轮双构建均通过；这三项保留为单独的 Android 构建链升级，不阻塞当前适配。

## 2026-08-12：同类型内容链接真机闭环

- 真机日志证明触摸命中、HTML 回调和 URL 类型解析均正常；专栏能打开而问题/回答
  无响应的差异发生在导航层。实测链接是 `question/{id}/answer/{id}`，已正确解析为
  answer，但当前页同为 `/answer` 时被 GetX 默认的同名路由去重静默拒绝。
- 同一次真机单击还会依次触发 SelectionArea 命中兜底与 flutter_html 原生回调。
  放开同名路由而不处理该事实会连续压入两个页面，因此最终方案同时完成两件事：
  所有原生内容路由显式允许同类型不同 ID 入栈；按 `kind + id` 在 500ms 内合并同一
  物理点击的重复回调。窗口结束后可再次正常访问同一目标，不锁定到页面返回。
- 审计所有直接 `Get.toNamed` 入口：其上下文均为首页→内容、问题→回答、回答→问题、
  用户→回答/文章等不同路由；同类型正文跳转统一收口在 `ContentLinkService`，未发现
  第二处仍会触发同名路由静默拦截的入口。
- 真机复验：回答正文内的专栏链接与问题+回答组合链接均可正确进入目标页面。
- Debug 构建新增 `.debug` 包名后缀，可与正式版并存并保留正式版本地历史。
- `dart analyze`：通过，无诊断。
- 链接定向测试 17 项通过，覆盖 SelectionArea→回答整链路、问题/回答/文章/想法/用户
  同类型跳转、同次双回调只入栈一次，以及 500ms 后可再次访问同一目标。
- `flutter test`：135 项全部通过。
- `flutter build apk --debug` 与 `flutter build apk --release`：均通过；本地 Release
  产物 66.7MB，未配置正式密钥时按既有策略使用 Debug 签名回退。
- `git diff --check`：通过。

## 2026-08-12：正文 SelectionArea 链接点击补全

- 用户从阅读历史重新打开既有专栏文章后，正文问题链接仍无法点击；确认与历史缓存、
  文章新旧无关，任何入口都会复现。
- 复盘发现 `v0.4.1` 只修复了 GetX 对 `/question` 同名路由的重复拦截，旧测试把 HTML
  点击、URL 解析和路由分别验证，却没有把 `CustomHtml` 放进详情页真实使用的
  `SelectionArea`。组件级复现证明选择区域会让 `RenderParagraph` 不再把 pointer
  交给 TextSpan 的普通点击识别器，因此事件根本尚未到达 URL/路由层。
- 新实现保留系统文本选择与 HTML 的 InlineSpan 结构，在选择模式的 pointer hit-test
  中精确定位实际命中的链接 span；只有短距离、短时长单击才触发链接，拖动滚动和
  长按选择均不触发。
- `dart analyze`：通过，无诊断。
- 定向测试 11 项通过，覆盖普通/嵌套/相对链接、SelectionArea 内问题链接、从链接
  起手滚动不误跳转、长按选择不误跳转、无 href/页内 anchor 和评论图片链接。
- `flutter test`：129 项全部通过。
- `flutter build apk --debug`：通过。

该修复后来随替换发布的 `v0.4.1+7` 进入 Release；它解决了 SelectionArea 吞点击，
但仍未覆盖回答→回答的 GetX 同名路由拦截，后者由本页上方的真机闭环继续修正。

## 2026-08-12：评论宽度与问题内链补丁

- 修复根评论缩略跟评宽度随文字长度变化：预览卡片固定占满父内容宽度；楼中楼弹层
  使用扣除左右安全区后的固定宽度，加载态、错误态和不同长度评论不再改变面板宽度。
- 定位并修复问题链接点击无反应：URL 解析一直能够识别 `/question/{id}`，实际原因是
  GetX 默认只按 `/question` 路由名去重，在问题页打开另一个问题时会静默拒绝导航；
  问题内链现在允许同名路由携带不同内容 ID 继续入栈。
- `dart analyze`：通过，无诊断。
- `flutter test`：126 项通过。新增覆盖短/长跟评同宽、安全区域面板约束，以及从一个
  问题路由打开另一个问题路由的完整导航链路；既有 URL 解析和 HTML 点击测试继续通过。
- `flutter build apk --debug`：通过。
- `git diff --check`：通过。

仍需真机确认不同屏幕安全区下的评论宽度，以及真实问题正文中的问题链接、返回栈与
连续多次跳转行为。

## 2026-08-08：正文体验、链接、首页横滑、回答分页与统计统一

- 背景问题现象：
  - 正文里的站内链接几乎不可用：链接被压成纯文本，协议相对、相对路径、
    `link.zhihu.com` 跳转和 `zhihu://` deep link 无法识别，站内目标会误进浏览器。
  - 行内代码没有正确 baseline 对齐，代码块是默认浏览器样式；回答页底栏点赞/
    评论数在正文未加载时短暂显示 0；问题浏览量用 `read_count` 且缺失时显示 0；
    热榜把眼睛图标绑定到 `follower_count` 冒充浏览量。
  - 首页三个主页不能左右滑动；回答页把问题页已加载的 ID 快照末尾误认为全部
    回答末尾，分页无法继续。
- `dart analyze`：通过，无诊断。
- `flutter test`：123 项通过。新增/扩充覆盖：
  - URL 解析矩阵（完整/相对/协议相对/`link.zhihu.com` target/`zhihu://` 单复数/
    question+answer 组合/zhuanlan/appview/oia/people/org/视频/外部/非法 scheme/
    循环与超深 redirect、query/fragment 保留、畸形内容 ID 拒绝）。
  - HTML 链接（普通文字链接可点击、嵌套 span 保留、评论图片缩略图 8px 圆角、
    无 href 不可点击、`#` 脚注不进浏览器、相对知乎链接走同一处理器）。
  - 代码渲染（inline code 非块、`<pre><code>` 单容器、长代码横向滚动、复制按钮
    1.2 秒勾选态恢复）。
  - 统计语义（`visit_count` 优先、`read_count` 兜底、未知值不是 0、拒绝非有限值和
    负数、热榜不再用 follower_count 冒充浏览量、真实顶层热度/标签字段、`—` 显示）。
  - 首页（横滑同步导航、点击导航动画切页、重复点击保留、页面保活、设置页 Switch
    不被 PageView 抢手势）。
  - 回答分页（种子游标继续加载、单回答入口补全、ID/重复 cursor/空页/整页重复、失败重试、
    is_end 停止、预取阈值、当前回答固定在首位、种子带游标不触发首屏补齐）。
  - 回答页底栏加载前显示 “—” 的组件级验证。
  - 专栏封面宽/高比例与非法尺寸回退、五列表格约束不异常。
- `flutter build apk --debug`：通过。
- 设置页 Switch 手势测试使用注入的纯测试页面，避免把 Hive 异步写入带进 Widget
  测试的 FakeAsync；`tearDownAll` 会真实等待 `GStorage.close()`，不再以超时掩盖
  未完成的资源关闭。

本轮仍需真机覆盖：首页三页横滑与 Switch 手势共存、回答连续多页预取与占位页
手感、正文链接真实跳转矩阵、代码块复制、文本选择与链接/图片手势共存；详见
[真机验收清单](device-acceptance.md)。

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
  `C677B8C96FE220664BBA662E0ED7F645691C027167997261C1ABFD6E34DC43A3`，与 Fourier
  本地 keystore 证书一致。
- 本次为 `workflow_dispatch` 内部构建，没有创建 tag 或 GitHub Release。

## 2026-07-22：阅读交互与刷新验收

- `dart analyze`：通过，无诊断。
- `flutter test`：22 项通过，覆盖回答横滑、HTML 分块、评论预加载、图片缩放平移、
  下拉刷新状态机及 AppBar 边界。
- `flutter build apk --debug`：通过。
- 真机确认下拉刷新反悔时圆环能够沿 Fourier 的路径回到 AppBar 边界，问题已解决。
- 真机确认回答正文深度阅读后反向滚动不会提前展开标题，固定 AppBar 不再出现边界
  弹性抖动。
- 真机确认设置页首张卡片使用正确的 AppBar 顶部安全距离，不再被顶栏遮挡。

## 2026-07-22：v0.2.0 发布流程诊断

- tag 工作流 run `29896803970` 在准备 Android job 时失败，未进入分析、签名或构建。
- 原因是参考工程当时使用的 `actions/setup-java@v6` 在 GitHub Actions 中不存在。
- Tritium 恢复使用已验证可用的 `actions/setup-java@v5`；发布结构继续参考 Fourier，
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

## 2026-07-31：评论区自动加载下一页

- 背景：评论组件内联嵌在外层滚动视图里，原尾部固定“查看更多评论”按钮需手动点击。
- 审查否决了“后代 `NotificationListener` + 把 reveal offset 当屏幕坐标”的初版：
  它收不到父滚动事件，且在长正文中使用错误坐标，详见[决策日志](../history/decisions.md)
  2026-07-31 条目。
- `dart analyze`：通过，无诊断。
- `flutter test test/comment_auto_load_test.dart`：7 项通过。
- `flutter test`：44 项通过。新增覆盖同一滚动坐标系的纯几何判断、长正文真实父
  `CustomScrollView` 滚动触发、短内容自动补页、重复游标停止，以及加载更多失败后
  成功切换排序清理错误。排序测试同时覆盖玻璃弹层必须用 `Material` 承载 ListTile
  ink 的回归。
- `flutter build apk --debug`：通过。
- 核心改动：`inline_comment_widget.dart` 使用祖先纵向 `ScrollPosition`、哨兵和
  三态尾部；`comment_auto_load.dart` 统一几何公式；`app_chrome.dart` 修正弹层
  Material 层级；`comment_auto_load_test.dart` 提供真实滚动与状态回归。
- 仍需真机确认固定预加载距离在不同屏幕、长短正文和连续多页真实接口中的手感，
  已记录在[待办](pending.md)与[真机验收清单](device-acceptance.md)。

## 2026-07-31：推荐会话去重、反馈与正文拖动

- `dart analyze`：通过，无诊断。
- `flutter test`：56 项通过。
- `flutter build apk --debug`：通过。
- 新增推荐身份测试覆盖 `target`、序列化 `brief`、`common_card` 跳转 URL，以及同页
  和跨刷新会话去重；不受支持的想法目标不会生成猜测反馈。
- 新增推荐控制器测试确认：刷新整页替换为本会话新内容；服务端全重复时保留原列表
  并停止分页；空新增页不会重复触发加载更多。
- 新增反馈服务测试确认：五条触达批量发送，点击已读立即冲刷等待触达，同时发生的
  点击不会因已有请求在途而丢失。
- 阅读进度 Widget 测试新增顶部横向拖动、短正文禁用和正文进度到实际滚动位置的
  双向映射；既有“视口下边缘到正文末尾为 100%”与评论高度稳定性测试继续通过。
- 真实知乎账户的反馈接受情况、推荐新鲜度、顶部拖动与纵向滚动/回答横滑手势竞争
  仍必须真机验收。
