import 'package:flutter/material.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final TextEditingController _postController = TextEditingController();
  bool _isComposerOpen = false;
  bool _isFriendsOpen = false;
  bool _isGroupsOpen = false;

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  void _openComposer() {
    setState(() {
      _isComposerOpen = true;
    });
  }

  void _closeComposer() {
    FocusScope.of(context).unfocus();
    setState(() {
      _isComposerOpen = false;
    });
  }

  void _openFriends() {
    FocusScope.of(context).unfocus();
    setState(() {
      _isComposerOpen = false;
      _isFriendsOpen = true;
      _isGroupsOpen = false;
    });
  }

  void _openGroups() {
    FocusScope.of(context).unfocus();
    setState(() {
      _isComposerOpen = false;
      _isFriendsOpen = false;
      _isGroupsOpen = true;
    });
  }

  void _closeSecondaryPage() {
    setState(() {
      _isFriendsOpen = false;
      _isGroupsOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(context),
      body: SafeArea(
        top: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _isFriendsOpen
              ? const _FriendsPanel(key: ValueKey('friends'))
              : _isGroupsOpen
                  ? const _GroupsPanel(key: ValueKey('groups'))
                  : ListView(
                      key: const ValueKey('community-feed'),
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                      children: [
                        const _SearchField(),
                        const SizedBox(height: 14),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: _isComposerOpen
                              ? _PostComposer(
                                  key: const ValueKey('composer-open'),
                                  controller: _postController,
                                  onClose: _closeComposer,
                                )
                              : _CreatePostCard(
                                  key: const ValueKey('composer-closed'),
                                  onTap: _openComposer,
                                ),
                        ),
                        const SizedBox(height: 18),
                        const _SectionLabel('COMMUNITY FEED'),
                        const SizedBox(height: 12),
                        const _PostCard(
                          initial: 'S',
                          name: 'Sarah Chen',
                          timeAgo: '2 hours ago',
                          content:
                              'Just completed my first 5km slow jog! Feeling amazing and completely pain-free. The key is patience and consistency!',
                          tags: [
                            '#MorningRun',
                            '#PainFree',
                            '#ProgressNotPerfection'
                          ],
                          likes: 24,
                          comments: 8,
                        ),
                        const SizedBox(height: 14),
                        const _PostCard(
                          initial: 'M',
                          name: 'Mike Johnson',
                          timeAgo: '5 hours ago',
                          content:
                              'Week 3 of slow jogging and my knee pain has completely disappeared. This approach really works!',
                          tags: ['#SlowJoggingChallenge', '#HealthyHabits'],
                          likes: 18,
                          comments: 5,
                        ),
                        const SizedBox(height: 14),
                        const _PostCard(
                          initial: 'A',
                          name: 'Anna Lee',
                          timeAgo: 'Yesterday',
                          content:
                              'Tiny steps, steady breathing, and no pressure. Today felt like the first run I actually wanted to repeat.',
                          tags: ['#EasyMiles', '#KeepMoving'],
                          likes: 31,
                          comments: 11,
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFFF8FAFC),
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: (_isFriendsOpen || _isGroupsOpen)
                ? _closeSecondaryPage
                : () => Navigator.maybePop(context),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chevron_left, size: 24, color: Color(0xFF4A5568)),
                  SizedBox(width: 2),
                  Text(
                    'Back',
                    style: TextStyle(
                      color: Color(0xFF4A5568),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 12,
                backgroundColor: Color(0xFFE2E8F0),
                child: Icon(Icons.directions_run,
                    size: 14, color: Color(0xFF4A5568)),
              ),
              const SizedBox(width: 8),
              Text(
                _isFriendsOpen
                    ? 'FRIENDS'
                    : _isGroupsOpen
                        ? 'GROUPS'
                        : 'COMMUNITY',
                style: const TextStyle(
                  color: Color(0xFF1A202C),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (_isGroupsOpen)
            const _CreateGroupButton()
          else ...[
            _FriendRequestsButton(onTap: _openFriends),
            const SizedBox(width: 8),
            _GroupsButton(onTap: _openGroups),
          ],
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: const Row(
        children: [
          Icon(Icons.search, color: Color(0xFFA0AEC0), size: 23),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Search posts, people, or hashtags...',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFF718096),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatePostCard extends StatelessWidget {
  final VoidCallback onTap;

  const _CreatePostCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
          ),
          child: Row(
            children: [
              const _Avatar(initial: 'L'),
              const SizedBox(width: 13),
              const Expanded(
                child: Text(
                  'Share your jogging thoughts...',
                  style: TextStyle(
                    color: Color(0xFFA0AEC0),
                    fontSize: 15,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: onTap,
                icon: const Icon(Icons.auto_awesome_outlined,
                    color: Color(0xFFA0AEC0)),
                splashRadius: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostComposer extends StatelessWidget {
  static const List<String> _tags = [
    '#MorningRun',
    '#PainFree',
    '#SlowJoggingChallenge',
    '#HealthyHabits',
    '#FitnessGoals',
    '#ProgressNotPerfection',
    '#JoggingLife',
    '#MindfulMovement',
  ];

  final TextEditingController controller;
  final VoidCallback onClose;

  const _PostComposer({
    super.key,
    required this.controller,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            offset: const Offset(0, 8),
            blurRadius: 18,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Share Your Journey',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: onClose,
                visualDensity: VisualDensity.compact,
                splashRadius: 20,
                icon: const Icon(Icons.close, color: Colors.black, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            minLines: 3,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText:
                  'Share your slow jogging experience,\nhealth tips, or achievements...',
              hintStyle: const TextStyle(
                color: Color(0xFF718096),
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.black, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Icon(Icons.add_circle_outline,
                  color: Color(0xFF718096), size: 16),
              SizedBox(width: 6),
              Text(
                'Add Tags',
                style: TextStyle(
                  color: Color(0xFF4A5568),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags.map((tag) => _TagPill(tag)).toList(),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              TextButton.icon(
                onPressed: () {},
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: const Text(
                  'Add Photo',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
              const Spacer(),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, child) {
                  final canPost = value.text.trim().isNotEmpty;

                  return ElevatedButton.icon(
                    onPressed: canPost ? () {} : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B7280),
                      disabledBackgroundColor: const Color(0xFF8A8A8A),
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.send_outlined, size: 16),
                    label: const Text(
                      'Post',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

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

class _PostCard extends StatelessWidget {
  final String initial;
  final String name;
  final String timeAgo;
  final String content;
  final List<String> tags;
  final int likes;
  final int comments;

  const _PostCard({
    required this.initial,
    required this.name,
    required this.timeAgo,
    required this.content,
    required this.tags,
    required this.likes,
    required this.comments,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Avatar(initial: initial),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        timeAgo,
                        style: const TextStyle(
                          color: Color(0xFF718096),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  visualDensity: VisualDensity.compact,
                  splashRadius: 20,
                  icon: const Icon(Icons.more_vert,
                      color: Color(0xFFA0AEC0), size: 22),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Text(
              content,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 2),
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              children: tags.map((tag) => _TagPill(tag)).toList(),
            ),
          ),
          const Divider(color: Color(0xFFF1F5F9), height: 18, thickness: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                _PostAction(
                    icon: Icons.favorite_border, label: likes.toString()),
                const SizedBox(width: 16),
                _PostAction(
                    icon: Icons.chat_bubble_outline,
                    label: comments.toString()),
                const SizedBox(width: 16),
                const Icon(Icons.bookmark_border,
                    color: Color(0xFF4A5568), size: 22),
                const Spacer(),
                const Icon(Icons.share_outlined,
                    color: Color(0xFF4A5568), size: 22),
                const SizedBox(width: 7),
                const Text(
                  'Share',
                  style: TextStyle(
                    color: Color(0xFF4A5568),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String initial;

  const _Avatar({required this.initial});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 17,
      backgroundColor: Colors.black,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  final String label;

  const _TagPill(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFECEFF3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF4A5568),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PostAction extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PostAction({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF4A5568), size: 22),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF4A5568),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _FriendsPanel extends StatefulWidget {
  const _FriendsPanel({super.key});

  @override
  State<_FriendsPanel> createState() => _FriendsPanelState();
}

class _FriendsPanelState extends State<_FriendsPanel> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        _FriendTabs(
          selectedIndex: _selectedTab,
          onChanged: (index) {
            setState(() {
              _selectedTab = index;
            });
          },
        ),
        const SizedBox(height: 20),
        if (_selectedTab == 0) ...const [
          _FriendSearchField(),
          SizedBox(height: 14),
          _SectionLabel('YOUR RUNNING BUDDIES (3)'),
          SizedBox(height: 12),
          _RunningBuddyCard(
            initial: 'S',
            name: 'Sarah Chen',
            runsTogether: 12,
            streak: 5,
            lastRun: '2024-03-02',
          ),
          SizedBox(height: 12),
          _RunningBuddyCard(
            initial: 'M',
            name: 'Mike Johnson',
            runsTogether: 8,
            streak: 3,
            lastRun: '2024-03-01',
          ),
          SizedBox(height: 12),
          _RunningBuddyCard(
            initial: 'J',
            name: 'Jordan Lee',
            runsTogether: 15,
            streak: 7,
            lastRun: '2024-03-03',
          ),
        ] else if (_selectedTab == 1) ...const [
          _SectionLabel('FRIEND REQUESTS (1)'),
          SizedBox(height: 12),
          _FriendRequestCard(),
          SizedBox(height: 18),
          _SectionLabel('PENDING (1)'),
          SizedBox(height: 12),
          _PendingFriendCard(),
        ] else ...const [
          _SectionLabel('PEOPLE YOU MAY KNOW'),
          SizedBox(height: 12),
          _SuggestionCard(
            initial: 'T',
            name: 'Taylor Swift',
            mutualFriends: 3,
          ),
          SizedBox(height: 12),
          _SuggestionCard(
            initial: 'C',
            name: 'Chris Evans',
            mutualFriends: 2,
          ),
          SizedBox(height: 12),
          _SuggestionCard(
            initial: 'O',
            name: 'Olivia Brown',
            mutualFriends: 5,
          ),
        ],
      ],
    );
  }
}

class _FriendTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _FriendTabs({
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _FriendTabButton(
            label: 'Friends\n(3)',
            isSelected: selectedIndex == 0,
            onTap: () => onChanged(0),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: _FriendTabButton(
            label: 'Requests',
            badge: '2',
            isSelected: selectedIndex == 1,
            onTap: () => onChanged(1),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: _FriendTabButton(
            label: 'Suggestions',
            isSelected: selectedIndex == 2,
            onTap: () => onChanged(2),
          ),
        ),
      ],
    );
  }
}

class _FriendTabButton extends StatelessWidget {
  final String label;
  final String? badge;
  final bool isSelected;
  final VoidCallback onTap;

  const _FriendTabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              backgroundColor:
                  isSelected ? Colors.black : const Color(0xFFF1F5F9),
              foregroundColor:
                  isSelected ? Colors.white : const Color(0xFF4A5568),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.zero,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                height: 1.25,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        if (badge != null)
          Positioned(
            right: -3,
            top: -6,
            child: Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFE53E3E),
                shape: BoxShape.circle,
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FriendSearchField extends StatelessWidget {
  const _FriendSearchField();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: const Row(
        children: [
          Icon(Icons.search, color: Color(0xFFA0AEC0), size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Search friends...',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFF718096),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RunningBuddyCard extends StatelessWidget {
  final String initial;
  final String name;
  final int runsTogether;
  final int streak;
  final String lastRun;

  const _RunningBuddyCard({
    required this.initial,
    required this.name,
    required this.runsTogether,
    required this.streak,
    required this.lastRun,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _friendCardDecoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DarkInitialAvatar(initial: initial),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.directions_run,
                        color: Color(0xFF718096), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '$runsTogether runs together',
                      style: _friendMetaStyle,
                    ),
                    const SizedBox(width: 18),
                    const Icon(Icons.emoji_events_outlined,
                        color: Color(0xFFD69E2E), size: 14),
                    const SizedBox(width: 4),
                    Text('$streak day streak', style: _friendMetaStyle),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        color: Color(0xFF718096), size: 14),
                    const SizedBox(width: 5),
                    Text('Last run: $lastRun', style: _friendMetaStyle),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _SmallFriendButton(
                      label: 'Invite to\nRun',
                      icon: Icons.calendar_today_outlined,
                      isPrimary: true,
                      onTap: () {},
                    ),
                    const SizedBox(width: 8),
                    _SmallFriendButton(
                      label: 'Message',
                      icon: Icons.chat_bubble_outline,
                      onTap: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const _IconSquareButton(icon: Icons.person_remove_alt_1_outlined),
        ],
      ),
    );
  }
}

class _FriendRequestCard extends StatelessWidget {
  const _FriendRequestCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _friendCardDecoration,
      child: Row(
        children: [
          const _DarkInitialAvatar(initial: 'A'),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Alex Rivera',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  'Wants to connect',
                  style: _friendMetaStyle,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _WideFriendButton(
                        label: 'Accept',
                        icon: Icons.check,
                        isPrimary: true,
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _WideFriendButton(
                        label: 'Decline',
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingFriendCard extends StatelessWidget {
  const _PendingFriendCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _friendCardDecoration,
      child: Row(
        children: [
          const _DarkInitialAvatar(initial: 'E'),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Emma Wilson',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.access_time, color: Color(0xFF718096), size: 14),
                    SizedBox(width: 4),
                    Text('Request pending', style: _friendMetaStyle),
                  ],
                ),
              ],
            ),
          ),
          _WideFriendButton(
            label: 'Cancel',
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final String initial;
  final String name;
  final int mutualFriends;

  const _SuggestionCard({
    required this.initial,
    required this.name,
    required this.mutualFriends,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _friendCardDecoration,
      child: Row(
        children: [
          _DarkInitialAvatar(initial: initial),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '$mutualFriends mutual friends',
                  style: _friendMetaStyle,
                ),
              ],
            ),
          ),
          _WideFriendButton(
            label: 'Add',
            icon: Icons.person_add_alt_1_outlined,
            isPrimary: true,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _DarkInitialAvatar extends StatelessWidget {
  final String initial;

  const _DarkInitialAvatar({required this.initial});

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

class _SmallFriendButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;

  const _SmallFriendButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 38,
      child: TextButton.icon(
        onPressed: onTap,
        style: _friendButtonStyle(isPrimary),
        icon: Icon(icon, size: 13),
        label: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            height: 1.05,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _WideFriendButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isPrimary;
  final VoidCallback onTap;

  const _WideFriendButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
    );

    return SizedBox(
      height: 34,
      child: icon == null
          ? TextButton(
              onPressed: onTap,
              style: _friendButtonStyle(isPrimary),
              child: text,
            )
          : TextButton.icon(
              onPressed: onTap,
              style: _friendButtonStyle(isPrimary),
              icon: Icon(icon, size: 15),
              label: text,
            ),
    );
  }
}

class _IconSquareButton extends StatelessWidget {
  final IconData icon;

  const _IconSquareButton({required this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 38,
      child: TextButton(
        onPressed: () {},
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xFFF1F5F9),
          foregroundColor: const Color(0xFF4A5568),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Icon(icon, size: 17),
      ),
    );
  }
}

ButtonStyle _friendButtonStyle(bool isPrimary) {
  return TextButton.styleFrom(
    backgroundColor: isPrimary ? Colors.black : const Color(0xFFF1F5F9),
    foregroundColor: isPrimary ? Colors.white : const Color(0xFF4A5568),
    padding: const EdgeInsets.symmetric(horizontal: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );
}

BoxDecoration get _friendCardDecoration {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
  );
}

const TextStyle _friendMetaStyle = TextStyle(
  color: Color(0xFF718096),
  fontSize: 11,
  fontWeight: FontWeight.w700,
);

class _GroupsPanel extends StatefulWidget {
  const _GroupsPanel({super.key});

  @override
  State<_GroupsPanel> createState() => _GroupsPanelState();
}

class _GroupsPanelState extends State<_GroupsPanel> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: _GroupTabButton(
                label: 'My Groups (2)',
                isSelected: _selectedTab == 0,
                onTap: () {
                  setState(() {
                    _selectedTab = 0;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _GroupTabButton(
                label: 'Discover',
                isSelected: _selectedTab == 1,
                onTap: () {
                  setState(() {
                    _selectedTab = 1;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const _GroupSearchField(),
        const SizedBox(height: 14),
        _SectionLabel(
            _selectedTab == 0 ? 'YOUR GROUPS (2)' : 'SUGGESTED GROUPS'),
        const SizedBox(height: 12),
        if (_selectedTab == 0) ...const [
          _GroupCard(
            name: 'Morning Runners Club',
            description: 'Early birds who love sunrise jogs',
            members: 142,
            runs: 856,
            progressText: '32/50 runs',
            progress: 0.64,
            actionLabel: 'View Group',
            showCrown: true,
            showSettings: true,
          ),
          SizedBox(height: 12),
          _GroupCard(
            name: 'City Park Joggers',
            description: 'Weekly meetups at Central Park',
            members: 87,
            runs: 432,
            progressText: '32/30 runs',
            progress: 1,
            actionLabel: 'View Group',
          ),
        ] else ...const [
          _SuggestedGroupCard(
            name: 'Weekend Warriors',
            description: 'Saturday and Sunday jogging enthusiasts',
            members: 56,
            actionLabel: 'Join Group',
            isPrivate: false,
          ),
          SizedBox(height: 12),
          _SuggestedGroupCard(
            name: 'Post-Work Runners',
            description: 'Evening jogs after work hours',
            members: 93,
            actionLabel: 'Request to Join',
            isPrivate: true,
          ),
        ],
      ],
    );
  }
}

class _GroupTabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _GroupTabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: isSelected ? Colors.black : const Color(0xFFF1F5F9),
          foregroundColor: isSelected ? Colors.white : const Color(0xFF4A5568),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _GroupSearchField extends StatelessWidget {
  const _GroupSearchField();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: const Row(
        children: [
          Icon(Icons.search, color: Color(0xFFA0AEC0), size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Search groups...',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFF718096),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestedGroupCard extends StatelessWidget {
  final String name;
  final String description;
  final int members;
  final String actionLabel;
  final bool isPrivate;

  const _SuggestedGroupCard({
    required this.name,
    required this.description,
    required this.members,
    required this.actionLabel,
    required this.isPrivate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _friendCardDecoration,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2937),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.groups_2_outlined,
                    color: Colors.white, size: 27),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Icon(
                          isPrivate ? Icons.lock_outline : Icons.public,
                          color: const Color(0xFF718096),
                          size: 16,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _friendMetaStyle,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.people_outline,
                            color: Color(0xFF718096), size: 14),
                        const SizedBox(width: 4),
                        Text('$members members', style: _friendMetaStyle),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: TextButton.icon(
              onPressed: () {},
              style: _friendButtonStyle(true),
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 15),
              label: Text(
                actionLabel,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final String name;
  final String description;
  final int members;
  final int runs;
  final String progressText;
  final double progress;
  final String actionLabel;
  final bool showCrown;
  final bool showSettings;

  const _GroupCard({
    required this.name,
    required this.description,
    required this.members,
    required this.runs,
    required this.progressText,
    required this.progress,
    required this.actionLabel,
    this.showCrown = false,
    this.showSettings = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _friendCardDecoration,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.groups_2_outlined,
                    color: Colors.white, size: 27),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (showCrown)
                          const Icon(Icons.workspace_premium_outlined,
                              color: Color(0xFFD69E2E), size: 16),
                        const SizedBox(width: 5),
                        const Icon(Icons.public,
                            color: Color(0xFF718096), size: 15),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _friendMetaStyle,
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Icon(Icons.people_outline,
                            color: Color(0xFF718096), size: 14),
                        const SizedBox(width: 4),
                        Text('$members members', style: _friendMetaStyle),
                        const SizedBox(width: 12),
                        const Icon(Icons.trending_up,
                            color: Color(0xFF718096), size: 14),
                        const SizedBox(width: 4),
                        Text('$runs runs', style: _friendMetaStyle),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextButton(
                    onPressed: () {},
                    style: _friendButtonStyle(true),
                    child: Text(
                      actionLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              if (showSettings) ...[
                const SizedBox(width: 10),
                const _IconSquareButton(icon: Icons.settings_outlined),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      'Weekly Goal',
                      style: TextStyle(
                        color: Color(0xFF4A5568),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      progressText,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateGroupButton extends StatelessWidget {
  const _CreateGroupButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: () {},
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.add, color: Colors.white, size: 20),
        splashRadius: 18,
      ),
    );
  }
}

class _GroupsButton extends StatelessWidget {
  final VoidCallback onTap;

  const _GroupsButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: Colors.black,
          shape: BoxShape.circle,
        ),
        child:
            const Icon(Icons.groups_2_outlined, color: Colors.white, size: 18),
      ),
    );
  }
}

class _FriendRequestsButton extends StatelessWidget {
  final VoidCallback onTap;

  const _FriendRequestsButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.person_add_alt_1_outlined,
                color: Color(0xFF4A5568), size: 24),
            Positioned(
              right: -2,
              top: -5,
              child: Container(
                width: 17,
                height: 17,
                decoration: const BoxDecoration(
                  color: Color(0xFFE53E3E),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text(
                  '2',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
