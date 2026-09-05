import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/community_post.dart';
import '../common/community_tag_pill.dart';
import '../common/community_input.dart';
import '../common/community_button.dart';

enum _ComposerMode { journey, plan, recipe }

class PostComposerSubmission {
  final CommunityPostType type;
  final String content;
  final List<String> tags;
  final WorkoutPlanData? plan;
  final RecipeData? recipe;

  const PostComposerSubmission({
    required this.type,
    required this.content,
    required this.tags,
    this.plan,
    this.recipe,
  });
}

class PostComposer extends StatefulWidget {
  final PostComposerSubmission? initialSubmission;
  final String submitLabel;
  final ValueChanged<PostComposerSubmission> onPost;
  final VoidCallback onClose;

  const PostComposer({
    super.key,
    this.initialSubmission,
    this.submitLabel = '發佈',
    required this.onPost,
    required this.onClose,
  });

  @override
  State<PostComposer> createState() => _PostComposerState();
}

class _PostComposerState extends State<PostComposer> {
  static const List<String> _tags = [
    '#晨跑',
    '#零疼痛',
    '#超慢跑挑戰',
    '#健康習慣',
    '#運動目標',
    '#進步比完美更重要',
    '#慢跑日常',
    '#覺察式運動',
  ];

  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _planTitleController = TextEditingController();
  final TextEditingController _planSummaryController = TextEditingController();
  final TextEditingController _recipeTitleController = TextEditingController();
  final TextEditingController _recipeDescriptionController =
      TextEditingController();
  final TextEditingController _recipeCookMinutesController =
      TextEditingController();
  final Set<String> _selectedTags = <String>{};
  final List<_EditablePlanStep> _planSteps = [
    _EditablePlanStep(),
    _EditablePlanStep(),
    _EditablePlanStep(),
  ];
  final List<_EditableRecipeIngredient> _recipeIngredients = [
    _EditableRecipeIngredient(),
    _EditableRecipeIngredient(),
  ];

  _ComposerMode _mode = _ComposerMode.journey;
  String _planDifficulty = '中等';

  @override
  void initState() {
    super.initState();
    _applyInitialSubmission();
  }

