import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../services/api_service.dart';
import 'models/community_post.dart';

class CommunityStore extends ChangeNotifier {
  final List<CommunityPost> _posts = [];

  bool _isLoading = false;
  String? _errorMessage;

  List<CommunityPost> get posts => List.unmodifiable(_posts);

  List<CommunityPost> get savedPosts =>
      _posts.where((post) => post.isSaved).toList(growable: false);

  int get savedCount => savedPosts.length;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  // ============================================================
  // 取得貼文
  // ============================================================

  Future<void> loadPosts() async {
    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    try {
      final response = await ApiService().dio.get(
            'community-posts/',
          );

      final data = response.data;

      if (data is! List) {
        throw Exception('貼文資料格式錯誤');
      }

      _posts
        ..clear()
        ..addAll(
          data.whereType<Map>().map(
                (item) => CommunityPost.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              ),
        );
    } on DioException catch (e) {
      _errorMessage = _getDioErrorMessage(
        e,
        defaultMessage: '取得貼文失敗',
      );
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;

      notifyListeners();
    }
  }

  // ============================================================
  // 發文
  // ============================================================

  Future<bool> addPost({
    required String content,
    required List<String> tags,
    CommunityPostType type = CommunityPostType.journey,
    WorkoutPlanData? plan,
    RecipeData? recipe,
  }) async {
    _errorMessage = null;

    final data = <String, dynamic>{
      'post_type': _postTypeToApi(type),
      'content': content,
      'tags': tags,
    };

    if (type == CommunityPostType.plan && plan != null) {
      data['workout_plan'] = plan.toJson();
    }

    try {
      final response = await ApiService().dio.post(
            'community-posts/',
            data: data,
          );

      final newPost = CommunityPost.fromJson(
        Map<String, dynamic>.from(response.data),
      );

      _posts.insert(
        0,
        newPost,
      );

      notifyListeners();

      return true;
    } on DioException catch (e) {
      _errorMessage = _getDioErrorMessage(
        e,
        defaultMessage: '發文失敗',
      );

      notifyListeners();

      return false;
    } catch (e) {
      _errorMessage = e.toString();

      notifyListeners();

      return false;
    }
  }

  // ============================================================
  // 修改貼文
  // ============================================================

  Future<bool> updatePost(
    int index, {
    required String content,
    required List<String> tags,
    required CommunityPostType type,
    WorkoutPlanData? plan,
    RecipeData? recipe,
  }) async {
    if (index < 0 || index >= _posts.length) {
      return false;
    }

    _errorMessage = null;

    final post = _posts[index];

    final data = <String, dynamic>{
      'post_type': _postTypeToApi(type),
      'content': content,
      'tags': tags,
    };

    if (type == CommunityPostType.plan && plan != null) {
      data['workout_plan'] = plan.toJson();
    }

    try {
      final response = await ApiService().dio.patch(
            'community-posts/${post.id}/',
            data: data,
          );

      _posts[index] = CommunityPost.fromJson(
        Map<String, dynamic>.from(response.data),
      );

      notifyListeners();

      return true;
    } on DioException catch (e) {
      _errorMessage = _getDioErrorMessage(
        e,
        defaultMessage: '修改貼文失敗',
      );

      notifyListeners();

      return false;
    } catch (e) {
      _errorMessage = e.toString();

      notifyListeners();

      return false;
    }
  }

  // ============================================================
  // 刪除貼文
  // ============================================================

  Future<bool> deletePost(
    int index,
  ) async {
    if (index < 0 || index >= _posts.length) {
      return false;
    }

    _errorMessage = null;

    final post = _posts[index];

    try {
      await ApiService().dio.delete(
            'community-posts/${post.id}/',
          );

      _posts.removeAt(index);

      notifyListeners();

      return true;
    } on DioException catch (e) {
      _errorMessage = _getDioErrorMessage(
        e,
        defaultMessage: '刪除貼文失敗',
      );

      notifyListeners();

      return false;
    } catch (e) {
      _errorMessage = e.toString();

      notifyListeners();

      return false;
    }
  }

  // ============================================================
  // 按讚
  // ============================================================

  Future<bool> toggleLike(
    int index,
  ) async {
    if (index < 0 || index >= _posts.length) {
      return false;
    }

    _errorMessage = null;

    final post = _posts[index];

    try {
      final response = await ApiService().dio.post(
            'community-posts/${post.id}/toggle-like/',
          );

      final data = response.data;

      _posts[index] = post.copyWith(
        isLiked: data['is_liked'] == true,
        likes: _toInt(data['like_count']),
      );

      notifyListeners();

      return true;
    } on DioException catch (e) {
      _errorMessage = _getDioErrorMessage(
        e,
        defaultMessage: '按讚失敗',
      );

      notifyListeners();

      return false;
    } catch (e) {
      _errorMessage = e.toString();

      notifyListeners();

      return false;
    }
  }

