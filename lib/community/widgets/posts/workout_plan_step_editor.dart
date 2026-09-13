import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/community_post.dart';
import '../common/community_input.dart';

class EditableWorkoutPlanStep {
  String exerciseType;

  final TextEditingController minutes;
  final TextEditingController reps;

  EditableWorkoutPlanStep({
    this.exerciseType = 'slow_jogging',
    int? minutes,
    int? reps,
  })  : minutes = TextEditingController(
          text: minutes?.toString() ?? '',
        ),
        reps = TextEditingController(
          text: reps?.toString() ?? '',
        );

  String get name {
    switch (exerciseType) {
      case 'squat':
        return '深蹲';
      case 'slow_jogging':
      default:
        return '超慢跑';
    }
  }

  WorkoutPlanStep? toPlanStep() {
    switch (exerciseType) {
      case 'slow_jogging':
        final value = int.tryParse(
              minutes.text.trim(),
            ) ??
            0;

        if (value <= 0) {
          return null;
        }

        return WorkoutPlanStep(
          name: '超慢跑',
          exerciseType: 'slow_jogging',
          minutes: value,
          reps: null,
        );

      case 'squat':
        final value = int.tryParse(
              reps.text.trim(),
            ) ??
            0;

        if (value <= 0) {
          return null;
        }

        return WorkoutPlanStep(
          name: '深蹲',
          exerciseType: 'squat',
          minutes: null,
          reps: value,
        );
    }

    return null;
  }

  void dispose() {
    minutes.dispose();
    reps.dispose();
  }
}

class WorkoutPlanStepEditor extends StatefulWidget {
  final int index;
  final EditableWorkoutPlanStep step;
  final VoidCallback onRemove;

  const WorkoutPlanStepEditor({
    super.key,
    required this.index,
    required this.step,
    required this.onRemove,
  });

  @override
  State<WorkoutPlanStepEditor> createState() => _WorkoutPlanStepEditorState();
}

class _WorkoutPlanStepEditorState extends State<WorkoutPlanStepEditor> {
  static const Map<String, String> _exerciseLabels = {
    'slow_jogging': '超慢跑',
    'squat': '深蹲',
  };

  Future<void> _pickMinutes() async {
    final current = int.tryParse(widget.step.minutes.text.trim()) ?? 10;

    final initialValue = current.clamp(1, 180);

    var selectedValue = initialValue;

    final controller = FixedExtentScrollController(
      initialItem: initialValue - 1,
    );

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: SizedBox(
            height: 300,
            child: Column(
              children: [
                _PickerHeader(
                  title: '選擇時間',
                  onCancel: () {
                    Navigator.of(sheetContext).pop();
                  },
                  onConfirm: () {
                    widget.step.minutes.text = selectedValue.toString();

                    Navigator.of(sheetContext).pop();

                    setState(() {});
                  },
                ),
                Expanded(
                  child: CupertinoPicker(
                    scrollController: controller,
                    itemExtent: 40,
                    useMagnifier: true,
                    magnification: 1.08,
                    onSelectedItemChanged: (index) {
                      selectedValue = index + 1;
                    },
                    children: List.generate(
                      180,
                      (index) => Center(
                        child: Text(
                          '${index + 1} 分鐘',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    controller.dispose();
  }

  Future<void> _pickReps() async {
    final current = int.tryParse(widget.step.reps.text.trim()) ?? 30;

    final initialValue = current.clamp(1, 500);

    var selectedValue = initialValue;

    final controller = FixedExtentScrollController(
      initialItem: initialValue - 1,
    );

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: SizedBox(
            height: 300,
            child: Column(
              children: [
                _PickerHeader(
                  title: '選擇次數',
                  onCancel: () {
                    Navigator.of(sheetContext).pop();
                  },
                  onConfirm: () {
                    widget.step.reps.text = selectedValue.toString();

                    Navigator.of(sheetContext).pop();

                    setState(() {});
                  },
                ),
                Expanded(
                  child: CupertinoPicker(
                    scrollController: controller,
                    itemExtent: 40,
                    useMagnifier: true,
                    magnification: 1.08,
                    onSelectedItemChanged: (index) {
                      selectedValue = index + 1;
                    },
                    children: List.generate(
                      500,
                      (index) => Center(
                        child: Text(
                          '${index + 1} 下',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    controller.dispose();
  }

  void _changeExerciseType(String? value) {
    if (value == null) {
      return;
    }

    setState(() {
      widget.step.exerciseType = value;

      if (value == 'slow_jogging') {
        widget.step.reps.clear();
      } else {
        widget.step.minutes.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSlowJogging = widget.step.exerciseType == 'slow_jogging';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFFE8F0FF),
                child: Text(
                  '${widget.index + 1}',
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: widget.step.exerciseType,
                  decoration: communityInputDecoration(
                    '動作名稱',
                  ),
                  items: _exerciseLabels.entries
                      .map(
                        (entry) => DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: _changeExerciseType,
                ),
              ),
              IconButton(
                onPressed: widget.onRemove,
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (isSlowJogging)
            InkWell(
              onTap: _pickMinutes,
              borderRadius: BorderRadius.circular(16),
              child: IgnorePointer(
                child: TextField(
                  controller: widget.step.minutes,
                  decoration: communityInputDecoration(
                    '選擇時間（分鐘）',
                  ).copyWith(
                    suffixIcon: const Icon(
                      Icons.access_time_outlined,
                    ),
                  ),
                ),
              ),
            )
          else
            InkWell(
              onTap: _pickReps,
              borderRadius: BorderRadius.circular(16),
              child: IgnorePointer(
                child: TextField(
                  controller: widget.step.reps,
                  decoration: communityInputDecoration(
                    '選擇次數',
                  ).copyWith(
                    suffixIcon: const Icon(
                      Icons.fitness_center_outlined,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PickerHeader extends StatelessWidget {
  final String title;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const _PickerHeader({
    required this.title,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        0,
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: onCancel,
            child: const Text('取消'),
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: onConfirm,
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }
}
