/// 应用常量定义
class Constants {
  Constants._();

  /// 应用名称
  static const String appName = 'Tritium';

  /// 应用版本 - 请使用 package_info_plus 动态获取
  /// 版本号统一在 pubspec.yaml 中管理

  /// 知乎 API 基础地址
  static const String zhihuApiBase = 'https://api.zhihu.com';

  /// 知乎 Web 基础地址
  static const String zhihuWebBase = 'https://www.zhihu.com';

  /// 知乎专栏基础地址
  static const String zhihuZhuanlanBase = 'https://zhuanlan.zhihu.com';

  /// 默认请求超时时间（毫秒）
  static const int defaultTimeout = 15000;

  /// 默认分页大小
  static const int defaultPageSize = 20;

  /// 缓存有效期（小时）
  static const int cacheExpireHours = 24;
}

/// 存储 Key 常量
class StorageKeys {
  StorageKeys._();

  // 用户相关
  static const String userInfo = 'user_info';
  static const String isLoggedIn = 'is_logged_in';
  static const String cookies = 'cookies';

  // 设置相关
  static const String themeMode = 'theme_mode';
  static const String dynamicColor = 'dynamic_color';
  static const String customColor = 'custom_color';

  // 缓存相关
  static const String feedCache = 'feed_cache';
  static const String historyCache = 'history_cache';

  // 排序偏好
  static const String defaultAnswerSort = 'default_answer_sort'; // default (heat), created (time)
  static const String defaultCommentSort = 'default_comment_sort'; // score (heat), ts (time)

  // 启动设置
  static const String defaultHomeTab = 'default_home_tab'; // 0: Recommend, 1: Hot

  // 显示设置
  static const String displayMode = 'display_mode';

  // 毛玻璃效果
  static const String enableBlurEffect = 'enable_blur_effect';
  static const String blurIntensity = 'blur_intensity';

  // 振动反馈
  static const String enableSwipeHaptics = 'enable_swipe_haptics';
}

/// API 路径常量
class ApiPaths {
  ApiPaths._();

  // 用户相关
  static const String me = '/me';
  static const String people = '/people';

  // Feed 相关
  static const String topstoryRecommend = '/topstory/recommend';
  /// 热榜 API - 注意：这是 v3 API，直接访问 www.zhihu.com，不走 api.zhihu.com 重写
  static const String topstoryHotList = 'https://www.zhihu.com/api/v3/feed/topstory/hot-lists/total';
  static const String feedSections = '/feed-root/sections/query/v2';
  static const String feedSection = '/feed-root/section';

  // 内容相关
  static const String questions = '/questions';
  static const String answers = '/answers';
  static const String articles = '/articles';
  
  // Web 端 API（需要 zse96 签名）
  static const String webQuestions = 'https://www.zhihu.com/api/v4/questions';
  static const String webAnswers = 'https://www.zhihu.com/api/v4/answers';
  static const String webArticles = 'https://www.zhihu.com/api/v4/articles';

  // 评论相关
  static const String comments = '/comment/list';

  // 搜索相关
  static const String search = '/search';
}
