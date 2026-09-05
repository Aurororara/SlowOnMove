class CommunityGroupOwner {
  final int id;
  final String name;
  final String initial;
  final String? avatar;

  const CommunityGroupOwner({
    required this.id,
    required this.name,
    required this.initial,
    this.avatar,
  });

  factory CommunityGroupOwner.fromJson(
    Map<String, dynamic> json,
  ) {
    return CommunityGroupOwner(
      id: _toInt(json['id']),
      name: (json['name'] ?? '').toString(),
      initial: (json['initial'] ?? 'U').toString(),
      avatar: json['avatar']?.toString(),
    );
  }
}

class CommunityGroupMember {
  final int id;
  final CommunityGroupOwner member;
  final DateTime joinedAt;

  const CommunityGroupMember({
    required this.id,
    required this.member,
    required this.joinedAt,
  });

  factory CommunityGroupMember.fromJson(
    Map<String, dynamic> json,
  ) {
    return CommunityGroupMember(
      id: _toInt(json['id']),
      member: CommunityGroupOwner.fromJson(
        Map<String, dynamic>.from(
          json['member'] ?? const {},
        ),
      ),
      joinedAt: DateTime.tryParse(
            json['joined_at']?.toString() ?? '',
          ) ??
          DateTime.now(),
    );
  }
}

class CommunityGroup {
  final int id;
  final CommunityGroupOwner owner;
  final String name;
  final String description;
  final bool isPrivate;
  final String exerciseType;
  final int weeklyGoalTarget;
  final int memberCount;
  final List<CommunityGroupMember> members;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CommunityGroup({
    required this.id,
    required this.owner,
    required this.name,
    required this.description,
    required this.isPrivate,
    required this.exerciseType,
    required this.weeklyGoalTarget,
    required this.memberCount,
    required this.members,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CommunityGroup.fromJson(
    Map<String, dynamic> json,
  ) {
    return CommunityGroup(
      id: _toInt(json['id']),
      owner: CommunityGroupOwner.fromJson(
        Map<String, dynamic>.from(
          json['owner'] ?? const {},
        ),
      ),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      isPrivate: json['is_private'] == true,
      exerciseType: (json['exercise_type'] ?? 'mixed').toString(),
      weeklyGoalTarget: _toInt(json['weekly_goal_target']),
      memberCount: _toInt(json['member_count']),
      members: _parseMembers(json['members']),
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

List<CommunityGroupMember> _parseMembers(
  dynamic value,
) {
  if (value is! List) {
    return const [];
  }

  return value
      .whereType<Map>()
      .map(
        (item) => CommunityGroupMember.fromJson(
          Map<String, dynamic>.from(item),
        ),
      )
      .toList();
}
