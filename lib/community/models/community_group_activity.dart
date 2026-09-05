import 'community_group.dart';

class CommunityGroupActivity {
  final int id;
  final int groupId;
  final CommunityGroupOwner creator;
  final String title;
  final String exerciseType;
  final DateTime scheduledAt;
  final String notes;
  final int participantCount;
  final bool isJoined;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CommunityGroupActivity({
    required this.id,
    required this.groupId,
    required this.creator,
    required this.title,
    required this.exerciseType,
    required this.scheduledAt,
    required this.notes,
    required this.participantCount,
    required this.isJoined,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CommunityGroupActivity.fromJson(
    Map<String, dynamic> json,
  ) {
    return CommunityGroupActivity(
      id: _toInt(json['id']),
      groupId: _toInt(json['group_id']),
      creator: CommunityGroupOwner.fromJson(
        Map<String, dynamic>.from(
          json['creator'] ?? const {},
        ),
      ),
      title: (json['title'] ?? '').toString(),
      exerciseType: (json['exercise_type'] ?? 'slow_jogging').toString(),
      scheduledAt: DateTime.tryParse(
            json['scheduled_at']?.toString() ?? '',
          ) ??
          DateTime.now(),
      notes: (json['notes'] ?? '').toString(),
      participantCount: _toInt(json['participant_count']),
      isJoined: json['is_joined'] == true,
      createdAt: DateTime.tryParse(
            json['created_at']?.toString() ?? '',
          ) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(
            json['updated_at']?.toString() ?? '',
          ) ??
          DateTime.now(),
    );
  }
}

int _toInt(dynamic value) {
  if (value is int) {
    return value;
  }

  return int.tryParse(
        value?.toString() ?? '',
      ) ??
      0;
}
