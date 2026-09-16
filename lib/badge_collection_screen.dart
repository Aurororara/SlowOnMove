import 'package:flutter/material.dart';

import 'services/badge_progress_service.dart';

class BadgeCollectionScreen extends StatefulWidget {
  const BadgeCollectionScreen({super.key});

  @override
  State<BadgeCollectionScreen> createState() => _BadgeCollectionScreenState();
}

class _BadgeCollectionScreenState extends State<BadgeCollectionScreen> {
  static const List<_BadgeCategory> _categories = [
    _BadgeCategory(
      title: '入門類',
      subtitle: '從第一次行動開始累積',
      color: Color(0xFFF7C65B),
      icon: Icons.rocket_launch_outlined,
      badges: [
        _BadgeItem(
          name: '起步之星',
          icon: Icons.star_outline_rounded,
          unlockedAssetPath: 'assets/badges/start_star_unlocked.png',
          lockedAssetPath: 'assets/badges/start_star_locked.png',
          condition: '完成第 1 次運動紀錄',
        ),
        _BadgeItem(
          name: '超慢跑新星',
          icon: Icons.directions_run_rounded,
          unlockedAssetPath: 'assets/badges/slow_jogging_rookie_unlocked.png',
          lockedAssetPath: 'assets/badges/slow_jogging_rookie_locked.png',
          condition: '累積完成 5 次超慢跑',
        ),
        _BadgeItem(
          name: '深蹲入門生',
          icon: Icons.fitness_center_rounded,
          unlockedAssetPath: 'assets/badges/squat_beginner_unlocked.png',
          lockedAssetPath: 'assets/badges/squat_beginner_locked.png',
          condition: '累積完成 5 次深蹲訓練',
        ),
      ],
    ),
    _BadgeCategory(
      title: '堅持類',
      subtitle: '讓運動成為穩定的日常',
      color: Color(0xFF76B7F2),
      icon: Icons.calendar_month_outlined,
      badges: [
        _BadgeItem(
          name: '穩穩前進',
          icon: Icons.trending_up_rounded,
          unlockedAssetPath: 'assets/badges/three_day_streak_unlocked.png',
          lockedAssetPath: 'assets/badges/three_day_streak_locked.png',
          condition: '連續運動 3 天',
        ),
        _BadgeItem(
          name: '節奏守護者',
          icon: Icons.graphic_eq_rounded,
          unlockedAssetPath: 'assets/badges/seven_day_streak_unlocked.png',
          lockedAssetPath: 'assets/badges/seven_day_streak_locked.png',
          condition: '連續運動 7 天',
        ),
        _BadgeItem(
          name: '不間斷玩家',
          icon: Icons.all_inclusive_rounded,
          unlockedAssetPath: 'assets/badges/thirty_day_streak_unlocked.png',
          lockedAssetPath: 'assets/badges/thirty_day_streak_locked.png',
          condition: '連續運動 30 天',
        ),
      ],
    ),
    _BadgeCategory(
      title: '表現類',
      subtitle: '挑戰更好的運動表現',
      color: Color(0xFFF28B82),
      icon: Icons.workspace_premium_outlined,
      badges: [
        _BadgeItem(
          name: '今日萬步王',
          icon: Icons.directions_walk_rounded,
          unlockedAssetPath: 'assets/badges/daily_10k_steps_unlocked.png',
          lockedAssetPath: 'assets/badges/daily_10k_steps_locked.png',
          condition: '單日步數達 10,000 步',
        ),
        _BadgeItem(
          name: '姿勢優等生',
          icon: Icons.verified_outlined,
          unlockedAssetPath: 'assets/badges/posture_honor_unlocked.png',
          lockedAssetPath: 'assets/badges/posture_honor_locked.png',
          condition: '單次運動姿勢分數達 90 分以上',
        ),
        _BadgeItem(
          name: '穩定輸出王',
          icon: Icons.stacked_line_chart_rounded,
          unlockedAssetPath: 'assets/badges/stable_output_unlocked.png',
          lockedAssetPath: 'assets/badges/stable_output_locked.png',
          condition: '連續 5 次運動姿勢分數都超過 90 分',
        ),
        _BadgeItem(
          name: '燃脂小火苗',
          icon: Icons.local_fire_department_outlined,
          unlockedAssetPath: 'assets/badges/calorie_flame_unlocked.png',
          lockedAssetPath: 'assets/badges/calorie_flame_locked.png',
          condition: '累積消耗 500 卡',
        ),
        _BadgeItem(
          name: '燃燒模式',
          icon: Icons.whatshot_rounded,
          unlockedAssetPath: 'assets/badges/burn_mode_unlocked.png',
          lockedAssetPath: 'assets/badges/burn_mode_locked.png',
          condition: '累積消耗 3,000 卡',
        ),
      ],
    ),
    _BadgeCategory(
      title: '互動類',
      subtitle: '與社群夥伴一起前進',
      color: Color(0xFFB99AF4),
      icon: Icons.people_alt_outlined,
      badges: [
        _BadgeItem(
          name: '社群冒險家',
          icon: Icons.explore_outlined,
          unlockedAssetPath: 'assets/badges/community_adventurer_unlocked.png',
          lockedAssetPath: 'assets/badges/community_adventurer_locked.png',
          condition: '首次發布社群貼文',
        ),
        _BadgeItem(
          name: '人氣回應王',
          icon: Icons.chat_bubble_outline_rounded,
          unlockedAssetPath: 'assets/badges/popular_responder_unlocked.png',
          lockedAssetPath: 'assets/badges/popular_responder_locked.png',
          condition: '單篇社群貼文累積 20 則回應',
        ),
        _BadgeItem(
          name: '按讚收集者',
          icon: Icons.favorite_border_rounded,
          unlockedAssetPath: 'assets/badges/like_collector_unlocked.png',
          lockedAssetPath: 'assets/badges/like_collector_locked.png',
          condition: '累積獲得 100 個讚',
        ),
      ],
    ),
  ];

