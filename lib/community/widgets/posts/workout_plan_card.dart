import 'package:flutter/material.dart';

import '../../models/community_post.dart';
import '../../../services/workout_menu_service.dart';

class WorkoutPlanCard extends StatefulWidget {
  final WorkoutPlanData plan;

  const WorkoutPlanCard({
    super.key,
    required this.plan,
  });

  @override
  State<WorkoutPlanCard> createState() => _WorkoutPlanCardState();
}

class _WorkoutPlanCardState extends State<WorkoutPlanCard> {
  final WorkoutMenuService _workoutMenuService = WorkoutMenuService();

  bool _isApplying = false;
  bool _isApplied = false;

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7FF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFC7DCFF),
          width: 1.5,
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
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  plan.title,
                  style: const TextStyle(
                    color: Color(0xFF1D4ED8),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            plan.summary,
            style: const TextStyle(
              color: Color(0xFF2563EB),
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(
            plan.steps.length,
            (index) {
              final step = plan.steps[index];

              String stepValueText(
                WorkoutPlanStep step,
              ) {
                switch (step.exerciseType) {
                  case 'squat':
                    final reps = step.reps;

                    if (reps == null) {
                      return '尚未設定次數';
                    }

                    return '$reps 下';

                  case 'slow_jogging':
                  default:
                    final minutes = step.minutes;

                    if (minutes == null) {
                      return '尚未設定時間';
                    }

                    return '$minutes 分鐘';
                }
              }

              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == plan.steps.length - 1 ? 0 : 10,
                ),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFFE8F0FF),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.name,
                              style: const TextStyle(
                                color: Color(0xFF1F2937),
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              stepValueText(step),
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _PlanMetricPill(
                icon: Icons.schedule_outlined,
                label: '${plan.totalMinutes} 分鐘',
              ),
              _PlanMetricPill(
                icon: Icons.local_fire_department_outlined,
                label: plan.difficulty,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isApplying || _isApplied ? null : _applyWorkoutPlan,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                disabledForegroundColor: const Color(0xFF6B7280),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: _isApplying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _isApplied
                          ? Icons.check_circle_outline
                          : Icons.add_circle_outline,
                    ),
              label: Text(
                _isApplied ? '已套用' : '套用運動菜單',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _applyWorkoutPlan() async {
    if (_isApplying || _isApplied) {
      return;
    }

    setState(() {
      _isApplying = true;
    });

    try {
      final planId = widget.plan.id;

      if (planId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('此運動計畫尚未同步完成，暫時無法套用'),
          ),
        );
        return;
      }
      final result = await _workoutMenuService.applyPostWorkoutPlan(
        planId,
      );

      final bool alreadyApplied = result['already_applied'] == true;

      if (!mounted) return;

      setState(() {
        _isApplied = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            alreadyApplied ? '此運動菜單已經套用過' : '已套用運動菜單',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '套用運動菜單失敗',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isApplying = false;
        });
      }
    }
  }
}

class _PlanMetricPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PlanMetricPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 7,
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
            size: 16,
            color: const Color(0xFF2563EB),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF2563EB),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
