import 'package:flutter/material.dart';

import 'pose_detector_view.dart';

class WorkoutSessionScreen extends StatefulWidget {
  final Map<String, dynamic> menu;

  const WorkoutSessionScreen({
    super.key,
    required this.menu,
  });

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  int _currentIndex = 0;
  bool _isStarting = false;

  List<Map<String, dynamic>> get _steps {
    final raw = widget.menu['steps'];

    if (raw is! List) {
      return [];
    }

    return raw
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(item),
        )
        .toList();
  }

  Map<String, dynamic>? get _currentStep {
    if (_steps.isEmpty || _currentIndex >= _steps.length) {
      return null;
    }

    return _steps[_currentIndex];
  }

  String _exerciseTitle(
    String exerciseType,
  ) {
    switch (exerciseType) {
      case 'squat':
        return '深蹲';

      case 'slow_jogging':
      default:
        return '超慢跑';
    }
  }

  Future<void> _startCurrentStep() async {
    if (_isStarting) {
      return;
    }

    final step = _currentStep;

    if (step == null) {
      return;
    }

    final exerciseType = step['exercise_type']?.toString() ?? '';

    final exerciseTitle = _exerciseTitle(exerciseType);

    final int? minutes = (step['minutes'] as num?)?.toInt();

    final int? reps = (step['reps'] as num?)?.toInt();

    setState(() {
      _isStarting = true;
    });

    final bool? completed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PoseDetectorView(
          exerciseTitle: exerciseTitle,
          fromWorkoutMenu: true,
          targetMinutes: minutes,
          targetReps: reps,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isStarting = false;
    });

    if (completed == true) {
      await _handleStepFinished();
    }
  }

  Future<void> _handleStepFinished() async {
    if (_currentIndex < _steps.length - 1) {
      setState(() {
        _currentIndex++;
      });

      return;
    }

    await _showWorkoutCompleted();
  }

  Future<void> _showWorkoutCompleted() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.check_circle_outline,
            size: 48,
          ),
          title: const Text(
            '菜單完成',
          ),
          content: Text(
            '你已完成「${widget.menu['title'] ?? '運動菜單'}」',
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text('完成'),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      return;
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final step = _currentStep;

    if (step == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('菜單訓練'),
        ),
        body: const Center(
          child: Text(
            '此菜單沒有訓練項目',
          ),
        ),
      );
    }

    final name = step['name']?.toString() ?? '運動';

    final exerciseType = step['exercise_type']?.toString() ?? '';

    final minutes = (step['minutes'] as num?)?.toInt();

    final reps = (step['reps'] as num?)?.toInt();

    final isSquat = exerciseType == 'squat';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.menu['title']?.toString() ?? '菜單訓練',
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              LinearProgressIndicator(
                value: (_currentIndex + 1) / _steps.length,
              ),
              const SizedBox(height: 12),
              Text(
                '第 ${_currentIndex + 1} / ${_steps.length} 項',
                style: const TextStyle(
                  color: Colors.black54,
                ),
              ),
              const Spacer(),
              Icon(
                isSquat ? Icons.fitness_center : Icons.directions_run,
                size: 72,
              ),
              const SizedBox(height: 24),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isSquat ? '${reps ?? 0} 下' : '${minutes ?? 0} 分鐘',
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '接下來將開啟 AI 動作分析',
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isStarting ? null : _startCurrentStep,
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
                    Icons.camera_alt_outlined,
                  ),
                  label: Text(
                    _isStarting ? '啟動中...' : '開始這項訓練',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
