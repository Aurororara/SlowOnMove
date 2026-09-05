import 'package:flutter/material.dart';
import '../../utils/group_formatters.dart';
import '../common/community_button.dart';
import '../common/community_card_styles.dart';

class GroupCard extends StatelessWidget {
  final String name;
  final String description;
  final int members;
  final int weeklyGoalCurrent;
  final int weeklyGoalTarget;
  final double progress;
  final String actionLabel;
  final bool isPrivate;
  final String exerciseType;
  final bool showCrown;
  final bool showSettings;
  final VoidCallback onActionTap;
  final VoidCallback? onSettingsTap;

  const GroupCard({
    super.key,
    required this.name,
    required this.description,
    required this.members,
    required this.weeklyGoalCurrent,
    required this.weeklyGoalTarget,
    required this.progress,
    required this.actionLabel,
    this.isPrivate = false,
    this.exerciseType = 'slow_jogging',
    required this.onActionTap,
    this.showCrown = false,
    this.showSettings = false,
    this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: communityCardDecoration(),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.groups_2_outlined,
                    color: Colors.white, size: 27),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (showCrown)
                          const Icon(Icons.workspace_premium_outlined,
                              color: Color(0xFFD69E2E), size: 16),
                        const SizedBox(width: 5),
                        Icon(
                          isPrivate ? Icons.lock_outline : Icons.public,
                          color: const Color(0xFF718096),
                          size: 15,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: communityMetaStyle,
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Icon(Icons.people_outline,
                            color: Color(0xFF718096), size: 14),
                        const SizedBox(width: 4),
                        Text('$members/30 人', style: communityMetaStyle),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextButton(
                    onPressed: onActionTap,
                    style: communityButtonStyle(true),
                    child: Text(
                      actionLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              if (showSettings) ...[
                const SizedBox(width: 10),
                GroupCardIconButton(
                  icon: Icons.settings_outlined,
                  onTap: onSettingsTap ?? () {},
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      '每週目標',
                      style: TextStyle(
                        color: Color(0xFF4A5568),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      groupWeeklyGoalLabel(
                        exerciseType,
                        weeklyGoalCurrent,
                        weeklyGoalTarget,
                      ),
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
