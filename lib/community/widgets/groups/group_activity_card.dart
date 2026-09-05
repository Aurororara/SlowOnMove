import 'package:flutter/material.dart';

import '../../models/community_group_activity.dart';

class BackendGroupActivityCard extends StatelessWidget {
  final CommunityGroupActivity activity;
  final VoidCallback? onJoin;
  final VoidCallback? onLeave;
  final bool isUpdating;

  const BackendGroupActivityCard({
    super.key,
    required this.activity,
    this.onJoin,
    this.onLeave,
    this.isUpdating = false,
  });

  String _formatDateTime(
    DateTime dateTime,
  ) {
    final local = dateTime.toLocal();

    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '${local.year}/$month/$day $hour:$minute';
  }

  String _exerciseLabel(
    String exerciseType,
  ) {
    switch (exerciseType) {
      case 'squat':
        return '深蹲';

      case 'slow_jogging':
      default:
        return '超慢跑';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _friendCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  activity.exerciseType == 'squat'
                      ? Icons.accessibility_new
                      : Icons.directions_run,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _exerciseLabel(
                        activity.exerciseType,
                      ),
                      style: _friendMetaStyle,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                _formatDateTime(
                  activity.scheduledAt,
                ),
                style: _friendMetaStyle,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.person_outline,
                size: 14,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                '建立者：${activity.creator.name}',
                style: _friendMetaStyle,
              ),
            ],
          ),

          // 參加人數
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.groups_outlined,
                size: 14,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                '${activity.participantCount} 人參加',
                style: _friendMetaStyle,
              ),
            ],
          ),

          if (activity.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(
                  0xFFF8FAFC,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                activity.notes,
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],

          // 加入 / 取消參加
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: activity.isJoined
                ? OutlinedButton.icon(
                    onPressed: isUpdating ? null : onLeave,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(
                        color: Color(0xFFFCA5A5),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: isUpdating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.person_remove_outlined,
                            size: 17,
                          ),
                    label: Text(
                      isUpdating ? '處理中...' : '取消參加',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: isUpdating ? null : onJoin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF9CA3AF),
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: isUpdating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.person_add_alt_1_outlined,
                            size: 17,
                          ),
                    label: Text(
                      isUpdating ? '處理中...' : '加入活動',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration get _friendCardDecoration {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: const Color(0xFFE2E8F0),
      width: 1.5,
    ),
  );
}

const TextStyle _friendMetaStyle = TextStyle(
  color: Color(0xFF718096),
  fontSize: 11,
  fontWeight: FontWeight.w700,
);
