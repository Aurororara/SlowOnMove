import 'package:flutter/material.dart';

import '../../models/community_post.dart';
import '../common/community_avatar.dart';
import 'workout_plan_card.dart';
import 'recipe_card.dart';
import '../common/community_tag_pill.dart';

class PostCard extends StatelessWidget {
  final VoidCallback onMoreTap;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;
  final VoidCallback onSaveTap;
  final VoidCallback onShareTap;
  final VoidCallback onProfileTap;
  final String initial;
  final String name;
  final String timeAgo;
  final String content;
  final List<String> tags;
  final CommunityPostType type;
  final WorkoutPlanData? plan;
  final RecipeData? recipe;
  final int likes;
  final int comments;
  final bool isLiked;
  final bool isSaved;

  const PostCard({
    required this.onMoreTap,
    required this.onLikeTap,
    required this.onCommentTap,
    required this.onSaveTap,
    required this.onShareTap,
    required this.onProfileTap,
    required this.initial,
    required this.name,
    required this.timeAgo,
    required this.content,
    required this.tags,
    required this.type,
    required this.plan,
    required this.recipe,
    required this.likes,
    required this.comments,
    required this.isLiked,
    required this.isSaved,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: onProfileTap,
                  borderRadius: BorderRadius.circular(999),
                  child: CommunityAvatar(initial: initial),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: onProfileTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Color(0xFF111827),
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            timeAgo,
                            style: const TextStyle(
                              color: Color(0xFF718096),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onMoreTap,
                  visualDensity: VisualDensity.compact,
                  splashRadius: 20,
                  icon: const Icon(Icons.more_vert,
                      color: Color(0xFFA0AEC0), size: 22),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Text(
              content,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (type == CommunityPostType.plan && plan != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: WorkoutPlanCard(plan: plan!),
            ),
          if (type == CommunityPostType.recipe && recipe != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: RecipeCard(recipe: recipe!),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 2),
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              children: tags.map((tag) => CommunityTagPill(tag)).toList(),
            ),
          ),
          const Divider(color: Color(0xFFF1F5F9), height: 18, thickness: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                _PostAction(
                  icon: isLiked ? Icons.favorite : Icons.favorite_border,
                  label: likes.toString(),
                  onTap: onLikeTap,
                  iconColor: isLiked
                      ? const Color(0xFFE11D48)
                      : const Color(0xFF4A5568),
                  textColor: isLiked
                      ? const Color(0xFFE11D48)
                      : const Color(0xFF4A5568),
                ),
                const SizedBox(width: 16),
                _PostAction(
                  icon: Icons.chat_bubble_outline,
                  label: comments.toString(),
                  onTap: onCommentTap,
                ),
                const SizedBox(width: 16),
                _IconAction(
                  icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
                  onTap: onSaveTap,
                  color: isSaved ? Colors.black : const Color(0xFF4A5568),
                ),
                const Spacer(),
                InkWell(
                  onTap: onShareTap,
                  borderRadius: BorderRadius.circular(10),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.share_outlined,
                            color: Color(0xFF4A5568), size: 22),
                        SizedBox(width: 7),
                        Text(
                          '分享',
                          style: TextStyle(
                            color: Color(0xFF4A5568),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PostAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;
  final Color textColor;

  const _PostAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = const Color(0xFF4A5568),
    this.textColor = const Color(0xFF4A5568),
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _IconAction({
    required this.icon,
    required this.onTap,
    this.color = const Color(0xFF4A5568),
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Icon(
          icon,
          color: color,
          size: 22,
        ),
      ),
    );
  }
}
