import 'package:flutter/material.dart';
import 'exercise_selection_screen.dart';
import 'profile.dart';
import 'bottom_nav_bar.dart';
import 'community_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  void _onNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomeScreen(), // Index 0
      const CommunityScreen(), // Index 1
      const ExerciseSelectionScreen(), // Index 2 (運動選擇頁)
      const Center(child: Text('Ranking')), // Index 3
      const ProfileScreen(), // Index 4 (個人檔案)
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
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN'
  ];
  final Set<int> _completedDays = {0, 1, 3, 4};

  int get _streakDays => _completedDays.length;

  void _toggleDay(int index) {
    setState(() {
      if (_completedDays.contains(index)) {
        _completedDays.remove(index);
      } else {
        _completedDays.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, Catherine',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            const Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 14, color: Color(0xFF6B7280)),
                SizedBox(width: 6),
                Text(
                  'Monday, April 27',
                  style: TextStyle(
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          '7-DAY STREAK',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
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
                                  '$_streakDays',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                  ),
                                ),
                                const Text(
                                  'days',
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
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1FB),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE9C8F6)),
                    ),
                    child: Text(
                      '$_streakDays-Day Streak! You\'re on a roll! +10 points!',
                      style: const TextStyle(
                        color: Color(0xFFFF5A4F),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: List.generate(
                      _labels.length,
                      (index) => Expanded(
                        child: _DayButton(
                          label: _labels[index],
                          isCompleted: _completedDays.contains(index),
                          onTap: () => _toggleDay(index),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFFE5E7EB), height: 1),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'Weekly Progress',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$_streakDays/7',
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
                      value: _streakDays / 7,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE5E7EB),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF65C16F)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _MetricCard(
                    icon: Icons.local_fire_department_outlined,
                    iconColor: Color(0xFFFF6B1A),
                    title: 'CALORIES',
                    value: '1,247',
                    unit: 'kcal',
                    percentText: '83%',
                    progress: 0.83,
                    progressColor: Color(0xFFFF6B1A),
                  ),
                  const SizedBox(height: 14),
                  const _MetricCard(
                    icon: Icons.directions_walk_outlined,
                    iconColor: Colors.black,
                    title: 'STEPS',
                    value: '8,342',
                    unit: '',
                    percentText: '83%',
                    progress: 0.83,
                    progressColor: Colors.black,
                  ),
                  const SizedBox(height: 18),
                  const Divider(color: Color(0xFFE5E7EB), height: 1),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Daily Goals (0/4)',
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
    );
  }
}

class _DayButton extends StatelessWidget {
  const _DayButton({
    required this.label,
    required this.isCompleted,
    required this.onTap,
  });

  final String label;
  final bool isCompleted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
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
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
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
                child: Icon(icon, color: iconColor, size: 22),
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
                        Text(
                          value,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
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
                    'of goal',
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
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
        ],
      ),
    );
  }
}
