import 'package:flutter/material.dart';

import 'models/community_post.dart';

class CommunityStore extends ChangeNotifier {
  final List<CommunityPost> _posts = [
    const CommunityPost(
      initial: 'S',
      name: 'Sarah Chen',
      timeAgo: '2 小時前',
      content: '剛完成了我的第一個5公里超慢跑！感覺超棒，完全沒有疼痛。關鍵在於耐心和持之以恆！',
      tags: ['#晨跑', '#零疼痛', '#進步比完美更重要'],
      likes: 24,
      commentThreads: ['很喜歡你的進步！', '真的很激勵人心'],
    ),
    const CommunityPost(
      initial: 'M',
      name: 'Mike Johnson',
      timeAgo: '5 小時前',
      content: '超慢跑第三週，我的膝蓋痛完全消失了。這個方法真的有效！💪',
      tags: ['#超慢跑挑戰', '#健康習慣'],
      likes: 18,
      commentThreads: ['今天正需要看到這段話'],
      type: CommunityPostType.plan,
      plan: WorkoutPlanData(
        title: '超慢跑計畫',
        summary: '一個幫助你改善超慢跑技巧並減少膝蓋疼痛的4週計畫。',
        difficulty: '中等',
        totalMinutes: 40,
        steps: [
          WorkoutPlanStep(name: '暖身', minutes: 5),
          WorkoutPlanStep(name: '超慢跑', minutes: 30),
          WorkoutPlanStep(name: '緩和', minutes: 5),
        ],
      ),
    ),
    const CommunityPost(
      initial: 'A',
      name: 'Anna Lee',
      timeAgo: '昨天',
      content: '小步幅、穩定的呼吸，沒有壓力。今天的跑步感覺像是我第一次真的想再跑一次。',
      tags: ['#輕鬆跑', '#持續前進'],
      likes: 31,
      commentThreads: ['穩穩來真的最有用', '這個心態我要收藏起來'],
    ),
    const CommunityPost(
      initial: 'J',
      name: 'Jamie Wu',
      timeAgo: '昨天',
      content: '跑後快速的一餐，讓我吃飽又充滿能量。',
      tags: ['#恢復餐', '#高蛋白'],
      likes: 15,
      commentThreads: ['今晚就來試試看'],
      type: CommunityPostType.recipe,
      recipe: RecipeData(
        title: '雞肉飯恢復餐',
        description: '運動後均衡的碳水化合物和蛋白質。',
        cookMinutes: 20,
        ingredients: [
          RecipeIngredient(name: '雞胸肉', grams: 120),
          RecipeIngredient(name: '白飯', grams: 150),
          RecipeIngredient(name: '花椰菜', grams: 80),
        ],
        nutrition: NutritionSummary(
          calories: 430,
          carbs: 47,
          protein: 35,
          fat: 8,
        ),
      ),
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
    CommunityPostType type = CommunityPostType.journey,
    WorkoutPlanData? plan,
    RecipeData? recipe,
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
        type: type,
        plan: plan,
        recipe: recipe,
      ),
    );
    notifyListeners();
  }

  void updatePost(
    int index, {
    required String content,
    required List<String> tags,
    required CommunityPostType type,
    WorkoutPlanData? plan,
    RecipeData? recipe,
  }) {
    final post = _posts[index];
    _posts[index] = post.copyWith(
      content: content,
      tags: tags,
      type: type,
      plan: plan,
      recipe: recipe,
    );
    notifyListeners();
  }

  void deletePost(int index) {
    if (index < 0 || index >= _posts.length) return;
    _posts.removeAt(index);
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
