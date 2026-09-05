import 'package:flutter/material.dart';
import 'community_button.dart';

InputDecoration communityInputDecoration(String hintText) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(
      color: Color(0xFF718096),
      fontSize: 14,
      height: 1.35,
      fontWeight: FontWeight.w500,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    filled: true,
    fillColor: Colors.white,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.black, width: 1.5),
    ),
  );
}

class CommunityFieldLabel extends StatelessWidget {
  final IconData icon;
  final String text;

  const CommunityFieldLabel({
    super.key,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF4A5568), size: 16),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF4A5568),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class CommunityChoicePicker<T> extends StatelessWidget {
  final List<T> options;
  final T value;
  final String Function(T option) labelBuilder;
  final ValueChanged<T> onChanged;
  final double spacing;
  final double runSpacing;

  const CommunityChoicePicker({
    super.key,
    required this.options,
    required this.value,
    required this.labelBuilder,
    required this.onChanged,
    this.spacing = 8,
    this.runSpacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: options.map((option) {
        return CommunityChoiceChip(
          label: labelBuilder(option),
          isSelected: value == option,
          onTap: () => onChanged(option),
        );
      }).toList(),
    );
  }
}
