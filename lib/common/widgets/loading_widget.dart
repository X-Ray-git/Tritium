import 'package:flutter/material.dart';

/// 加载中组件
class LoadingWidget extends StatelessWidget {
  final String? msg;

  const LoadingWidget({super.key, this.msg});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: colorScheme.primary,
            ),
          ),
          if (msg != null) ...[
            const SizedBox(height: 16),
            Text(
              msg!,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 页面加载中遮罩
class LoadingOverlay extends StatelessWidget {
  final String? msg;

  const LoadingOverlay({super.key, this.msg});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      color: colorScheme.surface.withValues(alpha: 0.8),
      child: LoadingWidget(msg: msg),
    );
  }
}
