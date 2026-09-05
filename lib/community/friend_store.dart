import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import 'models/community_friend.dart';

class FriendStore extends ChangeNotifier {
  final ApiService _api = ApiService();

  final List<CommunityFriend> _friends = [];
  final List<CommunityFriendRequest> _requests = [];
  final List<CommunityFriendRequest> _pendingRequests = [];
  final List<CommunityFriend> _suggestions = [];

  bool _isLoading = false;
  String? _errorMessage;

  List<CommunityFriend> get friends => List.unmodifiable(_friends);

  List<CommunityFriendRequest> get requests => List.unmodifiable(_requests);

  List<CommunityFriendRequest> get pendingRequests =>
      List.unmodifiable(_pendingRequests);

  List<CommunityFriend> get suggestions => List.unmodifiable(_suggestions);

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  Future<void> loadAll() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await Future.wait([
        loadFriends(notify: false),
        loadRequests(notify: false),
        loadPendingRequests(notify: false),
        loadSuggestions(notify: false),
      ]);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadFriends({
    bool notify = true,
  }) async {
    try {
      final response = await _api.dio.get(
        'friends/',
      );

      _friends
        ..clear()
        ..addAll(
          _parseFriends(response.data),
        );
    } catch (e) {
      _setError(e);
    }

    if (notify) {
      notifyListeners();
    }
  }

  Future<void> loadRequests({
    bool notify = true,
  }) async {
    try {
      final response = await _api.dio.get(
        'friends/requests/',
      );

      _requests
        ..clear()
        ..addAll(
          _parseRequests(response.data),
        );
    } catch (e) {
      _setError(e);
    }

    if (notify) {
      notifyListeners();
    }
  }

  Future<void> loadPendingRequests({
    bool notify = true,
  }) async {
    try {
      final response = await _api.dio.get(
        'friends/pending/',
      );

      _pendingRequests
        ..clear()
        ..addAll(
          _parseRequests(response.data),
        );
    } catch (e) {
      _setError(e);
    }

    if (notify) {
      notifyListeners();
    }
  }

  Future<void> loadSuggestions({
    bool notify = true,
  }) async {
    try {
      final response = await _api.dio.get(
        'friends/suggestions/',
      );

      _suggestions
        ..clear()
        ..addAll(
          _parseFriends(response.data),
        );
    } catch (e) {
      _setError(e);
    }

    if (notify) {
      notifyListeners();
    }
  }

  Future<bool> sendRequest(
    int memberId,
  ) async {
    try {
      await _api.dio.post(
        'friends/request/',
        data: {
          'member_id': memberId,
        },
      );

      await loadAll();

      return true;
    } catch (e) {
      _setError(e);
      notifyListeners();

      return false;
    }
  }

  Future<bool> acceptRequest(
    int requestId,
  ) async {
    try {
      await _api.dio.post(
        'friends/$requestId/accept/',
      );

      await loadAll();

      return true;
    } catch (e) {
      _setError(e);
      notifyListeners();

      return false;
    }
  }

  Future<bool> rejectRequest(
    int requestId,
  ) async {
    try {
      await _api.dio.post(
        'friends/$requestId/reject/',
      );

      await loadAll();

      return true;
    } catch (e) {
      _setError(e);
      notifyListeners();

      return false;
    }
  }

  Future<bool> cancelRequest(
    int requestId,
  ) async {
    try {
      await _api.dio.delete(
        'friends/$requestId/cancel/',
      );

      await loadAll();

      return true;
    } catch (e) {
      _setError(e);
      notifyListeners();

      return false;
    }
  }

  Future<bool> removeFriend(
    int memberId,
  ) async {
    try {
      await _api.dio.delete(
        'friends/$memberId/remove/',
      );

      await loadAll();

      return true;
    } catch (e) {
      _setError(e);
      notifyListeners();

      return false;
    }
  }

  List<CommunityFriend> _parseFriends(
    dynamic data,
  ) {
    if (data is! List) {
      return [];
    }

    return data
        .whereType<Map>()
        .map(
          (item) => CommunityFriend.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  List<CommunityFriendRequest> _parseRequests(
    dynamic data,
  ) {
    if (data is! List) {
      return [];
    }

    return data
        .whereType<Map>()
        .map(
          (item) => CommunityFriendRequest.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  void _setError(Object error) {
    if (error is DioException &&
        error.response?.data is Map &&
        error.response?.data['error'] != null) {
      _errorMessage = error.response?.data['error'].toString();
      return;
    }

    _errorMessage = _api.getErrorMessage(error);
  }
}
