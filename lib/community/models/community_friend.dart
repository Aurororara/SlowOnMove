class CommunityFriend {
  final int id;
  final String name;
  final String initial;
  final String? avatar;

  const CommunityFriend({
    required this.id,
    required this.name,
    required this.initial,
    this.avatar,
  });

  factory CommunityFriend.fromJson(
    Map<String, dynamic> json,
  ) {
    return CommunityFriend(
      id: _toInt(json['id']),
      name: (json['name'] ?? '').toString(),
      initial: (json['initial'] ?? 'U').toString(),
      avatar: json['avatar']?.toString(),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }
}

class CommunityFriendRequest {
  final int id;
  final CommunityFriend sender;
  final CommunityFriend receiver;
  final String status;

  const CommunityFriendRequest({
    required this.id,
    required this.sender,
    required this.receiver,
    required this.status,
  });

  factory CommunityFriendRequest.fromJson(
    Map<String, dynamic> json,
  ) {
    return CommunityFriendRequest(
      id: CommunityFriend._toInt(json['id']),
      sender: CommunityFriend.fromJson(
        Map<String, dynamic>.from(
          json['sender'],
        ),
      ),
      receiver: CommunityFriend.fromJson(
        Map<String, dynamic>.from(
          json['receiver'],
        ),
      ),
      status: (json['status'] ?? '').toString(),
    );
  }
}
