import 'package:flutter/material.dart';

import '../common/community_card_styles.dart';

class GroupActivityForm extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController dateController;
  final TextEditingController notesController;
  final String selectedActivityType;
  final String? selectedTime;
  final List<String> timeOptions;
  final VoidCallback onPickDate;
  final ValueChanged<String> onActivityTypeSelected;
  final ValueChanged<String> onTimeSelected;
  final VoidCallback onCreate;

  const GroupActivityForm({
    super.key,
    required this.titleController,
    required this.dateController,
    required this.notesController,
    required this.selectedActivityType,
    required this.selectedTime,
    required this.timeOptions,
    required this.onPickDate,
    required this.onActivityTypeSelected,
    required this.onTimeSelected,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final canCreate = titleController.text.trim().isNotEmpty &&
        dateController.text.trim().isNotEmpty &&
        selectedTime != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: communityCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '建立團跑活動',
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          const _ActivityFieldLabel(
            icon: Icons.flag_outlined,
            text: '活動標題',
          ),
          const SizedBox(height: 8),
          TextField(
            controller: titleController,
            decoration: _inputDecoration(
              '例如：早晨訓練',
            ),
            onChanged: (_) {
              (context as Element).markNeedsBuild();
            },
          ),
          const SizedBox(height: 18),
          const _ActivityFieldLabel(
            icon: Icons.sports_gymnastics_outlined,
            text: '活動類型',
          ),
          const SizedBox(height: 10),
          Row(
            children: _activityOptions.map(
              (option) {
                final isSelected = selectedActivityType == option.value;

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: option.value == 'slow_jogging' ? 10 : 0,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(
                        14,
                      ),
                      onTap: () {
                        onActivityTypeSelected(
                          option.value,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            14,
                          ),
                          border: Border.all(
                            color: isSelected
                                ? Colors.black
                                : const Color(
                                    0xFFE2E8F0,
                                  ),
                            width: isSelected ? 2 : 1.2,
                          ),
                          color: isSelected
                              ? const Color(
                                  0xFFF8FAFC,
                                )
                              : Colors.white,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              option.icon,
                              color: Colors.black,
                              size: 20,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              option.label,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ).toList(),
          ),
          const SizedBox(height: 18),
          const _ActivityFieldLabel(
            icon: Icons.calendar_today_outlined,
            text: '選擇日期',
          ),
          const SizedBox(height: 8),
          TextField(
            controller: dateController,
            readOnly: true,
            onTap: onPickDate,
            decoration: _inputDecoration(
              '年 / 月 / 日',
              suffixIcon: IconButton(
                onPressed: onPickDate,
                icon: const Icon(
                  Icons.calendar_today_outlined,
                  size: 20,
                ),
              ),
            ),
            onChanged: (_) {
              (context as Element).markNeedsBuild();
            },
          ),
          const SizedBox(height: 18),
          const _ActivityFieldLabel(
            icon: Icons.access_time_outlined,
            text: '選擇時間',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: timeOptions.map(
              (time) {
                final isSelected = selectedTime == time;

                return ChoiceChip(
                  label: Text(time),
                  selected: isSelected,
                  onSelected: (_) {
                    onTimeSelected(time);
                  },
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : const Color(
                            0xFF4A5568,
                          ),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                  selectedColor: Colors.black,
                  backgroundColor: const Color(
                    0xFFF1F5F9,
                  ),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              },
            ).toList(),
          ),
          const SizedBox(height: 18),
          const _ActivityFieldLabel(
            icon: Icons.edit_note_outlined,
            text: '額外備註（選填）',
          ),
          const SizedBox(height: 8),
          TextField(
            controller: notesController,
            maxLines: 4,
            decoration: _inputDecoration(
              '新增配速、距離或集合指示...',
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: canCreate ? onCreate : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                disabledBackgroundColor: const Color(0xFF9CA3AF),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(
                Icons.add,
                size: 18,
              ),
              label: const Text(
                '建立活動',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityExerciseOption {
  final String value;
  final String label;
  final IconData icon;

  const _ActivityExerciseOption({
    required this.value,
    required this.label,
    required this.icon,
  });
}

const List<_ActivityExerciseOption> _activityOptions = [
  _ActivityExerciseOption(
    value: 'slow_jogging',
    label: '超慢跑',
    icon: Icons.directions_run,
  ),
  _ActivityExerciseOption(
    value: 'squat',
    label: '深蹲',
    icon: Icons.accessibility_new,
  ),
];

class _ActivityFieldLabel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ActivityFieldLabel({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: const Color(0xFF4A5568),
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF4A5568),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

InputDecoration _inputDecoration(
  String hintText, {
  Widget? suffixIcon,
}) {
  return InputDecoration(
    hintText: hintText,
    suffixIcon: suffixIcon,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 14,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(
        color: Color(0xFFE2E8F0),
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(
        color: Color(0xFFE2E8F0),
      ),
    ),
  );
}
