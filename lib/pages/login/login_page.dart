import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import '../../services/account_service.dart';
import '../../common/widgets/loading_widget.dart';

/// 登录页面
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  InAppWebViewController? _webViewController;
  final _isLoading = true.obs;
  final _progress = 0.0.obs;
  final _currentUrl = ''.obs;
  bool _hasCheckedLogin = false;
  
  static const String _loginUrl = 'https://www.zhihu.com/signin';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('登录知乎'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Get.back(),
        ),
        actions: [
          // 手动获取登录状态按钮
          IconButton(
            icon: const Icon(Icons.check_circle_outline),
            onPressed: _manualCheckLogin,
            tooltip: '确认登录',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _webViewController?.reload(),
            tooltip: '刷新',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Obx(() => _progress.value < 1.0
              ? LinearProgressIndicator(
                  value: _progress.value,
                  backgroundColor: Colors.transparent,
                )
              : const SizedBox.shrink()),
        ),
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(_loginUrl)),
            initialSettings: InAppWebViewSettings(
              useShouldOverrideUrlLoading: true,
              javaScriptEnabled: true,
              domStorageEnabled: true,
              databaseEnabled: true,
              cacheEnabled: true,
              thirdPartyCookiesEnabled: true,
              userAgent: 'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
            ),
            onWebViewCreated: (controller) {
              _webViewController = controller;
            },
            onLoadStart: (controller, url) {
              _isLoading.value = true;
              _currentUrl.value = url?.toString() ?? '';
              debugPrint('LoginPage: onLoadStart - $url');
            },
            onLoadStop: (controller, url) async {
              _isLoading.value = false;
              _currentUrl.value = url?.toString() ?? '';
              debugPrint('LoginPage: onLoadStop - $url');
              
              // 检查是否登录成功
              await _checkLoginStatus(url?.toString());
            },
            onProgressChanged: (controller, progress) {
              _progress.value = progress / 100.0;
            },
            shouldOverrideUrlLoading: (controller, action) async {
              final url = action.request.url?.toString() ?? '';
              debugPrint('LoginPage: shouldOverrideUrlLoading - $url');
              
              // 允许 zhihu 相关链接
              if (url.contains('zhihu.com')) {
                return NavigationActionPolicy.ALLOW;
              }
              
              // 允许 https 链接
              if (url.startsWith('https://')) {
                return NavigationActionPolicy.ALLOW;
              }
              
              return NavigationActionPolicy.CANCEL;
            },
          ),
          // 加载遮罩
          Obx(() => _isLoading.value
              ? Container(
                  color: colorScheme.surface,
                  child: const LoadingWidget(msg: '加载中...'),
                )
              : const SizedBox.shrink()),
        ],
      ),
    );
  }

  /// 手动检查登录状态
  Future<void> _manualCheckLogin() async {
    SmartDialog.showLoading(msg: '获取登录状态...');
    
    try {
      // 获取所有 Cookie
      final cookies = await CookieManager.instance().getCookies(
        url: WebUri('https://www.zhihu.com'),
      );
      
      debugPrint('LoginPage: Got ${cookies.length} cookies');
      for (final cookie in cookies) {
        debugPrint('  ${cookie.name}=${cookie.value?.substring(0, (cookie.value?.length ?? 0) > 20 ? 20 : cookie.value?.length ?? 0)}...');
      }
      
      if (cookies.isEmpty) {
        SmartDialog.dismiss();
        SmartDialog.showToast('未获取到登录信息，请先完成登录');
        return;
      }
      
      // 检查是否有关键 Cookie
      final hasZSid = cookies.any((c) => c.name == 'z_c0');
      
      if (!hasZSid) {
        SmartDialog.dismiss();
        SmartDialog.showToast('请先完成知乎登录');
        return;
      }
      
      // 构建 Cookie 字符串
      final cookieString = cookies
          .map((c) => '${c.name}=${c.value}')
          .join('; ');
      
      debugPrint('LoginPage: Cookie string length: ${cookieString.length}');
      
      // 设置登录 Cookie
      final success = await Get.find<AccountService>().setLoginCookie(cookieString);
      
      SmartDialog.dismiss();
      
      if (success) {
        Get.back(result: true);
        SmartDialog.showToast('登录成功！');
      } else {
        SmartDialog.showToast('登录失败，请重试');
      }
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showToast('获取登录状态失败: $e');
      debugPrint('LoginPage: Error - $e');
    }
  }

  /// 检查登录状态
  Future<void> _checkLoginStatus(String? url) async {
    if (url == null || _hasCheckedLogin) return;
    
    debugPrint('LoginPage: Checking login status for URL: $url');
    
    // 检查是否已经跳转到知乎首页（登录成功的标志）
    final isHomePage = url == 'https://www.zhihu.com/' ||
        url.startsWith('https://www.zhihu.com/?') ||
        url.startsWith('https://www.zhihu.com/follow') ||
        url.startsWith('https://www.zhihu.com/hot');
    
    if (!isHomePage) {
      debugPrint('LoginPage: Not home page, skipping check');
      return;
    }
    
    _hasCheckedLogin = true;
    
    // 获取 Cookie
    final cookies = await CookieManager.instance().getCookies(
      url: WebUri('https://www.zhihu.com'),
    );
    
    debugPrint('LoginPage: Got ${cookies.length} cookies after login');
    
    // 检查关键 Cookie
    final hasZC0 = cookies.any((c) => c.name == 'z_c0');
    
    if (!hasZC0) {
      debugPrint('LoginPage: Missing z_c0 cookie');
      _hasCheckedLogin = false;
      return;
    }
    
    // 构建 Cookie 字符串
    final cookieString = cookies
        .map((c) => '${c.name}=${c.value}')
        .join('; ');
    
    // 设置登录 Cookie
    final success = await Get.find<AccountService>().setLoginCookie(cookieString);
    
    if (success) {
      Get.back(result: true);
      SmartDialog.showToast('登录成功！');
    } else {
      _hasCheckedLogin = false;
    }
  }

  @override
  void dispose() {
    _webViewController = null;
    super.dispose();
  }
}
