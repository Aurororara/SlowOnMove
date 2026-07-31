enum CommunityPostType { journey, plan, recipe }

class CommunityPost {
  final String initial;
  final String name;
  final String timeAgo;
  final String content;
  final List<String> tags;
  final int likes;
  final List<String> commentThreads;
  final bool isLiked;
  final bool isSaved;
  final CommunityPostType type;
  final WorkoutPlanData? plan;
  final RecipeData? recipe;

  const CommunityPost({
    required this.initial,
    required this.name,
    required this.timeAgo,
    required this.content,
    required this.tags,
    required this.likes,
    required this.commentThreads,
    this.isLiked = false,
    this.isSaved = false,
    this.type = CommunityPostType.journey,
    this.plan,
    this.recipe,
  });

  int get commentCount => commentThreads.length;

  CommunityPost copyWith({
    String? initial,
    String? name,
    String? timeAgo,
    String? content,
    List<String>? tags,
    int? likes,
    List<String>? commentThreads,
    bool? isLiked,
    bool? isSaved,
    CommunityPostType? type,
    WorkoutPlanData? plan,
    RecipeData? recipe,
  }) {
    return CommunityPost(
      initial: initial ?? this.initial,
      name: name ?? this.name,
      timeAgo: timeAgo ?? this.timeAgo,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      likes: likes ?? this.likes,
      commentThreads: commentThreads ?? this.commentThreads,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      type: type ?? this.type,
      plan: plan ?? this.plan,
      recipe: recipe ?? this.recipe,
    );
  }
}

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
}

class WorkoutPlanStep {
  final String name;
  final int minutes;

  const WorkoutPlanStep({
    required this.name,
    required this.minutes,
  });
}

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
