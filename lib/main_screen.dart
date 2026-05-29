import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'bottom_nav_bar.dart';
import 'community_screen.dart';
import 'config/api_config.dart';
import 'exercise_selection_screen.dart';
import 'leaderboard_page.dart';
import 'profile.dart';
import 'services/user_session.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final CommunityStore _communityStore = CommunityStore();
  final GlobalKey<_HomeScreenState> _homeKey = GlobalKey<_HomeScreenState>();

  void _onNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      _homeKey.currentState?.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(key: _homeKey),
      CommunityScreen(store: _communityStore),
      const ExerciseSelectionScreen(),
      const LeaderboardPage(),
      ProfileScreen(store: _communityStore),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: NavBar(
        currentIndex: _selectedIndex,
        onTap: _onNavTap,
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const List<String> _labels = [
    '一',
    '二',
    '三',
    '四',
    '五',
    '六',
    '日',
  ];

  bool _isLoading = true;

  int _todayTrainingCount = 0;
  int _todayCalories = 0;
  int _todaySteps = 0;
  double _todayDistance = 0.0;
  int _todayMins = 0;

  int _weeklyCompletedDays = 0;
  int _currentStreak = 0;
  List<bool> _weekdayCompleted = List<bool>.filled(7, false);

  @override
  void initState() {
    super.initState();
    _fetchHomeData();
  }

  Future<void> refresh() async {
    await _fetchHomeData();
  }

  String _buildUrl(String path) {
    final String baseUrl = ApiConfig.baseUrl;

    if (baseUrl.endsWith('/')) {
      return '$baseUrl$path';
    }

    return '$baseUrl/$path';
  }

  DateTime _onlyDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  num _readNum(Map log, List<String> keys) {
    for (final key in keys) {
      final value = log[key];

      if (value == null) continue;

      if (value is num) {
        return value;
      }

      if (value is String) {
        final parsed = num.tryParse(value);

        if (parsed != null) {
          return parsed;
        }
      }
    }

    return 0;
  }

  int _readCalories(Map log) {
    final num directCalories = _readNum(
      log,
      [
        'calories',
        'calorie',
        'kcal',
        'calories_burned',
        'calorie_burned',
      ],
    );

    if (directCalories > 0) {
      return directCalories.round();
    }

    final int totalMins = _readNum(
      log,
      [
        'total_mins',
        'total_minutes',
      ],
    ).round();

    if (totalMins > 0) {
      return (totalMins * 8.0).round();
    }

    return 0;
  }

  int _calculateCurrentStreak(Set<DateTime> activeDates) {
    int streak = 0;
    DateTime checkingDate = _onlyDate(DateTime.now());

    while (activeDates.contains(checkingDate)) {
      streak++;
      checkingDate = checkingDate.subtract(const Duration(days: 1));
    }

    return streak;
  }

  Future<void> _fetchHomeData() async {
    final int currentMemberId = UserSession.memberId;

    try {
      final response = await http.get(
        Uri.parse(_buildUrl('training-logs/')),
      );

      if (response.statusCode == 200) {
        final List allLogs = json.decode(response.body);

        final DateTime now = DateTime.now();
        final DateTime today = _onlyDate(now);

        final DateTime weekStart = today.subtract(
          Duration(days: today.weekday - 1),
        );

        final DateTime weekEnd = weekStart.add(
          const Duration(days: 6),
        );

        final List myLogs = allLogs.where((rawLog) {
          final Map log = rawLog as Map;

          final bool isMyLog =
              log['member']?.toString() == currentMemberId.toString();

          return isMyLog;
        }).toList();

        final List todayLogs = myLogs.where((rawLog) {
          final Map log = rawLog as Map;

          final String? startTimeText = log['start_time']?.toString();
          final String? createdAtText = log['created_at']?.toString();

          bool isStartTimeToday = false;
          bool isCreatedAtToday = false;

          if (startTimeText != null && startTimeText.isNotEmpty) {
            final DateTime startTime = DateTime.parse(startTimeText).toLocal();
            isStartTimeToday = _isSameDay(startTime, now);
          }

          if (createdAtText != null && createdAtText.isNotEmpty) {
            final DateTime createdAt = DateTime.parse(createdAtText).toLocal();
            isCreatedAtToday = _isSameDay(createdAt, now);
          }

          return isStartTimeToday || isCreatedAtToday;
        }).toList();

        todayLogs.sort((a, b) {
          final String aTime =
              (a['created_at'] ?? a['start_time'] ?? '').toString();
          final String bTime =
              (b['created_at'] ?? b['start_time'] ?? '').toString();

          return bTime.compareTo(aTime);
        });

        final int todayTrainingCount = todayLogs.length;

        final int todayCalories = todayLogs.fold<int>(
          0,
          (sum, rawLog) {
            final Map log = rawLog as Map;
            return sum + _readCalories(log);
          },
        );

        final int todaySteps = todayLogs.fold<int>(
          0,
          (sum, rawLog) {
            final Map log = rawLog as Map;

            return sum +
                _readNum(
                  log,
                  [
                    'step_count',
                    'steps',
                    'stepCount',
                  ],
                ).round();
          },
        );

        final double todayDistance = todayLogs.fold<double>(
          0.0,
          (sum, rawLog) {
            final Map log = rawLog as Map;

            return sum +
                _readNum(
                  log,
                  [
                    'distance',
                    'distance_km',
                    'distanceKm',
                  ],
                ).toDouble();
          },
        );

        final int todayMins = todayLogs.fold<int>(
          0,
          (sum, rawLog) {
            final Map log = rawLog as Map;

            return sum +
                _readNum(
                  log,
                  [
                    'total_mins',
                    'total_minutes',
                  ],
                ).round();
          },
        );

        final Set<DateTime> activeDates = {};

        for (final rawLog in myLogs) {
          final Map log = rawLog as Map;

          final String? createdAtText = log['created_at']?.toString();
          final String? startTimeText = log['start_time']?.toString();

          final String? dateText =
              createdAtText != null && createdAtText.isNotEmpty
                  ? createdAtText
                  : startTimeText;

          if (dateText == null || dateText.isEmpty) {
            continue;
          }

          final DateTime date = DateTime.parse(dateText).toLocal();
          activeDates.add(_onlyDate(date));
        }

        final List<bool> weekdayCompleted = List<bool>.filled(7, false);

        for (final activeDate in activeDates) {
          final bool isThisWeek =
              !activeDate.isBefore(weekStart) && !activeDate.isAfter(weekEnd);

          final bool isNotFuture = !activeDate.isAfter(today);

          if (isThisWeek && isNotFuture) {
            weekdayCompleted[activeDate.weekday - 1] = true;
          }
        }

        final int weeklyCompletedDays =
            weekdayCompleted.where((completed) => completed).length;

        final int currentStreak = _calculateCurrentStreak(activeDates);

        debugPrint('首頁目前會員 ID：$currentMemberId');
        debugPrint('首頁我的最新 5 筆：${jsonEncode(myLogs.take(5).toList())}');
        debugPrint('首頁今日原始資料：${jsonEncode(todayLogs)}');
        debugPrint('首頁全部紀錄數量：${allLogs.length}');
        debugPrint('首頁我的紀錄數量：${myLogs.length}');
        debugPrint('首頁今日紀錄數量：$todayTrainingCount');
        debugPrint('首頁今日熱量：$todayCalories');
        debugPrint('首頁今日步數：$todaySteps');
        debugPrint('首頁今日里程：$todayDistance');
        debugPrint('首頁今日分鐘：$todayMins');

        if (mounted) {
          setState(() {
            _todayTrainingCount = todayTrainingCount;
            _todayCalories = todayCalories;
            _todaySteps = todaySteps;
            _todayDistance = todayDistance;
            _todayMins = todayMins;
            _weekdayCompleted = weekdayCompleted;
            _weeklyCompletedDays = weeklyCompletedDays;
            _currentStreak = currentStreak;
            _isLoading = false;
          });
        }
      } else {
        debugPrint('首頁 API 錯誤，狀態碼：${response.statusCode}');

        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      debugPrint('首頁抓取資料失敗：$e');

      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  int get _dailyGoalCompletedCount {
    int count = 0;

    if (_todayTrainingCount > 0) count++;
    if (_todayMins > 0) count++;
    if (_todayCalories > 0) count++;
    if (_todaySteps > 0 || _todayDistance > 0) count++;

    return count;
  }

  String _formatDate(DateTime date) {
    const weekdays = [
      '星期一',
      '星期二',
      '星期三',
      '星期四',
      '星期五',
      '星期六',
      '星期日',
    ];

    return '${date.month}月${date.day}日，${weekdays[date.weekday - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final DateTime today = DateTime.now();

    if (_isLoading) {
      return const SafeArea(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _fetchHomeData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '歡迎，${UserSession.displayName.isNotEmpty ? UserSession.displayName : '使用者'}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatDate(today),
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.black87, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStreakHeader(theme),
                    const SizedBox(height: 16),
                    _buildStreakBanner(),
                    const SizedBox(height: 14),
                    _buildWeekDaysRow(),
                    const SizedBox(height: 20),
                    const Divider(
                      color: Color(0xFFE5E7EB),
                      height: 1,
                    ),
                    const SizedBox(height: 16),
                    _buildWeeklyProgress(theme),
                    const SizedBox(height: 18),
                    _MetricCard(
                      icon: Icons.fitness_center_outlined,
                      iconColor: const Color(0xFF16A34A),
                      title: '今日訓練',
                      value: NumberFormat('#,###').format(_todayTrainingCount),
                      unit: '次',
                      percentText:
                          '${(_todayTrainingCount / 1 * 100).clamp(0, 100).toInt()}%',
                      progress: (_todayTrainingCount / 1).clamp(0.0, 1.0),
                      progressColor: const Color(0xFF16A34A),
                    ),
                    const SizedBox(height: 14),
                    _MetricCard(
                      icon: Icons.local_fire_department_outlined,
                      iconColor: const Color(0xFFFF6B1A),
                      title: '今日熱量',
                      value: NumberFormat('#,###').format(_todayCalories),
                      unit: 'kcal',
                      percentText:
                          '${(_todayCalories / 500 * 100).clamp(0, 100).toInt()}%',
                      progress: (_todayCalories / 500).clamp(0.0, 1.0),
                      progressColor: const Color(0xFFFF6B1A),
                    ),
                    const SizedBox(height: 14),
                    _MetricCard(
                      icon: Icons.directions_walk_outlined,
                      iconColor: Colors.black,
                      title: '今日步數',
                      value: NumberFormat('#,###').format(_todaySteps),
                      unit: '步',
                      percentText:
                          '${(_todaySteps / 10000 * 100).clamp(0, 100).toInt()}%',
                      progress: (_todaySteps / 10000).clamp(0.0, 1.0),
                      progressColor: Colors.black,
                    ),
                    const SizedBox(height: 14),
                    _MetricCard(
                      icon: Icons.route_outlined,
                      iconColor: const Color(0xFF2563EB),
                      title: '今日里程',
                      value: _todayDistance < 1
                          ? NumberFormat('#,###').format(
                              (_todayDistance * 1000).round(),
                            )
                          : _todayDistance.toStringAsFixed(2),
                      unit: _todayDistance < 1 ? 'm' : 'km',
                      percentText:
                          '${(_todayDistance / 3 * 100).clamp(0, 100).toInt()}%',
                      progress: (_todayDistance / 3).clamp(0.0, 1.0),
                      progressColor: const Color(0xFF2563EB),
                    ),
                    const SizedBox(height: 14),
                    _MetricCard(
                      icon: Icons.timer_outlined,
                      iconColor: const Color(0xFF7C3AED),
                      title: '今日時長',
                      value: NumberFormat('#,###').format(_todayMins),
                      unit: '分鐘',
                      percentText:
                          '${(_todayMins / 30 * 100).clamp(0, 100).toInt()}%',
                      progress: (_todayMins / 30).clamp(0.0, 1.0),
                      progressColor: const Color(0xFF7C3AED),
                    ),
                    const SizedBox(height: 18),
                    const Divider(
                      color: Color(0xFFE5E7EB),
                      height: 1,
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        '今日目標 ($_dailyGoalCompletedCount/4)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6B7280),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreakHeader(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            '連續運動',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: Color(0xFF6B7280),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$_currentStreak',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                  const Text(
                    '天',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStreakBanner() {
    final String message = _currentStreak > 0
        ? '已連續運動 $_currentStreak 天！繼續保持，獲得 +10 點！'
        : '今天也來完成一次運動吧！';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1FB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE9C8F6),
        ),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFFFF5A4F),
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildWeekDaysRow() {
    return Row(
      children: List.generate(
        _labels.length,
        (index) => Expanded(
          child: _DayButton(
            label: _labels[index],
            isCompleted: _weekdayCompleted[index],
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyProgress(ThemeData theme) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              '本週進度',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF6B7280),
              ),
            ),
            const Spacer(),
            Text(
              '$_weeklyCompletedDays/7',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: _weeklyCompletedDays / 7,
            minHeight: 8,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: const AlwaysStoppedAnimation<Color>(
              Color(0xFF65C16F),
            ),
          ),
        ),
      ],
    );
  }
}

class _DayButton extends StatelessWidget {
  const _DayButton({
    required this.label,
    required this.isCompleted,
  });

  final String label;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted ? const Color(0xFF65C16F) : Colors.white,
              border: Border.all(
                color: isCompleted
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFD1D5DB),
                width: 2,
              ),
            ),
            child: Icon(
              isCompleted ? Icons.check : Icons.add,
              size: 18,
              color: isCompleted ? Colors.white : const Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.unit,
    required this.percentText,
    required this.progress,
    required this.progressColor,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String unit;
  final String percentText;
  final double progress;
  final Color progressColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        12,
        12,
        12,
        10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF6B7280),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            value,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        if (unit.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              unit,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF9CA3AF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    percentText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                  const Text(
                    '目標達成',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation<Color>(
                progressColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
