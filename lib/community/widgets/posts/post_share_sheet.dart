import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/community_post.dart';

class PostShareSheet extends StatelessWidget {
  final CommunityPost post;

  const PostShareSheet({
    super.key,
    required this.post,
  });

  @override
  Widget build(BuildContext context) {
    final shareText = _buildShareText();

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          18,
          12,
          18,
          24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '分享貼文',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFF1F5F9),
                child: Icon(
                  Icons.share_outlined,
                  color: Color(0xFF0F172A),
                ),
              ),
              title: const Text(
                '分享至其他 App',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: const Text(
                'LINE、Messenger、Facebook 等',
              ),
              onTap: () async {
                Navigator.pop(context);

                await SharePlus.instance.share(
                  ShareParams(
                    text: shareText,
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFF1F5F9),
                child: Icon(
                  Icons.copy_outlined,
                  color: Color(0xFF0F172A),
                ),
              ),
              title: const Text(
                '複製內容',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: () async {
                await Clipboard.setData(
                  ClipboardData(
                    text: shareText,
                  ),
                );

                if (!context.mounted) {
                  return;
                }

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已複製分享內容'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _buildShareText() {
    final buffer = StringBuffer();

    buffer.writeln('${post.name} 在 Slow On Move 分享了一則貼文');
    buffer.writeln();
    buffer.writeln(post.content);

    if (post.type == CommunityPostType.plan && post.plan != null) {
      final plan = post.plan!;

      buffer.writeln();
      buffer.writeln('🏃 ${plan.title}');

      if (plan.summary.isNotEmpty) {
        buffer.writeln(plan.summary);
      }

      buffer.writeln(
        '難度：${plan.difficulty}・${plan.totalMinutes} 分鐘',
      );

      if (plan.steps.isNotEmpty) {
        buffer.writeln();

        for (var i = 0; i < plan.steps.length; i++) {
          final step = plan.steps[i];

          String value;

          if (step.exerciseType == 'squat') {
            value = '${step.reps ?? 0} 下';
          } else {
            value = '${step.minutes ?? 0} 分鐘';
          }

          buffer.writeln(
            '${i + 1}. ${step.name} $value',
          );
        }
      }
    }

    if (post.tags.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(
        post.tags.map((tag) => '#$tag').join(' '),
      );
    }

    return buffer.toString().trim();
  }
}
