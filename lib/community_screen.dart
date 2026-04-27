import 'package:flutter/material.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final TextEditingController _postController = TextEditingController();
  final List<_CommunityPost> _posts = [
    const _CommunityPost(
      initial: 'S',
      name: 'Sarah Chen',
      timeAgo: '2 hours ago',
      content:
          'Just completed my first 5km slow jog! Feeling amazing and completely pain-free. The key is patience and consistency!',
      tags: ['#MorningRun', '#PainFree', '#ProgressNotPerfection'],
      likes: 24,
      commentThreads: ['Love this progress!', 'So inspiring'],
    ),
    const _CommunityPost(
      initial: 'M',
      name: 'Mike Johnson',
      timeAgo: '5 hours ago',
      content:
          'Week 3 of slow jogging and my knee pain has completely disappeared. This approach really works!',
      tags: ['#SlowJoggingChallenge', '#HealthyHabits'],
      likes: 18,
      commentThreads: ['Needed to hear this today'],
    ),
    const _CommunityPost(
      initial: 'A',
      name: 'Anna Lee',
      timeAgo: 'Yesterday',
      content:
          'Tiny steps, steady breathing, and no pressure. Today felt like the first run I actually wanted to repeat.',
      tags: ['#EasyMiles', '#KeepMoving'],
      likes: 31,
      commentThreads: ['Steady really wins', 'Saving this mindset'],
    ),
  ];
  final Set<String> _selectedComposerTags = <String>{};
  final Map<String, List<_ChatEntry>> _friendChats = {
    'Sarah Chen': const [
      _ChatEntry(
        text: 'Want to do an easy recovery run this week?',
        isMine: false,
        timestamp: '9:12 AM',
      ),
      _ChatEntry(
        text: 'Yes please, mornings are best for me.',
        isMine: true,
        timestamp: '9:14 AM',
      ),
    ],
    'Mike Johnson': const [
      _ChatEntry(
        text: 'How is your knee feeling after week 3?',
        isMine: false,
        timestamp: 'Yesterday',
      ),
    ],
    'Jordan Lee': const [],
  };
  bool _isComposerOpen = false;
  bool _isFriendsOpen = false;
  bool _isGroupsOpen = false;
  _RunInviteFriend? _inviteFriend;
  _RunInviteFriend? _chatFriend;

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
      _selectedComposerTags.clear();
    });
  }

  void _toggleComposerTag(String tag) {
    final text = _postController.text;
    final normalizedText = text.trimRight();
    final hasTag = _selectedComposerTags.contains(tag);

    setState(() {
      if (hasTag) {
        _selectedComposerTags.remove(tag);
        _postController.text = normalizedText
            .replaceAll(' $tag', '')
            .replaceAll('$tag ', '')
            .replaceAll(tag, '')
            .replaceAll(RegExp(r'\s{2,}'), ' ')
            .trim();
      } else {
        _selectedComposerTags.add(tag);
        _postController.text =
            normalizedText.isEmpty ? tag : '$normalizedText $tag';
      }

      _postController.selection = TextSelection.collapsed(
        offset: _postController.text.length,
      );
    });
  }

  void _submitPost() {
    final content = _postController.text.trim();
    if (content.isEmpty) return;

    final detectedTags = RegExp(r'#\w+')
        .allMatches(content)
        .map((match) => match.group(0)!)
        .toList();
    final tags = <String>{..._selectedComposerTags, ...detectedTags}.toList();

    setState(() {
      _posts.insert(
        0,
        _CommunityPost(
          initial: 'C',
          name: 'Catherine',
          timeAgo: 'Just now',
          content: content,
          tags: tags,
          likes: 0,
          commentThreads: const [],
        ),
      );
      _postController.clear();
      _selectedComposerTags.clear();
      _isComposerOpen = false;
    });

    FocusScope.of(context).unfocus();
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
      if (_chatFriend != null || _inviteFriend != null) {
        _isFriendsOpen = true;
        _isGroupsOpen = false;
        _inviteFriend = null;
        _chatFriend = null;
      } else {
        _isFriendsOpen = false;
        _isGroupsOpen = false;
        _inviteFriend = null;
        _chatFriend = null;
      }
    });
  }

  void _openInviteToRun(_RunInviteFriend friend) {
    FocusScope.of(context).unfocus();
    setState(() {
      _isComposerOpen = false;
      _isFriendsOpen = false;
      _isGroupsOpen = false;
      _inviteFriend = friend;
      _chatFriend = null;
    });
  }

  void _openChat(_RunInviteFriend friend) {
    FocusScope.of(context).unfocus();
    setState(() {
      _isComposerOpen = false;
      _isFriendsOpen = false;
      _isGroupsOpen = false;
      _inviteFriend = null;
      _chatFriend = friend;
    });
  }

  void _acceptInvitation(String friendName, int messageIndex) {
    final messages = _friendChats[friendName];
    if (messages == null || messageIndex >= messages.length) return;

    final target = messages[messageIndex];
    final invitation = target.invitation;
    if (invitation == null ||
        invitation.status == _RunInvitationStatus.accepted) {
      return;
    }

    setState(() {
      _friendChats[friendName] = [
        for (int i = 0; i < messages.length; i++)
          if (i == messageIndex)
            messages[i].copyWith(
              invitation: invitation.copyWith(
                status: _RunInvitationStatus.accepted,
              ),
            )
          else
            messages[i],
        _ChatEntry(
          text:
              'Accepted! See you on ${invitation.date} at ${invitation.time}.',
          isMine: false,
          timestamp: 'Just now',
        ),
      ];
    });
  }

  void _toggleLike(int index) {
    final post = _posts[index];
    final isLiked = !post.isLiked;
    setState(() {
      _posts[index] = post.copyWith(
        isLiked: isLiked,
        likes: post.likes + (isLiked ? 1 : -1),
      );
    });
  }

  void _toggleSave(int index) {
    final post = _posts[index];
    setState(() {
      _posts[index] = post.copyWith(isSaved: !post.isSaved);
    });
  }

  Future<void> _openComments(int index) async {
    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            final post = _posts[index];
            final comments = post.commentThreads;

            void submitComment() {
              final text = controller.text.trim();
              if (text.isEmpty) return;

              setState(() {
                _posts[index] = post.copyWith(
                  commentThreads: [...comments, text],
                );
              });
              modalSetState(() {});
              controller.clear();
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1D5DB),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Comments',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (comments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text(
                          'No comments yet. Start the conversation.',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 260),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: comments.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, commentIndex) {
                            final comment = comments[commentIndex];
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _Avatar(initial: 'C'),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Community Member',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          comment,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            height: 1.4,
                                            color: Color(0xFF374151),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            decoration: InputDecoration(
                              hintText: 'Write a comment...',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: controller,
                          builder: (context, value, child) {
                            return ElevatedButton(
                              onPressed: value.text.trim().isEmpty
                                  ? null
                                  : submitComment,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                disabledBackgroundColor:
                                    const Color(0xFFD1D5DB),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                              child: const Text(
                                'Send',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    controller.dispose();
  }

  Future<void> _showPostMenu(int index) async {
    final post = _posts[index];
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading:
                      const Icon(Icons.flag_outlined, color: Colors.redAccent),
                  title: Text('Report ${post.name}\'s post'),
                  subtitle: const Text('Flag this post for review'),
                  onTap: () {
                    Navigator.pop(context);
                    _showReportReasons(post.name);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showReportReasons(String authorName) async {
    const reasons = [
      'Scam or fraud',
      'Sexual harassment',
      'Bullying or harassment',
      'Hate speech',
      'Violence or dangerous behavior',
      'False health information',
      'Spam',
      'Something else',
    ];

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Why are you reporting $authorName\'s post?',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose the reason that best fits this content.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ...reasons.map(
                    (reason) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        radius: 18,
                        backgroundColor: Color(0xFFF8FAFC),
                        child:
                            Icon(Icons.flag_outlined, color: Colors.redAccent),
                      ),
                      title: Text(
                        reason,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(content: Text('Report submitted: $reason')),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showShareSheet(int index) async {
    const shareTargets = [
      ('Instagram', Icons.camera_alt_outlined),
      ('Facebook', Icons.thumb_up_alt_outlined),
      ('Messenger', Icons.send_outlined),
      ('Copy Link', Icons.link_outlined),
    ];

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Share to',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 14),
                ...shareTargets.map((target) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFF1F5F9),
                      child: Icon(target.$2, color: Colors.black),
                    ),
                    title: Text(target.$1),
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(content: Text('Shared to ${target.$1}')),
                      );
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
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
            child: _chatFriend != null
                ? _FriendChatPanel(
                    key: ValueKey('chat-${_chatFriend!.name}'),
                    friend: _chatFriend!,
                    messages: _friendChats[_chatFriend!.name] ?? const [],
                    onAcceptInvitation: (messageIndex) {
                      _acceptInvitation(_chatFriend!.name, messageIndex);
                    },
                    onSendMessage: (message) {
                      final existing = _friendChats[_chatFriend!.name] ?? [];
                      setState(() {
                        _friendChats[_chatFriend!.name] = [
                          ...existing,
                          _ChatEntry(
                            text: message,
                            isMine: true,
                            timestamp: 'Just now',
                          ),
                        ];
                      });
                    },
                  )
                : _inviteFriend != null
                    ? _InviteToRunPanel(
                        key: ValueKey('invite-${_inviteFriend!.name}'),
                        friend: _inviteFriend!,
                        onSendInvitation: (invitation) {
                          final existing =
                              _friendChats[_inviteFriend!.name] ?? [];
                          setState(() {
                            _friendChats[_inviteFriend!.name] = [
                              ...existing,
                              _ChatEntry.invitation(
                                invitation: invitation,
                                isMine: true,
                                timestamp: 'Just now',
                              ),
                            ];
                            _chatFriend = _inviteFriend;
                            _inviteFriend = null;
                            _isFriendsOpen = false;
                          });
                        },
                      )
                    : _isFriendsOpen
                        ? _FriendsPanel(
                            key: const ValueKey('friends'),
                            onInviteTap: _openInviteToRun,
                            onMessageTap: _openChat,
                          )
                        : _isGroupsOpen
                            ? const _GroupsPanel(key: ValueKey('groups'))
                            : ListView(
                                key: const ValueKey('community-feed'),
                                padding:
                                    const EdgeInsets.fromLTRB(18, 14, 18, 24),
                                children: [
                                  const _SearchField(),
                                  const SizedBox(height: 14),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 220),
                                    switchInCurve: Curves.easeOutCubic,
                                    switchOutCurve: Curves.easeInCubic,
                                    child: _isComposerOpen
                                        ? _PostComposer(
                                            key:
                                                const ValueKey('composer-open'),
                                            controller: _postController,
                                            selectedTags: _selectedComposerTags,
                                            onTagTap: _toggleComposerTag,
                                            onPost: _submitPost,
                                            onClose: _closeComposer,
                                          )
                                        : _CreatePostCard(
                                            key: const ValueKey(
                                                'composer-closed'),
                                            onTap: _openComposer,
                                          ),
                                  ),
                                  const SizedBox(height: 18),
                                  const _SectionLabel('COMMUNITY FEED'),
                                  const SizedBox(height: 12),
                                  ...List.generate(_posts.length, (index) {
                                    final post = _posts[index];
                                    return Padding(
                                      padding: EdgeInsets.only(
                                        bottom:
                                            index == _posts.length - 1 ? 0 : 14,
                                      ),
                                      child: _PostCard(
                                        onMoreTap: () => _showPostMenu(index),
                                        onLikeTap: () => _toggleLike(index),
                                        onCommentTap: () =>
                                            _openComments(index),
                                        onSaveTap: () => _toggleSave(index),
                                        onShareTap: () =>
                                            _showShareSheet(index),
                                        initial: post.initial,
                                        name: post.name,
                                        timeAgo: post.timeAgo,
                                        content: post.content,
                                        tags: post.tags,
                                        likes: post.likes,
                                        comments: post.commentCount,
                                        isLiked: post.isLiked,
                                        isSaved: post.isSaved,
                                      ),
                                    );
                                  }),
                                ],
                              )),
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
            onTap: (_chatFriend != null ||
                    _inviteFriend != null ||
                    _isFriendsOpen ||
                    _isGroupsOpen)
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
                _chatFriend != null
                    ? 'MESSAGES'
                    : _inviteFriend != null
                        ? 'INVITE TO RUN'
                        : _isFriendsOpen
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
          if (_chatFriend != null || _inviteFriend != null)
            const SizedBox(width: 56)
          else if (_isGroupsOpen)
            _CreateGroupButton(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Create group flow coming next')),
                );
              },
            )
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
  final Set<String> selectedTags;
  final ValueChanged<String> onTagTap;
  final VoidCallback onPost;
  final VoidCallback onClose;

  const _PostComposer({
    super.key,
    required this.controller,
    required this.selectedTags,
    required this.onTagTap,
    required this.onPost,
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
            color: Colors.black.withValues(alpha: 0.08),
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
            children: _tags
                .map(
                  (tag) => _TagPill(
                    tag,
                    isSelected: selectedTags.contains(tag),
                    onTap: () => onTagTap(tag),
                  ),
                )
                .toList(),
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
                    onPressed: canPost ? onPost : null,
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

class _CommunityPost {
  final String initial;
  final String name;
  final String timeAgo;
  final String content;
  final List<String> tags;
  final int likes;
  final List<String> commentThreads;
  final bool isLiked;
  final bool isSaved;

  const _CommunityPost({
    required this.initial,
    required this.name,
    required this.timeAgo,
    required this.content,
    required this.tags,
    required this.likes,
    required this.commentThreads,
    this.isLiked = false,
    this.isSaved = false,
  });

  int get commentCount => commentThreads.length;

  _CommunityPost copyWith({
    String? initial,
    String? name,
    String? timeAgo,
    String? content,
    List<String>? tags,
    int? likes,
    List<String>? commentThreads,
    bool? isLiked,
    bool? isSaved,
  }) {
    return _CommunityPost(
      initial: initial ?? this.initial,
      name: name ?? this.name,
      timeAgo: timeAgo ?? this.timeAgo,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      likes: likes ?? this.likes,
      commentThreads: commentThreads ?? this.commentThreads,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
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
  final VoidCallback onMoreTap;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;
  final VoidCallback onSaveTap;
  final VoidCallback onShareTap;
  final String initial;
  final String name;
  final String timeAgo;
  final String content;
  final List<String> tags;
  final int likes;
  final int comments;
  final bool isLiked;
  final bool isSaved;

  const _PostCard({
    required this.onMoreTap,
    required this.onLikeTap,
    required this.onCommentTap,
    required this.onSaveTap,
    required this.onShareTap,
    required this.initial,
    required this.name,
    required this.timeAgo,
    required this.content,
    required this.tags,
    required this.likes,
    required this.comments,
    required this.isLiked,
    required this.isSaved,
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
                  onPressed: onMoreTap,
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
                  icon: isLiked ? Icons.favorite : Icons.favorite_border,
                  label: likes.toString(),
                  onTap: onLikeTap,
                  iconColor: isLiked
                      ? const Color(0xFFE11D48)
                      : const Color(0xFF4A5568),
                  textColor: isLiked
                      ? const Color(0xFFE11D48)
                      : const Color(0xFF4A5568),
                ),
                const SizedBox(width: 16),
                _PostAction(
                  icon: Icons.chat_bubble_outline,
                  label: comments.toString(),
                  onTap: onCommentTap,
                ),
                const SizedBox(width: 16),
                _IconAction(
                  icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
                  onTap: onSaveTap,
                  color: isSaved ? Colors.black : const Color(0xFF4A5568),
                ),
                const Spacer(),
                InkWell(
                  onTap: onShareTap,
                  borderRadius: BorderRadius.circular(10),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.share_outlined,
                            color: Color(0xFF4A5568), size: 22),
                        SizedBox(width: 7),
                        Text(
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
  final bool isSelected;
  final VoidCallback? onTap;

  const _TagPill(this.label, {this.isSelected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : const Color(0xFFECEFF3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF4A5568),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _PostAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;
  final Color textColor;

  const _PostAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = const Color(0xFF4A5568),
    this.textColor = const Color(0xFF4A5568),
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _IconAction({
    required this.icon,
    required this.onTap,
    this.color = const Color(0xFF4A5568),
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Icon(
          icon,
          color: color,
          size: 22,
        ),
      ),
    );
  }
}

class _FriendsPanel extends StatefulWidget {
  final ValueChanged<_RunInviteFriend>? onInviteTap;
  final ValueChanged<_RunInviteFriend>? onMessageTap;

  const _FriendsPanel({super.key, this.onInviteTap, this.onMessageTap});

  @override
  State<_FriendsPanel> createState() => _FriendsPanelState();
}

class _FriendsPanelState extends State<_FriendsPanel> {
  int _selectedTab = 0;
  final List<_RunInviteFriend> _friends = [
    const _RunInviteFriend(
      initial: 'S',
      name: 'Sarah Chen',
      runsTogether: 12,
      streak: 5,
      lastRun: '2024-03-02',
    ),
    const _RunInviteFriend(
      initial: 'M',
      name: 'Mike Johnson',
      runsTogether: 8,
      streak: 3,
      lastRun: '2024-03-01',
    ),
    const _RunInviteFriend(
      initial: 'J',
      name: 'Jordan Lee',
      runsTogether: 15,
      streak: 7,
      lastRun: '2024-03-03',
    ),
  ];
  final List<_FriendRequest> _requests = [
    const _FriendRequest(initial: 'A', name: 'Alex Rivera'),
  ];
  final List<_FriendRequest> _pendingRequests = [
    const _FriendRequest(initial: 'E', name: 'Emma Wilson'),
  ];
  final List<_FriendSuggestion> _suggestions = [
    const _FriendSuggestion(
        initial: 'T', name: 'Taylor Swift', mutualFriends: 3),
    const _FriendSuggestion(
        initial: 'C', name: 'Chris Evans', mutualFriends: 2),
    const _FriendSuggestion(
        initial: 'O', name: 'Olivia Brown', mutualFriends: 5),
  ];

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _acceptRequest(_FriendRequest request) {
    setState(() {
      _requests.removeWhere((item) => item.name == request.name);
      _friends.add(
        _RunInviteFriend(
          initial: request.initial,
          name: request.name,
          runsTogether: 0,
          streak: 0,
          lastRun: 'Not yet',
        ),
      );
    });
    _showMessage('${request.name} added to friends');
  }

  void _declineRequest(_FriendRequest request) {
    setState(() {
      _requests.removeWhere((item) => item.name == request.name);
    });
    _showMessage('${request.name} request declined');
  }

  void _cancelPending(_FriendRequest request) {
    setState(() {
      _pendingRequests.removeWhere((item) => item.name == request.name);
    });
    _showMessage('Canceled request to ${request.name}');
  }

  void _addSuggestion(_FriendSuggestion suggestion) {
    setState(() {
      _suggestions.removeWhere((item) => item.name == suggestion.name);
      _pendingRequests.add(
        _FriendRequest(initial: suggestion.initial, name: suggestion.name),
      );
      _selectedTab = 1;
    });
    _showMessage('Friend request sent to ${suggestion.name}');
  }

  void _removeFriend(_RunInviteFriend friend) {
    setState(() {
      _friends.removeWhere((item) => item.name == friend.name);
    });
    _showMessage('${friend.name} removed from friends');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        _FriendTabs(
          friendsCount: _friends.length,
          requestsCount: _requests.length + _pendingRequests.length,
          selectedIndex: _selectedTab,
          onChanged: (index) {
            setState(() {
              _selectedTab = index;
            });
          },
        ),
        const SizedBox(height: 20),
        if (_selectedTab == 0) ...[
          const _FriendSearchField(),
          const SizedBox(height: 14),
          _SectionLabel('YOUR RUNNING BUDDIES (${_friends.length})'),
          const SizedBox(height: 12),
          if (_friends.isEmpty)
            const _EmptyState(text: 'No running buddies yet.')
          else
            ...List.generate(_friends.length, (index) {
              final friend = _friends[index];
              return Padding(
                padding: EdgeInsets.only(
                    bottom: index == _friends.length - 1 ? 0 : 12),
                child: _RunningBuddyCard(
                  initial: friend.initial,
                  name: friend.name,
                  runsTogether: friend.runsTogether,
                  streak: friend.streak,
                  lastRun: friend.lastRun,
                  onInviteTap: widget.onInviteTap,
                  onMessageTap: widget.onMessageTap,
                  onRemoveTap: () => _removeFriend(friend),
                ),
              );
            }),
        ] else if (_selectedTab == 1) ...[
          _SectionLabel('FRIEND REQUESTS (${_requests.length})'),
          const SizedBox(height: 12),
          if (_requests.isEmpty)
            const _EmptyState(text: 'No new friend requests.')
          else
            ...List.generate(_requests.length, (index) {
              final request = _requests[index];
              return Padding(
                padding: EdgeInsets.only(
                    bottom: index == _requests.length - 1 ? 0 : 12),
                child: _FriendRequestCard(
                  request: request,
                  onAccept: () => _acceptRequest(request),
                  onDecline: () => _declineRequest(request),
                ),
              );
            }),
          const SizedBox(height: 18),
          _SectionLabel('PENDING (${_pendingRequests.length})'),
          const SizedBox(height: 12),
          if (_pendingRequests.isEmpty)
            const _EmptyState(text: 'No pending requests.')
          else
            ...List.generate(_pendingRequests.length, (index) {
              final request = _pendingRequests[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == _pendingRequests.length - 1 ? 0 : 12,
                ),
                child: _PendingFriendCard(
                  request: request,
                  onCancel: () => _cancelPending(request),
                ),
              );
            }),
        ] else ...[
          const _SectionLabel('PEOPLE YOU MAY KNOW'),
          const SizedBox(height: 12),
          if (_suggestions.isEmpty)
            const _EmptyState(text: 'No suggestions right now.')
          else
            ...List.generate(_suggestions.length, (index) {
              final suggestion = _suggestions[index];
              return Padding(
                padding: EdgeInsets.only(
                    bottom: index == _suggestions.length - 1 ? 0 : 12),
                child: _SuggestionCard(
                  initial: suggestion.initial,
                  name: suggestion.name,
                  mutualFriends: suggestion.mutualFriends,
                  onAdd: () => _addSuggestion(suggestion),
                ),
              );
            }),
        ],
      ],
    );
  }
}

class _FriendTabs extends StatelessWidget {
  final int friendsCount;
  final int requestsCount;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _FriendTabs({
    required this.friendsCount,
    required this.requestsCount,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _FriendTabButton(
            label: 'Friends\n($friendsCount)',
            isSelected: selectedIndex == 0,
            onTap: () => onChanged(0),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: _FriendTabButton(
            label: 'Requests',
            badge: requestsCount > 0 ? '$requestsCount' : null,
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
  final ValueChanged<_RunInviteFriend>? onInviteTap;
  final ValueChanged<_RunInviteFriend>? onMessageTap;
  final VoidCallback? onRemoveTap;

  const _RunningBuddyCard({
    required this.initial,
    required this.name,
    required this.runsTogether,
    required this.streak,
    required this.lastRun,
    this.onInviteTap,
    this.onMessageTap,
    this.onRemoveTap,
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
                      onTap: () {
                        onInviteTap?.call(
                          _RunInviteFriend(
                            initial: initial,
                            name: name,
                            runsTogether: runsTogether,
                            streak: streak,
                            lastRun: lastRun,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _SmallFriendButton(
                      label: 'Message',
                      icon: Icons.chat_bubble_outline,
                      onTap: () {
                        onMessageTap?.call(
                          _RunInviteFriend(
                            initial: initial,
                            name: name,
                            runsTogether: runsTogether,
                            streak: streak,
                            lastRun: lastRun,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _IconSquareButton(
            icon: Icons.person_remove_alt_1_outlined,
            onTap: onRemoveTap ?? () {},
          ),
        ],
      ),
    );
  }
}

class _RunInviteFriend {
  final String initial;
  final String name;
  final int runsTogether;
  final int streak;
  final String lastRun;

  const _RunInviteFriend({
    required this.initial,
    required this.name,
    required this.runsTogether,
    required this.streak,
    required this.lastRun,
  });
}

class _ChatEntry {
  final String? text;
  final _RunInvitation? invitation;
  final bool isMine;
  final String timestamp;

  const _ChatEntry({
    this.text,
    this.invitation,
    required this.isMine,
    required this.timestamp,
  });

  const _ChatEntry.invitation({
    required _RunInvitation invitation,
    required bool isMine,
    required String timestamp,
  }) : this(
          invitation: invitation,
          isMine: isMine,
          timestamp: timestamp,
        );

  _ChatEntry copyWith({
    String? text,
    _RunInvitation? invitation,
    bool? isMine,
    String? timestamp,
  }) {
    return _ChatEntry(
      text: text ?? this.text,
      invitation: invitation ?? this.invitation,
      isMine: isMine ?? this.isMine,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

enum _RunInvitationStatus { pending, accepted }

class _RunInvitation {
  final String date;
  final String time;
  final String notes;
  final _RunInvitationStatus status;

  const _RunInvitation({
    required this.date,
    required this.time,
    required this.notes,
    this.status = _RunInvitationStatus.pending,
  });

  _RunInvitation copyWith({
    String? date,
    String? time,
    String? notes,
    _RunInvitationStatus? status,
  }) {
    return _RunInvitation(
      date: date ?? this.date,
      time: time ?? this.time,
      notes: notes ?? this.notes,
      status: status ?? this.status,
    );
  }
}

class _InviteToRunPanel extends StatefulWidget {
  final _RunInviteFriend friend;
  final ValueChanged<_RunInvitation> onSendInvitation;

  const _InviteToRunPanel({
    super.key,
    required this.friend,
    required this.onSendInvitation,
  });

  @override
  State<_InviteToRunPanel> createState() => _InviteToRunPanelState();
}

class _InviteToRunPanelState extends State<_InviteToRunPanel> {
  static const List<String> _timeOptions = [
    '06:00 AM',
    '07:00 AM',
    '08:00 AM',
    '06:00 PM',
    '07:00 PM',
  ];

  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String? _selectedTime;

  @override
  void dispose() {
    _dateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(2026, 4, 27),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );

    if (pickedDate == null) return;

    final month = pickedDate.month.toString().padLeft(2, '0');
    final day = pickedDate.day.toString().padLeft(2, '0');
    setState(() {
      _dateController.text = '${pickedDate.year} / $month / $day';
    });
  }

  void _sendInvitation() {
    if (_dateController.text.trim().isEmpty || _selectedTime == null) return;

    final note = _notesController.text.trim();
    widget.onSendInvitation(
      _RunInvitation(
        date: _dateController.text.trim(),
        time: _selectedTime!,
        notes: note,
      ),
    );
    final summary = note.isEmpty
        ? 'Invitation sent to ${widget.friend.name}'
        : 'Invitation sent to ${widget.friend.name}: $note';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(summary)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSend =
        _dateController.text.trim().isNotEmpty && _selectedTime != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: _friendCardDecoration,
          child: Column(
            children: [
              Row(
                children: [
                  _DarkInitialAvatar(initial: widget.friend.initial),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.friend.name,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.friend.runsTogether} runs together',
                          style: _friendMetaStyle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  'Last run together: ${widget.friend.lastRun}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF4A5568),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _friendCardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Plan Your Run',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              const _InviteFieldLabel(
                icon: Icons.calendar_today_outlined,
                text: 'Select Date',
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _dateController,
                readOnly: true,
                onTap: _pickDate,
                decoration: InputDecoration(
                  hintText: '年 / 月 / 日',
                  suffixIcon: IconButton(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 20),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const _InviteFieldLabel(
                icon: Icons.access_time_outlined,
                text: 'Select Time',
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _timeOptions.map((time) {
                  final isSelected = _selectedTime == time;
                  return ChoiceChip(
                    label: Text(time),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _selectedTime = time;
                      });
                    },
                    labelStyle: TextStyle(
                      color:
                          isSelected ? Colors.white : const Color(0xFF4A5568),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                    selectedColor: Colors.black,
                    backgroundColor: const Color(0xFFF1F5F9),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Text(
                      _selectedTime ?? '--:--',
                      style: TextStyle(
                        color: _selectedTime == null
                            ? const Color(0xFF6B7280)
                            : Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.access_time_outlined, size: 18),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const _InviteFieldLabel(
                icon: Icons.edit_note_outlined,
                text: 'Additional Notes (Optional)',
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText:
                      'Add any details about pace,\ndistance, or meeting instructions...',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: canSend ? _sendInvitation : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8A8A8A),
                    disabledBackgroundColor: const Color(0xFFBDBDBD),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.send_outlined, size: 18),
                  label: const Text(
                    'Send Invitation',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FriendChatPanel extends StatefulWidget {
  final _RunInviteFriend friend;
  final List<_ChatEntry> messages;
  final ValueChanged<String> onSendMessage;
  final ValueChanged<int> onAcceptInvitation;

  const _FriendChatPanel({
    super.key,
    required this.friend,
    required this.messages,
    required this.onSendMessage,
    required this.onAcceptInvitation,
  });

  @override
  State<_FriendChatPanel> createState() => _FriendChatPanelState();
}

class _FriendChatPanelState extends State<_FriendChatPanel> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSendMessage(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: _friendCardDecoration,
                child: Row(
                  children: [
                    _DarkInitialAvatar(initial: widget.friend.initial),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.friend.name,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.friend.runsTogether} runs together',
                            style: _friendMetaStyle,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...widget.messages.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Align(
                        alignment: entry.value.isMine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 280),
                          child: entry.value.invitation != null
                              ? _InvitationMessageBubble(
                                  invitation: entry.value.invitation!,
                                  isMine: entry.value.isMine,
                                  timestamp: entry.value.timestamp,
                                  onAccept: () =>
                                      widget.onAcceptInvitation(entry.key),
                                )
                              : _TextMessageBubble(
                                  text: entry.value.text ?? '',
                                  isMine: entry.value.isMine,
                                  timestamp: entry.value.timestamp,
                                ),
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Write a message...',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (context, value, child) {
                    return ElevatedButton(
                      onPressed: value.text.trim().isEmpty ? null : _send,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        disabledBackgroundColor: const Color(0xFFD1D5DB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Icon(Icons.send_outlined, size: 18),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TextMessageBubble extends StatelessWidget {
  final String text;
  final bool isMine;
  final String timestamp;

  const _TextMessageBubble({
    required this.text,
    required this.isMine,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: isMine ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: isMine ? null : Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: TextStyle(
              color: isMine ? Colors.white : Colors.black,
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            timestamp,
            style: TextStyle(
              color: isMine ? Colors.white70 : const Color(0xFF6B7280),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InvitationMessageBubble extends StatelessWidget {
  final _RunInvitation invitation;
  final bool isMine;
  final String timestamp;
  final VoidCallback? onAccept;

  const _InvitationMessageBubble({
    required this.invitation,
    required this.isMine,
    required this.timestamp,
    this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isMine ? const Color(0xFFF3F4F6) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 16),
              SizedBox(width: 8),
              Text(
                'Run Invitation',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Date: ${invitation.date}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Time: ${invitation.time}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
            ),
          ),
          if (invitation.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              invitation.notes,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Color(0xFF4B5563),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            timestamp,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 10),
          if (!isMine && invitation.status == _RunInvitationStatus.pending)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: onAccept,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Accept',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            )
          else if (isMine && invitation.status == _RunInvitationStatus.pending)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Waiting for reply',
                style: TextStyle(
                  color: Color(0xFF4B5563),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Accepted',
                style: TextStyle(
                  color: Color(0xFF166534),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InviteFieldLabel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InviteFieldLabel({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF4A5568), size: 16),
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

class _FriendRequestCard extends StatelessWidget {
  final _FriendRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _FriendRequestCard({
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _friendCardDecoration,
      child: Row(
        children: [
          _DarkInitialAvatar(initial: request.initial),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.name,
                  style: const TextStyle(
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
                        onTap: onAccept,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _WideFriendButton(
                        label: 'Decline',
                        onTap: onDecline,
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
  final _FriendRequest request;
  final VoidCallback onCancel;

  const _PendingFriendCard({
    required this.request,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _friendCardDecoration,
      child: Row(
        children: [
          _DarkInitialAvatar(initial: request.initial),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.name,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Row(
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
            onTap: onCancel,
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
  final VoidCallback onAdd;

  const _SuggestionCard({
    required this.initial,
    required this.name,
    required this.mutualFriends,
    required this.onAdd,
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
            onTap: onAdd,
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
  final VoidCallback onTap;

  const _IconSquareButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 38,
      child: TextButton(
        onPressed: onTap,
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

class _FriendRequest {
  final String initial;
  final String name;

  const _FriendRequest({
    required this.initial,
    required this.name,
  });
}

class _FriendSuggestion {
  final String initial;
  final String name;
  final int mutualFriends;

  const _FriendSuggestion({
    required this.initial,
    required this.name,
    required this.mutualFriends,
  });
}

class _EmptyState extends StatelessWidget {
  final String text;

  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _friendCardDecoration,
      child: Text(text, style: _friendMetaStyle),
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
  final List<_MyGroup> _myGroups = [
    const _MyGroup(
      name: 'Morning Runners Club',
      description: 'Early birds who love sunrise jogs',
      members: 142,
      runs: 856,
      progressText: '32/50 runs',
      progress: 0.64,
      showCrown: true,
      showSettings: true,
    ),
    const _MyGroup(
      name: 'City Park Joggers',
      description: 'Weekly meetups at Central Park',
      members: 87,
      runs: 432,
      progressText: '32/30 runs',
      progress: 1,
    ),
  ];
  final List<_DiscoverGroup> _discoverGroups = [
    const _DiscoverGroup(
      name: 'Weekend Warriors',
      description: 'Saturday and Sunday jogging enthusiasts',
      members: 56,
      isPrivate: false,
    ),
    const _DiscoverGroup(
      name: 'Post-Work Runners',
      description: 'Evening jogs after work hours',
      members: 93,
      isPrivate: true,
    ),
  ];

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _viewGroup(String name) {
    _showMessage('Opened $name');
  }

  void _openGroupSettings(String name) {
    _showMessage('Opened settings for $name');
  }

  void _joinGroup(_DiscoverGroup group) {
    setState(() {
      _discoverGroups.removeWhere((item) => item.name == group.name);
      _myGroups.add(
        _MyGroup(
          name: group.name,
          description: group.description,
          members: group.members + 1,
          runs: 0,
          progressText: '0/20 runs',
          progress: 0,
        ),
      );
      _selectedTab = 0;
    });
    _showMessage('Joined ${group.name}');
  }

  void _requestGroup(_DiscoverGroup group) {
    setState(() {
      final index =
          _discoverGroups.indexWhere((item) => item.name == group.name);
      if (index != -1) {
        _discoverGroups[index] = _discoverGroups[index].copyWith(
          requestSent: true,
        );
      }
    });
    _showMessage('Request sent to ${group.name}');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: _GroupTabButton(
                label: 'My Groups (${_myGroups.length})',
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
        _SectionLabel(_selectedTab == 0
            ? 'YOUR GROUPS (${_myGroups.length})'
            : 'SUGGESTED GROUPS'),
        const SizedBox(height: 12),
        if (_selectedTab == 0) ...[
          if (_myGroups.isEmpty)
            const _EmptyState(text: 'No groups yet.')
          else
            ...List.generate(_myGroups.length, (index) {
              final group = _myGroups[index];
              return Padding(
                padding: EdgeInsets.only(
                    bottom: index == _myGroups.length - 1 ? 0 : 12),
                child: _GroupCard(
                  name: group.name,
                  description: group.description,
                  members: group.members,
                  runs: group.runs,
                  progressText: group.progressText,
                  progress: group.progress,
                  actionLabel: 'View Group',
                  showCrown: group.showCrown,
                  showSettings: group.showSettings,
                  onActionTap: () => _viewGroup(group.name),
                  onSettingsTap: group.showSettings
                      ? () => _openGroupSettings(group.name)
                      : null,
                ),
              );
            }),
        ] else ...[
          if (_discoverGroups.isEmpty)
            const _EmptyState(text: 'No suggested groups right now.')
          else
            ...List.generate(_discoverGroups.length, (index) {
              final group = _discoverGroups[index];
              return Padding(
                padding: EdgeInsets.only(
                    bottom: index == _discoverGroups.length - 1 ? 0 : 12),
                child: _SuggestedGroupCard(
                  name: group.name,
                  description: group.description,
                  members: group.members,
                  actionLabel: group.requestSent
                      ? 'Requested'
                      : (group.isPrivate ? 'Request to Join' : 'Join Group'),
                  isPrivate: group.isPrivate,
                  isDisabled: group.requestSent,
                  onTap: group.requestSent
                      ? null
                      : () => group.isPrivate
                          ? _requestGroup(group)
                          : _joinGroup(group),
                ),
              );
            }),
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
  final bool isDisabled;
  final VoidCallback? onTap;

  const _SuggestedGroupCard({
    required this.name,
    required this.description,
    required this.members,
    required this.actionLabel,
    required this.isPrivate,
    this.isDisabled = false,
    this.onTap,
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
              onPressed: isDisabled ? null : onTap,
              style: _friendButtonStyle(true).copyWith(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.disabled)) {
                    return const Color(0xFF9CA3AF);
                  }
                  return Colors.black;
                }),
                foregroundColor: WidgetStateProperty.all(Colors.white),
              ),
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
  final VoidCallback onActionTap;
  final VoidCallback? onSettingsTap;

  const _GroupCard({
    required this.name,
    required this.description,
    required this.members,
    required this.runs,
    required this.progressText,
    required this.progress,
    required this.actionLabel,
    required this.onActionTap,
    this.showCrown = false,
    this.showSettings = false,
    this.onSettingsTap,
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
                    onPressed: onActionTap,
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
                _IconSquareButton(
                  icon: Icons.settings_outlined,
                  onTap: onSettingsTap ?? () {},
                ),
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
  final VoidCallback onTap;

  const _CreateGroupButton({required this.onTap});

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
        onPressed: onTap,
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.add, color: Colors.white, size: 20),
        splashRadius: 18,
      ),
    );
  }
}

class _MyGroup {
  final String name;
  final String description;
  final int members;
  final int runs;
  final String progressText;
  final double progress;
  final bool showCrown;
  final bool showSettings;

  const _MyGroup({
    required this.name,
    required this.description,
    required this.members,
    required this.runs,
    required this.progressText,
    required this.progress,
    this.showCrown = false,
    this.showSettings = false,
  });
}

class _DiscoverGroup {
  final String name;
  final String description;
  final int members;
  final bool isPrivate;
  final bool requestSent;

  const _DiscoverGroup({
    required this.name,
    required this.description,
    required this.members,
    required this.isPrivate,
    this.requestSent = false,
  });

  _DiscoverGroup copyWith({
    String? name,
    String? description,
    int? members,
    bool? isPrivate,
    bool? requestSent,
  }) {
    return _DiscoverGroup(
      name: name ?? this.name,
      description: description ?? this.description,
      members: members ?? this.members,
      isPrivate: isPrivate ?? this.isPrivate,
      requestSent: requestSent ?? this.requestSent,
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
