import 'package:flutter/material.dart';

import '../../models/community_post.dart';

class RecipeCard extends StatelessWidget {
  final RecipeData recipe;

  const RecipeCard({
    super.key,
    required this.recipe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF3),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF3D69A), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.restaurant_menu,
                  color: Color(0xFFD97706), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  recipe.title,
                  style: const TextStyle(
                    color: Color(0xFFB45309),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (recipe.description.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              recipe.description,
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '食材',
                  style: TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                ...recipe.ingredients.map(
                  (ingredient) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.circle,
                            size: 7, color: Color(0xFFD97706)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ingredient.name,
                            style: const TextStyle(
                              color: Color(0xFF374151),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${ingredient.grams.toStringAsFixed(0)} 克',
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _RecipeMetricPill(label: '${recipe.cookMinutes} 分鐘'),
              _RecipeMetricPill(label: '${recipe.nutrition.calories} 大卡'),
              _RecipeMetricPill(
                  label: '${recipe.nutrition.protein.toStringAsFixed(1)}g 蛋白質'),
              _RecipeMetricPill(
                  label: '${recipe.nutrition.carbs.toStringAsFixed(1)}g 碳水'),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecipeMetricPill extends StatelessWidget {
  final String label;

  const _RecipeMetricPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFB45309),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
