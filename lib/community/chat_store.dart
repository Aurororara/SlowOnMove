import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import 'models/community_chat.dart';

class ChatStore extends ChangeNotifier {
  final ApiService _api = ApiService();

  final Map<int, List<CommunityChatMessage>> _messagesByFriend = {};
  final Map<int, int?> _firstUnreadMessageByFriend = {};

  int _unreadTotal = 0;
  final Map<int, int> _unreadByFriend = {};

  bool _isLoading = false;
  bool _isSending = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get errorMessage => _errorMessage;
  int get unreadTotal => _unreadTotal;

  int? firstUnreadMessageIdFor(int friendId) {
    return _firstUnreadMessageByFriend[friendId];
  }

  int unreadCountFor(int friendId) {
    return _unreadByFriend[friendId] ?? 0;
  }

  List<CommunityChatMessage> messagesFor(int friendId) {
    return List.unmodifiable(
      _messagesByFriend[friendId] ?? const [],
    );
  }

  Future<void> loadUnread() async {
    try {
      final response = await _api.dio.get(
        'chats/unread/',
      );

      final data = response.data;

      if (data is! Map) {
        return;
      }

      _unreadTotal = _toInt(data['total']);
      _unreadByFriend.clear();

      final friends = data['friends'];

      if (friends is List) {
        for (final item in friends) {
          if (item is! Map) {
            continue;
          }

          final friendId = _toInt(
            item['friend_id'],
          );

          final unreadCount = _toInt(
            item['unread_count'],
          );

          if (friendId > 0 && unreadCount > 0) {
            _unreadByFriend[friendId] = unreadCount;
          }
        }
      }

      notifyListeners();
    } catch (e) {
      _setError(e);
      notifyListeners();
    }
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  Future<void> loadMessages(
    int friendId, {
    bool showLoading = true,
    bool preserveFirstUnread = false,
  }) async {
    if (showLoading) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final response = await _api.dio.get(
        'chats/$friendId/messages/',
      );

      final data = response.data;

      if (data is Map) {
        if (!preserveFirstUnread) {
          final firstUnreadId = data['first_unread_message_id'];

          if (firstUnreadId == null) {
            _firstUnreadMessageByFriend[friendId] = null;
          } else {
            _firstUnreadMessageByFriend[friendId] = _toInt(
              firstUnreadId,
            );
          }
        }

        final messages = data['messages'];

        if (messages is List) {
          _messagesByFriend[friendId] = messages
              .whereType<Map>()
              .map(
                (item) => CommunityChatMessage.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList();
        } else {
          _messagesByFriend[friendId] = [];
        }
      } else {
        _firstUnreadMessageByFriend[friendId] = null;
        _messagesByFriend[friendId] = [];
      }
      final readCount = _unreadByFriend.remove(friendId) ?? 0;

      _unreadTotal -= readCount;

      if (_unreadTotal < 0) {
        _unreadTotal = 0;
      }
    } catch (e) {
      _setError(e);
    } finally {
      if (showLoading) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<bool> sendMessage(
    int friendId,
    String content,
  ) async {
    final text = content.trim();

    if (text.isEmpty) {
      return false;
    }

    _isSending = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.dio.post(
        'chats/$friendId/messages/',
        data: {
          'content': text,
        },
      );

      final message = CommunityChatMessage.fromJson(
        Map<String, dynamic>.from(
          response.data,
        ),
      );

      final messages = List<CommunityChatMessage>.from(
        _messagesByFriend[friendId] ?? const [],
      );

      messages.add(message);

      _messagesByFriend[friendId] = messages;

      return true;
    } catch (e) {
      _setError(e);
      return false;
    } finally {
      _isSending = false;
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

    _errorMessage = _api.getErrorMessage(error);
  }

  void clearFirstUnreadMessageId(int friendId) {
    _firstUnreadMessageByFriend.remove(friendId);
  }
}
