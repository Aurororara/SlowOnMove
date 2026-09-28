import 'package:flutter/material.dart';
import 'workout_session_screen.dart';
import 'services/workout_menu_service.dart';

class MyWorkoutMenuScreen extends StatefulWidget {
  const MyWorkoutMenuScreen({
    super.key,
  });

  @override
  State<MyWorkoutMenuScreen> createState() => _MyWorkoutMenuScreenState();
}

class _MyWorkoutMenuScreenState extends State<MyWorkoutMenuScreen> {
  final WorkoutMenuService _service = WorkoutMenuService();

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _loadMenus();
  }

  Future<void> _loadMenus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await _service.getMyWorkoutItems();

      if (!mounted) return;

      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = '載入我的菜單失敗';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text(
          '我的菜單',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: RefreshIndicator(
        onRefresh: _loadMenus,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 100),
          const Icon(
            Icons.error_outline,
            size: 52,
            color: Colors.grey,
          ),
          const SizedBox(height: 14),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
            ),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 100),
          Icon(
            Icons.fitness_center_outlined,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            '目前還沒有套用的運動菜單',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        32,
      ),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        return _buildMenuCard(
          _items[index],
        );
      },
    );
  }

  Widget _buildMenuCard(
    Map<String, dynamic> item,
  ) {
    final menuRaw = item['menu_detail'];

    if (menuRaw is! Map) {
      return const SizedBox.shrink();
    }

    final menu = Map<String, dynamic>.from(
      menuRaw,
    );

    final String title = menu['title']?.toString() ?? '未命名菜單';

    final String description = menu['description']?.toString() ?? '';

    final String difficulty = menu['difficulty']?.toString() ?? '中等';

    final int totalMinutes = (menu['total_minutes'] as num?)?.toInt() ?? 0;

    final List<dynamic> steps = menu['steps'] is List
        ? List<dynamic>.from(
            menu['steps'],
          )
        : [];

    return Container(
      margin: const EdgeInsets.only(
        bottom: 16,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.fitness_center,
                color: Color(0xFF2563EB),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MenuPill(
                icon: Icons.schedule_outlined,
                text: '$totalMinutes 分鐘',
              ),
              _MenuPill(
                icon: Icons.local_fire_department_outlined,
                text: difficulty,
              ),
            ],
          ),
          if (steps.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...List.generate(
              steps.length,
              (index) {
                final raw = steps[index];

                if (raw is! Map) {
                  return const SizedBox.shrink();
                }

                final step = Map<String, dynamic>.from(raw);

                return _buildStep(
                  index,
                  step,
                );
              },
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: steps.isEmpty
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WorkoutSessionScreen(
                            menu: menu,
                          ),
                        ),
                      );
                    },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.grey.shade600,
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(
                Icons.play_arrow_rounded,
              ),
              label: const Text(
                '開始訓練',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(
    int index,
    Map<String, dynamic> step,
  ) {
    final String name = step['name']?.toString() ?? '運動';

    final String exerciseType = step['exercise_type']?.toString() ?? '';

    final int? minutes = (step['minutes'] as num?)?.toInt();

    final int? reps = (step['reps'] as num?)?.toInt();

    String value = '';

    if (exerciseType == 'squat') {
      value = '${reps ?? 0} 下';
    } else {
      value = '${minutes ?? 0} 分鐘';
    }

    return Container(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(
              0xFFE8F0FF,
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Color(0xFF2563EB),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
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

class _MenuPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MenuPill({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: const Color(
              0xFF2563EB,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF2563EB),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
