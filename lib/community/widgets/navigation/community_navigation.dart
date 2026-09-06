import 'package:flutter/material.dart';

enum CommunitySection {
  feed,
  friends,
  groups,
}

class CommunityNavigation extends StatelessWidget {
  final CommunitySection selected;
  final int friendBadge;
  final int groupBadge;
  final ValueChanged<CommunitySection> onChanged;

  const CommunityNavigation({
    super.key,
    required this.selected,
    required this.friendBadge,
    required this.groupBadge,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: _CommunityNavigationItem(
                label: '動態',
                icon: Icons.dynamic_feed_outlined,
                selected: selected == CommunitySection.feed,
                onTap: () {
                  onChanged(CommunitySection.feed);
                },
              ),
            ),
            Expanded(
              child: _CommunityNavigationItem(
                label: '好友',
                icon: Icons.people_outline,
                badge: friendBadge,
                selected: selected == CommunitySection.friends,
                onTap: () {
                  onChanged(CommunitySection.friends);
                },
              ),
            ),
            Expanded(
              child: _CommunityNavigationItem(
                label: '群組',
                icon: Icons.groups_2_outlined,
                badge: groupBadge,
                selected: selected == CommunitySection.groups,
                onTap: () {
                  onChanged(CommunitySection.groups);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityNavigationItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  const _CommunityNavigationItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 44,
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF475569),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (badge > 0) ...[
              const SizedBox(width: 5),
              Container(
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? Colors.white : const Color(0xFFE53E3E),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge > 99 ? '99+' : '$badge',
                  style: TextStyle(
                    color: selected ? Colors.black : Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
