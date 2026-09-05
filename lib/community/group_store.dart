import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import 'models/community_group.dart';
import 'models/community_group_join_request.dart';

class GroupStore extends ChangeNotifier {
  final ApiService _api = ApiService();

  final List<CommunityGroup> _groups = [];
  final List<CommunityGroup> _discoverGroups = [];
  final Map<int, List<CommunityGroupJoinRequest>> _joinRequestsByGroup = {};

  CommunityGroup? _selectedGroup;
  bool _isLoading = false;
  bool _isCreating = false;
  String? _errorMessage;

  List<CommunityGroup> get groups => List.unmodifiable(_groups);

  List<CommunityGroup> get discoverGroups => List.unmodifiable(_discoverGroups);

  List<CommunityGroupJoinRequest> joinRequestsFor(
    int groupId,
  ) {
    return List.unmodifiable(
      _joinRequestsByGroup[groupId] ?? const [],
    );
  }

  CommunityGroup? get selectedGroup => _selectedGroup;

  bool get isLoading => _isLoading;

  bool get isCreating => _isCreating;

  String? get errorMessage => _errorMessage;

  Future<void> loadGroups({
    String search = '',
  }) async {
    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    try {
      final response = await _api.dio.get(
        'groups/',
        queryParameters: search.trim().isEmpty
            ? null
            : {
                'search': search.trim(),
              },
      );

      final data = response.data;

      if (data is! List) {
        throw Exception('群組資料格式錯誤');
      }

      _groups
        ..clear()
        ..addAll(
          data.whereType<Map>().map(
                (item) => CommunityGroup.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              ),
        );
    } catch (e) {
      _setError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDiscoverGroups({
    String search = '',
  }) async {
    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    try {
      final response = await _api.dio.get(
        'groups/discover/',
        queryParameters: search.trim().isEmpty
            ? null
            : {
                'search': search.trim(),
              },
      );

      final data = response.data;

      if (data is! List) {
        throw Exception('探索群組資料格式錯誤');
      }

      _discoverGroups
        ..clear()
        ..addAll(
          data.whereType<Map>().map(
                (item) => CommunityGroup.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              ),
        );
    } catch (e) {
      _setError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> joinGroup(
    int groupId,
  ) async {
    _errorMessage = null;

    try {
      final response = await _api.dio.post(
        'groups/$groupId/join/',
      );

      if (response.data is! Map) {
        throw Exception('加入群組資料格式錯誤');
      }

      final group = CommunityGroup.fromJson(
        Map<String, dynamic>.from(
          response.data,
        ),
      );

      _discoverGroups.removeWhere(
        (item) => item.id == groupId,
      );

      final index = _groups.indexWhere(
        (item) => item.id == group.id,
      );

      if (index >= 0) {
        _groups[index] = group;
      } else {
        _groups.insert(
          0,
          group,
        );
      }

      notifyListeners();

      return true;
    } catch (e) {
      _setError(e);
      notifyListeners();

      return false;
    }
  }

  Future<bool> loadJoinRequests(
    int groupId,
  ) async {
    _errorMessage = null;

    try {
      final response = await _api.dio.get(
        'groups/$groupId/join-requests/',
      );

      final data = response.data;

      if (data is! List) {
        throw Exception('群組加入申請資料格式錯誤');
      }

      _joinRequestsByGroup[groupId] = data
          .whereType<Map>()
          .map(
            (item) => CommunityGroupJoinRequest.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();

      notifyListeners();

      return true;
    } catch (e) {
      _setError(e);
      notifyListeners();

      return false;
    }
  }

  Future<bool> respondJoinRequest({
    required int groupId,
    required int requestId,
    required bool accept,
  }) async {
    _errorMessage = null;

    try {
      await _api.dio.post(
        'groups/$groupId/join-requests/$requestId/respond/',
        data: {
          'action': accept ? 'accept' : 'reject',
        },
      );

      _joinRequestsByGroup[groupId]?.removeWhere(
        (item) => item.id == requestId,
      );

      if (accept) {
        await loadGroup(
          groupId,
          showLoading: false,
        );
      }

      notifyListeners();

      return true;
    } catch (e) {
      _setError(e);
      notifyListeners();

      return false;
    }
  }

  Future<bool> loadGroup(
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
        'groups/$groupId/',
      );

      final data = response.data;

      if (data is! Map) {
        throw Exception('群組資料格式錯誤');
      }

      final group = CommunityGroup.fromJson(
        Map<String, dynamic>.from(data),
      );

      _selectedGroup = group;

      final index = _groups.indexWhere(
        (item) => item.id == group.id,
      );

      if (index >= 0) {
        _groups[index] = group;
      }

      return true;
    } catch (e) {
      _setError(e);
      return false;
    } finally {
      if (showLoading) {
        _isLoading = false;
      }

      notifyListeners();
    }
  }

  Future<bool> requestJoinGroup(
    int groupId,
  ) async {
    _errorMessage = null;

    try {
      await _api.dio.post(
        'groups/$groupId/request-join/',
      );

      notifyListeners();

      return true;
    } catch (e) {
      _setError(e);
      notifyListeners();

      return false;
    }
  }

  Future<bool> createGroup({
    required String name,
    required String description,
    required bool isPrivate,
    String exerciseType = 'mixed',
    int weeklyGoalTarget = 20,
  }) async {
    final groupName = name.trim();
    final groupDescription = description.trim();

    if (groupName.isEmpty || groupDescription.isEmpty) {
      return false;
    }

    _isCreating = true;
    _errorMessage = null;

    notifyListeners();

    try {
      final response = await _api.dio.post(
        'groups/',
        data: {
          'name': groupName,
          'description': groupDescription,
          'is_private': isPrivate,
          'exercise_type': exerciseType,
          'weekly_goal_target': weeklyGoalTarget,
        },
      );

      final group = CommunityGroup.fromJson(
        Map<String, dynamic>.from(
          response.data,
        ),
      );

      _groups.insert(
        0,
        group,
      );

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

  void clearSelectedGroup() {
    _selectedGroup = null;
    notifyListeners();
  }
}
