import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import 'models/run_invitation.dart';

class RunInvitationStore extends ChangeNotifier {
  final ApiService _api = ApiService();

  final Map<int, List<CommunityRunInvitation>> _invitationsByFriend = {};

  int _pendingTotal = 0;
  final Map<int, int> _pendingByFriend = {};

  String? errorMessage;

  int get pendingTotal => _pendingTotal;

  int pendingCountFor(int friendId) {
    return _pendingByFriend[friendId] ?? 0;
  }

  List<CommunityRunInvitation> invitationsFor(
    int friendId,
  ) {
    return List.unmodifiable(
      _invitationsByFriend[friendId] ?? const [],
    );
  }

  Future<void> loadInvitations(
    int friendId,
  ) async {
    errorMessage = null;

    try {
      final response = await _api.dio.get(
        'run-invitations/with/$friendId/',
      );

      final data = response.data;

      if (data is! List) {
        _invitationsByFriend[friendId] = [];
        return;
      }

      _invitationsByFriend[friendId] = data
          .whereType<Map>()
          .map(
            (item) => CommunityRunInvitation.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    } catch (e) {
      _setError(e);
    } finally {
      notifyListeners();
    }
  }

  Future<void> loadPending() async {
    errorMessage = null;

    try {
      final response = await _api.dio.get(
        'run-invitations/pending/',
      );

      final data = response.data;

      if (data is! Map) {
        _pendingTotal = 0;
        _pendingByFriend.clear();
        return;
      }

      _pendingTotal = int.tryParse(
            data['total']?.toString() ?? '',
          ) ??
          0;

      _pendingByFriend.clear();

      final friends = data['friends'];

      if (friends is List) {
        for (final item in friends) {
          if (item is! Map) {
            continue;
          }

          final friendId = int.tryParse(
            item['friend_id']?.toString() ?? '',
          );

          final pendingCount = int.tryParse(
                item['pending_count']?.toString() ?? '',
              ) ??
              0;

          if (friendId != null) {
            _pendingByFriend[friendId] = pendingCount;
          }
        }
      }
    } catch (e) {
      _setError(e);
    } finally {
      notifyListeners();
    }
  }

  Future<bool> respondInvitation({
    required int friendId,
    required int invitationId,
    required bool accept,
  }) async {
    errorMessage = null;

    try {
      await _api.dio.post(
        'run-invitations/$invitationId/${accept ? 'accept' : 'reject'}/',
      );

      await loadInvitations(
        friendId,
      );

      return true;
    } catch (e) {
      _setError(e);
      notifyListeners();

      return false;
    }
  }

  Future<bool> cancelInvitation({
    required int friendId,
    required int invitationId,
  }) async {
    errorMessage = null;

    try {
      await _api.dio.post(
        'run-invitations/$invitationId/cancel/',
      );

      await loadInvitations(
        friendId,
      );

      await loadPending();

      return true;
    } catch (e) {
      _setError(e);
      notifyListeners();

      return false;
    }
  }

  Future<bool> sendInvitation({
    required int inviteeId,
    required DateTime scheduledAt,
    double? targetDistanceKm,
    int? targetDurationMinutes,
    String notes = '',
  }) async {
    errorMessage = null;

    try {
      await _api.dio.post(
        'run-invitations/',
        data: {
          'invitee_id': inviteeId,
          'scheduled_at': scheduledAt.toUtc().toIso8601String(),
          'target_distance_km': targetDistanceKm,
          'target_duration_minutes': targetDurationMinutes,
          'notes': notes.trim(),
        },
      );

      await loadPending();

      return true;
    } catch (e) {
      _setError(e);
      notifyListeners();
      return false;
    }
  }

  void _setError(Object error) {
    if (error is DioException &&
        error.response?.data is Map &&
        error.response?.data['error'] != null) {
      errorMessage = error.response?.data['error'].toString();
      return;
    }

    errorMessage = _api.getErrorMessage(error);
  }
}
