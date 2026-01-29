import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

import '../common/constants/constants.dart';
import '../utils/storage.dart';
import '../utils/zse96_encrypt.dart';

/// HTTP 请求单例类
class Request {
  static final Request _instance = Request._internal();
  static late final Dio dio;

  factory Request() => _instance;

  Request._internal() {
    // 基础配置
    BaseOptions options = BaseOptions(
      baseUrl: Constants.zhihuApiBase,
      connectTimeout: const Duration(milliseconds: Constants.defaultTimeout),
      receiveTimeout: const Duration(milliseconds: Constants.defaultTimeout),
      sendTimeout: const Duration(milliseconds: Constants.defaultTimeout),
      headers: {
        'user-agent': 'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        'accept': 'application/json',
        'accept-language': 'zh-CN,zh;q=0.9',
      },
    );

    dio = Dio(options);

    // 配置 HTTP 客户端
    if (!kIsWeb) {
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient()
            ..idleTimeout = const Duration(seconds: 15);
          if (kDebugMode) {
            client.badCertificateCallback = (cert, host, port) => true;
          }
          return client;
        },
      );
    }

    // 添加拦截器
    dio.interceptors.add(_CookieInterceptor());

    // 日志拦截器 (仅调试模式)
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          request: true,
          requestHeader: true,
          requestBody: true,
          responseHeader: false,
          responseBody: true,
          error: true,
        ),
      );
    }
  }

  /// 设置 Cookie
  static void setCookie() {
    // Cookie 会通过拦截器自动添加
  }

  /// GET 请求
  Future<Response> get(
    String url, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await dio.get(
        url,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// POST 请求
  Future<Response> post(
    String url, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await dio.post(
        url,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// DELETE 请求
  Future<Response> delete(
    String url, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await dio.delete(
        url,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// PUT 请求
  Future<Response> put(
    String url, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await dio.put(
        url,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// 错误处理
  Response _handleError(DioException e) {
    String message;
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        message = '连接超时';
        break;
      case DioExceptionType.sendTimeout:
        message = '发送超时';
        break;
      case DioExceptionType.receiveTimeout:
        message = '接收超时';
        break;
      case DioExceptionType.badResponse:
        message = '服务器响应错误: ${e.response?.statusCode}';
        break;
      case DioExceptionType.cancel:
        message = '请求已取消';
        break;
      case DioExceptionType.connectionError:
        message = '网络连接失败';
        break;
      default:
        message = e.message ?? '未知错误';
    }

    return Response(
      data: {'message': message, 'error': true},
      statusCode: e.response?.statusCode ?? -1,
      requestOptions: e.requestOptions,
    );
  }
}

/// Cookie 拦截器
class _CookieInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final cookies = Pref.cookies;
    final fullUrl = options.uri.toString();
    
    debugPrint('Original URL: $fullUrl');
    
    // 判断请求类型
    final isApiZhihu = fullUrl.contains('api.zhihu.com');
    final isWwwZhihu = fullUrl.contains('www.zhihu.com');
    
    if (isApiZhihu) {
      // api.zhihu.com 请求：使用 Android 客户端 headers（不重写 URL，不使用签名）
      // 参考 Hydrogen muk.lua 的 apphead 配置
      options.headers['x-api-version'] = '3.1.8';
      options.headers['x-app-za'] = 'OS=Android&VersionName=10.12.0&VersionCode=21210&Product=com.zhihu.android&Installer=Google+Play&DeviceType=AndroidPhone';
      options.headers['x-app-version'] = '10.12.0';
      options.headers['x-app-bundleid'] = 'com.zhihu.android';
      options.headers['x-app-flavor'] = 'play';
      options.headers['x-app-build'] = 'release';
      options.headers['x-network-type'] = 'WiFi';
      options.headers['user-agent'] = 'com.zhihu.android/Futureve/10.12.0';
      
      if (cookies != null && cookies.isNotEmpty) {
        options.headers['cookie'] = cookies;
      }
      
      debugPrint('Using Android client headers for api.zhihu.com');
      
    } else if (isWwwZhihu) {
      // www.zhihu.com 请求：使用 Web 端签名（zse96）
      if (cookies != null && cookies.isNotEmpty) {
        options.headers['cookie'] = cookies;
        
        final result = Zse96Encrypt.generateSignHeadersWithUrl(
          url: fullUrl,
          cookies: cookies,
        );
        
        debugPrint('Rewritten URL: ${result.rewrittenUrl}');
        debugPrint('Generated Headers: ${result.headers}');
        
        // www.zhihu.com 不需要 URL 重写，直接添加签名
        options.headers['user-agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
        options.headers['Referer'] = 'https://www.zhihu.com/';
        options.headers.addAll(result.headers);
        
        debugPrint('Using Web client headers with zse96 signature');
      }
    } else {
      // 其他请求：添加通用 cookies
      if (cookies != null && cookies.isNotEmpty) {
        options.headers['cookie'] = cookies;
      }
    }
    
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // 保存 Cookie
    final setCookie = response.headers['set-cookie'];
    if (setCookie != null && setCookie.isNotEmpty) {
      // 合并 Cookie
      final existingCookies = Pref.cookies ?? '';
      final newCookies = _mergeCookies(existingCookies, setCookie);
      Pref.cookies = newCookies;
    }
    handler.next(response);
  }

  /// 合并 Cookie
  String _mergeCookies(String existing, List<String> newCookies) {
    final cookieMap = <String, String>{};

    // 解析现有 Cookie
    if (existing.isNotEmpty) {
      for (final part in existing.split('; ')) {
        final idx = part.indexOf('=');
        if (idx > 0) {
          cookieMap[part.substring(0, idx)] = part.substring(idx + 1);
        }
      }
    }

    // 解析新 Cookie
    for (final cookie in newCookies) {
      final parts = cookie.split(';');
      if (parts.isNotEmpty) {
        final keyValue = parts[0].trim();
        final idx = keyValue.indexOf('=');
        if (idx > 0) {
          cookieMap[keyValue.substring(0, idx)] = keyValue.substring(idx + 1);
        }
      }
    }

    // 组合 Cookie
    return cookieMap.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }
}

/// 加载状态封装
sealed class LoadingState<T> {
  const LoadingState();
}

class Loading<T> extends LoadingState<T> {
  const Loading();
}

class Success<T> extends LoadingState<T> {
  final T response;
  const Success(this.response);
}

class Error<T> extends LoadingState<T> {
  final String errMsg;
  const Error(this.errMsg);
}
