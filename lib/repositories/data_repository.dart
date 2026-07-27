import '../models/user_model.dart';
import '../models/training_log_model.dart';
import '../services/api_service.dart';

class DataRepository {
  final ApiService _api = ApiService();

  // ==== Users ====

  Future<void> createUserProfile(UserModel user) async {
    try {
      await _api.dio.post(
        'members/',
        data: user.toJson(),
      );
    } catch (e) {
      throw _api.getErrorMessage(e);
    }
  }

  Future<UserModel?> getUserProfile(String uid) async {
    try {
      final response = await _api.dio.get('members/$uid/');
      return UserModel.fromJson(response.data, uid);
    } catch (e) {
      throw _api.getErrorMessage(e);
    }
  }

  // ==== Training Logs ====

  Future<void> saveTrainingLog(TrainingLogModel log) async {
    try {
      await _api.dio.post(
        'training-logs/',
        data: log.toJson(),
      );
    } catch (e) {
      throw _api.getErrorMessage(e);
    }
  }

  Future<void> saveWorkoutTrainingLog({
    required int timeSeconds,
    required int stepCount,
    required double accuracy,
    required int calories,
  }) async {
    try {
      await _api.dio.post(
        'training-logs/',
        data: {
          'exercise_type': 'slow_jogging',
          'total_mins': timeSeconds ~/ 60,
          'posture_score': accuracy.toInt(),
          'calories': calories,
          'step_count': stepCount,
          'start_time': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      throw _api.getErrorMessage(e);
    }
  }

  Future<List<TrainingLogModel>> getUserTrainingHistory(String uid) async {
    try {
      final response = await _api.dio.get(
        'training-logs/',
        queryParameters: {
          'member': uid,
        },
      );

      final List data = response.data as List;

      return data
          .map(
            (item) => TrainingLogModel.fromJson(
              item,
              item['id'].toString(),
            ),
          )
          .toList();
    } catch (e) {
      throw _api.getErrorMessage(e);
    }
  }
}