  final Map<String, DateTime> _earnedDates = {};
  bool _isLoadingDates = true;
  bool _dateLoadFailed = false;

  int get _totalBadgeCount => _categories.fold(
        0,
        (total, category) => total + category.badges.length,
      );

  @override
  void initState() {
    super.initState();
    _loadEarnedDates();
  }

  Future<void> _loadEarnedDates() async {
    if (mounted) {
      setState(() {
        _isLoadingDates = true;
        _dateLoadFailed = false;
      });
    }

    try {
      final earnedDates = await BadgeProgressService().loadEarnedDates();

      if (!mounted) {
        return;
      }

      setState(() {
        _earnedDates
          ..clear()
          ..addAll(earnedDates);
        _isLoadingDates = false;
      });
    } catch (error) {
      debugPrint('載入勳章獲得日期失敗: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingDates = false;
        _dateLoadFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F4EF),
        surfaceTintColor: const Color(0xFFF8F4EF),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '我的勳章',
          style: TextStyle(
            color: Color(0xFF2B211C),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadEarnedDates,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
          children: [
            _CollectionHeader(
              earnedCount: _earnedDates.length,
              totalCount: _totalBadgeCount,
              isLoading: _isLoadingDates,
              loadFailed: _dateLoadFailed,
            ),
            const SizedBox(height: 20),
            _BadgeCabinet(
              categories: _categories,
              earnedDates: _earnedDates,
              isLoadingDates: _isLoadingDates,
              dateLoadFailed: _dateLoadFailed,
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionHeader extends StatelessWidget {
  final int earnedCount;
  final int totalCount;
  final bool isLoading;
  final bool loadFailed;

  const _CollectionHeader({
    required this.earnedCount,
    required this.totalCount,
    required this.isLoading,
    required this.loadFailed,
  });

  @override
  Widget build(BuildContext context) {
    final String progressText;
    if (isLoading) {
      progressText = '讀取中';
    } else if (loadFailed) {
      progressText = '-- / $totalCount';
    } else {
      progressText = '$earnedCount / $totalCount';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF171411),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Color(0xFF2A241F),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events_outlined,
              color: Color(0xFFE7BB64),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '勳章展示櫃',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '每一層都收藏一段進步',
                  style: TextStyle(
                    color: Color(0xFFAAA29B),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                progressText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                '已收藏',
                style: TextStyle(
                  color: Color(0xFFAAA29B),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BadgeCabinet extends StatelessWidget {
  final List<_BadgeCategory> categories;
  final Map<String, DateTime> earnedDates;
  final bool isLoadingDates;
  final bool dateLoadFailed;

  const _BadgeCabinet({
    required this.categories,
    required this.earnedDates,
    required this.isLoadingDates,
    required this.dateLoadFailed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 12, 11, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFD9B99C), Color(0xFFB88968)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF956B4F), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3375543F),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          const _CabinetCap(),
          for (int index = 0; index < categories.length; index++)
            _CabinetShelf(
              floorNumber: index + 1,
              category: categories[index],
              earnedDates: earnedDates,
              isLoadingDates: isLoadingDates,
              dateLoadFailed: dateLoadFailed,
            ),
          const _CabinetBase(),
        ],
      ),
    );
  }
}

class _CabinetCap extends StatelessWidget {
  const _CabinetCap();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 13,
      margin: const EdgeInsets.fromLTRB(4, 0, 4, 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE9CDB3), Color(0xFFBD906F)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF977057)),
      ),
    );
  }
}

