import 'community_group.dart';

class CommunityGroupInvitation {
  final int id;
  final int groupId;
  final String groupName;
  final CommunityGroupOwner inviter;
  final CommunityGroupOwner invitee;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? respondedAt;

  const CommunityGroupInvitation({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.inviter,
    required this.invitee,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.respondedAt,
  });

  factory CommunityGroupInvitation.fromJson(
    Map<String, dynamic> json,
  ) {
    return CommunityGroupInvitation(
      id: _toInt(json['id']),
      groupId: _toInt(json['group_id']),
      groupName: (json['group_name'] ?? '').toString(),
      inviter: CommunityGroupOwner.fromJson(
        Map<String, dynamic>.from(
          json['inviter'] ?? const {},
        ),
      ),
      invitee: CommunityGroupOwner.fromJson(
        Map<String, dynamic>.from(
          json['invitee'] ?? const {},
        ),
      ),
      status: (json['status'] ?? 'pending').toString(),
      createdAt: DateTime.tryParse(
            json['created_at']?.toString() ?? '',
          ) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(
            json['updated_at']?.toString() ?? '',
          ) ??
          DateTime.now(),
      respondedAt: json['responded_at'] == null
          ? null
          : DateTime.tryParse(
              json['responded_at'].toString(),
            ),
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
