import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bottom_nav_bar.dart';
import 'community/community_store.dart';
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

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;

  final CommunityStore _communityStore = CommunityStore();

  final GlobalKey<_HomeScreenState> _homeKey = GlobalKey<_HomeScreenState>();

  late final AnimationController _rewardAnimationController;

  bool _showRewardAnimation = false;

  @override
  void initState() {
    super.initState();

    _rewardAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {
            _showRewardAnimation = false;
          });

          _rewardAnimationController.reset();
        }
      });
  }

  @override
  void dispose() {
    _rewardAnimationController.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      _homeKey.currentState?.refresh();
    }
  }

  void _playDailyRewardAnimation() {
    setState(() {
      _showRewardAnimation = true;
    });

    _rewardAnimationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        key: _homeKey,
        onDailyRewardGranted: _playDailyRewardAnimation,
      ),
      CommunityScreen(store: _communityStore),
      const ExerciseSelectionScreen(),
      const LeaderboardPage(),
      ProfileScreen(store: _communityStore),
    ];

    return Stack(
      children: [
        Scaffold(
          body: IndexedStack(
            index: _selectedIndex,
            children: pages,
          ),
          bottomNavigationBar: NavBar(
            currentIndex: _selectedIndex,
            onTap: _onNavTap,
          ),
        ),
        if (_showRewardAnimation)
          Positioned.fill(
            child: IgnorePointer(
              child: _DailyRewardCoinsOverlay(
                animation: _rewardAnimationController,
              ),
            ),
          ),
      ],
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.onDailyRewardGranted,
  });

  final VoidCallback? onDailyRewardGranted;

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
  int _todayMins = 0;

  int _weeklyCompletedDays = 0;
  int _currentStreak = 0;

  List<bool> _weekdayCompleted = List<bool>.filled(7, false);

  Set<DateTime> _activeDates = {};

  // ============================================================
  // 個人化運動設定
  // ============================================================

  String _exerciseGoal = 'health';

  String _exerciseFrequency = '1_2';

  List<_PersonalizedTask> _personalizedTasks = [];

  // 今天實際完成過的運動類型
  Set<String> _todayExerciseTypes = {};

  @override
  void initState() {
    super.initState();

    _fetchHomeData();
    _fetchExercisePreferences();
  }

  Future<void> refresh() async {
    await Future.wait([
      _fetchHomeData(),
      _fetchExercisePreferences(),
    ]);
  }

  String _buildUrl(String path) {
    final String baseUrl = ApiConfig.baseUrl;

    if (baseUrl.endsWith('/')) {
      return '$baseUrl$path';
    }

    return '$baseUrl/$path';
  }

  // ============================================================
  // 日期工具
  // ============================================================

  DateTime _onlyDate(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime? _readLogEventDate(Map log) {
    final String? startTimeText = log['start_time']?.toString();

    final String? createdAtText = log['created_at']?.toString();

    final String? dateText = startTimeText != null && startTimeText.isNotEmpty
        ? startTimeText
        : createdAtText;

    if (dateText == null || dateText.isEmpty) {
      return null;
    }

    try {
      final String dateOnly = dateText.split('T').first;

      return DateTime.parse(dateOnly);
    } catch (e) {
      debugPrint(
        '日期解析失敗: $dateText, error: $e',
      );

      return null;
    }
  }

  // ============================================================
  // 數值讀取
  // ============================================================

  num _readNum(
    Map log,
    List<String> keys,
  ) {
    for (final key in keys) {
      final dynamic value = log[key];

      if (value == null) {
        continue;
      }

      if (value is num) {
        return value;
      }

      if (value is String) {
        final num? parsed = num.tryParse(value);

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

  // ============================================================
  // 運動紀錄判斷
  // ============================================================

  bool _isQualifiedExerciseLog(Map log) {
    final String exerciseType =
        (log['exercise_type'] ?? log['type'] ?? log['activity'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

    return exerciseType == 'squat' ||
        exerciseType == 'slow_jogging' ||
        exerciseType == 'slow jogging' ||
        exerciseType == '深蹲' ||
        exerciseType == '超慢跑';
  }

  String _normalizeExerciseType(Map log) {
    final String exerciseType =
        (log['exercise_type'] ?? log['type'] ?? log['activity'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

    if (exerciseType == 'squat' || exerciseType == '深蹲') {
      return 'squat';
    }

    if (exerciseType == 'slow_jogging' ||
        exerciseType == 'slow jogging' ||
        exerciseType == '超慢跑') {
      return 'slow_jogging';
    }

    return exerciseType;
  }

  bool _hasTodayExercise(String type) {
    return _todayExerciseTypes.contains(
      type,
    );
  }

  // ============================================================
  // 連續運動
  // ============================================================

  int _calculateCurrentStreak(
    Set<DateTime> activeDates,
  ) {
    int streak = 0;

    DateTime checkingDate = _onlyDate(DateTime.now());

    while (activeDates.contains(checkingDate)) {
      streak++;

      checkingDate = checkingDate.subtract(
        const Duration(days: 1),
      );
    }

    return streak;
  }

  void _syncWeeklyState(
    Set<DateTime> activeDates,
  ) {
    final DateTime today = _onlyDate(DateTime.now());

    final DateTime weekStart = today.subtract(
      Duration(
        days: today.weekday - 1,
      ),
    );

    final DateTime weekEnd = weekStart.add(
      const Duration(days: 6),
    );

    final List<bool> weekdayCompleted = List<bool>.filled(7, false);

    for (final activeDate in activeDates) {
      final bool isThisWeek =
          !activeDate.isBefore(weekStart) && !activeDate.isAfter(weekEnd);

      final bool isNotFuture = !activeDate.isAfter(today);

      if (isThisWeek && isNotFuture) {
        weekdayCompleted[activeDate.weekday - 1] = true;
      }
    }

    _activeDates = activeDates;

    _weekdayCompleted = weekdayCompleted;

    _weeklyCompletedDays =
        weekdayCompleted.where((completed) => completed).length;

    _currentStreak = _calculateCurrentStreak(activeDates);
  }

  // ============================================================
  // 取得會員運動目標與運動習慣
  // ============================================================

  Future<void> _fetchExercisePreferences() async {
    final int currentMemberId = UserSession.memberId;

    try {
      final response = await http.get(
        Uri.parse(
          _buildUrl(
            'members/$currentMemberId/',
          ),
        ),
      );

      debugPrint(
        '取得運動偏好 API 狀態碼：'
        '${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);

        if (decoded is Map) {
          if (!mounted) {
            return;
          }

          setState(() {
            _exerciseGoal = decoded['exercise_goal']?.toString() ?? 'health';

            _exerciseFrequency =
                decoded['exercise_frequency']?.toString() ?? '1_2';
          });

          _generatePersonalizedTasks();
        }
      } else {
        debugPrint(
          '取得運動偏好失敗：'
          '${response.body}',
        );
      }
    } catch (e) {
      debugPrint(
        '取得運動偏好發生錯誤：$e',
      );
    }
  }

  // ============================================================
  // 個人化任務產生器
  //
  // 根據：
  // 1. 使用者運動目標
  // 2. 使用者每週運動頻率
  // 3. 今天已完成的運動資料
  //
  // 自動產生今日任務
  // ============================================================

  void _generatePersonalizedTasks() {
    final List<_PersonalizedTask> tasks = [];

    // ==========================================================
    // 減脂
    // ==========================================================

    if (_exerciseGoal == 'weight_loss') {
      int minuteTarget;
      int stepTarget;

      if (_exerciseFrequency == '5_plus') {
        minuteTarget = 40;
        stepTarget = 10000;
      } else if (_exerciseFrequency == '3_4') {
        minuteTarget = 35;
        stepTarget = 9000;
      } else {
        minuteTarget = 30;
        stepTarget = 8000;
      }

      tasks.add(
        _PersonalizedTask(
          title: '累積運動 $minuteTarget 分鐘',
          subtitle: '今天累積運動時間達到 $minuteTarget 分鐘',
          icon: Icons.timer_outlined,
          isCompleted: _todayMins >= minuteTarget,
        ),
      );

      tasks.add(
        _PersonalizedTask(
          title: '完成 1 次超慢跑',
          subtitle: '進行一次超慢跑訓練',
          icon: Icons.directions_run,
          isCompleted: _hasTodayExercise(
            'slow_jogging',
          ),
        ),
      );

      tasks.add(
        _PersonalizedTask(
          title: '累積 $stepTarget 步',
          subtitle: '依照你的運動頻率設定今日步數目標',
          icon: Icons.directions_walk_outlined,
          isCompleted: _todaySteps >= stepTarget,
        ),
      );
    }

    // ==========================================================
    // 增肌
    // ==========================================================

    else if (_exerciseGoal == 'muscle_gain') {
      int trainingTarget;
      int minuteTarget;

      if (_exerciseFrequency == '5_plus') {
        trainingTarget = 3;
        minuteTarget = 45;
      } else if (_exerciseFrequency == '3_4') {
        trainingTarget = 2;
        minuteTarget = 40;
      } else {
        trainingTarget = 1;
        minuteTarget = 30;
      }

      tasks.add(
        _PersonalizedTask(
          title: '完成 $trainingTarget 次訓練',
          subtitle: '今天完成至少 $trainingTarget 次運動紀錄',
          icon: Icons.fitness_center_outlined,
          isCompleted: _todayTrainingCount >= trainingTarget,
        ),
      );

      tasks.add(
        _PersonalizedTask(
          title: '完成 1 次深蹲訓練',
          subtitle: '進行一次深蹲訓練',
          icon: Icons.fitness_center,
          isCompleted: _hasTodayExercise('squat'),
        ),
      );

      tasks.add(
        _PersonalizedTask(
          title: '累積運動 $minuteTarget 分鐘',
          subtitle: '依照你的運動頻率設定今日運動時長',
          icon: Icons.timer_outlined,
          isCompleted: _todayMins >= minuteTarget,
        ),
      );
    }

    // ==========================================================
    // 維持健康
    // ==========================================================

    else {
      int trainingTarget;
      int stepTarget;
      int minuteTarget;

      if (_exerciseFrequency == '5_plus') {
        trainingTarget = 2;
        stepTarget = 10000;
        minuteTarget = 40;
      } else if (_exerciseFrequency == '3_4') {
        trainingTarget = 2;
        stepTarget = 9000;
        minuteTarget = 30;
      } else {
        trainingTarget = 1;
        stepTarget = 8000;
        minuteTarget = 30;
      }

      tasks.add(
        _PersonalizedTask(
          title: '完成 $trainingTarget 次訓練',
          subtitle: '依照你的運動頻率設定今日訓練目標',
          icon: Icons.fitness_center_outlined,
          isCompleted: _todayTrainingCount >= trainingTarget,
        ),
      );

      tasks.add(
        _PersonalizedTask(
          title: '累積運動 $minuteTarget 分鐘',
          subtitle: '今天運動時間達到 $minuteTarget 分鐘',
          icon: Icons.timer_outlined,
          isCompleted: _todayMins >= minuteTarget,
        ),
      );

      tasks.add(
        _PersonalizedTask(
          title: '累積 $stepTarget 步',
          subtitle: '依照你的運動頻率設定今日步數目標',
          icon: Icons.directions_walk_outlined,
          isCompleted: _todaySteps >= stepTarget,
        ),
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _personalizedTasks = tasks;
    });
  }

  // ============================================================
  // 顯示文字
  // ============================================================

  String get _goalLabel {
    switch (_exerciseGoal) {
      case 'weight_loss':
        return '減脂';

      case 'muscle_gain':
        return '增肌';

      case 'health':
      default:
        return '維持健康';
    }
  }

  String get _frequencyLabel {
    switch (_exerciseFrequency) {
      case '3_4':
        return '每週 3–4 次';

      case '5_plus':
        return '每週 5 次以上';

      case '1_2':
      default:
        return '每週 1–2 次';
    }
  }

  // ============================================================
  // 首頁資料
  // ============================================================

  Future<void> _fetchHomeData() async {
    final int currentMemberId = UserSession.memberId;

    debugPrint(
      '========== 首頁資料 Debug 開始 ==========',
    );

    debugPrint(
      '目前登入的 memberId: $currentMemberId',
    );

    try {
      final response = await http.get(
        Uri.parse(
          _buildUrl('training-logs/'),
        ),
      );

      debugPrint(
        'training-logs API 狀態碼: '
        '${response.statusCode}',
      );

      debugPrint(
        'training-logs API 狀態碼: '
        '${response.statusCode}',
      );
      if (response.statusCode == 200) {
        final List allLogs = json.decode(response.body);

        final DateTime now = DateTime.now();

        debugPrint(
          '現在手機本地時間: $now',
        );

        debugPrint(
          '全部紀錄數: ${allLogs.length}',
        );

        final List myLogs = allLogs.where((rawLog) {
          final Map log = rawLog as Map;

          return log['member']?.toString() == currentMemberId.toString();
        }).toList();

        debugPrint(
          '我的紀錄數: ${myLogs.length}',
        );

        final List todayLogs = myLogs.where((rawLog) {
          final Map log = rawLog as Map;

          final DateTime? eventDate = _readLogEventDate(log);

          return eventDate != null &&
              _isSameDay(eventDate, now) &&
              _isQualifiedExerciseLog(log);
        }).toList();

        todayLogs.sort((a, b) {
          final String aTime =
              (a['created_at'] ?? a['start_time'] ?? '').toString();

          final String bTime =
              (b['created_at'] ?? b['start_time'] ?? '').toString();

          return bTime.compareTo(aTime);
        });

        debugPrint(
          '今日紀錄數: ${todayLogs.length}',
        );

        // --------------------------------------------------------
        // 今天完成的運動類型
        // --------------------------------------------------------

        final Set<String> todayExerciseTypes = {};

        for (final rawLog in todayLogs) {
          final Map log = rawLog as Map;

          final String type = _normalizeExerciseType(log);

          if (type.isNotEmpty) {
            todayExerciseTypes.add(type);
          }
        }

        // --------------------------------------------------------
        // 今日訓練次數
        // --------------------------------------------------------

        final int todayTrainingCount = todayLogs.length;

        // --------------------------------------------------------
        // 今日熱量
        // --------------------------------------------------------

        final int todayCalories = todayLogs.fold<int>(
          0,
          (sum, rawLog) {
            final Map log = rawLog as Map;

            return sum + _readCalories(log);
          },
        );

        // --------------------------------------------------------
        // 今日步數
        // --------------------------------------------------------

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

        // --------------------------------------------------------
        // 今日運動分鐘
        // --------------------------------------------------------

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

        // --------------------------------------------------------
        // 有運動的日期
        // --------------------------------------------------------

        final Set<DateTime> activeDates = {};

        for (final rawLog in myLogs) {
          final Map log = rawLog as Map;

          final DateTime? eventDate = _readLogEventDate(log);

          if (eventDate == null || !_isQualifiedExerciseLog(log)) {
            continue;
          }

          activeDates.add(
            _onlyDate(eventDate),
          );
        }

        debugPrint(
          '今日訓練次數: $todayTrainingCount',
        );

        debugPrint(
          '今日熱量: $todayCalories',
        );

        debugPrint(
          '今日步數: $todaySteps',
        );

        debugPrint(
          '今日分鐘: $todayMins',
        );

        debugPrint(
          '今日運動類型: $todayExerciseTypes',
        );

        if (mounted) {
          setState(() {
            _todayTrainingCount = todayTrainingCount;

            _todayCalories = todayCalories;

            _todaySteps = todaySteps;

            _todayMins = todayMins;

            _todayExerciseTypes = todayExerciseTypes;

            _syncWeeklyState(
              activeDates,
            );

            _isLoading = false;
          });

          // 資料更新後重新產生今日個人化任務
          _generatePersonalizedTasks();

          // 檢查是否完成全部任務
          _tryAwardDailyReward(now);
        }
      } else {
        debugPrint(
          '首頁 API 錯誤，狀態碼：'
          '${response.statusCode}',
        );

        debugPrint(
          '首頁 API 回傳內容：'
          '${response.body}',
        );

        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          _generatePersonalizedTasks();
        }
      }
    } catch (e) {
      debugPrint(
        '首頁抓取資料失敗：$e',
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        _generatePersonalizedTasks();
      }
    }
  }

  // ============================================================
  // 每日獎勵
  // ============================================================

  void _tryAwardDailyReward(
    DateTime now,
  ) {
    if (!_isDailyGoalRewardUnlocked) {
      return;
    }

    final bool granted = UserSession.claimDailyRewardForDate(
      _onlyDate(now),
      amount: 0.1,
    );

    if (granted) {
      widget.onDailyRewardGranted?.call();
    }
  }

  int get _dailyGoalCompletedCount {
    int count = 0;

    for (final goal in _dailyGoals) {
      if (goal.isCompleted) {
        count++;
      }
    }

    return count;
  }

  bool get _isDailyGoalRewardUnlocked {
    return _dailyGoals.isNotEmpty &&
        _dailyGoalCompletedCount == _dailyGoals.length;
  }

  // ============================================================
  // 將個人化任務轉成原本 DailyGoalItem
  // ============================================================

  List<_DailyGoalItem> get _dailyGoals {
    return _personalizedTasks
        .map(
          (task) => _DailyGoalItem(
            title: task.title,
            subtitle: task.subtitle,
            isCompleted: task.isCompleted,
          ),
        )
        .toList();
  }

  // ============================================================
  // 今日個人化任務 Sheet
  // ============================================================

  Future<void> _openDailyGoalSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(
              12,
              24,
              12,
              12,
            ),
            padding: const EdgeInsets.fromLTRB(
              18,
              14,
              18,
              20,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: SingleChildScrollView(
              child: _buildDailyGoalPanel(
                Theme.of(sheetContext),
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // 日期文字
  // ============================================================

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

    return '${date.month}月${date.day}日，'
        '${weekdays[date.weekday - 1]}';
  }

  String _formatMonthTitle(
    DateTime date,
  ) {
    return '${date.year} 年 ${date.month} 月';
  }

  // ============================================================
  // 月份統計
  // ============================================================

  int _monthCompletedCount(
    DateTime month,
  ) {
    return _activeDates.where((date) {
      return date.year == month.year && date.month == month.month;
    }).length;
  }

  int _monthLongestStreak(
    DateTime month,
  ) {
    final List<DateTime> monthDates = _activeDates
        .where(
          (date) => date.year == month.year && date.month == month.month,
        )
        .toList()
      ..sort();

    if (monthDates.isEmpty) {
      return 0;
    }

    int longest = 1;
    int current = 1;

    for (int i = 1; i < monthDates.length; i++) {
      final int diff = monthDates[i]
          .difference(
            monthDates[i - 1],
          )
          .inDays;

      if (diff == 1) {
        current++;

        if (current > longest) {
          longest = current;
        }
      } else if (diff > 1) {
        current = 1;
      }
    }

    return longest;
  }

  List<DateTime> _buildCalendarDays(
    DateTime month,
  ) {
    final DateTime firstDayOfMonth = DateTime(
      month.year,
      month.month,
      1,
    );

    final DateTime gridStart = firstDayOfMonth.subtract(
      Duration(
        days: firstDayOfMonth.weekday - 1,
      ),
    );

    return List<DateTime>.generate(
      42,
      (index) => gridStart.add(
        Duration(days: index),
      ),
    );
  }

  // ============================================================
  // 月運動紀錄
  // ============================================================

  Future<void> _openMonthlyActivitySheet() async {
    DateTime visibleMonth = DateTime(
      DateTime.now().year,
      DateTime.now().month,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (
            context,
            setSheetState,
          ) {
            final List<DateTime> days = _buildCalendarDays(
              visibleMonth,
            );

            final int completedCount = _monthCompletedCount(
              visibleMonth,
            );

            final int longestStreak = _monthLongestStreak(
              visibleMonth,
            );

            final DateTime today = _onlyDate(DateTime.now());

            return SafeArea(
              child: LayoutBuilder(
                builder: (
                  context,
                  constraints,
                ) {
                  final double maxSheetHeight = constraints.maxHeight * 0.88;

                  return Container(
                    constraints: BoxConstraints(
                      maxHeight: maxSheetHeight,
                    ),
                    margin: const EdgeInsets.fromLTRB(
                      12,
                      24,
                      12,
                      12,
                    ),
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      14,
                      20,
                      24,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        28,
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 42,
                              height: 5,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFE5E7EB,
                                ),
                                borderRadius: BorderRadius.circular(
                                  999,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: 18,
                          ),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  '月運動紀錄',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              _CalendarMonthButton(
                                icon: Icons.chevron_left_rounded,
                                onTap: () {
                                  setSheetState(
                                    () {
                                      visibleMonth = DateTime(
                                        visibleMonth.year,
                                        visibleMonth.month - 1,
                                      );
                                    },
                                  );
                                },
                              ),
                              const SizedBox(
                                width: 8,
                              ),
                              _CalendarMonthButton(
                                icon: Icons.chevron_right_rounded,
                                onTap: () {
                                  setSheetState(
                                    () {
                                      visibleMonth = DateTime(
                                        visibleMonth.year,
                                        visibleMonth.month + 1,
                                      );
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 6,
                          ),
                          Text(
                            _formatMonthTitle(
                              visibleMonth,
                            ),
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(
                            height: 18,
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _CalendarSummaryCard(
                                  label: '本月運動',
                                  value: '$completedCount 天',
                                ),
                              ),
                              const SizedBox(
                                width: 12,
                              ),
                              Expanded(
                                child: _CalendarSummaryCard(
                                  label: '最長連續',
                                  value: '$longestStreak 天',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 18,
                          ),
                          Row(
                            children: _labels
                                .map(
                                  (label) => Expanded(
                                    child: Center(
                                      child: Text(
                                        label,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(
                                            0xFF6B7280,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: days.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 0.9,
                            ),
                            itemBuilder: (context, index) {
                              final DateTime date = days[index];

                              final bool isCurrentMonth =
                                  date.month == visibleMonth.month &&
                                      date.year == visibleMonth.year;

                              final bool isCompleted = _activeDates.contains(
                                _onlyDate(
                                  date,
                                ),
                              );

                              final bool isToday = _isSameDay(
                                date,
                                today,
                              );

                              return _CalendarDayCell(
                                day: date.day,
                                isCurrentMonth: isCurrentMonth,
                                isCompleted: isCompleted,
                                isToday: isToday,
                              );
                            },
                          ),
                          const SizedBox(
                            height: 14,
                          ),
                          const Text(
                            '有運動紀錄的日期會以綠色標示，資料來源為後端運動紀錄。',
                            style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // 首頁 UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

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
        onRefresh: refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            16,
            20,
            16,
            24,
          ),
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
              const SizedBox(
                height: 4,
              ),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: Color(0xFF6B7280),
                  ),
                  const SizedBox(
                    width: 6,
                  ),
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
              const SizedBox(
                height: 16,
              ),

              // ==================================================
              // 主卡片
              // ==================================================

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(
                    28,
                  ),
                  border: Border.all(
                    color: Colors.black87,
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStreakHeader(
                      theme,
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    _buildStreakBanner(),

                    const SizedBox(
                      height: 14,
                    ),

                    _buildWeekDaysRow(),

                    const SizedBox(
                      height: 4,
                    ),

                    Row(
                      children: [
                        const Spacer(),
                        InkWell(
                          borderRadius: BorderRadius.circular(
                            999,
                          ),
                          onTap: _openMonthlyActivitySheet,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_month_outlined,
                                  size: 15,
                                  color: Color(
                                    0xFF6B7280,
                                  ),
                                ),
                                SizedBox(
                                  width: 6,
                                ),
                                Text(
                                  '查看整月紀錄',
                                  style: TextStyle(
                                    color: Color(
                                      0xFF6B7280,
                                    ),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    const Divider(
                      color: Color(0xFFE5E7EB),
                      height: 1,
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    _buildWeeklyProgress(
                      theme,
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    // ==================================================
                    // 今日訓練
                    // ==================================================

                    _MetricCard(
                      icon: Icons.fitness_center_outlined,
                      iconColor: const Color(
                        0xFF16A34A,
                      ),
                      title: '今日訓練',
                      value: NumberFormat(
                        '#,###',
                      ).format(
                        _todayTrainingCount,
                      ),
                      unit: '次',
                      percentText:
                          '${(_todayTrainingCount / 1 * 100).clamp(0, 100).toInt()}%',
                      progress: (_todayTrainingCount / 1).clamp(
                        0.0,
                        1.0,
                      ),
                      progressColor: const Color(
                        0xFF16A34A,
                      ),
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    // ==================================================
                    // 今日熱量
                    // ==================================================

                    _MetricCard(
                      icon: Icons.local_fire_department_outlined,
                      iconColor: const Color(
                        0xFFFF6B1A,
                      ),
                      title: '今日熱量',
                      value: NumberFormat(
                        '#,###',
                      ).format(
                        _todayCalories,
                      ),
                      unit: 'kcal',
                      percentText:
                          '${(_todayCalories / 500 * 100).clamp(0, 100).toInt()}%',
                      progress: (_todayCalories / 500).clamp(
                        0.0,
                        1.0,
                      ),
                      progressColor: const Color(
                        0xFFFF6B1A,
                      ),
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    // ==================================================
                    // 今日步數
                    // ==================================================

                    _MetricCard(
                      icon: Icons.directions_walk_outlined,
                      iconColor: Colors.black,
                      title: '今日步數',
                      value: NumberFormat(
                        '#,###',
                      ).format(
                        _todaySteps,
                      ),
                      unit: '步',
                      percentText:
                          '${(_todaySteps / 10000 * 100).clamp(0, 100).toInt()}%',
                      progress: (_todaySteps / 10000).clamp(
                        0.0,
                        1.0,
                      ),
                      progressColor: Colors.black,
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    // ==================================================
                    // 今日時長
                    // ==================================================

                    _MetricCard(
                      icon: Icons.timer_outlined,
                      iconColor: const Color(
                        0xFF7C3AED,
                      ),
                      title: '今日時長',
                      value: NumberFormat(
                        '#,###',
                      ).format(
                        _todayMins,
                      ),
                      unit: '分鐘',
                      percentText:
                          '${(_todayMins / 30 * 100).clamp(0, 100).toInt()}%',
                      progress: (_todayMins / 30).clamp(
                        0.0,
                        1.0,
                      ),
                      progressColor: const Color(
                        0xFF7C3AED,
                      ),
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    const Divider(
                      color: Color(0xFFE5E7EB),
                      height: 1,
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    // ==================================================
                    // 今日個人化任務
                    // ==================================================

                    _buildDailyGoalSummaryRow(
                      theme,
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

  // ============================================================
  // 連續運動標題
  // ============================================================

  Widget _buildStreakHeader(
    ThemeData theme,
  ) {
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
            borderRadius: BorderRadius.circular(
              18,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: Color(0xFF6B7280),
              ),
              const SizedBox(
                width: 10,
              ),
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

  // ============================================================
  // 連續運動提示
  // ============================================================

  Widget _buildStreakBanner() {
    final String message = _currentStreak > 0
        ? '已連續運動 $_currentStreak 天！繼續保持今天的節奏。'
        : '今天也來完成一次運動吧！';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1FB),
        borderRadius: BorderRadius.circular(
          18,
        ),
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

  // ============================================================
  // 星期列
  // ============================================================

  Widget _buildWeekDaysRow() {
    final DateTime today = _onlyDate(DateTime.now());

    final DateTime weekStart = today.subtract(
      Duration(
        days: today.weekday - 1,
      ),
    );

    return Row(
      children: List.generate(
        _labels.length,
        (index) => Expanded(
          child: _DayButton(
            label: _labels[index],
            isCompleted: _weekdayCompleted[index],
            isToday: index == today.weekday - 1,
            isFuture: weekStart
                .add(
                  Duration(
                    days: index,
                  ),
                )
                .isAfter(
                  today,
                ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 每週進度
  // ============================================================

  Widget _buildWeeklyProgress(
    ThemeData theme,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              '本週進度',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(
                  0xFF6B7280,
                ),
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
        const SizedBox(
          height: 10,
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(
            999,
          ),
          child: LinearProgressIndicator(
            value: _weeklyCompletedDays / 7,
            minHeight: 8,
            backgroundColor: const Color(
              0xFFE5E7EB,
            ),
            valueColor: const AlwaysStoppedAnimation<Color>(
              Color(0xFF65C16F),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // 今日個人化任務面板
  // ============================================================

  Widget _buildDailyGoalPanel(
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(
          22,
        ),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ------------------------------------------------------
          // 標題
          // ------------------------------------------------------

          Row(
            children: [
              Expanded(
                child: Text(
                  '今日個人化任務 '
                  '($_dailyGoalCompletedCount/'
                  '${_dailyGoals.length})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                _isDailyGoalRewardUnlocked ? '獎勵已兌換 +0.1' : '完成全部任務可獲得獎勵',
                style: TextStyle(
                  color: _isDailyGoalRewardUnlocked
                      ? const Color(
                          0xFF16A34A,
                        )
                      : const Color(
                          0xFF6B7280,
                        ),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 10,
          ),

          // ------------------------------------------------------
          // 個人化條件
          // ------------------------------------------------------

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(
                14,
              ),
              border: Border.all(
                color: const Color(
                  0xFFE5E7EB,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.tune_rounded,
                  size: 17,
                  color: Color(0xFF16A34A),
                ),
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                  child: Text(
                    '依據：$_goalLabel・$_frequencyLabel',
                    style: const TextStyle(
                      color: Color(0xFF374151),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          // ------------------------------------------------------
          // 任務
          // ------------------------------------------------------

          ..._dailyGoals.map(
            (goal) => Padding(
              padding: const EdgeInsets.only(
                bottom: 10,
              ),
              child: _DailyGoalTile(
                goal: goal,
              ),
            ),
          ),

          // ------------------------------------------------------
          // 完成全部任務
          // ------------------------------------------------------

          if (_isDailyGoalRewardUnlocked) ...[
            const SizedBox(
              height: 6,
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: const Color(
                  0xFFECFDF3,
                ),
                borderRadius: BorderRadius.circular(
                  16,
                ),
                border: Border.all(
                  color: const Color(
                    0xFFBBF7D0,
                  ),
                ),
              ),
              child: const Text(
                '今日個人化任務全部完成，獎勵已自動兌換至錢包。',
                style: TextStyle(
                  color: Color(0xFF166534),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // 首頁任務摘要
  // ============================================================

  Widget _buildDailyGoalSummaryRow(
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(
              8,
            ),
            onTap: _openDailyGoalSheet,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 2,
                vertical: 4,
              ),
              child: Text(
                '今日個人化任務',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(
            width: 8,
          ),
          Text(
            '($_dailyGoalCompletedCount/'
            '${_dailyGoals.length})',
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            _isDailyGoalRewardUnlocked ? '已兌換 +0.1' : '查看任務 ›',
            style: TextStyle(
              color: _isDailyGoalRewardUnlocked
                  ? const Color(
                      0xFF16A34A,
                    )
                  : const Color(
                      0xFF6B7280,
                    ),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// 個人化任務資料
// ================================================================

class _PersonalizedTask {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isCompleted;

  const _PersonalizedTask({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isCompleted,
  });
}

// ================================================================
// 每日目標資料
// ================================================================

class _DailyGoalItem {
  final String title;
  final String subtitle;
  final bool isCompleted;

  const _DailyGoalItem({
    required this.title,
    required this.subtitle,
    required this.isCompleted,
  });
}

// ================================================================
// 每日獎勵動畫
// ================================================================

class _DailyRewardCoinsOverlay extends StatelessWidget {
  const _DailyRewardCoinsOverlay({
    required this.animation,
  });

  final Animation<double> animation;

  static const List<Offset> _coinStarts = [
    Offset(0.38, 0.74),
    Offset(0.44, 0.78),
    Offset(0.50, 0.76),
    Offset(0.56, 0.79),
    Offset(0.60, 0.73),
    Offset(0.47, 0.82),
    Offset(0.54, 0.84),
  ];

  @override
  Widget build(
    BuildContext context,
  ) {
    final Size size = MediaQuery.of(context).size;

    final Offset target = Offset(
      size.width - 110,
      size.height - 118,
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final double t = Curves.easeInOutCubic.transform(
          animation.value,
        );

        final double walletScale = 1 +
            (math.sin(
                  t * math.pi,
                ) *
                0.08 *
                (t > 0.55 ? 1 : 0));

        return Stack(
          children: [
            for (int i = 0; i < _coinStarts.length; i++)
              _AnimatedCoin(
                progress: t,
                delay: i * 0.05,
                start: Offset(
                  size.width * _coinStarts[i].dx,
                  size.height * _coinStarts[i].dy,
                ),
                end: target,
              ),
            Positioned(
              right: 18,
              bottom: 84,
              child: Transform.scale(
                scale: walletScale,
                child: ValueListenableBuilder<double>(
                  valueListenable: UserSession.walletBalanceNotifier,
                  builder: (
                    context,
                    walletBalance,
                    _,
                  ) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          999,
                        ),
                        border: Border.all(
                          color: const Color(
                            0xFFFACC15,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(
                              0.08,
                            ),
                            blurRadius: 16,
                            offset: const Offset(
                              0,
                              8,
                            ),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(
                              color: Color(
                                0xFFFFF7D6,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet_rounded,
                              size: 16,
                              color: Color(
                                0xFF92400E,
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '點券入帳',
                                style: TextStyle(
                                  color: Color(
                                    0xFF6B7280,
                                  ),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${_formatWalletAmount(walletBalance)} 點',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              right: 44,
              bottom: 140,
              child: Opacity(
                opacity: animation.value < 0.18
                    ? 0
                    : (1 - t).clamp(
                        0,
                        1,
                      ),
                child: Transform.translate(
                  offset: Offset(
                    0,
                    -18 * t,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFFFFF7D6,
                      ),
                      borderRadius: BorderRadius.circular(
                        999,
                      ),
                      border: Border.all(
                        color: const Color(
                          0xFFFACC15,
                        ),
                      ),
                    ),
                    child: const Text(
                      '+0.1 點券',
                      style: TextStyle(
                        color: Color(
                          0xFF92400E,
                        ),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (t > 0.7)
              Positioned(
                right: 78,
                bottom: 118,
                child: Opacity(
                  opacity: ((t - 0.7) / 0.3).clamp(
                    0,
                    1,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFFFACC15),
                    size: 18,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

String _formatWalletAmount(
  double value,
) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }

  return value.toStringAsFixed(1);
}

// ================================================================
// 飛行硬幣
// ================================================================

class _AnimatedCoin extends StatelessWidget {
  const _AnimatedCoin({
    required this.progress,
    required this.delay,
    required this.start,
    required this.end,
  });

  final double progress;
  final double delay;
  final Offset start;
  final Offset end;

  @override
  Widget build(
    BuildContext context,
  ) {
    final double localProgress = ((progress - delay) / (1 - delay)).clamp(0, 1);

    final double curved = Curves.easeOutCubic.transform(
      localProgress,
    );

    final double arcLift = math.sin(
          curved * math.pi,
        ) *
        90;

    final Offset position = Offset.lerp(
          start,
          end,
          curved,
        )! -
        Offset(
          0,
          arcLift,
        );

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Opacity(
        opacity: (1 - localProgress).clamp(
          0.15,
          1,
        ),
        child: Transform.scale(
          scale: 0.85 + (0.35 * (1 - localProgress)),
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: const Color(
                0xFFFACC15,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFFFACC15,
                  ).withOpacity(
                    0.32,
                  ),
                  blurRadius: 10,
                  offset: const Offset(
                    0,
                    4,
                  ),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text(
              '¢',
              style: TextStyle(
                color: Color(
                  0xFF92400E,
                ),
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// 星期按鈕
// ================================================================

class _DayButton extends StatelessWidget {
  const _DayButton({
    required this.label,
    required this.isCompleted,
    required this.isToday,
    required this.isFuture,
  });

  final String label;
  final bool isCompleted;
  final bool isToday;
  final bool isFuture;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isToday
                  ? Colors.black
                  : isFuture
                      ? const Color(
                          0xFFD1D5DB,
                        )
                      : const Color(
                          0xFF6B7280,
                        ),
            ),
          ),
          const SizedBox(
            height: 10,
          ),
          AnimatedContainer(
            duration: const Duration(
              milliseconds: 180,
            ),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted
                  ? const Color(
                      0xFF65C16F,
                    )
                  : Colors.white,
              border: Border.all(
                color: isCompleted
                    ? const Color(
                        0xFF4CAF50,
                      )
                    : isToday
                        ? Colors.black
                        : const Color(
                            0xFFD1D5DB,
                          ),
                width: isToday ? 2.2 : 2,
              ),
            ),
            child: isCompleted
                ? const Icon(
                    Icons.check,
                    size: 18,
                    color: Colors.white,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

// ================================================================
// 每日任務 Tile
// ================================================================

class _DailyGoalTile extends StatelessWidget {
  const _DailyGoalTile({
    required this.goal,
  });

  final _DailyGoalItem goal;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: goal.isCompleted
            ? const Color(
                0xFFF0FDF4,
              )
            : Colors.white,
        borderRadius: BorderRadius.circular(
          16,
        ),
        border: Border.all(
          color: goal.isCompleted
              ? const Color(
                  0xFF86EFAC,
                )
              : const Color(
                  0xFFE5E7EB,
                ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: goal.isCompleted
                  ? const Color(
                      0xFF16A34A,
                    )
                  : const Color(
                      0xFFF8FAFC,
                    ),
              shape: BoxShape.circle,
            ),
            child: goal.isCompleted
                ? const Icon(
                    Icons.check,
                    size: 16,
                    color: Colors.white,
                  )
                : const Icon(
                    Icons.radio_button_unchecked,
                    size: 16,
                    color: Color(
                      0xFF94A3B8,
                    ),
                  ),
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal.title,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(
                  height: 2,
                ),
                Text(
                  goal.subtitle,
                  style: const TextStyle(
                    color: Color(
                      0xFF6B7280,
                    ),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

// ================================================================
// 月份切換按鈕
// ================================================================

class _CalendarMonthButton extends StatelessWidget {
  const _CalendarMonthButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(
        14,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(
          14,
        ),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}

// ================================================================
// 月份摘要
// ================================================================

class _CalendarSummaryCard extends StatelessWidget {
  const _CalendarSummaryCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(
            height: 6,
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// 月曆日期
// ================================================================

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.day,
    required this.isCurrentMonth,
    required this.isCompleted,
    required this.isToday,
  });

  final int day;
  final bool isCurrentMonth;
  final bool isCompleted;
  final bool isToday;

  @override
  Widget build(
    BuildContext context,
  ) {
    final Color textColor;

    if (!isCurrentMonth) {
      textColor = const Color(0xFFD1D5DB);
    } else if (isCompleted) {
      textColor = Colors.white;
    } else {
      textColor = Colors.black;
    }

    return Container(
      decoration: BoxDecoration(
        color: isCompleted
            ? const Color(
                0xFF65C16F,
              )
            : isCurrentMonth
                ? const Color(
                    0xFFF8FAFC,
                  )
                : const Color(
                    0xFFEFF3F7,
                  ),
        borderRadius: BorderRadius.circular(
          16,
        ),
        border: Border.all(
          color: isToday
              ? Colors.black
              : const Color(
                  0xFFE5E7EB,
                ),
          width: isToday ? 1.6 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$day',
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// 數據卡片
// ================================================================

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
  Widget build(
    BuildContext context,
  ) {
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
        borderRadius: BorderRadius.circular(
          22,
        ),
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
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(
                          0xFF6B7280,
                        ),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(
                      height: 2,
                    ),
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
                          const SizedBox(
                            width: 6,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: 2,
                            ),
                            child: Text(
                              unit,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(
                                  0xFF9CA3AF,
                                ),
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
                      color: Color(
                        0xFF9CA3AF,
                      ),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(
            height: 12,
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(
              999,
            ),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(
                0xFFE5E7EB,
              ),
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