class _CabinetBase extends StatelessWidget {
  const _CabinetBase();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 17,
      margin: const EdgeInsets.fromLTRB(2, 0, 2, 1),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE4C4A8), Color(0xFFA97859)],
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(9),
        ),
        border: Border.all(color: const Color(0xFF90664E)),
      ),
    );
  }
}

class _CabinetShelf extends StatelessWidget {
  final int floorNumber;
  final _BadgeCategory category;
  final Map<String, DateTime> earnedDates;
  final bool isLoadingDates;
  final bool dateLoadFailed;

  const _CabinetShelf({
    required this.floorNumber,
    required this.category,
    required this.earnedDates,
    required this.isLoadingDates,
    required this.dateLoadFailed,
  });

  @override
  Widget build(BuildContext context) {
    final earnedCount = category.badges
        .where((badge) => earnedDates.containsKey(badge.name))
        .length;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF766055), Color(0xFF8B7061)],
            ),
            border: Border.symmetric(
              vertical: BorderSide(color: Color(0xFF9B745D)),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: category.color.withAlpha(35),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: category.color.withAlpha(75)),
                    ),
                    child: Icon(category.icon, color: category.color, size: 17),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '第 $floorNumber 層｜${category.title}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          category.subtitle,
                          style: const TextStyle(
                            color: Color(0xFFE7DCD4),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    isLoadingDates
                        ? '...'
                        : '$earnedCount / ${category.badges.length}',
                    style: TextStyle(
                      color: category.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = (constraints.maxWidth - 10) / 3;
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int index = 0;
                            index < category.badges.length;
                            index++) ...[
                          SizedBox(
                            width: itemWidth,
                            child: _ShelfBadge(
                              badge: category.badges[index],
                              categoryTitle: category.title,
                              accentColor: category.color,
                              earnedAt:
                                  earnedDates[category.badges[index].name],
                              isLoadingDate: isLoadingDates,
                              dateLoadFailed: dateLoadFailed,
                            ),
                          ),
                          if (index != category.badges.length - 1)
                            const SizedBox(width: 5),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        Container(
          height: 14,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE6C5A8), Color(0xFFA87859)],
            ),
            border: Border.all(color: const Color(0xFF90664E)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3D5B3F30),
                blurRadius: 5,
                offset: Offset(0, 3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShelfBadge extends StatelessWidget {
  final _BadgeItem badge;
  final Color accentColor;
  final String categoryTitle;
  final DateTime? earnedAt;
  final bool isLoadingDate;
  final bool dateLoadFailed;

  const _ShelfBadge({
    required this.badge,
    required this.accentColor,
    required this.categoryTitle,
    required this.earnedAt,
    required this.isLoadingDate,
    required this.dateLoadFailed,
  });

  bool get _isEarned => earnedAt != null;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showBadgeDetails(context),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 7, 2, 5),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Opacity(
                    opacity:
                        _isEarned || isLoadingDate || dateLoadFailed ? 1 : 0.42,
                    child: _BadgeArtwork(
                      badge: badge,
                      accentColor: accentColor,
                      size: 66,
                      isEarned: _isEarned,
                    ),
                  ),
                  if (!isLoadingDate && !dateLoadFailed)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _isEarned
                              ? const Color(0xFF3C9C68)
                              : const Color(0xFF8F8178),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF695247),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          _isEarned ? Icons.check_rounded : Icons.lock_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                badge.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _isEarned || isLoadingDate || dateLoadFailed
                      ? Colors.white
                      : const Color(0xFFD8CBC2),
                  fontSize: 11,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBadgeDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _BadgeDetailSheet(
          badge: badge,
          accentColor: accentColor,
          categoryTitle: categoryTitle,
          earnedAt: earnedAt,
          isLoadingDate: isLoadingDate,
          dateLoadFailed: dateLoadFailed,
        );
      },
    );
  }
}

