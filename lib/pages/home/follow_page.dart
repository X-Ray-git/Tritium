import 'package:flutter/material.dart';

/// 关注页
class FollowPage extends StatelessWidget {
  const FollowPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.rss_feed,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            '关注动态暂未开放',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
