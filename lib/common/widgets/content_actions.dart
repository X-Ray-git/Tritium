import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'feedback_toast.dart';

enum _ContentAction { share, copy, browser }

class ContentActionsMenu extends StatelessWidget {
  final String title;
  final String url;

  const ContentActionsMenu({super.key, required this.title, required this.url});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ContentAction>(
      tooltip: '更多',
      icon: const Icon(Icons.more_horiz_rounded),
      onSelected: (action) => _handle(action),
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _ContentAction.share,
          child: ListTile(
            leading: Icon(Icons.share_rounded),
            title: Text('分享'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: _ContentAction.copy,
          child: ListTile(
            leading: Icon(Icons.link_rounded),
            title: Text('复制链接'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: _ContentAction.browser,
          child: ListTile(
            leading: Icon(Icons.open_in_browser_rounded),
            title: Text('浏览器打开'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Future<void> _handle(_ContentAction action) async {
    switch (action) {
      case _ContentAction.share:
        try {
          await Share.share(url, subject: title);
        } catch (_) {
          TritiumFeedback.error('分享失败', '系统未能打开分享面板');
        }
        return;
      case _ContentAction.copy:
        try {
          await Clipboard.setData(ClipboardData(text: url));
          TritiumFeedback.success('已复制', '链接已复制到剪贴板');
        } catch (_) {
          TritiumFeedback.error('复制失败', '无法写入剪贴板');
        }
        return;
      case _ContentAction.browser:
        final uri = Uri.tryParse(url);
        try {
          final opened =
              uri != null &&
              await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (!opened) TritiumFeedback.warning('无法打开', '未找到可用的浏览器');
        } catch (_) {
          TritiumFeedback.warning('无法打开', '系统未能启动浏览器');
        }
        return;
    }
  }
}
