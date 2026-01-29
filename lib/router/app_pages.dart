import 'package:get/get.dart';

import '../pages/main/main_page.dart';
import '../pages/login/login_page.dart';
import '../pages/question/question_page.dart';
import '../pages/answer/answer_page.dart';
import '../pages/article/article_page.dart';
import '../pages/user/user_page.dart';
import '../pages/settings/settings_page.dart';
import '../pages/settings/display_mode_page.dart';
import '../pages/comment/comment_page.dart';
import '../pages/pin/pin_page.dart';

/// 路由名称
class Routes {
  Routes._();

  static const String main = '/';
  static const String login = '/login';
  static const String question = '/question';
  static const String answer = '/answer';
  static const String article = '/article';
  static const String user = '/user';
  static const String settings = '/settings';
  static const String displayMode = '/displayMode';
  static const String comment = '/comment';
  static const String pin = '/pin';
}

/// 路由定义
List<GetPage> get appPages => [
  GetPage(
    name: Routes.main,
    page: () => const MainPage(),
  ),
  GetPage(
    name: Routes.login,
    page: () => const LoginPage(),
    transition: Transition.rightToLeft,
  ),
  GetPage(
    name: Routes.question,
    page: () => const QuestionPage(),
  ),
  GetPage(
    name: Routes.answer,
    page: () => const AnswerPage(),
    // 使用 native，会尊重 ThemeData.pageTransitionsTheme 中的 ZoomPageTransitionsBuilder
  ),
  GetPage(
    name: Routes.article,
    page: () => const ArticlePage(),
  ),
  GetPage(
    name: Routes.user,
    page: () => const UserPage(),
    transition: Transition.rightToLeft,
  ),
  GetPage(
    name: Routes.settings,
    page: () => const SettingsPage(),
    transition: Transition.rightToLeft,
  ),
  GetPage(
    name: Routes.displayMode,
    page: () => const DisplayModePage(),
    transition: Transition.rightToLeft,
  ),
  GetPage(
    name: Routes.comment,
    page: () => const CommentPage(),
    transition: Transition.rightToLeft,
  ),
  GetPage(
    name: Routes.pin,
    page: () => const PinPage(),
  ),
];
