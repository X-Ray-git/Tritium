import 'package:flutter/material.dart';

/// 空数据组件
class EmptyWidget extends StatelessWidget {
  final String? message;
  final IconData? icon;
  final VoidCallback? onAction;
  final String? actionLabel;

  const EmptyWidget({
    super.key,
    this.message,
    this.icon,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? Icons.inbox_rounded,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              message ?? '暂无内容',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 24),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
