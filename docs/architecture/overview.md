# 架构概览

Tritium 采用按页面模块组织的轻量 Flutter 架构。当前体量下不引入额外分层框架，
但保持以下边界：

- `lib/http/`：Dio 初始化、鉴权参数和各业务接口。
- `lib/models/`：跨页面复用、可单测的数据规则，例如统一分页信息。
- `lib/services/`：账户、预加载、运行时版本等应用级能力。
- `lib/pages/`：内容、详情、评论、设置等页面和局部控制器。
- `lib/common/`：主题与通用展示组件，不直接发起业务请求。
- `lib/utils/`：存储和无状态工具。

## 加载约定

参考 Hydrogen 的页面模型思路，每个列表需要明确区分首次加载、刷新、加载更多和
加载更多失败。分页统一通过 `PagingInfo` 解析；请求期间必须有并发锁，页面销毁或
刷新后必须忽略旧请求结果。已有内容刷新失败时保留旧内容并给出轻提示。

列表加载更多以自动加载为默认行为：独立列表（推荐流）监听自身滚动 `extentAfter`；
内联评论通过 `Scrollable.maybeOf(context, axis: Axis.vertical)` 订阅最近的祖先
`ScrollPosition`，并用尾部哨兵的绝对 reveal offset、当前 `pixels` 与
`viewportDimension` 计算它到视口下边缘的距离。不要在评论组件内部用
`NotificationListener` 监听外层滚动——通知只向祖先冒泡，后代监听器收不到事件；
也不要把 `getOffsetToReveal().offset` 误当成屏幕坐标。触发后保留可点击兜底，失败
退化为可重试状态，成功、重新排序和首屏重载必须清理旧错误。

自动分页必须锁定并捕获本次请求的 `nextUrl`，成功后按评论 ID 去重；空页、重复游标
或已经消费的游标视为无进展并停止自动请求，避免逐帧重复拉取同一页。

## 状态约定

应用级状态由 Service 管理，页面级状态留在页面或对应 GetX Controller 中。不要把
一次页面请求缓存扩展成隐式的全局状态。预加载缓存必须连同 `nextUrl/isEnd` 保存，
否则消费缓存后无法继续分页。

## 正文渲染约定

文章和回答的长 HTML 按块级语义拆分，超长内容解析移出主 Isolate；解析后的块通过
单个 `SliverToBoxAdapter + Column` 一次布局。不得改回变量高度 `SliverList` 惰性
构建，否则新块和图片进入视口时会持续修正正文终点并让阅读进度跳动。公式、表情、
链接和知乎图片属性仍统一交给 `CustomHtml` 处理，避免为了复用 Fourier 的 RSS
渲染器而引入 Tritium 不需要的视频、桌面交互和代理逻辑。图片必须保留显式宽高或
样式中的尺寸信息，使用稳定占位、8 像素圆角和按设备像素密度设置的缓存尺寸。

正文语义组件建立在 flutter_html 扩展之上，与稳定布局正交：行内代码是
alphabetic baseline 对齐的半透明圆角胶囊；`<pre>` 渲染为单容器代码块（8px 圆角、
细边框、横向滚动、复制按钮带 1.2 秒勾选态），`<pre><code>` 不会出现两层背景；
引用块、宽表横向滚动、列表、分割线统一视觉。文本选择在页面级接入
`SelectionArea`：回答页包在整个 PageView 外层（SelectionArea 是横滑祖先时不会
抢走横滑手势），文章/想法/问题描述/评论包在各自滚动视图外层；这些包装不改变
正文终点的几何，阅读进度、标题时机与评论预加载不受影响。

回答横滑期间不得触发父页面整体重建、正文 DOM 解析或评论列表初始化。切页后的
标题、计数、预加载与纵向位置复位统一在横向滚动结束后执行。

评论惰性加载同时使用滚动余量和锚点屏幕位置判断。正文最终布局后，如果短内容的
评论锚点已经进入当前视口或预加载范围，必须立即创建评论区，不能等待下一次滚动。

## 阅读会话与历史

- `ReadingSession` 统一维护文章、回答和想法的正文进度。进度终点是正文后的评论
  锚点对齐视口下边缘所需的滚动位置，而不是锚点对齐视口顶端的位置。正文初始已
  完整位于视口内时进度直接为 100%；评论列表的延迟插入和继续分页不得改变终点。
- 每篇横滑回答拥有独立的滚动位置和进度；只有真正停稳并显示的回答写入阅读历史，
  相邻预加载内容不能污染历史顺序。
