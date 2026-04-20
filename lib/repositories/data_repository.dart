import 'package:dio/dio.dart';
import '../models/user_model.dart';
import '../models/training_log_model.dart';

class DataRepository {
  // Replace with actual local/remote server IP (e.g. 10.0.2.2 for Android Simulator, 127.0.0.1 for iOS)
  final Dio _dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000/api/'));

  // ==== Users ====
  
  /// Create or update a user profile
  Future<void> createUserProfile(UserModel user) async {
    try {
      await _dio.post('members/', data: user.toJson());
    } catch (e) {
      print('Error creating profile: $e');
    }
  }

  /// Get a user profile by ID
  Future<UserModel?> getUserProfile(String uid) async {
    try {
      final response = await _dio.get('members/$uid/');
      return UserModel.fromJson(response.data, uid);
    } catch (e) {
      print('Error getting profile: $e');
      return null;
    }
  }

  // ==== Training Logs ====
  
  /// Save a training log for a user
  Future<void> saveTrainingLog(TrainingLogModel log) async {
    try {
      await _dio.post('training-logs/', data: log.toJson());
    } catch (e) {
      print('Error saving training log: $e');
    }
  }

  /// Get past training logs (e.g. for history screen)
  Future<List<TrainingLogModel>> getUserTrainingHistory(String uid) async {
    try {
      final response = await _dio.get('training-logs/', queryParameters: {'member': uid});
      final data = response.data as List;
      return data.map((item) => TrainingLogModel.fromJson(item, item['id'].toString())).toList();
    } catch (e) {
      print('Error fetching user training history: $e');
      return [];
    }
  }
}
