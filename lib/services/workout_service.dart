import 'package:dio/dio.dart';

class WorkoutService {
  static final Dio _dio = Dio(BaseOptions(baseUrl: '你的API網址'));

  static Future<void> saveTrainingLog({
    required int timeSeconds,
    required int stepCount,
    required double accuracy,
    required int calories,
  }) async {
    try {
      await _dio.post('/api/training-logs/', data: {
        "exercise_type": "slow_jogging", // 根據 seed_db.py 的設定
        "total_mins": timeSeconds ~/ 60,
        "posture_score": accuracy.toInt(),
        "calories": calories,
        "step_count": stepCount, // 如果後端模型有這一欄的話
        "start_time": DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print("儲存失敗: $e");
    }
  }
}