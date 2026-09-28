import 'api_service.dart';

class WorkoutMenuService {
  final ApiService _api = ApiService();

  Future<List<Map<String, dynamic>>> getMenus() async {
    final response = await _api.dio.get(
      'workout-menus/',
    );

    final data = response.data;

    if (data is List) {
      return data
          .map(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();
    }

    return [];
  }

  Future<List<Map<String, dynamic>>> getMyWorkoutItems() async {
    final response = await _api.dio.get(
      'workout-items/',
    );

    final data = response.data;

    if (data is List) {
      return data
          .map(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();
    }

    return [];
  }

  Future<bool> applyMenu(int menuId) async {
    final response = await _api.dio.post(
      'workout-items/',
      data: {
        'menu': menuId,
      },
    );

    final data = response.data;

    if (data is Map<String, dynamic>) {
      if (data['already_applied'] == true) {
        return false;
      }
    }

    return true;
  }

  Future<Map<String, dynamic>> applyPostWorkoutPlan(
    int postWorkoutPlanId,
  ) async {
    final response = await _api.dio.post(
      'workout-menus/apply/',
      data: {
        'post_workout_plan_id': postWorkoutPlanId,
      },
    );

    return Map<String, dynamic>.from(
      response.data,
    );
  }

  Future<Map<String, dynamic>> createMenuSession(
    int menuId,
  ) async {
    final response = await _api.dio.post(
      'workout-menu-sessions/',
      data: {
        'menu': menuId,
      },
    );

    return Map<String, dynamic>.from(
      response.data,
    );
  }

  Future<Map<String, dynamic>> completeMenuSession(
    int sessionId,
  ) async {
    final response = await _api.dio.post(
      'workout-menu-sessions/$sessionId/complete/',
    );

    return Map<String, dynamic>.from(
      response.data,
    );
  }

  Future<Map<String, dynamic>> abandonMenuSession(
    int sessionId,
  ) async {
    final response = await _api.dio.post(
      'workout-menu-sessions/$sessionId/abandon/',
    );

    return Map<String, dynamic>.from(
      response.data,
    );
  }

  Future<void> deleteWorkoutItem(
    int itemId,
  ) async {
    await _api.dio.delete(
      'workout-items/$itemId/',
    );
  }
}
