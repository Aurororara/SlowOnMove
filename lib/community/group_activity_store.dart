import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import 'models/community_group_activity.dart';

class GroupActivityStore extends ChangeNotifier {
  final ApiService _api = ApiService();

  final Map<int, List<CommunityGroupActivity>> _activitiesByGroup = {};

  bool _isLoading = false;
  bool _isCreating = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;

  bool get isCreating => _isCreating;

  String? get errorMessage => _errorMessage;

  List<CommunityGroupActivity> activitiesFor(
    int groupId,
  ) {
    return List.unmodifiable(
      _activitiesByGroup[groupId] ?? const <CommunityGroupActivity>[],
    );
  }

  Future<bool> joinActivity({
    required int groupId,
    required int activityId,
  }) async {
    _errorMessage = null;

    notifyListeners();

    try {
      final response = await _api.dio.post(
        'groups/$groupId/activities/$activityId/join/',
      );

      final data = response.data;

      if (data is! Map) {
        throw Exception(
          '加入群組活動回傳格式錯誤',
        );
      }

      final updated = CommunityGroupActivity.fromJson(
        Map<String, dynamic>.from(data),
      );

      _replaceActivity(
        groupId: groupId,
        activity: updated,
      );

      notifyListeners();

      return true;
    } catch (e) {
      _setError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> leaveActivity({
    required int groupId,
    required int activityId,
  }) async {
    _errorMessage = null;

    notifyListeners();

    try {
      final response = await _api.dio.post(
        'groups/$groupId/activities/$activityId/leave/',
      );

      final data = response.data;

      if (data is! Map) {
        throw Exception(
          '取消群組活動回傳格式錯誤',
        );
      }

      final updated = CommunityGroupActivity.fromJson(
        Map<String, dynamic>.from(data),
      );

      _replaceActivity(
        groupId: groupId,
        activity: updated,
      );

      notifyListeners();

      return true;
    } catch (e) {
      _setError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> loadActivities(
    int groupId, {
    bool showLoading = true,
  }) async {
    if (showLoading) {
      _isLoading = true;
      notifyListeners();
    }

    _errorMessage = null;

    try {
      final response = await _api.dio.get(
        'groups/$groupId/activities/',
      );

      final data = response.data;

      if (data is! List) {
        throw Exception(
          '群組活動資料格式錯誤',
        );
      }

      _activitiesByGroup[groupId] = data
          .whereType<Map>()
          .map(
            (item) => CommunityGroupActivity.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    } catch (e) {
      _setError(e);
    } finally {
      if (showLoading) {
        _isLoading = false;
      }

      notifyListeners();
    }
  }

  Future<bool> createActivity({
    required int groupId,
    required String title,
    required String exerciseType,
    required DateTime scheduledAt,
    required String notes,
  }) async {
    _isCreating = true;
    _errorMessage = null;

    notifyListeners();

    try {
      final response = await _api.dio.post(
        'groups/$groupId/activities/',
        data: {
          'title': title,
          'exercise_type': exerciseType,
          'scheduled_at': scheduledAt.toIso8601String(),
          'notes': notes,
        },
      );

      final data = response.data;

      if (data is! Map) {
        throw Exception(
          '建立群組活動回傳格式錯誤',
        );
      }

      final activity = CommunityGroupActivity.fromJson(
        Map<String, dynamic>.from(data),
      );

      final current = List<CommunityGroupActivity>.from(
        _activitiesByGroup[groupId] ?? const <CommunityGroupActivity>[],
      );

      current.add(activity);

      current.sort(
        (a, b) => a.scheduledAt.compareTo(
          b.scheduledAt,
        ),
      );

      _activitiesByGroup[groupId] = current;

      return true;
    } catch (e) {
      _setError(e);
      return false;
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _replaceActivity({
    required int groupId,
    required CommunityGroupActivity activity,
  }) {
    final current = List<CommunityGroupActivity>.from(
      _activitiesByGroup[groupId] ?? const <CommunityGroupActivity>[],
    );

    final index = current.indexWhere(
      (item) => item.id == activity.id,
    );

    if (index == -1) {
      current.add(activity);
    } else {
      current[index] = activity;
    }

    current.sort(
      (a, b) => a.scheduledAt.compareTo(
        b.scheduledAt,
      ),
    );

    _activitiesByGroup[groupId] = current;
  }

  void _setError(Object error) {
    if (error is DioException &&
        error.response?.data is Map &&
        error.response?.data['error'] != null) {
      _errorMessage = error.response?.data['error'].toString();
      return;
    }

    if (error is DioException &&
        error.response?.data is Map &&
        error.response?.data['detail'] != null) {
      _errorMessage = error.response?.data['detail'].toString();
      return;
    }

    _errorMessage = _api.getErrorMessage(error);
  }
}
