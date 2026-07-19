import 'dart:async';

import 'package:flutter/foundation.dart';
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
  bool _isCheckingLogin = false;
  Timer? _loadingWatchdog;
  Timer? _progressCompletionTimer;
  int _navigationGeneration = 0;
  int _checkpointSequence = 0;
  int _lastLoggedProgress = -1;
  final Stopwatch _debugClock = Stopwatch()..start();

  static const String _loginUrl = 'https://www.zhihu.com/signin';
  static const Duration _loadingTimeout = Duration(seconds: 12);

  @override
  void initState() {
    super.initState();
    _checkpoint('page-init');
  }

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
            onPressed: _reload,
            tooltip: '刷新',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Obx(
            () => _progress.value < 1.0
                ? LinearProgressIndicator(
                    value: _progress.value,
                    backgroundColor: Colors.transparent,
                  )
                : const SizedBox.shrink(),
          ),
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
              userAgent:
                  'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
            ),
            onWebViewCreated: (controller) {
              _webViewController = controller;
              _checkpoint('webview-created');
              _beginLoading(WebUri(_loginUrl), source: 'webview-created');
            },
            onLoadStart: (controller, url) {
              _beginLoading(url, source: 'onLoadStart');
            },
            onLoadStop: (controller, url) async {
              if (!mounted) return;
              _finishLoading(url, source: 'onLoadStop');

              // 检查是否登录成功
              await _checkLoginStatus(url?.toString());
            },
            onProgressChanged: (controller, progress) {
              if (!mounted) return;
              _progress.value = progress / 100.0;
              _logProgress(progress);

              // Android WebView 偶尔不会回调 onLoadStop。进度到 100 后短暂等待，
              // 若没有新的主文档导航，就主动移除遮罩。
              if (progress >= 100) {
                final generation = _navigationGeneration;
                _progressCompletionTimer?.cancel();
                _progressCompletionTimer = Timer(
                  const Duration(milliseconds: 500),
                  () {
                    if (!mounted ||
                        generation != _navigationGeneration ||
                        !_isLoading.value) {
                      return;
                    }
                    _finishLoading(
                      _webUriFromCurrentUrl(),
                      source: 'progress-100-fallback',
                    );
                  },
                );
              }
            },
            onUpdateVisitedHistory: (controller, url, isReload) {
              if (!mounted) return;
              _currentUrl.value = url?.toString() ?? _currentUrl.value;
              _checkpoint(
                'history-updated',
                data: {'url': _safeUrl(url), 'reload': isReload ?? false},
              );
            },
            onReceivedError: (controller, request, error) {
              if (request.isForMainFrame != true) return;
              _checkpoint(
                'main-frame-error',
                data: {'url': _safeUrl(request.url), 'type': error.type},
              );
              _finishLoading(request.url, source: 'onReceivedError');
            },
            onReceivedHttpError: (controller, request, errorResponse) {
              if (request.isForMainFrame != true) return;
              _checkpoint(
                'main-frame-http-error',
                data: {
                  'url': _safeUrl(request.url),
                  'status': errorResponse.statusCode,
                },
              );
              _finishLoading(request.url, source: 'onReceivedHttpError');
            },
            shouldOverrideUrlLoading: (controller, action) async {
              final url = action.request.url?.toString() ?? '';

              final uri = Uri.tryParse(url);
              final host = uri?.host.toLowerCase() ?? '';
              final isZhihuHost =
                  host == 'zhihu.com' || host.endsWith('.zhihu.com');
              if (isZhihuHost) {
                _logNavigationDecision(action, 'allow-zhihu');
                return NavigationActionPolicy.ALLOW;
              }

              // 允许 https 链接
              if (url.startsWith('https://')) {
                _logNavigationDecision(action, 'allow-https');
                return NavigationActionPolicy.ALLOW;
              }

              _logNavigationDecision(action, 'cancel-non-https');
              return NavigationActionPolicy.CANCEL;
            },
          ),
          // 加载遮罩
          Obx(
            () => _isLoading.value
                ? Container(
                    color: colorScheme.surface,
                    child: const LoadingWidget(msg: '加载中...'),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  /// 手动检查登录状态
  Future<void> _manualCheckLogin() async {
    if (_isCheckingLogin) {
      _checkpoint('manual-check-skipped', data: {'reason': 'busy'});
      return;
    }
    _isCheckingLogin = true;
    _checkpoint('manual-check-start');
    SmartDialog.showLoading(msg: '获取登录状态...');

    try {
      // 获取所有 Cookie
      final cookies = await CookieManager.instance().getCookies(
        url: WebUri('https://www.zhihu.com'),
      );
      if (!mounted) return;

      _checkpoint(
        'manual-cookie-read',
        data: {
          'count': cookies.length,
          'has_z_c0': cookies.any((cookie) => cookie.name == 'z_c0'),
          'has_d_c0': cookies.any((cookie) => cookie.name == 'd_c0'),
        },
      );

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

      // 设置登录 Cookie
      final success = await Get.find<AccountService>().setLoginCookie(
        cookieString,
      );
      if (!mounted) return;

      _checkpoint('manual-account-check-finished', data: {'success': success});

      SmartDialog.dismiss();

      if (success) {
        Get.back(result: true);
        SmartDialog.showToast('登录成功！');
      } else {
        SmartDialog.showToast('登录失败，请重试');
      }
    } catch (error) {
      _checkpoint('manual-check-error', data: {'type': error.runtimeType});
      SmartDialog.dismiss();
      if (mounted) SmartDialog.showToast('获取登录状态失败，请重试');
    } finally {
      _isCheckingLogin = false;
      SmartDialog.dismiss();
      _checkpoint('manual-check-finished');
    }
  }

  /// 检查登录状态
  Future<void> _checkLoginStatus(String? url) async {
    if (url == null || _hasCheckedLogin) {
      _checkpoint(
        'auto-check-skipped',
        data: {'reason': url == null ? 'missing-url' : 'already-checking'},
      );
      return;
    }

    // 检查是否已经跳转到知乎首页（登录成功的标志）
    final isHomePage =
        url == 'https://www.zhihu.com/' ||
        url.startsWith('https://www.zhihu.com/?') ||
        url.startsWith('https://www.zhihu.com/follow') ||
        url.startsWith('https://www.zhihu.com/hot');

    if (!isHomePage) {
      _checkpoint(
        'auto-check-skipped',
        data: {'reason': 'not-home', 'url': _safeUrl(url)},
      );
      return;
    }

    _hasCheckedLogin = true;
    _checkpoint('auto-check-start', data: {'url': _safeUrl(url)});

    // 获取 Cookie
    final cookies = await CookieManager.instance().getCookies(
      url: WebUri('https://www.zhihu.com'),
    );
    if (!mounted) return;

    // 检查关键 Cookie
    final hasZC0 = cookies.any((c) => c.name == 'z_c0');

    _checkpoint(
      'auto-cookie-read',
      data: {
        'count': cookies.length,
        'has_z_c0': hasZC0,
        'has_d_c0': cookies.any((cookie) => cookie.name == 'd_c0'),
      },
    );

    if (!hasZC0) {
      _hasCheckedLogin = false;
      _checkpoint('auto-check-reset', data: {'reason': 'missing-z-c0'});
      return;
    }

    // 构建 Cookie 字符串
    final cookieString = cookies.map((c) => '${c.name}=${c.value}').join('; ');

    // 设置登录 Cookie
    final success = await Get.find<AccountService>().setLoginCookie(
      cookieString,
    );
    if (!mounted) return;

    _checkpoint('auto-account-check-finished', data: {'success': success});

    if (success) {
      Get.back(result: true);
      SmartDialog.showToast('登录成功！');
    } else {
      _hasCheckedLogin = false;
      _checkpoint('auto-check-reset', data: {'reason': 'account-rejected'});
    }
  }

  void _reload() {
    _checkpoint('reload-requested', data: {'url': _safeUrl(_currentUrl.value)});
    _webViewController?.reload();
  }

  void _beginLoading(WebUri? url, {required String source}) {
    if (!mounted) return;

    final generation = ++_navigationGeneration;
    _loadingWatchdog?.cancel();
    _progressCompletionTimer?.cancel();
    _lastLoggedProgress = -1;
    _isLoading.value = true;
    _progress.value = 0;
    _currentUrl.value = url?.toString() ?? _currentUrl.value;
    _checkpoint(
      'loading-began',
      data: {'source': source, 'generation': generation, 'url': _safeUrl(url)},
    );

    _loadingWatchdog = Timer(_loadingTimeout, () {
      if (!mounted ||
          generation != _navigationGeneration ||
          !_isLoading.value) {
        return;
      }

      _checkpoint(
        'loading-timeout',
        data: {
          'generation': generation,
          'progress': '${(_progress.value * 100).round()}%',
          'url': _safeUrl(_currentUrl.value),
          'action': 'hide-overlay',
        },
      );
      _isLoading.value = false;
    });
  }

  void _finishLoading(WebUri? url, {required String source}) {
    if (!mounted) return;

    _loadingWatchdog?.cancel();
    _progressCompletionTimer?.cancel();
    _isLoading.value = false;
    _currentUrl.value = url?.toString() ?? _currentUrl.value;
    _checkpoint(
      'loading-finished',
      data: {
        'source': source,
        'generation': _navigationGeneration,
        'progress': '${(_progress.value * 100).round()}%',
        'url': _safeUrl(url),
      },
    );
  }

  void _logProgress(int progress) {
    final milestone = progress >= 100 ? 100 : (progress ~/ 20) * 20;
    if (milestone == _lastLoggedProgress) return;
    _lastLoggedProgress = milestone;
    _checkpoint(
      'progress',
      data: {'generation': _navigationGeneration, 'value': '$progress%'},
    );
  }

  void _logNavigationDecision(NavigationAction action, String decision) {
    if (!action.isForMainFrame) return;
    _checkpoint(
      'navigation-decision',
      data: {'decision': decision, 'url': _safeUrl(action.request.url)},
    );
  }

  WebUri? _webUriFromCurrentUrl() {
    final value = _currentUrl.value;
    return value.isEmpty ? null : WebUri(value);
  }

  String _safeUrl(Object? value) {
    final rawValue = value?.toString();
    if (rawValue == null || rawValue.isEmpty) return 'unknown';

    final uri = Uri.tryParse(rawValue);
    if (uri == null || uri.host.isEmpty) return 'invalid';

    final safeSegments = uri.pathSegments.map((segment) {
      if (segment.length > 24) return '<redacted>';
      return segment;
    });
    final path = safeSegments.isEmpty ? '/' : '/${safeSegments.join('/')}';
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port$path';
  }

  void _checkpoint(String event, {Map<String, Object?> data = const {}}) {
    if (!kDebugMode) return;

    final sequence = (++_checkpointSequence).toString().padLeft(2, '0');
    final details = data.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(' ');
    final suffix = details.isEmpty ? '' : ' $details';
    debugPrint(
      '[TritiumLogin][$sequence][+${_debugClock.elapsedMilliseconds}ms] '
      '$event$suffix',
    );
  }

  @override
  void dispose() {
    _checkpoint('page-dispose');
    _loadingWatchdog?.cancel();
    _progressCompletionTimer?.cancel();
    _webViewController = null;
    _isLoading.close();
    _progress.close();
    _currentUrl.close();
    super.dispose();
  }
}
