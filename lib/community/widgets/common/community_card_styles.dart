import 'package:flutter/material.dart';

BoxDecoration communityCardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: const Color(0xFFE2E8F0),
      width: 1.5,
    ),
  );
}

const TextStyle communityMetaStyle = TextStyle(
  color: Color(0xFF718096),
  fontSize: 11,
  fontWeight: FontWeight.w700,
);
