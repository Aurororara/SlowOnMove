import 'package:flutter/material.dart';

import '../common/community_avatar.dart';
import '../common/community_card_styles.dart';

class BackendGroupMemberCard extends StatelessWidget {
  final String name;
  final String initial;
  final String joinedDate;
  final bool isOwner;

  final bool canRemove;
  final VoidCallback? onRemove;

  const BackendGroupMemberCard({
    super.key,
    required this.name,
    required this.initial,
    required this.joinedDate,
    required this.isOwner,
    this.canRemove = false,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: communityCardDecoration(),
      child: Row(
        children: [
          CommunityAvatar(
            initial: initial,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (isOwner) ...[
                      const SizedBox(width: 6),
                      const Text(
                        '👑',
                        style: TextStyle(
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '加入於 $joinedDate',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '運動統計尚未串接',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (canRemove && !isOwner)
            PopupMenuButton<String>(
              tooltip: '更多操作',
              icon: const Icon(
                Icons.more_vert_rounded,
                color: Color(0xFF64748B),
              ),
              onSelected: (value) {
                if (value == 'remove') {
                  onRemove?.call();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_remove_outlined,
                        size: 19,
                        color: Colors.red,
                      ),
                      SizedBox(width: 8),
                      Text(
                        '移除成員',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
