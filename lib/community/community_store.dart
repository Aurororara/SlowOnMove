import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../services/api_service.dart';
import 'models/community_post.dart';

class CommunityStore extends ChangeNotifier {
  final List<CommunityPost> _posts = [];

  final List<CommunityPost> _savedPosts = [];
  bool _savedPostsLoading = false;

  List<CommunityPost> get savedPosts => List.unmodifiable(_savedPosts);

  int get savedCount => _savedPosts.length;

  List<CommunityPost> get savedWorkoutPlans => _savedPosts
      .where((post) => post.type == CommunityPostType.plan)
      .toList(growable: false);

  bool get savedPostsLoading => _savedPostsLoading;

  bool _isLoading = false;
  String? _errorMessage;

  List<CommunityPost> get posts => List.unmodifiable(_posts);

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

  Future<bool> loadSavedPosts() async {
    if (_savedPostsLoading) {
      return false;
    }

    _savedPostsLoading = true;
    notifyListeners();

    try {
      final response = await ApiService().dio.get(
            'community-posts/saved/',
          );

      final data = response.data;

      if (data is List) {
        _savedPosts
          ..clear()
          ..addAll(
            data.whereType<Map>().map(
                  (json) => CommunityPost.fromJson(
                    Map<String, dynamic>.from(json),
                  ),
                ),
          );
      }

      return true;
    } on DioException catch (e) {
      _errorMessage = _getDioErrorMessage(
        e,
        defaultMessage: '取得收藏失敗',
      );

      return false;
    } catch (e) {
      _errorMessage = e.toString();

      return false;
    } finally {
      _savedPostsLoading = false;
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

  Future<bool> toggleLikeByPostId(int postId) async {
    _errorMessage = null;

    try {
      final response = await ApiService().dio.post(
            'community-posts/$postId/toggle-like/',
          );

      final data = response.data;

      final isLiked = data['is_liked'] == true;
      final likes = _toInt(data['like_count']);

      final savedIndex = _savedPosts.indexWhere(
        (post) => post.id == postId,
      );

      if (savedIndex != -1) {
        _savedPosts[savedIndex] = _savedPosts[savedIndex].copyWith(
          isLiked: isLiked,
          likes: likes,
        );
      }

      final postIndex = _posts.indexWhere(
        (post) => post.id == postId,
      );

      if (postIndex != -1) {
        _posts[postIndex] = _posts[postIndex].copyWith(
          isLiked: isLiked,
          likes: likes,
        );
      }

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

      final isSaved = data['is_saved'] == true;

      final updatedPost = post.copyWith(
        isSaved: isSaved,
      );

      _posts[index] = updatedPost;

      if (isSaved) {
        final exists = _savedPosts.any(
          (item) => item.id == updatedPost.id,
        );

        if (!exists) {
          _savedPosts.insert(0, updatedPost);
        }
      } else {
        _savedPosts.removeWhere(
          (item) => item.id == updatedPost.id,
        );
      }

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

  Future<bool> toggleSaveByPostId(int postId) async {
    _errorMessage = null;

    try {
      final response = await ApiService().dio.post(
            'community-posts/$postId/toggle-favorite/',
          );

      final data = response.data;
      final isSaved = data['is_saved'] == true;

      // 更新社群貼文列表
      final postIndex = _posts.indexWhere(
        (post) => post.id == postId,
      );

      if (postIndex != -1) {
        _posts[postIndex] = _posts[postIndex].copyWith(
          isSaved: isSaved,
        );
      }

      // 找出目前收藏列表中的貼文
      final savedIndex = _savedPosts.indexWhere(
        (post) => post.id == postId,
      );

      if (isSaved) {
        // 收藏
        if (savedIndex == -1) {
          CommunityPost? post;

          if (postIndex != -1) {
            post = _posts[postIndex];
          }

          if (post != null) {
            _savedPosts.insert(0, post);
          }
        }
      } else {
        // 取消收藏
        if (savedIndex != -1) {
          _savedPosts.removeAt(savedIndex);
        }
      }

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

  Future<bool> addCommentByPostId(
    int postId,
    String comment,
  ) async {
    final content = comment.trim();

    if (content.isEmpty) {
      return false;
    }

    _errorMessage = null;

    try {
      await ApiService().dio.post(
        'community-posts/$postId/comments/',
        data: {
          'content': content,
        },
      );

      final savedIndex = _savedPosts.indexWhere(
        (post) => post.id == postId,
      );

      if (savedIndex != -1) {
        final post = _savedPosts[savedIndex];

        _savedPosts[savedIndex] = post.copyWith(
          commentCount: post.commentCount + 1,
        );
      }

      final postIndex = _posts.indexWhere(
        (post) => post.id == postId,
      );

      if (postIndex != -1) {
        final post = _posts[postIndex];

        _posts[postIndex] = post.copyWith(
          commentCount: post.commentCount + 1,
        );
      }

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
