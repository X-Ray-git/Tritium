import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'content_link_service.dart';

abstract final class DeepLinkService {
  static const MethodChannel _channel = MethodChannel(
    'io.github.xraygit.tritium/deep_link',
  );
  static String? _pendingUrl;
  static bool _scheduled = false;

  static Future<void> initialize() async {
    if (!Platform.isAndroid) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onLink' && call.arguments is String) {
        _enqueue(call.arguments as String);
      }
    });
    final initial = await _channel.invokeMethod<String>('getInitialLink');
    if (initial != null && initial.isNotEmpty) _enqueue(initial);
  }

  static void _enqueue(String url) {
    _pendingUrl = url;
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      final pending = _pendingUrl;
      _pendingUrl = null;
      if (pending != null) ContentLinkService.open(pending);
    });
    WidgetsBinding.instance.scheduleFrame();
  }
}
