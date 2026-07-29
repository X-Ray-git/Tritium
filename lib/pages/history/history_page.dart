import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../common/widgets/app_chrome.dart';
import '../../services/content_link_service.dart';
import '../../services/reading_history_service.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TritiumBlurAppBar(
        title: const TritiumSectionTitle('阅读历史'),
        actions: [
          ValueListenableBuilder<Box>(
            valueListenable: ReadingHistoryService.listenable,
            builder: (context, box, child) {
              if (ReadingHistoryService.entries.isEmpty) {
                return const SizedBox.shrink();
              }
              return IconButton(
                tooltip: '清空',
                icon: const Icon(Icons.delete_sweep_outlined),
                onPressed: () => _confirmClear(context),
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<Box>(
        valueListenable: ReadingHistoryService.listenable,
        builder: (context, box, child) {
          final entries = ReadingHistoryService.entries;
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 42,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  const Text('暂无阅读历史'),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(
              8,
              8,
              8,
              12 + MediaQuery.paddingOf(context).bottom,
            ),
            itemCount: entries.length,
            separatorBuilder: (context, index) => const Divider(indent: 64),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Dismissible(
                key: ValueKey(entry.storageId),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
                onDismissed: (_) {
                  ReadingHistoryService.remove(entry.kind, entry.id);
                },
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: Icon(
                      _iconFor(entry.kind),
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: Text(
                    entry.title.isEmpty ? _labelFor(entry.kind) : entry.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    entry.preview.isEmpty
                        ? _labelFor(entry.kind)
                        : '${_labelFor(entry.kind)} · ${entry.preview}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: entry.progress <= 0
                      ? null
                      : Text(
                          '${(entry.progress * 100).round()}%',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                  onTap: () => ContentLinkService.open(entry.url),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空阅读历史？'),
        content: const Text('阅读进度也会一并清除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed == true) await ReadingHistoryService.clear();
  }

  static String _labelFor(String kind) => switch (kind) {
    'answer' => '回答',
    'article' => '文章',
    'pin' => '想法',
    'question' => '问题',
    'user' => '用户',
    _ => '内容',
  };

  static IconData _iconFor(String kind) => switch (kind) {
    'answer' => Icons.question_answer_outlined,
    'article' => Icons.article_outlined,
    'pin' => Icons.lightbulb_outline_rounded,
    'question' => Icons.help_outline_rounded,
    'user' => Icons.person_outline_rounded,
    _ => Icons.description_outlined,
  };
}
