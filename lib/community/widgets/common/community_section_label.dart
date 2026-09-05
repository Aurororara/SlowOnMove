import 'package:flutter/material.dart';

class CommunitySectionLabel extends StatelessWidget {
  final String text;

  const CommunitySectionLabel(
    this.text, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF4A5568),
        fontSize: 13,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
      ),
    );
  }
}