  // ============================================================
  // 收藏
  // ============================================================

  Future<bool> toggleSave(
    int index,
  ) async {
    if (index < 0 || index >= _posts.length) {
      return false;
    }

    _errorMessage = null;

    final post = _posts[index];

    try {
      final response = await ApiService().dio.post(
            'community-posts/${post.id}/toggle-favorite/',
          );

      final data = response.data;

      _posts[index] = post.copyWith(
        isSaved: data['is_saved'] == true,
      );

      notifyListeners();

      return true;
    } on DioException catch (e) {
      _errorMessage = _getDioErrorMessage(
        e,
        defaultMessage: '收藏失敗',
      );

      notifyListeners();

      return false;
    } catch (e) {
      _errorMessage = e.toString();

      notifyListeners();

      return false;
    }
  }

  // ============================================================
  // 留言
  // ============================================================

  Future<List<Map<String, dynamic>>> loadComments(
    int postId,
  ) async {
    _errorMessage = null;

    try {
      final response = await ApiService().dio.get(
            'community-posts/$postId/comments/',
          );

      final data = response.data;

      if (data is! List) {
        throw Exception('留言資料格式錯誤');
      }

      return data
          .whereType<Map>()
          .map(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();
    } on DioException catch (e) {
      _errorMessage = _getDioErrorMessage(
        e,
        defaultMessage: '取得留言失敗',
      );

      return [];
    } catch (e) {
      _errorMessage = e.toString();

      return [];
    }
  }

  Future<bool> addComment(
    int index,
    String comment,
  ) async {
    if (index < 0 || index >= _posts.length) {
      return false;
    }

    final content = comment.trim();

    if (content.isEmpty) {
      return false;
    }

    _errorMessage = null;

    final post = _posts[index];

    try {
      await ApiService().dio.post(
        'community-posts/${post.id}/comments/',
        data: {
          'content': content,
        },
      );

      _posts[index] = post.copyWith(
        commentCount: post.commentCount + 1,
      );

      notifyListeners();

      return true;
    } on DioException catch (e) {
      _errorMessage = _getDioErrorMessage(
        e,
        defaultMessage: '留言失敗',
      );

      notifyListeners();

      return false;
    } catch (e) {
      _errorMessage = e.toString();

      notifyListeners();

      return false;
    }
  }

  Future<bool> reportPost(
    int index,
    String reason,
  ) async {
    if (index < 0 || index >= _posts.length) {
      return false;
    }

    final post = _posts[index];
    final reportReason = reason.trim();

    if (reportReason.isEmpty) {
      return false;
    }

    _errorMessage = null;

    try {
      await ApiService().dio.post(
        'community-posts/${post.id}/report/',
        data: {
          'reason': reportReason,
        },
      );

      return true;
    } on DioException catch (e) {
      _errorMessage = _getDioErrorMessage(
        e,
        defaultMessage: '檢舉失敗',
      );

      notifyListeners();

      return false;
    } catch (e) {
      _errorMessage = e.toString();

      notifyListeners();

      return false;
    }
  }

  // ============================================================
  // 搜尋
  // ============================================================

  Future<void> searchPosts(
    String keyword,
  ) async {
    final query = keyword.trim();

    if (query.isEmpty) {
      await loadPosts();
      return;
    }

    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    try {
      final response = await ApiService().dio.get(
        'community-posts/',
        queryParameters: {
          'search': query,
        },
      );

      final data = response.data;

      if (data is! List) {
        throw Exception('搜尋結果格式錯誤');
      }

      _posts
        ..clear()
        ..addAll(
          data.whereType<Map>().map(
                (item) => CommunityPost.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              ),
        );
    } on DioException catch (e) {
      _errorMessage = _getDioErrorMessage(
        e,
        defaultMessage: '搜尋失敗',
      );
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;

      notifyListeners();
    }
  }

  // ============================================================
  // Helpers
  // ============================================================

  String _postTypeToApi(
    CommunityPostType type,
  ) {
    switch (type) {
      case CommunityPostType.journey:
        return 'journey';

      case CommunityPostType.plan:
        return 'plan';

      case CommunityPostType.recipe:
        return 'recipe';
    }
  }

  int _toInt(
    dynamic value,
  ) {
    if (value is int) {
      return value;
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  String _getDioErrorMessage(
    DioException e, {
    required String defaultMessage,
  }) {
    final data = e.response?.data;

    if (data is Map) {
      if (data['error'] != null) {
        return data['error'].toString();
      }

      if (data['detail'] != null) {
        return data['detail'].toString();
      }
    }

    return defaultMessage;
  }
}
