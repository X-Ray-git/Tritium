import 'package:flutter/material.dart';

/// 错误组件
class ErrorWidget extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const ErrorWidget({
    super.key,
    this.message,
    this.onRetry,
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
              Icons.error_outline_rounded,
              size: 64,
              color: colorScheme.error.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              message ?? '加载失败',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重试'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
