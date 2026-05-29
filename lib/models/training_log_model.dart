class TrainingLogModel {
  final String? logId;
  final String memberId;
  final DateTime startTime;
  final DateTime endTime;
  final int totalMins;
  final int postureScore; // Based on average accuracy
  final int calories;
  final int stepCount;

  TrainingLogModel({
    this.logId,
    required this.memberId,
    required this.startTime,
    required this.endTime,
    required this.totalMins,
    required this.postureScore,
    required this.calories,
    required this.stepCount,
  });

  factory TrainingLogModel.fromJson(Map<String, dynamic> json, String id) {
    return TrainingLogModel(
      logId: id,
      memberId:
          json['member_id']?.toString() ?? json['member']?.toString() ?? '',
      startTime: json['start_time'] != null
          ? DateTime.parse(json['start_time'])
          : DateTime.now(),
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'])
          : DateTime.now(),
      totalMins: (json['total_mins'] ?? 0).toInt(),
      postureScore: (json['posture_score'] ?? 0).toInt(),
      calories: (json['calories'] ?? 0).toInt(),
      stepCount: (json['step_count'] ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'member_id': memberId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'total_mins': totalMins,
      'posture_score': postureScore,
      'calories': calories,
      'step_count': stepCount,
    };
  }
}