class _BadgeArtwork extends StatelessWidget {
  final _BadgeItem badge;
  final Color accentColor;
  final double size;
  final bool isEarned;

  const _BadgeArtwork({
    required this.badge,
    required this.accentColor,
    required this.size,
    required this.isEarned,
  });

  @override
  Widget build(BuildContext context) {
    final assetPath = isEarned
        ? badge.unlockedAssetPath
        : badge.lockedAssetPath ?? badge.unlockedAssetPath;

    if (assetPath != null) {
      return SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              _buildPlaceholderArtwork(),
        ),
      );
    }

    return _buildPlaceholderArtwork();
  }

  Widget _buildPlaceholderArtwork() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF806A5E),
        shape: BoxShape.circle,
        border: Border.all(color: accentColor.withAlpha(130), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3D000000),
            blurRadius: 7,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Icon(badge.icon, color: accentColor, size: size * 0.5),
    );
  }
}

class _BadgeDetailSheet extends StatelessWidget {
  final _BadgeItem badge;
  final Color accentColor;
  final String categoryTitle;
  final DateTime? earnedAt;
  final bool isLoadingDate;
  final bool dateLoadFailed;

  const _BadgeDetailSheet({
    required this.badge,
    required this.accentColor,
    required this.categoryTitle,
    required this.earnedAt,
    required this.isLoadingDate,
    required this.dateLoadFailed,
  });

  String get _earnedDateText {
    if (isLoadingDate) {
      return '讀取中';
    }
    if (dateLoadFailed) {
      return '暫時無法取得';
    }
    if (earnedAt == null) {
      return '尚未獲得';
    }
    return '${earnedAt!.year} 年 ${earnedAt!.month} 月 ${earnedAt!.day} 日';
  }

  @override
  Widget build(BuildContext context) {
    final isEarned = earnedAt != null;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 24),
            _BadgeArtwork(
              badge: badge,
              accentColor: accentColor,
              size: 116,
              isEarned: isEarned,
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: accentColor.withAlpha(38),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                categoryTitle,
                style: TextStyle(
                  color: _darken(accentColor),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              badge.name,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 20),
            _DetailRow(
              icon: Icons.flag_outlined,
              label: '獲取條件',
              value: badge.condition,
              iconColor: const Color(0xFF8A5C3D),
            ),
            const SizedBox(height: 10),
            _DetailRow(
              icon: isEarned
                  ? Icons.event_available_outlined
                  : Icons.lock_clock_outlined,
              label: '獲得日期',
              value: _earnedDateText,
              iconColor:
                  isEarned ? const Color(0xFF2F855A) : const Color(0xFF6B7280),
            ),
          ],
        ),
      ),
    );
  }

  Color _darken(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - 0.28).clamp(0.0, 1.0)).toColor();
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(25),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
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

class _BadgeCategory {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final List<_BadgeItem> badges;

  const _BadgeCategory({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.badges,
  });
}

class _BadgeItem {
  final String name;
  final IconData icon;
  final String? unlockedAssetPath;
  final String? lockedAssetPath;
  final String condition;

  const _BadgeItem({
    required this.name,
    required this.icon,
    this.unlockedAssetPath,
    this.lockedAssetPath,
    this.condition = '獲取條件即將公布',
  });
}
