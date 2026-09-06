import 'package:flutter/material.dart';

class FriendTabs extends StatelessWidget {
  final int friendsCount;
  final int requestsCount;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const FriendTabs({
    super.key,
    required this.friendsCount,
    required this.requestsCount,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _FriendTabItem(
              label: '好友',
              count: friendsCount,
              isSelected: selectedIndex == 0,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _FriendTabItem(
              label: '請求',
              badge: requestsCount,
              isSelected: selectedIndex == 1,
              onTap: () => onChanged(1),
            ),
          ),
          Expanded(
            child: _FriendTabItem(
              label: '建議',
              isSelected: selectedIndex == 2,
              onTap: () => onChanged(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendTabItem extends StatelessWidget {
  final String label;
  final int? count;
  final int badge;
  final bool isSelected;
  final VoidCallback onTap;

  const _FriendTabItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.count,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final displayLabel = count != null ? '$label ($count)' : label;

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 46,
        child: Stack(
          children: [
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Text(
                    displayLabel,
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFF111827)
                          : const Color(0xFF64748B),
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                  if (badge > 0)
                    Positioned(
                      right: -18,
                      top: -8,
                      child: Container(
                        height: 17,
                        constraints: const BoxConstraints(
                          minWidth: 17,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53E3E),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badge > 99 ? '99+' : '$badge',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            height: 1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (isSelected)
              Positioned(
                left: 28,
                right: 28,
                bottom: 0,
                child: Container(
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
