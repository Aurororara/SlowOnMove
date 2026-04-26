import 'package:flutter/material.dart';
import 'repositories/data_repository.dart';
import 'models/training_log_model.dart';
import 'package:intl/intl.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _HeaderSection(),
              const SizedBox(height: 18),
              const _MainDashboardCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  String _formatDate(DateTime date) {
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
    ];

    const months = [
      'January', 'February', 'March', 'April', 'May', 'June', 
      'July', 'August', 'September', 'October', 'November', 'December',
    ];

    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Welcome, Catherine',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: Color(0xFF7A7A7A),
            ),
            const SizedBox(width: 6),
            Text(
              _formatDate(today),
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF7A7A7A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MainDashboardCard extends StatefulWidget {
  const _MainDashboardCard({super.key});

  @override
  State<_MainDashboardCard> createState() => _MainDashboardCardState();
}

class _MainDashboardCardState extends State<_MainDashboardCard> {
  final DataRepository _repository = DataRepository();
  List<TrainingLogModel> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final history = await _repository.getUserTrainingHistory('test_user_001');
    if (mounted) {
      setState(() {
        _history = history;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(40.0),
        child: CircularProgressIndicator(),
      ));
    }

    int totalCalories = _history.fold(0, (sum, item) => sum + item.calories);
    int totalSteps = _history.length * 1200; 

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StreakHeader(),
          const SizedBox(height: 16),
          const _StreakBanner(),
          const SizedBox(height: 18),
          const _WeekDaysRow(),
          const SizedBox(height: 18),
          const Divider(color: Color(0xFFE4E4E4), thickness: 1),
          const SizedBox(height: 16),
          _ProgressSection(itemsCompleted: _history.length),
          const SizedBox(height: 18),
          _MetricCard(
            icon: Icons.local_fire_department_outlined,
            iconColor: const Color(0xFFFF6A00),
            label: 'CALORIES',
            value: NumberFormat('#,###').format(totalCalories),
            unit: 'kcal',
            percent: '${(totalCalories / 2000 * 100).clamp(0, 100).toInt()}%',
            subText: 'of goal',
            progress: (totalCalories / 2000).clamp(0.0, 1.0),
            progressColor: const Color(0xFFFF6A00),
          ),
          const SizedBox(height: 14),
          _MetricCard(
            icon: Icons.directions_walk_outlined,
            iconColor: Colors.black,
            label: 'STEPS',
            value: NumberFormat('#,###').format(totalSteps),
            unit: '',
            percent: '${(totalSteps / 10000 * 100).clamp(0, 100).toInt()}%',
            subText: 'of goal',
            progress: (totalSteps / 10000).clamp(0.0, 1.0),
            progressColor: Colors.black,
          ),
          const SizedBox(height: 18),
          const Divider(color: Color(0xFFE4E4E4), thickness: 1),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Daily Goals (${_history.length > 4 ? 4 : _history.length}/4)',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF7A7A7A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakHeader extends StatelessWidget {
  const _StreakHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            '7-DAY STREAK',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            showDialog(
              context: context,
              barrierColor: Colors.black.withOpacity(0.72),
              builder: (context) => const _MonthlyCheckInDialog(),
            );
          },
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: Color(0xFF676767),
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '4',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'days',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6F6F6F),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MonthlyCheckInDialog extends StatelessWidget {
  const _MonthlyCheckInDialog();

  static const Set<int> _completedDays = {
    1, 2, 3, 4, 6, 8, 9, 12, 15, 16, 18, 19, 20,
  };

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
                color: const Color(0xFF080B12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'February 2026',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Your jogging check-in history',
                            style: TextStyle(
                              color: Color(0xFFB9BEC8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(99),
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0xFF3A3A3A),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 14, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CalendarWeekHeader(),
                    SizedBox(height: 10),
                    _CalendarMonthGrid(),
                    SizedBox(height: 16),
                    Divider(height: 1, color: Color(0xFFE7E7E7)),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _CheckInStat(value: '13', label: 'Days Active', color: Colors.black)),
                        Expanded(child: _CheckInStat(value: '65%', label: 'Success Rate', color: Color(0xFF4FBF63))),
                        Expanded(child: _CheckInStat(value: '4', label: 'Current Streak', color: Color(0xFFF59E0B))),
                      ],
                    ),
                    SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _LegendItem(color: Color(0xFF4FBF63), label: 'Completed'),
                        SizedBox(width: 18),
                        _LegendItem(color: Colors.black, label: 'Today'),
                      ],
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
}

