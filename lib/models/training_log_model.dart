import 'package:cloud_firestore/cloud_firestore.dart';

class TrainingLogModel {
  final String? logId;
  final String memberId;
  final DateTime startTime;
  final DateTime endTime;
  final int totalMins;
  final int postureScore; // Based on average accuracy
  final int calories;

  TrainingLogModel({
    this.logId,
    required this.memberId,
    required this.startTime,
    required this.endTime,
    required this.totalMins,
    required this.postureScore,
    required this.calories,
  });

  factory TrainingLogModel.fromJson(Map<String, dynamic> json, String id) {
    return TrainingLogModel(
      logId: id,
      memberId: json['member_id'] as String? ?? '',
      startTime: (json['start_time'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (json['end_time'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalMins: json['total_mins'] as int? ?? 0,
      postureScore: json['posture_score'] as int? ?? 0,
      calories: json['calories'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'member_id': memberId,
      'start_time': Timestamp.fromDate(startTime),
      'end_time': Timestamp.fromDate(endTime),
      'total_mins': totalMins,
      'posture_score': postureScore,
      'calories': calories,
    };
  }
}
