enum CommunityPostType {
  journey,
  plan,
  recipe,
}

class CommunityPost {
  final int id;
  final int memberId;

  final String initial;
  final String name;
  final String? avatar;

  final String timeAgo;
  final String content;

  final List<String> tags;

  final int likes;
  final int commentCount;

  final bool isLiked;
  final bool isSaved;

  final CommunityPostType type;

  final WorkoutPlanData? plan;
  final RecipeData? recipe;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CommunityPost({
    required this.id,
    required this.memberId,
    required this.initial,
    required this.name,
    this.avatar,
    required this.timeAgo,
    required this.content,
    required this.tags,
    required this.likes,
    required this.commentCount,
    required this.isLiked,
    required this.isSaved,
    required this.type,
    this.plan,
    this.recipe,
    this.createdAt,
    this.updatedAt,
  });

  // =========================
  // JSON -> CommunityPost
  // =========================

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    return CommunityPost(
      id: _toInt(json['id']),
      memberId: _toInt(json['member_id']),

      initial: (json['member_initial'] ?? 'U').toString(),

      name: (json['member_name'] ?? '使用者').toString(),

      avatar: json['member_avatar']?.toString(),

      timeAgo: (json['time_ago'] ?? '').toString(),

      content: (json['content'] ?? '').toString(),

      tags: json['tags'] is List
          ? (json['tags'] as List).map((tag) => tag.toString()).toList()
          : <String>[],

      likes: _toInt(json['like_count']),

      commentCount: _toInt(json['comment_count']),

      isLiked: json['is_liked'] == true,

      isSaved: json['is_saved'] == true,

      type: _parsePostType(json['post_type']),

      plan: json['workout_plan'] is Map
          ? WorkoutPlanData.fromJson(
              Map<String, dynamic>.from(
                json['workout_plan'],
              ),
            )
          : null,

      // 食譜後端目前還沒做
      recipe: null,

      createdAt: _parseDateTime(json['created_at']),

      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  // =========================
  // copyWith
  // =========================

  CommunityPost copyWith({
    int? id,
    int? memberId,
    String? initial,
    String? name,
    String? avatar,
    String? timeAgo,
    String? content,
    List<String>? tags,
    int? likes,
    int? commentCount,
    bool? isLiked,
    bool? isSaved,
    CommunityPostType? type,
    WorkoutPlanData? plan,
    RecipeData? recipe,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CommunityPost(
      id: id ?? this.id,
      memberId: memberId ?? this.memberId,
      initial: initial ?? this.initial,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      timeAgo: timeAgo ?? this.timeAgo,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      likes: likes ?? this.likes,
      commentCount: commentCount ?? this.commentCount,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      type: type ?? this.type,
      plan: plan ?? this.plan,
      recipe: recipe ?? this.recipe,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static CommunityPostType _parsePostType(dynamic value) {
    switch (value?.toString()) {
      case 'plan':
        return CommunityPostType.plan;

      case 'recipe':
        return CommunityPostType.recipe;

      case 'journey':
      default:
        return CommunityPostType.journey;
    }
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }
}

// ============================================================
// Workout Plan
// ============================================================

class WorkoutPlanData {
  final String title;
  final String summary;
  final String difficulty;
  final int totalMinutes;
  final List<WorkoutPlanStep> steps;

  const WorkoutPlanData({
    required this.title,
    required this.summary,
    required this.difficulty,
    required this.totalMinutes,
    required this.steps,
  });

  factory WorkoutPlanData.fromJson(
    Map<String, dynamic> json,
  ) {
    return WorkoutPlanData(
      title: (json['title'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      difficulty: (json['difficulty'] ?? '').toString(),
      totalMinutes: CommunityPost._toInt(
        json['total_minutes'],
      ),
      steps: json['steps'] is List
          ? (json['steps'] as List)
              .whereType<Map>()
              .map(
                (step) => WorkoutPlanStep.fromJson(
                  Map<String, dynamic>.from(step),
                ),
              )
              .toList()
          : <WorkoutPlanStep>[],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'summary': summary,
      'difficulty': difficulty,
      'total_minutes': totalMinutes,
      'steps': steps
          .map(
            (step) => step.toJson(),
          )
          .toList(),
    };
  }
}

// ============================================================
// Workout Plan Step
// ============================================================

class WorkoutPlanStep {
  final String name;
  final int minutes;

  const WorkoutPlanStep({
    required this.name,
    required this.minutes,
  });

  factory WorkoutPlanStep.fromJson(
    Map<String, dynamic> json,
  ) {
    return WorkoutPlanStep(
      name: (json['name'] ?? '').toString(),
      minutes: CommunityPost._toInt(
        json['minutes'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'minutes': minutes,
    };
  }
}

// ============================================================
// Recipe
// ============================================================

class RecipeData {
  final String title;
  final String description;
  final int cookMinutes;
  final List<RecipeIngredient> ingredients;
  final NutritionSummary nutrition;

  const RecipeData({
    required this.title,
    required this.description,
    required this.cookMinutes,
    required this.ingredients,
    required this.nutrition,
  });
}

class RecipeIngredient {
  final String name;
  final double grams;

  const RecipeIngredient({
    required this.name,
    required this.grams,
  });
}

class NutritionSummary {
  final int calories;
  final double carbs;
  final double protein;
  final double fat;

  const NutritionSummary({
    required this.calories,
    required this.carbs,
    required this.protein,
    required this.fat,
  });
}
