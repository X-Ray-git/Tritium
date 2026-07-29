# 路由与状态

## 路由

GetX 路由集中定义在 `lib/router/app_pages.dart`。主路由包含推荐/热榜/设置壳层，
详情路由覆盖登录、问题、回答、文章、想法、用户、阅读历史和显示模式。

知乎链接先由 `ContentLinkService` 解析：已支持的内容进入应用内路由，外部链接和
未提供原生阅读页的内容交给系统浏览器。

Android 冷启动和运行中链接由 `DeepLinkService` 通过
`io.github.xraygit.tritium/deep_link` MethodChannel 接收。`MainActivity` 只负责
提取 `ACTION_VIEW/ACTION_EDIT` 的 URI，并分别通过 `getInitialLink` 或 `onLink`
交给 Dart；不得在 Kotlin 侧再建立内容路由。Manifest 接受 `zhihu://` 及知乎 HTTPS
链接，`singleTop` Activity 通过 `onNewIntent` 复用已有任务。

`ContentLinkService` 原生解析问题、回答、文章、想法和用户。话题、机构、专栏等尚无
只读原生页面的知乎 URI 转为等价 HTTPS 后交给浏览器；视频始终使用浏览器。历史页、
正文链接和 Android Intent 必须调用同一服务，避免三套路由规则漂移。

## 状态边界

- 应用级登录态由 `AccountService` 管理。
- Android 外部链接生命周期由 `DeepLinkService` 管理。
- 轻量页面状态留在 StatefulWidget 或对应 GetX Controller。
- 不把单次页面请求隐式提升成全局状态。
- 主导航保留三个页面实例，再次点击“推荐”或“热榜”触发对应列表回到顶部。

## 异步加载约定

列表控制器需要维护加载锁和刷新代次。刷新后到达的旧请求结果必须丢弃；加载更多失败
时保留已有内容和分页游标。Widget 销毁后不得更新 Rx 或 `setState`。
