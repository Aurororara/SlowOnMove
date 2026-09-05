import 'package:flutter/material.dart';

class CommunityAvatar extends StatelessWidget {
  final String initial;

  const CommunityAvatar({
    super.key,
    required this.initial,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: Colors.black,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
