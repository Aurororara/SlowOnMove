import 'package:flutter/material.dart';

import 'community_card_styles.dart';

class CommunityEmptyState extends StatelessWidget {
  final String text;

  const CommunityEmptyState({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: communityCardDecoration(),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF718096),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
