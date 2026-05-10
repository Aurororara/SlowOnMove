import 'package:flutter/foundation.dart';

import '../models/community_post.dart';

class CommunityStore extends ChangeNotifier {
  final List<CommunityPost> _posts = [
    const CommunityPost(
      initial: 'S',
      name: 'Sarah Chen',
      timeAgo: '2 hours ago',
      content:
          'Just completed my first 5km slow jog! Feeling amazing and completely pain-free. The key is patience and consistency!',
      tags: ['#MorningRun', '#PainFree', '#ProgressNotPerfection'],
      likes: 24,
      commentThreads: ['Love this progress!', 'So inspiring'],
    ),
    const CommunityPost(
      initial: 'M',
      name: 'Mike Johnson',
      timeAgo: '5 hours ago',
      content:
          'Week 3 of slow jogging and my knee pain has completely disappeared. This approach really works!',
      tags: ['#SlowJoggingChallenge', '#HealthyHabits'],
      likes: 18,
      commentThreads: ['Needed to hear this today'],
    ),
    const CommunityPost(
      initial: 'A',
      name: 'Anna Lee',
      timeAgo: 'Yesterday',
      content:
          'Tiny steps, steady breathing, and no pressure. Today felt like the first run I actually wanted to repeat.',
      tags: ['#EasyMiles', '#KeepMoving'],
      likes: 31,
      commentThreads: ['Steady really wins', 'Saving this mindset'],
    ),
  ];

  List<CommunityPost> get posts => List.unmodifiable(_posts);

  List<CommunityPost> get savedPosts =>
      _posts.where((post) => post.isSaved).toList(growable: false);

  int get savedCount => savedPosts.length;

  void addPost({
    required String initial,
    required String name,
    required String timeAgo,
    required String content,
    required List<String> tags,
  }) {
    _posts.insert(
      0,
      CommunityPost(
        initial: initial,
        name: name,
        timeAgo: timeAgo,
        content: content,
        tags: tags,
        likes: 0,
        commentThreads: const [],
      ),
    );
    notifyListeners();
  }

  void toggleLike(int index) {
    final post = _posts[index];
    final isLiked = !post.isLiked;
    _posts[index] = post.copyWith(
      isLiked: isLiked,
      likes: post.likes + (isLiked ? 1 : -1),
    );
    notifyListeners();
  }

  void toggleSave(int index) {
    final post = _posts[index];
    _posts[index] = post.copyWith(isSaved: !post.isSaved);
    notifyListeners();
  }

  void addComment(int index, String comment) {
    final post = _posts[index];
    _posts[index] = post.copyWith(
      commentThreads: [...post.commentThreads, comment],
    );
    notifyListeners();
  }
}
