import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import 'models/community_group_invitation.dart';

class GroupInvitationStore extends ChangeNotifier {
  final ApiService _api = ApiService();

  final List<CommunityGroupInvitation> _pendingInvitations = [];

  bool _isLoading = false;
  bool _isSending = false;
  bool _isResponding = false;
  String? _errorMessage;

  List<CommunityGroupInvitation> get pendingInvitations =>
      List.unmodifiable(_pendingInvitations);

  int get pendingTotal => _pendingInvitations.length;

  bool get isLoading => _isLoading;

  bool get isSending => _isSending;

  bool get isResponding => _isResponding;

  String? get errorMessage => _errorMessage;

  Future<void> loadPending() async {
    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    try {
      final response = await _api.dio.get(
        'group-invitations/pending/',
      );

      final data = response.data;

      if (data is! List) {
        throw Exception('群組邀請資料格式錯誤');
      }

      _pendingInvitations
        ..clear()
        ..addAll(
          data.whereType<Map>().map(
                (item) => CommunityGroupInvitation.fromJson(
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

  Future<bool> sendInvitation({
    required int groupId,
    required int inviteeId,
  }) async {
    _isSending = true;
    _errorMessage = null;

    notifyListeners();

    try {
      await _api.dio.post(
        'groups/$groupId/invite/',
        data: {
          'invitee_id': inviteeId,
        },
      );

      return true;
    } catch (e) {
      _setError(e);
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<bool> respondInvitation({
    required int invitationId,
    required bool accept,
  }) async {
    _isResponding = true;
    _errorMessage = null;

    notifyListeners();

    try {
      final response = await _api.dio.post(
        'group-invitations/$invitationId/respond/',
        data: {
          'action': accept ? 'accept' : 'reject',
        },
      );

      final data = response.data;

      if (data is Map) {
        final updated = CommunityGroupInvitation.fromJson(
          Map<String, dynamic>.from(data),
        );

        _pendingInvitations.removeWhere(
          (item) => item.id == updated.id,
        );
      } else {
        _pendingInvitations.removeWhere(
          (item) => item.id == invitationId,
        );
      }

      return true;
    } catch (e) {
      _setError(e);
      return false;
    } finally {
      _isResponding = false;
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
}
