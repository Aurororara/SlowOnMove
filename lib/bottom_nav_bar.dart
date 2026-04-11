import 'package:flutter/material.dart';

class NavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const NavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavItem(Icons.home_outlined, 'Home', 0),
              _buildNavItem(Icons.chat_bubble_outline, 'Community', 1),
              // 中間的主按鈕：點擊後切換到 index 2 (運動頁面)
              GestureDetector(
                onTap: () => onTap(2),
                child: _buildMainPlayButton(),
              ),
              _buildNavItem(Icons.emoji_events_outlined, 'Ranking', 3),
              _buildNavItem(Icons.person, 'Me', 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    bool isActive = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? Colors.black : const Color(0xFFF7FAFC),
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.white : const Color(0xFF4A5568),
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? Colors.black : const Color(0xFF718096),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainPlayButton() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black,
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
            ],
          ),
          child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 6),
        const Text(
          'Start',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ],
    );
  }
}