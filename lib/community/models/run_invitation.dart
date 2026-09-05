class CommunityRunInvitation {
  final int id;
  final int inviterId;
  final int inviteeId;
  final DateTime scheduledAt;
  final double? targetDistanceKm;
  final int? targetDurationMinutes;
  final String notes;
  final String status;
  final DateTime createdAt;

  const CommunityRunInvitation({
    required this.id,
    required this.inviterId,
    required this.inviteeId,
    required this.scheduledAt,
    this.targetDistanceKm,
    this.targetDurationMinutes,
    required this.notes,
    required this.status,
    required this.createdAt,
  });

  factory CommunityRunInvitation.fromJson(
    Map<String, dynamic> json,
  ) {
    final inviter = json['inviter'] as Map?;
    final invitee = json['invitee'] as Map?;

    return CommunityRunInvitation(
      id: _toInt(json['id']),
      inviterId: _toInt(
        inviter?['id'],
      ),
      inviteeId: _toInt(
        invitee?['id'],
      ),
      scheduledAt: DateTime.parse(
        json['scheduled_at'].toString(),
      ),
      targetDistanceKm: _toDouble(
        json['target_distance_km'],
      ),
      targetDurationMinutes: json['target_duration_minutes'] == null
          ? null
          : _toInt(
              json['target_duration_minutes'],
            ),
      notes: json['notes']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      createdAt: DateTime.parse(
        json['created_at'].toString(),
      ),
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

  static double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );
  }
}
