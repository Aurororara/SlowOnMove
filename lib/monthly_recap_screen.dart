import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config/api_config.dart';
import 'services/user_session.dart';

class MonthlyRecapScreen extends StatefulWidget {
  const MonthlyRecapScreen({super.key});

  @override
  State<MonthlyRecapScreen> createState() => _MonthlyRecapScreenState();
}

class _MonthlyRecapScreenState extends State<MonthlyRecapScreen> {
  bool _isLoading = true;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  List<dynamic> _monthLogs = [];
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _fetchMonthlyLogs();
  }

  Future<void> _fetchMonthlyLogs() async {
    setState(() => _isLoading = true);

    final int memberId = UserSession.memberId;
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}training-logs/'));

    if (response.statusCode == 200) {
      final List allLogs = json.decode(response.body);

      final logs = allLogs.where((log) {
        if (log['member'] != memberId || log['start_time'] == null) return false;

        final DateTime time = DateTime.parse(log['start_time']);
        return time.year == _selectedMonth.year && time.month == _selectedMonth.month;
      }).toList();

      logs.sort((a, b) => b['start_time'].compareTo(a['start_time']));

      if (mounted) {
        setState(() {
          _monthLogs = logs;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + offset);
    });
    _pageController.jumpToPage(0);
    _fetchMonthlyLogs();
  }

  int get totalMinutes => _monthLogs.fold(0, (sum, log) => sum + ((log['total_mins'] ?? 0) as int));
  int get totalCalories => _monthLogs.fold(0, (sum, log) => sum + ((log['calories'] ?? 0) as int));
  int get totalSteps => _monthLogs.fold(0, (sum, log) => sum + ((log['step_count'] ?? 0) as int));

  double get totalDistance => _monthLogs.fold(
        0.0,
        (sum, log) => sum + ((log['distance'] as num?)?.toDouble() ?? 0.0),
      );

  int get avgAccuracy {
    if (_monthLogs.isEmpty) return 0;
    final total = _monthLogs.fold(0, (sum, log) => sum + ((log['posture_score'] ?? 0) as int));
    return total ~/ _monthLogs.length;
  }

  dynamic get bestDurationLog {
    if (_monthLogs.isEmpty) return null;
    return _monthLogs.reduce((a, b) => (a['total_mins'] ?? 0) > (b['total_mins'] ?? 0) ? a : b);
  }

  String get badgeTitle {
    if (_monthLogs.length >= 12) return '穩定慢跑王';
    if (totalDistance >= 20) return '長距離挑戰者';
    if (avgAccuracy >= 85) return '姿勢控制大師';
    if (totalCalories >= 1500) return '燃脂達人';
    if (_monthLogs.length >= 4) return '習慣養成者';
    return '慢慢開始者';
  }

  String get monthTitle => '${_selectedMonth.year}.${_selectedMonth.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('Monthly Recap', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          _buildMonthSelector(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _monthLogs.isEmpty
                    ? _buildEmptyState()
                    : PageView(
                        controller: _pageController,
                        children: [
                          _buildCoverPage(),
                          _buildStatsPage(),
                          _buildBestMomentPage(),
                          _buildChartPage(),
                          _buildBadgePage(),
                        ],
                      ),
          ),
          if (!_isLoading && _monthLogs.isNotEmpty) _buildPageHint(),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _changeMonth(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Center(
                child: Text(
                  '$monthTitle 月度回顧',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () => _changeMonth(1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverPage() {
    return _RecapPage(
      gradientColors: const [Color(0xFF141E30), Color(0xFF243B55)],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.auto_awesome, color: Colors.white, size: 54),
          const SizedBox(height: 24),
          Text(monthTitle, style: const TextStyle(color: Colors.white70, fontSize: 22)),
          const SizedBox(height: 8),
          const Text(
            '你的慢跑月度回顧',
            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          Text(
            '${_monthLogs.length}',
            style: const TextStyle(color: Colors.white, fontSize: 82, fontWeight: FontWeight.w900),
          ),
          const Text(
            '次慢跑紀錄',
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsPage() {
    return _RecapPage(
      gradientColors: const [Color(0xFF654EA3), Color(0xFFEAafc8)],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '本月總成績',
            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              _buildStatBox('$totalMinutes', '分鐘'),
              _buildStatBox(totalDistance.toStringAsFixed(2), '公里'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatBox('$totalCalories', 'kcal'),
              _buildStatBox('$totalSteps', '步數'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBestMomentPage() {
    final best = bestDurationLog;
    final bestMins = best?['total_mins'] ?? 0;
    final bestDate = best?['start_time']?.toString().split('T')[0] ?? '--';

    return _RecapPage(
      gradientColors: const [Color(0xFF11998E), Color(0xFF38EF7D)],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events, color: Colors.white, size: 64),
          const SizedBox(height: 24),
          const Text(
            'Best Moment',
            style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 28),
          const Text('本月最長一次慢跑', style: TextStyle(color: Colors.white70, fontSize: 18)),
          const SizedBox(height: 12),
          Text(
            '$bestMins min',
            style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(bestDate, style: const TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 28),
          Text(
            '平均姿勢準確率 $avgAccuracy%',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildChartPage() {
    final weeklyMinutes = List<int>.filled(5, 0);

    for (final log in _monthLogs) {
      final date = DateTime.parse(log['start_time']);
      final weekIndex = ((date.day - 1) ~/ 7).clamp(0, 4);
      weeklyMinutes[weekIndex] += (log['total_mins'] ?? 0) as int;
    }

    final maxValue = max(weeklyMinutes.reduce(max), 1);

    return _RecapPage(
      gradientColors: const [Color(0xFF232526), Color(0xFF414345)],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '每週運動趨勢',
            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 36),
          ...List.generate(weeklyMinutes.length, (index) {
            final value = weeklyMinutes[index];
            final barWidth = 220 * (value / maxValue);

            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(
                children: [
                  SizedBox(
                    width: 58,
                    child: Text(
                      'Week ${index + 1}',
                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          width: barWidth,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('$value', style: const TextStyle(color: Colors.white)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBadgePage() {
    return _RecapPage(
      gradientColors: const [Color(0xFFFF512F), Color(0xFFF09819)],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.workspace_premium, color: Colors.white, size: 70),
          const SizedBox(height: 24),
          const Text(
            '本月稱號',
            style: TextStyle(color: Colors.white70, fontSize: 20),
          ),
          const SizedBox(height: 12),
          Text(
            badgeTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 28),
          const Text(
            '每一次紀錄都算數。\n你正在慢慢累積自己的進步。',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 17, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String value, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_month_outlined, size: 84, color: Colors.grey[300]),
            const SizedBox(height: 18),
            const Text(
              '這個月還沒有跑步紀錄',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            const Text(
              '切換月份看看，或完成一次慢跑後再回來查看 Recap。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHint() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Text(
        '左右滑動查看完整回顧',
        style: TextStyle(color: Colors.grey, fontSize: 12),
      ),
    );
  }
}

class _RecapPage extends StatelessWidget {
  final List<Color> gradientColors;
  final Widget child;

  const _RecapPage({
    required this.gradientColors,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: gradientColors.last.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}