  void _applyInitialSubmission() {
    final submission = widget.initialSubmission;
    if (submission == null) return;

    _contentController.text = submission.content;
    _selectedTags.addAll(submission.tags);

    switch (submission.type) {
      case CommunityPostType.journey:
        _mode = _ComposerMode.journey;
        break;
      case CommunityPostType.plan:
        _mode = _ComposerMode.plan;
        final plan = submission.plan;
        if (plan != null) {
          _planTitleController.text = plan.title;
          _planSummaryController.text = plan.summary;
          _planDifficulty = plan.difficulty;
          for (final step in _planSteps) {
            step.dispose();
          }
          _planSteps
            ..clear()
            ..addAll(
              plan.steps.map((step) {
                final editable = _EditablePlanStep();
                editable.name.text = step.name;
                editable.minutes.text = step.minutes.toString();
                return editable;
              }),
            );
        }
        break;
      case CommunityPostType.recipe:
        _mode = _ComposerMode.journey;
        break;
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    _planTitleController.dispose();
    _planSummaryController.dispose();
    _recipeTitleController.dispose();
    _recipeDescriptionController.dispose();
    _recipeCookMinutesController.dispose();
    for (final step in _planSteps) {
      step.dispose();
    }
    for (final ingredient in _recipeIngredients) {
      ingredient.dispose();
    }
    super.dispose();
  }

  String get _title {
    switch (_mode) {
      case _ComposerMode.journey:
        return '分享你的旅程';
      case _ComposerMode.plan:
        return '分享你的計畫';
      case _ComposerMode.recipe:
        return '分享你的食譜';
    }
  }

  String get _hintText {
    switch (_mode) {
      case _ComposerMode.journey:
        return '分享你的超慢跑經驗、\n健康秘訣或成就...';
      case _ComposerMode.plan:
        return '描述此訓練計畫的幫助，\n例如耐力、恢復或姿勢...';
      case _ComposerMode.recipe:
        return '告訴大家這份食譜對你的好處，\n例如跑前能量補充或跑後恢復...';
    }
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  void _addPlanStep() {
    setState(() {
      _planSteps.add(_EditablePlanStep());
    });
  }

  void _removePlanStep(int index) {
    if (_planSteps.length <= 1) return;
    setState(() {
      final removed = _planSteps.removeAt(index);
      removed.dispose();
    });
  }

  void _addRecipeIngredient() {
    setState(() {
      _recipeIngredients.add(_EditableRecipeIngredient());
    });
  }

  void _removeRecipeIngredient(int index) {
    if (_recipeIngredients.length <= 1) return;
    setState(() {
      final removed = _recipeIngredients.removeAt(index);
      removed.dispose();
    });
  }

  bool get _canSubmit {
    switch (_mode) {
      case _ComposerMode.journey:
        return _contentController.text.trim().isNotEmpty;
      case _ComposerMode.plan:
        return _contentController.text.trim().isNotEmpty &&
            _planTitleController.text.trim().isNotEmpty &&
            _validPlanSteps.isNotEmpty;
      case _ComposerMode.recipe:
        return _contentController.text.trim().isNotEmpty &&
            _recipeTitleController.text.trim().isNotEmpty &&
            _validRecipeIngredients.isNotEmpty;
    }
  }

  List<WorkoutPlanStep> get _validPlanSteps => _planSteps
      .map((step) => step.toPlanStep())
      .whereType<WorkoutPlanStep>()
      .toList(growable: false);

  List<RecipeIngredient> get _validRecipeIngredients => _recipeIngredients
      .map((ingredient) => ingredient.toRecipeIngredient())
      .whereType<RecipeIngredient>()
      .toList(growable: false);

  void _submit() {
    if (!_canSubmit) return;

    final detectedTags = RegExp(r'#\w+')
        .allMatches(_contentController.text.trim())
        .map((match) => match.group(0)!)
        .toList();
    final tags = <String>{..._selectedTags, ...detectedTags}.toList();

    if (_mode == _ComposerMode.plan) {
      final steps = _validPlanSteps;
      final totalMinutes =
          steps.fold<int>(0, (sum, step) => sum + step.minutes);
      widget.onPost(
        PostComposerSubmission(
          type: CommunityPostType.plan,
          content: _contentController.text.trim(),
          tags: tags,
          plan: WorkoutPlanData(
            title: _planTitleController.text.trim(),
            summary: _planSummaryController.text.trim().isEmpty
                ? _contentController.text.trim()
                : _planSummaryController.text.trim(),
            difficulty: _planDifficulty,
            totalMinutes: totalMinutes,
            steps: steps,
          ),
        ),
      );
      return;
    }

    if (_mode == _ComposerMode.recipe) {
      final ingredients = _validRecipeIngredients;
      final nutrition = _calculateNutrition(ingredients);
      widget.onPost(
        PostComposerSubmission(
          type: CommunityPostType.recipe,
          content: _contentController.text.trim(),
          tags: tags,
          recipe: RecipeData(
            title: _recipeTitleController.text.trim(),
            description: _recipeDescriptionController.text.trim(),
            cookMinutes:
                int.tryParse(_recipeCookMinutesController.text.trim()) ?? 0,
            ingredients: ingredients,
            nutrition: nutrition,
          ),
        ),
      );
      return;
    }

    widget.onPost(
      PostComposerSubmission(
        type: CommunityPostType.journey,
        content: _contentController.text.trim(),
        tags: tags,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            offset: const Offset(0, 8),
            blurRadius: 18,
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _contentController,
          _planTitleController,
          _planSummaryController,
          _recipeTitleController,
          _recipeDescriptionController,
          _recipeCookMinutesController,
          ..._planSteps.expand((step) => [step.name, step.minutes]),
          ..._recipeIngredients.expand((item) => [item.name, item.grams]),
        ]),
        builder: (context, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _ComposerModeSwitcher(
                          selectedMode: _mode,
                          onChanged: (mode) {
                            setState(() {
                              _mode = mode;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onClose,
                    visualDensity: VisualDensity.compact,
                    splashRadius: 20,
                    icon:
                        const Icon(Icons.close, color: Colors.black, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contentController,
                minLines: 2,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: communityInputDecoration(_hintText),
              ),
              if (_mode == _ComposerMode.plan) ...[
                const SizedBox(height: 14),
                const CommunityFieldLabel(
                  icon: Icons.route_outlined,
                  text: '計畫詳情',
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _planTitleController,
                  decoration: communityInputDecoration('計畫標題，例如：4週友善膝蓋計畫'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _planSummaryController,
                  maxLines: 2,
                  decoration: communityInputDecoration(
                    '簡短的計畫摘要或目標',
                  ),
                ),
                const SizedBox(height: 10),
                CommunityChoicePicker<String>(
                  options: const [
                    '簡單',
                    '中等',
                    '進階',
                  ],
                  value: _planDifficulty,
                  labelBuilder: (option) => option,
                  onChanged: (value) {
                    setState(() {
                      _planDifficulty = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                ...List.generate(_planSteps.length, (index) {
                  final step = _planSteps[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == _planSteps.length - 1 ? 0 : 10,
                    ),
                    child: _PlanStepEditor(
                      index: index,
                      step: step,
                      onRemove: () => _removePlanStep(index),
                    ),
                  );
                }),
                const SizedBox(height: 10),
                CommunitySecondaryButton(
                  icon: Icons.add,
                  label: '新增步驟',
                  onTap: _addPlanStep,
                ),
              ],
              if (_mode == _ComposerMode.recipe) ...[
                const SizedBox(height: 14),
                const CommunityFieldLabel(
                  icon: Icons.restaurant_menu_outlined,
                  text: '食譜詳情',
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _recipeTitleController,
                  decoration: communityInputDecoration('食譜標題，例如：跑後高蛋白餐'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _recipeDescriptionController,
                  minLines: 2,
                  maxLines: 3,
                  textInputAction: TextInputAction.newline,
                  decoration: communityInputDecoration(
                    '食譜描述（顯示在食譜卡片內）',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _recipeCookMinutesController,
                  keyboardType: TextInputType.number,
                  decoration: communityInputDecoration('烹調時間（分鐘）'),
                ),
                const SizedBox(height: 12),
                ...List.generate(_recipeIngredients.length, (index) {
                  final ingredient = _recipeIngredients[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == _recipeIngredients.length - 1 ? 0 : 10,
                    ),
                    child: _RecipeIngredientEditor(
                      ingredient: ingredient,
                      onRemove: () => _removeRecipeIngredient(index),
                    ),
                  );
                }),
                const SizedBox(height: 10),
                CommunitySecondaryButton(
                  icon: Icons.add,
                  label: '新增食材',
                  onTap: _addRecipeIngredient,
                ),
                const SizedBox(height: 12),
                _RecipeNutritionPreview(
                  nutrition: _calculateNutrition(_validRecipeIngredients),
                ),
              ],
              if (_mode != _ComposerMode.recipe) ...[
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Icon(Icons.add_circle_outline,
                        color: Color(0xFF718096), size: 16),
                    SizedBox(width: 6),
                    Text(
                      '新增標籤',
                      style: TextStyle(
                        color: Color(0xFF4A5568),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tags
                      .map(
                        (tag) => CommunityTagPill(
                          tag,
                          isSelected: _selectedTags.contains(tag),
                          onTap: () => _toggleTag(tag),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 18),
              ] else
                const SizedBox(height: 18),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: Icon(
                      _mode == _ComposerMode.recipe
                          ? Icons.calculate_outlined
                          : Icons.auto_awesome_outlined,
                      size: 18,
                    ),
                    label: Text(
                      _mode == _ComposerMode.recipe ? '自動計算營養' : '結構化貼文',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _canSubmit ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B7280),
                      disabledBackgroundColor: const Color(0xFF8A8A8A),
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.send_outlined, size: 16),
                    label: Text(
                      widget.submitLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ComposerModeSwitcher extends StatelessWidget {
  final _ComposerMode selectedMode;
  final ValueChanged<_ComposerMode> onChanged;

  const _ComposerModeSwitcher({
    required this.selectedMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        CommunityChoiceChip(
          label: '旅程',
          isSelected: selectedMode == _ComposerMode.journey,
          onTap: () => onChanged(_ComposerMode.journey),
        ),
        CommunityChoiceChip(
          label: '計畫',
          isSelected: selectedMode == _ComposerMode.plan,
          onTap: () => onChanged(_ComposerMode.plan),
        ),
      ],
    );
  }
}

class _EditablePlanStep {
  final TextEditingController name = TextEditingController();
  final TextEditingController minutes = TextEditingController();

  WorkoutPlanStep? toPlanStep() {
    final stepName = name.text.trim();
    final stepMinutes = int.tryParse(minutes.text.trim()) ?? 0;
    if (stepName.isEmpty || stepMinutes <= 0) return null;
    return WorkoutPlanStep(
      name: stepName,
      minutes: stepMinutes,
    );
  }

  void dispose() {
    name.dispose();
    minutes.dispose();
  }
}

class _PlanStepEditor extends StatelessWidget {
  final int index;
  final _EditablePlanStep step;
  final VoidCallback onRemove;

  const _PlanStepEditor({
    required this.index,
    required this.step,
    required this.onRemove,
  });

  Future<void> _pickMinutes(BuildContext context) async {
    final currentMinutes = int.tryParse(step.minutes.text.trim()) ?? 10;
    final initialMinutes = currentMinutes.clamp(1, 180);
    var selectedMinutes = initialMinutes;
    final pickerController =
        FixedExtentScrollController(initialItem: initialMinutes - 1);

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: SizedBox(
            height: 300,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text('取消'),
                      ),
                      const Spacer(),
                      const Text(
                        '選擇分鐘數',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          step.minutes.text = selectedMinutes.toString();
                          Navigator.of(sheetContext).pop();
                        },
                        child: const Text('完成'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    scrollController: pickerController,
                    itemExtent: 40,
                    useMagnifier: true,
                    magnification: 1.08,
                    onSelectedItemChanged: (value) {
                      selectedMinutes = value + 1;
                    },
                    children: List.generate(
                      180,
                      (index) => Center(
                        child: Text(
                          '${index + 1} 分鐘',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFFE8F0FF),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: step.name,
                  decoration: communityInputDecoration('動作名稱'),
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => _pickMinutes(context),
            borderRadius: BorderRadius.circular(16),
            child: IgnorePointer(
              child: TextField(
                controller: step.minutes,
                decoration: communityInputDecoration('分鐘數'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableRecipeIngredient {
  final TextEditingController name = TextEditingController();
  final TextEditingController grams = TextEditingController();

  RecipeIngredient? toRecipeIngredient() {
    final ingredientName = name.text.trim();
    final ingredientGrams = double.tryParse(grams.text.trim()) ?? 0;
    if (ingredientName.isEmpty || ingredientGrams <= 0) return null;
    return RecipeIngredient(name: ingredientName, grams: ingredientGrams);
  }

  void dispose() {
    name.dispose();
    grams.dispose();
  }
}

class _RecipeIngredientEditor extends StatelessWidget {
  final _EditableRecipeIngredient ingredient;
  final VoidCallback onRemove;

  const _RecipeIngredientEditor({
    required this.ingredient,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: ingredient.name,
              decoration: communityInputDecoration('食材名稱'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: TextField(
              controller: ingredient.grams,
              keyboardType: TextInputType.number,
              decoration: communityInputDecoration('克數'),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline, size: 18),
          ),
        ],
      ),
    );
  }
}

class _RecipeNutritionPreview extends StatelessWidget {
  final NutritionSummary nutrition;

  const _RecipeNutritionPreview({required this.nutrition});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC7DCFF)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _NutritionPill(label: '${nutrition.calories} 大卡'),
          _NutritionPill(label: '${nutrition.carbs.toStringAsFixed(1)}g 碳水'),
          _NutritionPill(label: '${nutrition.protein.toStringAsFixed(1)}g 蛋白質'),
          _NutritionPill(label: '${nutrition.fat.toStringAsFixed(1)}g 脂肪'),
        ],
      ),
    );
  }
}

class _NutritionPill extends StatelessWidget {
  final String label;

  const _NutritionPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF2563EB),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

const Map<String, NutritionSummary> _ingredientNutritionPer100g = {
  'chicken breast':
      NutritionSummary(calories: 165, carbs: 0, protein: 31, fat: 3.6),
  'egg': NutritionSummary(calories: 155, carbs: 1.1, protein: 13, fat: 11),
  'rice': NutritionSummary(calories: 130, carbs: 28.2, protein: 2.7, fat: 0.3),
  'oats': NutritionSummary(calories: 389, carbs: 66.3, protein: 16.9, fat: 6.9),
  'banana': NutritionSummary(calories: 89, carbs: 22.8, protein: 1.1, fat: 0.3),
  'broccoli':
      NutritionSummary(calories: 35, carbs: 7.2, protein: 2.4, fat: 0.4),
  'salmon': NutritionSummary(calories: 208, carbs: 0, protein: 20, fat: 13),
  'tofu': NutritionSummary(calories: 76, carbs: 1.9, protein: 8, fat: 4.8),
  'milk': NutritionSummary(calories: 42, carbs: 5, protein: 3.4, fat: 1),
  'greek yogurt':
      NutritionSummary(calories: 59, carbs: 3.6, protein: 10, fat: 0.4),
  'avocado': NutritionSummary(calories: 160, carbs: 8.5, protein: 2, fat: 14.7),
};

NutritionSummary _calculateNutrition(List<RecipeIngredient> ingredients) {
  double totalCalories = 0;
  double totalCarbs = 0;
  double totalProtein = 0;
  double totalFat = 0;

  for (final ingredient in ingredients) {
    final match = _ingredientNutritionPer100g.entries
        .firstWhere(
          (entry) =>
              ingredient.name.toLowerCase().contains(entry.key) ||
              entry.key.contains(ingredient.name.toLowerCase()),
          orElse: () => const MapEntry(
            '',
            NutritionSummary(calories: 0, carbs: 0, protein: 0, fat: 0),
          ),
        )
        .value;
    final multiplier = ingredient.grams / 100;
    totalCalories += match.calories * multiplier;
    totalCarbs += match.carbs * multiplier;
    totalProtein += match.protein * multiplier;
    totalFat += match.fat * multiplier;
  }

  return NutritionSummary(
    calories: totalCalories.round(),
    carbs: totalCarbs,
    protein: totalProtein,
    fat: totalFat,
  );
}
