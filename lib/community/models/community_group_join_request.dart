import 'community_group.dart';

class CommunityGroupJoinRequest {
  final int id;
  final int groupId;
  final String groupName;
  final CommunityGroupOwner requester;
  final String status;
  final DateTime createdAt;

  const CommunityGroupJoinRequest({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.requester,
    required this.status,
    required this.createdAt,
  });

  factory CommunityGroupJoinRequest.fromJson(
    Map<String, dynamic> json,
  ) {
    return CommunityGroupJoinRequest(
      id: _toInt(json['id']),
      groupId: _toInt(json['group_id']),
      groupName: (json['group_name'] ?? '').toString(),
      requester: CommunityGroupOwner.fromJson(
        Map<String, dynamic>.from(
          json['requester'] ?? const {},
        ),
      ),
      status: (json['status'] ?? '').toString(),
      createdAt: DateTime.tryParse(
            json['created_at']?.toString() ?? '',
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