class _CalendarWeekHeader extends StatelessWidget {
  const _CalendarWeekHeader();

  @override
  Widget build(BuildContext context) {
    const weekDays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Row(
      children: weekDays.map((day) {
        return Expanded(
          child: Center(
            child: Text(
              day,
              style: const TextStyle(
                color: Color(0xFF747B86),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CalendarMonthGrid extends StatelessWidget {
  const _CalendarMonthGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 28,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final day = index + 1;
        final completed = _MonthlyCheckInDialog._completedDays.contains(day);
        final isToday = day == 7;
        return _CalendarDayCell(day: day, completed: completed, isToday: isToday);
      },
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  final int day;
  final bool completed;
  final bool isToday;

  const _CalendarDayCell({required this.day, required this.completed, required this.isToday});

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isToday ? Colors.black : completed ? const Color(0xFF4FBF63) : const Color(0xFFF0F1F3);
    final textColor = (completed || isToday) ? Colors.white : const Color(0xFF8E95A1);

    return Container(
      decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(9)),
      child: Stack(
        children: [
          Center(
            child: Text('$day', style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w800)),
          ),
          if (completed)
            const Positioned(top: 5, right: 5, child: Icon(Icons.check, color: Colors.white, size: 9)),
        ],
      ),
    );
  }
}

class _CheckInStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _CheckInStat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Color(0xFF747B86), fontSize: 10, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 13, height: 13, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Color(0xFF4B5563), fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _StreakBanner extends StatelessWidget {
  const _StreakBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1FB),
        border: Border.all(color: const Color(0xFFE2B7FF)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text(
        '4-Day Streak! You\'re on a roll! +10 points!',
        style: TextStyle(color: Color(0xFFFF3B30), fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _WeekDaysRow extends StatelessWidget {
  const _WeekDaysRow();

  @override
  Widget build(BuildContext context) {
    const labels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const completed = [true, true, false, true, true, false, false];
    return Row(
      children: List.generate(labels.length, (index) {
        return Expanded(child: _DayStatusItem(day: labels[index], completed: completed[index]));
      }),
    );
  }
}

class _DayStatusItem extends StatelessWidget {
  final String day;
  final bool completed;

  const _DayStatusItem({required this.day, required this.completed});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(day, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF727272))),
        const SizedBox(height: 8),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: completed ? const Color(0xFF22C55E) : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: completed ? const Color(0xFF16A34A) : const Color(0xFFD4D4D4), width: 2),
          ),
          child: Icon(completed ? Icons.check : Icons.add, color: completed ? Colors.white : const Color(0xFFBDBDBD), size: 18),
        ),
      ],
    );
  }
}

class _ProgressSection extends StatelessWidget {
  final int itemsCompleted;
  const _ProgressSection({super.key, this.itemsCompleted = 0});

  @override
  Widget build(BuildContext context) {
    double progress = (itemsCompleted / 7).clamp(0.0, 1.0);
    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Weekly Progress',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF5D6470)),
              ),
            ),
            Text(
              '$itemsCompleted/7',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(99)),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 9,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF22C55E)),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String unit;
  final String percent;
  final String subText;
  final double progress;
  final Color progressColor;

  const _MetricCard({
    required this.icon, required this.iconColor, required this.label, required this.value, required this.unit,
    required this.percent, required this.subText, required this.progress, required this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(22)),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF8A8FA0), fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.black, height: 1)),
                        if (unit.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(unit, style: const TextStyle(fontSize: 18, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
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
                  Text(percent, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black)),
                  Text(subText, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation(progressColor),
            ),
          ),
        ],
      ),
    );
  }
}