- 阅读历史最多保留 200 条，存储于本机 Hive cache box，不同步知乎服务器。重复打开
  同一内容只更新时间和元数据，并保留已有进度。
- 历史写入通过单一队列串行执行，避免快速横滑时并发读改写覆盖进度。

## 内容链接

正文链接、历史记录与 Android 外部 Intent 最终都进入 `ContentLinkService`，采用
三层结构：

1. **URL 归一化**（`ContentLinkTarget.normalizeLinkUrl`）：去除无效空白、支持
   协议相对 `//host` 与站内相对路径（带或不带前导斜线）、解包
   `link.zhihu.com/?target=`（最大解包深度 + 已访问集合防循环）、保留真正外部
   HTTP/HTTPS、拒绝 `javascript:`/`data:`/`file:` 等不安全 scheme。
2. **类型化解析**：覆盖 question/answer 组合、article/p、pin/pins、people/org
   （org 复用用户页）、appview、oia/articles、zvideo/video 与 `zhihu://`
   单复数 deep link。
3. **导航策略**：原生支持问题、回答、文章、想法和用户；视频及尚未建设原生只读
   页的话题、机构、专栏等知乎目的地转换为 HTTPS 后交给系统浏览器。无效链接给
   出统一反馈，不静默失败。所有原生内容跳转显式允许同一路由名携带不同内容 ID
   入栈；不能依赖 GetX 默认按路由名去重，否则回答→回答、问题→问题等会被静默
   拒绝。SelectionArea 兜底与 flutter_html 原生点击可能在 Android 同时回调，
   服务只按具体目标合并 500ms 内的重复分发，不能把目标锁定到页面退出。

HTML 渲染不再用覆盖全部 `<a>` 的扩展压平链接：普通链接保留 flutter_html 的
嵌套结构、样式与 `onLinkTap` 回调（同时保留文字选择），只有评论“查看图片/动图”
链接使用专用缩略图扩展；`#anchor` 由 flutter_html 内置定位处理，找不到目标时
不再交给浏览器；没有 `href` 的文字不伪装成可点击。Android 使用 `singleTop`
Activity：冷启动链接由 `getInitialLink` 消费，运行中链接由 `onNewIntent` 推送，
禁止建立第二套页面路由表。

## 回答分页

回答页拥有独立的 `AnswerPager` 状态模型（questionId、answerIds、nextUrl、
sortBy）。从问题页进入时接收 ID 列表 + 下一页游标 + 排序方式作为种子；从只传
单个回答的入口进入时先补齐所属问题第一页并保留当前回答。分页约定与推荐/评论
一致：按 ID 去重、重复 cursor/空页/`is_end` 停止、失败可重试；追加数据不改动
既有条目的索引，PageController 不跳页。占位页只是过渡状态，不渲染成回答，
也不触发“已切换回答”的振动。

## 统计值与反馈

统计值统一经 `lib/utils/count_format.dart` 可空解析：字段缺失、解析失败或尚未
加载时显示 “—”，绝不伪装成 0；浏览量 `visit_count` 优先、`read_count` 兜底。
状态反馈统一走 `lib/common/widgets/feedback_toast.dart` 的 `TritiumFeedback`
（info/success/warning/error 顶部胶囊，滑入淡入、不拦截交互）；加载遮罩仍由
SmartDialog 控制。

## 本地参考工程

- Hydrogen 固定放在 `reference/hydrogen/`，仅用于核对知乎接口、数据字段和功能
  模块行为；Fourier（原 Auto Folo）从 `/Users/x.rw/dev/Fourier` 参考设计、维护和
  发布流程。它不是 Tritium 的构建依赖，路径缺失时不得影响分析、测试或构建。
- `reference/` 被 Tritium 根仓库整体忽略。其内部 Git 元数据、构建产物、签名文件
  和配置不得暂存、复制进 Tritium 或进入 CI/Release 输入。
- 参考工程不是 Tritium 的源码依赖；新克隆缺少它时，分析、测试和构建必须照常完成。
- 不在参考工程内直接修改代码。较大移植需要记录来源仓库的 commit 和具体文件，
  在 Tritium 内按当前产品边界重新审查，并建立独立回归测试。
- 更新 Hydrogen 时只在其嵌套仓库内执行 Git 操作，不从 Tritium 根目录递归处理。

## 安全约定

- 仅接受系统信任的 TLS 证书，不设置绕过证书验证的回调。
- 不在日志中输出 Cookie、签名参数、完整请求头或登录 URL。
- 登录态只保存在本地应用存储，不写入仓库。
