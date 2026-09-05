class CommunityChatMessage {
  final int id;
  final int senderId;
  final int receiverId;
  final String content;
  final bool isMine;
  final bool isRead;
  final DateTime createdAt;

  const CommunityChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.isMine,
    required this.isRead,
    required this.createdAt,
  });

  factory CommunityChatMessage.fromJson(
    Map<String, dynamic> json,
  ) {
    return CommunityChatMessage(
      id: _toInt(json['id']),
      senderId: _toInt(json['sender_id']),
      receiverId: _toInt(json['receiver_id']),
      content: (json['content'] ?? '').toString(),
      isMine: json['is_mine'] == true,
      isRead: json['is_read'] == true,
      createdAt: DateTime.tryParse(
            json['created_at']?.toString() ?? '',
          ) ??
          DateTime.now(),
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
