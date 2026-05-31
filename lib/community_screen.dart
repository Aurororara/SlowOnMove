import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'services/user_session.dart';

const List<_RunInviteFriend> _sharedFriendsSeed = [
  _RunInviteFriend(
    initial: 'S',
    name: 'Sarah Chen',
    runsTogether: 12,
    streak: 5,
    lastRun: '2024-03-02',
  ),
  _RunInviteFriend(
    initial: 'M',
    name: 'Mike Johnson',
    runsTogether: 8,
    streak: 3,
    lastRun: '2024-03-01',
  ),
  _RunInviteFriend(
    initial: 'J',
    name: 'Jordan Lee',
    runsTogether: 15,
    streak: 7,
    lastRun: '2024-03-03',
  ),
];

const List<_GroupExerciseOption> _groupExerciseOptions = [
  _GroupExerciseOption(
    value: 'mixed',
    label: '超慢跑＋深蹲',
    icon: Icons.fitness_center,
  ),
  _GroupExerciseOption(
    value: 'slow_jogging',
    label: '超慢跑',
    icon: Icons.directions_run,
  ),
  _GroupExerciseOption(
    value: 'squat',
    label: '深蹲',
    icon: Icons.accessibility_new,
  ),
];

class CommunityScreen extends StatefulWidget {
  final CommunityStore store;

  const CommunityScreen({super.key, required this.store});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final GlobalKey<_GroupsPanelState> _groupsPanelKey =
      GlobalKey<_GroupsPanelState>();
  final TextEditingController _searchController = TextEditingController();
  final Map<String, Timer> _groupEventReminderTimers = {};
  final Map<String, List<_ChatEntry>> _friendChats = {
    'Sarah Chen': const [
      _ChatEntry(
        text: '這週想輕鬆跑恢復一下嗎？',
        isMine: false,
        timestamp: '9:12 AM',
      ),
      _ChatEntry(
        text: '好啊，早上對我最方便。',
        isMine: true,
        timestamp: '9:14 AM',
      ),
    ],
    'Mike Johnson': const [
      _ChatEntry(
        text: '第三週之後你的膝蓋感覺如何？',
        isMine: false,
        timestamp: '昨天',
      ),
    ],
    'Jordan Lee': const [],
  };
  bool _isComposerOpen = false;
  bool _isFriendsOpen = false;
  bool _isGroupsOpen = false;
  _RunInviteFriend? _inviteFriend;
  _RunInviteFriend? _chatFriend;

  List<CommunityPost> get _posts => widget.store.posts;
  String get _searchQuery => _searchController.text.trim().toLowerCase();

  List<({int index, CommunityPost post})> get _filteredPosts {
    if (_searchQuery.isEmpty) {
      return List.generate(
        _posts.length,
        (index) => (index: index, post: _posts[index]),
      );
    }

    return _posts
        .asMap()
        .entries
        .where((entry) {
          final post = entry.value;
          final tagsText = post.tags.join(' ').toLowerCase();
          final planText = post.plan == null
              ? ''
              : [
                  post.plan!.title,
                  post.plan!.summary,
                  post.plan!.difficulty,
                  ...post.plan!.steps.map((step) => step.name),
                ].join(' ').toLowerCase();
          final recipeText = post.recipe == null
              ? ''
              : [
                  post.recipe!.title,
                  post.recipe!.description,
                  ...post.recipe!.ingredients.map((item) => item.name),
                ].join(' ').toLowerCase();
          final searchableText = [
            post.name,
            post.content,
            tagsText,
            planText,
            recipeText,
          ].join(' ').toLowerCase();
          return searchableText.contains(_searchQuery);
        })
        .map((entry) => (index: entry.key, post: entry.value))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_handleStoreChanged);
    _searchController.addListener(_handleStoreChanged);
  }

  void _handleStoreChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    for (final timer in _groupEventReminderTimers.values) {
      timer.cancel();
    }
    widget.store.removeListener(_handleStoreChanged);
    _searchController
      ..removeListener(_handleStoreChanged)
      ..dispose();
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

  void _submitPost(_ComposerSubmission submission) {
    widget.store.addPost(
      initial: UserSession.displayInitial,
      name: UserSession.displayName,
      timeAgo: '剛剛',
      content: submission.content,
      tags: submission.tags,
      type: submission.type,
      plan: submission.plan,
      recipe: submission.recipe,
    );

    setState(() {
      _isComposerOpen = false;
    });

    FocusScope.of(context).unfocus();
  }

  _ComposerSubmission _submissionFromPost(CommunityPost post) {
    return _ComposerSubmission(
      type: post.type,
      content: post.content,
      tags: post.tags,
      plan: post.plan,
      recipe: post.recipe,
    );
  }

  Future<void> _editPost(int index) async {
    final post = _posts[index];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 48,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 18,
          ),
          child: SingleChildScrollView(
            child: _PostComposer(
              initialSubmission: _submissionFromPost(post),
              submitLabel: '儲存',
              onPost: (submission) {
                widget.store.updatePost(
                  index,
                  content: submission.content,
                  tags: submission.tags,
                  type: submission.type,
                  plan: submission.plan,
                  recipe: submission.recipe,
                );
                Navigator.of(sheetContext).pop();
              },
              onClose: () => Navigator.of(sheetContext).pop(),
            ),
          ),
        );
      },
    );
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

  void _openMyCommunityProfile() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityProfileScreen(store: widget.store),
      ),
    );
  }

  void _openAuthorCommunityProfile({
    required String initial,
    required String name,
  }) {
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityProfileScreen(
          store: widget.store,
          profileInitial: initial,
          profileName: name,
        ),
      ),
    );
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

  void _appendSystemChatMessage(_RunInviteFriend friend, String text) {
    final existing = _friendChats[friend.name] ?? const <_ChatEntry>[];
    setState(() {
      _friendChats[friend.name] = [
        ...existing,
        _ChatEntry(
          text: text,
          isMine: true,
          timestamp: '剛剛',
        ),
      ];
    });
  }

  DateTime? _parseGroupEventDateTime(String date, String time) {
    final RegExp datePattern = RegExp(r'^(\d{4})\s*/\s*(\d{2})\s*/\s*(\d{2})$');
    final RegExp timePattern = RegExp(r'^(\d{2}):(\d{2})\s*(AM|PM)$');

    final dateMatch = datePattern.firstMatch(date.trim());
    final timeMatch = timePattern.firstMatch(time.trim());

    if (dateMatch == null || timeMatch == null) {
      return null;
    }

    final year = int.parse(dateMatch.group(1)!);
    final month = int.parse(dateMatch.group(2)!);
    final day = int.parse(dateMatch.group(3)!);
    int hour = int.parse(timeMatch.group(1)!);
    final minute = int.parse(timeMatch.group(2)!);
    final period = timeMatch.group(3)!;

    if (period == 'PM' && hour != 12) {
      hour += 12;
    } else if (period == 'AM' && hour == 12) {
      hour = 0;
    }

    return DateTime(year, month, day, hour, minute);
  }

  void _scheduleGroupEventReminder(
    _MyGroup group,
    String title,
    String date,
    String time,
    String activityLabel,
  ) {
    final eventDateTime = _parseGroupEventDateTime(date, time);
    if (eventDateTime == null) return;

    final reminderTime = eventDateTime.subtract(const Duration(minutes: 30));
    final now = DateTime.now();
    final timerKey = '${group.name}|$title|$date|$time';

    void sendReminder() {
      final membersToNotify =
          group.memberPreview.where((member) => member.canMessage).toList();

      for (final member in membersToNotify) {
        _appendSystemChatMessage(
          _RunInviteFriend(
            initial: member.initial,
            name: member.name,
            runsTogether: member.totalRuns,
            streak: member.runsThisWeek,
            lastRun: '群組聊天',
          ),
          '${_GroupsPanelState._currentUserName} 提醒你：'
          '群組活動「$title」將於 30 分鐘後開始'
          '（$activityLabel・$time）。',
        );
      }

      _groupEventReminderTimers.remove(timerKey)?.cancel();
    }

    if (!eventDateTime.isAfter(now)) {
      return;
    }

    if (!reminderTime.isAfter(now)) {
      sendReminder();
      return;
    }

    _groupEventReminderTimers[timerKey]?.cancel();
    _groupEventReminderTimers[timerKey] =
        Timer(reminderTime.difference(now), sendReminder);
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
          text: '接受！${invitation.date} ${invitation.time} 見。',
          isMine: false,
          timestamp: '剛剛',
        ),
      ];
    });
  }

  void _toggleLike(int index) {
    widget.store.toggleLike(index);
  }

  void _toggleSave(int index) {
    final isSaving = !_posts[index].isSaved;
    widget.store.toggleSave(index);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isSaving ? '已加入我的珍藏' : '已從我的珍藏移除'),
        duration: const Duration(seconds: 2),
      ),
    );
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

              widget.store.addComment(index, text);
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
                      '留言',
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
                          '目前還沒有留言。開始對話吧。',
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
                                          '社群成員',
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
                              hintText: '寫下留言...',
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
                                '送出',
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
    final isOwnPost = post.name == UserSession.displayName;
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
                if (isOwnPost)
                  ListTile(
                    leading:
                        const Icon(Icons.edit_outlined, color: Colors.black),
                    title: const Text('編輯貼文'),
                    subtitle: const Text('更新你的內容與詳細資訊'),
                    onTap: () {
                      Navigator.pop(context);
                      _editPost(index);
                    },
                  ),
                if (isOwnPost) const Divider(height: 1),
                ListTile(
                  leading:
                      const Icon(Icons.flag_outlined, color: Colors.redAccent),
                  title: Text('檢舉 ${post.name} 的貼文'),
                  subtitle: const Text('標記這則貼文以供審查'),
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
      '詐騙或欺詐',
      '性騷擾',
      '霸凌或騷擾',
      '仇恨言論',
      '暴力或危險行為',
      '不實的健康資訊',
      '垃圾訊息',
      '其他',
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
                    '你為何要檢舉 $authorName 的貼文？',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '選擇最符合此內容的理由。',
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
                          SnackBar(content: Text('檢舉已提交：$reason')),
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
      ('複製連結', Icons.link_outlined),
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
                  '分享至',
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
                        SnackBar(content: Text('已分享至 ${target.$1}')),
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
      appBar: _isGroupsOpen ? null : _buildAppBar(context),
      body: SafeArea(
        top: !_isGroupsOpen,
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
                            timestamp: '剛剛',
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
                                timestamp: '剛剛',
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
                            ? _GroupsPanel(
                                key: _groupsPanelKey,
                                onBack: _closeSecondaryPage,
                                onMessageTap: _openChat,
                                onSystemMessage: _appendSystemChatMessage,
                                onScheduleEventReminder:
                                    _scheduleGroupEventReminder,
                              )
                            : ListView(
                                key: const ValueKey('community-feed'),
                                padding:
                                    const EdgeInsets.fromLTRB(18, 14, 18, 24),
                                children: [
                                  _SearchField(
                                    controller: _searchController,
                                    onClear: _searchQuery.isEmpty
                                        ? null
                                        : () => _searchController.clear(),
                                  ),
                                  const SizedBox(height: 14),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 220),
                                    switchInCurve: Curves.easeOutCubic,
                                    switchOutCurve: Curves.easeInCubic,
                                    child: _isComposerOpen
                                        ? _PostComposer(
                                            key:
                                                const ValueKey('composer-open'),
                                            onPost: _submitPost,
                                            onClose: _closeComposer,
                                          )
                                        : _CreatePostCard(
                                            key: const ValueKey(
                                                'composer-closed'),
                                            onTap: _openComposer,
                                            onProfileTap:
                                                _openMyCommunityProfile,
                                          ),
                                  ),
                                  const SizedBox(height: 18),
                                  const _SectionLabel('社群動態'),
                                  const SizedBox(height: 12),
                                  if (_filteredPosts.isEmpty)
                                    const _EmptyState(
                                      text: '找不到符合關鍵字的貼文。',
                                    )
                                  else
                                    ...List.generate(_filteredPosts.length,
                                        (visibleIndex) {
                                      final matched =
                                          _filteredPosts[visibleIndex];
                                      final index = matched.index;
                                      final post = matched.post;
                                      return Padding(
                                        padding: EdgeInsets.only(
                                          bottom: visibleIndex ==
                                                  _filteredPosts.length - 1
                                              ? 0
                                              : 14,
                                        ),
                                        child: _PostCard(
                                          onMoreTap: () => _showPostMenu(index),
                                          onLikeTap: () => _toggleLike(index),
                                          onCommentTap: () =>
                                              _openComments(index),
                                          onSaveTap: () => _toggleSave(index),
                                          onShareTap: () =>
                                              _showShareSheet(index),
                                          onProfileTap: () =>
                                              _openAuthorCommunityProfile(
                                            initial: post.initial,
                                            name: post.name,
                                          ),
                                          initial: post.initial,
                                          name: post.name,
                                          timeAgo: post.timeAgo,
                                          content: post.content,
                                          tags: post.tags,
                                          type: post.type,
                                          plan: post.plan,
                                          recipe: post.recipe,
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
                    '返回',
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
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: Color(0xFFE2E8F0),
                child: Icon(Icons.directions_run,
                    size: 14, color: Color(0xFF4A5568)),
              ),
            ],
          ),
          const Spacer(),
          if (_chatFriend != null || _inviteFriend != null)
            const SizedBox(width: 56)
          else if (_isGroupsOpen)
            _CreateGroupButton(
              onTap: () {
                _groupsPanelKey.currentState?.openCreateGroup();
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
  final TextEditingController controller;
  final VoidCallback? onClear;

  const _SearchField({
    required this.controller,
    this.onClear,
  });

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
      child: Row(
        children: [
          const Icon(Icons.search, color: Color(0xFFA0AEC0), size: 23),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: '搜尋貼文、人物或標籤...',
                hintStyle: TextStyle(
                  color: Color(0xFF718096),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          if (onClear != null)
            InkWell(
              onTap: onClear,
              borderRadius: BorderRadius.circular(999),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, color: Color(0xFFA0AEC0), size: 18),
              ),
            ),
        ],
      ),
    );
  }
}

class _CreatePostCard extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback onProfileTap;

  const _CreatePostCard({
    super.key,
    required this.onTap,
    required this.onProfileTap,
  });

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
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onProfileTap,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: _Avatar(initial: UserSession.displayInitial),
                ),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Text(
                  '分享你的慢跑心得...',
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

enum _ComposerMode { journey, plan, recipe }

class _ComposerSubmission {
  final CommunityPostType type;
  final String content;
  final List<String> tags;
  final WorkoutPlanData? plan;
  final RecipeData? recipe;

  const _ComposerSubmission({
    required this.type,
    required this.content,
    required this.tags,
    this.plan,
    this.recipe,
  });
}

class _PostComposer extends StatefulWidget {
  final _ComposerSubmission? initialSubmission;
  final String submitLabel;
  final ValueChanged<_ComposerSubmission> onPost;
  final VoidCallback onClose;

  const _PostComposer({
    super.key,
    this.initialSubmission,
    this.submitLabel = '發佈',
    required this.onPost,
    required this.onClose,
  });

  @override
  State<_PostComposer> createState() => _PostComposerState();
}

class _PostComposerState extends State<_PostComposer> {
  static const List<String> _tags = [
    '#晨跑',
    '#零疼痛',
    '#超慢跑挑戰',
    '#健康習慣',
    '#運動目標',
    '#進步比完美更重要',
    '#慢跑日常',
    '#覺察式運動',
  ];

  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _planTitleController = TextEditingController();
  final TextEditingController _planSummaryController = TextEditingController();
  final TextEditingController _recipeTitleController = TextEditingController();
  final TextEditingController _recipeDescriptionController =
      TextEditingController();
  final TextEditingController _recipeCookMinutesController =
      TextEditingController();
  final Set<String> _selectedTags = <String>{};
  final List<_EditablePlanStep> _planSteps = [
    _EditablePlanStep(),
    _EditablePlanStep(),
    _EditablePlanStep(),
  ];
  final List<_EditableRecipeIngredient> _recipeIngredients = [
    _EditableRecipeIngredient(),
    _EditableRecipeIngredient(),
  ];

  _ComposerMode _mode = _ComposerMode.journey;
  String _planDifficulty = '中等';

  @override
  void initState() {
    super.initState();
    _applyInitialSubmission();
  }

  void _applyInitialSubmission() {
    final submission = widget.initialSubmission;
    if (submission == null) return;

    _contentController.text = submission.content;
    _selectedTags.addAll(submission.tags);

    switch (submission.type) {
      case CommunityPostType.journey:
        _mode = _ComposerMode.journey;
        break;
      case CommunityPostType.plan:
        _mode = _ComposerMode.plan;
        final plan = submission.plan;
        if (plan != null) {
          _planTitleController.text = plan.title;
          _planSummaryController.text = plan.summary;
          _planDifficulty = plan.difficulty;
          for (final step in _planSteps) {
            step.dispose();
          }
          _planSteps
            ..clear()
            ..addAll(
              plan.steps.map((step) {
                final editable = _EditablePlanStep();
                editable.name.text = step.name;
                editable.minutes.text = step.minutes.toString();
                return editable;
              }),
            );
        }
        break;
      case CommunityPostType.recipe:
        _mode = _ComposerMode.journey;
        break;
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    _planTitleController.dispose();
    _planSummaryController.dispose();
    _recipeTitleController.dispose();
    _recipeDescriptionController.dispose();
    _recipeCookMinutesController.dispose();
    for (final step in _planSteps) {
      step.dispose();
    }
    for (final ingredient in _recipeIngredients) {
      ingredient.dispose();
    }
    super.dispose();
  }

  String get _title {
    switch (_mode) {
      case _ComposerMode.journey:
        return '分享你的旅程';
      case _ComposerMode.plan:
        return '分享你的計畫';
      case _ComposerMode.recipe:
        return '分享你的食譜';
    }
  }

  String get _hintText {
    switch (_mode) {
      case _ComposerMode.journey:
        return '分享你的超慢跑經驗、\n健康秘訣或成就...';
      case _ComposerMode.plan:
        return '描述此訓練計畫的幫助，\n例如耐力、恢復或姿勢...';
      case _ComposerMode.recipe:
        return '告訴大家這份食譜對你的好處，\n例如跑前能量補充或跑後恢復...';
    }
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  void _addPlanStep() {
    setState(() {
      _planSteps.add(_EditablePlanStep());
    });
  }

  void _removePlanStep(int index) {
    if (_planSteps.length <= 1) return;
    setState(() {
      final removed = _planSteps.removeAt(index);
      removed.dispose();
    });
  }

  void _addRecipeIngredient() {
    setState(() {
      _recipeIngredients.add(_EditableRecipeIngredient());
    });
  }

  void _removeRecipeIngredient(int index) {
    if (_recipeIngredients.length <= 1) return;
    setState(() {
      final removed = _recipeIngredients.removeAt(index);
      removed.dispose();
    });
  }

  bool get _canSubmit {
    switch (_mode) {
      case _ComposerMode.journey:
        return _contentController.text.trim().isNotEmpty;
      case _ComposerMode.plan:
        return _contentController.text.trim().isNotEmpty &&
            _planTitleController.text.trim().isNotEmpty &&
            _validPlanSteps.isNotEmpty;
      case _ComposerMode.recipe:
        return _contentController.text.trim().isNotEmpty &&
            _recipeTitleController.text.trim().isNotEmpty &&
            _validRecipeIngredients.isNotEmpty;
    }
  }

  List<WorkoutPlanStep> get _validPlanSteps => _planSteps
      .map((step) => step.toPlanStep())
      .whereType<WorkoutPlanStep>()
      .toList(growable: false);

  List<RecipeIngredient> get _validRecipeIngredients => _recipeIngredients
      .map((ingredient) => ingredient.toRecipeIngredient())
      .whereType<RecipeIngredient>()
      .toList(growable: false);

  void _submit() {
    if (!_canSubmit) return;

    final detectedTags = RegExp(r'#\w+')
        .allMatches(_contentController.text.trim())
        .map((match) => match.group(0)!)
        .toList();
    final tags = <String>{..._selectedTags, ...detectedTags}.toList();

    if (_mode == _ComposerMode.plan) {
      final steps = _validPlanSteps;
      final totalMinutes =
          steps.fold<int>(0, (sum, step) => sum + step.minutes);
      widget.onPost(
        _ComposerSubmission(
          type: CommunityPostType.plan,
          content: _contentController.text.trim(),
          tags: tags,
          plan: WorkoutPlanData(
            title: _planTitleController.text.trim(),
            summary: _planSummaryController.text.trim().isEmpty
                ? _contentController.text.trim()
                : _planSummaryController.text.trim(),
            difficulty: _planDifficulty,
            totalMinutes: totalMinutes,
            steps: steps,
          ),
        ),
      );
      return;
    }

    if (_mode == _ComposerMode.recipe) {
      final ingredients = _validRecipeIngredients;
      final nutrition = _calculateNutrition(ingredients);
      widget.onPost(
        _ComposerSubmission(
          type: CommunityPostType.recipe,
          content: _contentController.text.trim(),
          tags: tags,
          recipe: RecipeData(
            title: _recipeTitleController.text.trim(),
            description: _recipeDescriptionController.text.trim(),
            cookMinutes:
                int.tryParse(_recipeCookMinutesController.text.trim()) ?? 0,
            ingredients: ingredients,
            nutrition: nutrition,
          ),
        ),
      );
      return;
    }

    widget.onPost(
      _ComposerSubmission(
        type: CommunityPostType.journey,
        content: _contentController.text.trim(),
        tags: tags,
      ),
    );
  }

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
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _contentController,
          _planTitleController,
          _planSummaryController,
          _recipeTitleController,
          _recipeDescriptionController,
          _recipeCookMinutesController,
          ..._planSteps.expand((step) => [step.name, step.minutes]),
          ..._recipeIngredients.expand((item) => [item.name, item.grams]),
        ]),
        builder: (context, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _ComposerModeSwitcher(
                          selectedMode: _mode,
                          onChanged: (mode) {
                            setState(() {
                              _mode = mode;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onClose,
                    visualDensity: VisualDensity.compact,
                    splashRadius: 20,
                    icon:
                        const Icon(Icons.close, color: Colors.black, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contentController,
                minLines: 2,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: _composerInputDecoration(_hintText),
              ),
              if (_mode == _ComposerMode.plan) ...[
                const SizedBox(height: 14),
                const _ComposerFieldLabel(
                  icon: Icons.route_outlined,
                  text: '計畫詳情',
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _planTitleController,
                  decoration: _composerInputDecoration('計畫標題，例如：4週友善膝蓋計畫'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _planSummaryController,
                  maxLines: 2,
                  decoration: _composerInputDecoration(
                    '簡短的計畫摘要或目標',
                  ),
                ),
                const SizedBox(height: 10),
                _DifficultyPicker(
                  value: _planDifficulty,
                  onChanged: (value) {
                    setState(() {
                      _planDifficulty = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                ...List.generate(_planSteps.length, (index) {
                  final step = _planSteps[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == _planSteps.length - 1 ? 0 : 10,
                    ),
                    child: _PlanStepEditor(
                      index: index,
                      step: step,
                      onRemove: () => _removePlanStep(index),
                    ),
                  );
                }),
                const SizedBox(height: 10),
                _SecondaryActionButton(
                  icon: Icons.add,
                  label: '新增步驟',
                  onTap: _addPlanStep,
                ),
              ],
              if (_mode == _ComposerMode.recipe) ...[
                const SizedBox(height: 14),
                const _ComposerFieldLabel(
                  icon: Icons.restaurant_menu_outlined,
                  text: '食譜詳情',
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _recipeTitleController,
                  decoration: _composerInputDecoration('食譜標題，例如：跑後高蛋白餐'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _recipeDescriptionController,
                  minLines: 2,
                  maxLines: 3,
                  textInputAction: TextInputAction.newline,
                  decoration: _composerInputDecoration(
                    '食譜描述（顯示在食譜卡片內）',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _recipeCookMinutesController,
                  keyboardType: TextInputType.number,
                  decoration: _composerInputDecoration('烹調時間（分鐘）'),
                ),
                const SizedBox(height: 12),
                ...List.generate(_recipeIngredients.length, (index) {
                  final ingredient = _recipeIngredients[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == _recipeIngredients.length - 1 ? 0 : 10,
                    ),
                    child: _RecipeIngredientEditor(
                      ingredient: ingredient,
                      onRemove: () => _removeRecipeIngredient(index),
                    ),
                  );
                }),
                const SizedBox(height: 10),
                _SecondaryActionButton(
                  icon: Icons.add,
                  label: '新增食材',
                  onTap: _addRecipeIngredient,
                ),
                const SizedBox(height: 12),
                _RecipeNutritionPreview(
                  nutrition: _calculateNutrition(_validRecipeIngredients),
                ),
              ],
              if (_mode != _ComposerMode.recipe) ...[
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Icon(Icons.add_circle_outline,
                        color: Color(0xFF718096), size: 16),
                    SizedBox(width: 6),
                    Text(
                      '新增標籤',
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
                          isSelected: _selectedTags.contains(tag),
                          onTap: () => _toggleTag(tag),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 18),
              ] else
                const SizedBox(height: 18),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: Icon(
                      _mode == _ComposerMode.recipe
                          ? Icons.calculate_outlined
                          : Icons.auto_awesome_outlined,
                      size: 18,
                    ),
                    label: Text(
                      _mode == _ComposerMode.recipe ? '自動計算營養' : '結構化貼文',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _canSubmit ? _submit : null,
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
                    label: Text(
                      widget.submitLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

InputDecoration _composerInputDecoration(String hintText) {
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

class _ComposerModeSwitcher extends StatelessWidget {
  final _ComposerMode selectedMode;
  final ValueChanged<_ComposerMode> onChanged;

  const _ComposerModeSwitcher({
    required this.selectedMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ModeChip(
          label: '旅程',
          isSelected: selectedMode == _ComposerMode.journey,
          onTap: () => onChanged(_ComposerMode.journey),
        ),
        _ModeChip(
          label: '計畫',
          isSelected: selectedMode == _ComposerMode.plan,
          onTap: () => onChanged(_ComposerMode.plan),
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '分享你的$label',
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF4A5568),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ComposerFieldLabel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ComposerFieldLabel({
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

class _SecondaryActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SecondaryActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.black,
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _DifficultyPicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _DifficultyPicker({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const options = ['簡單', '中等', '進階'];
    return Row(
      children: options
          .map(
            (option) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(option),
                selected: value == option,
                onSelected: (_) => onChanged(option),
                labelStyle: TextStyle(
                  color: value == option ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w700,
                ),
                selectedColor: Colors.black,
                backgroundColor: const Color(0xFFF1F5F9),
                side: BorderSide.none,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _EditablePlanStep {
  final TextEditingController name = TextEditingController();
  final TextEditingController minutes = TextEditingController();

  WorkoutPlanStep? toPlanStep() {
    final stepName = name.text.trim();
    final stepMinutes = int.tryParse(minutes.text.trim()) ?? 0;
    if (stepName.isEmpty || stepMinutes <= 0) return null;
    return WorkoutPlanStep(
      name: stepName,
      minutes: stepMinutes,
    );
  }

  void dispose() {
    name.dispose();
    minutes.dispose();
  }
}

class _PlanStepEditor extends StatelessWidget {
  final int index;
  final _EditablePlanStep step;
  final VoidCallback onRemove;

  const _PlanStepEditor({
    required this.index,
    required this.step,
    required this.onRemove,
  });

  Future<void> _pickMinutes(BuildContext context) async {
    final currentMinutes = int.tryParse(step.minutes.text.trim()) ?? 10;
    final initialMinutes = currentMinutes.clamp(1, 180);
    var selectedMinutes = initialMinutes;
    final pickerController =
        FixedExtentScrollController(initialItem: initialMinutes - 1);

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: SizedBox(
            height: 300,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text('取消'),
                      ),
                      const Spacer(),
                      const Text(
                        '選擇分鐘數',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          step.minutes.text = selectedMinutes.toString();
                          Navigator.of(sheetContext).pop();
                        },
                        child: const Text('完成'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    scrollController: pickerController,
                    itemExtent: 40,
                    useMagnifier: true,
                    magnification: 1.08,
                    onSelectedItemChanged: (value) {
                      selectedMinutes = value + 1;
                    },
                    children: List.generate(
                      180,
                      (index) => Center(
                        child: Text(
                          '${index + 1} 分鐘',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFFE8F0FF),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: step.name,
                  decoration: _composerInputDecoration('動作名稱'),
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => _pickMinutes(context),
            borderRadius: BorderRadius.circular(16),
            child: IgnorePointer(
              child: TextField(
                controller: step.minutes,
                decoration: _composerInputDecoration('分鐘數'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableRecipeIngredient {
  final TextEditingController name = TextEditingController();
  final TextEditingController grams = TextEditingController();

  RecipeIngredient? toRecipeIngredient() {
    final ingredientName = name.text.trim();
    final ingredientGrams = double.tryParse(grams.text.trim()) ?? 0;
    if (ingredientName.isEmpty || ingredientGrams <= 0) return null;
    return RecipeIngredient(name: ingredientName, grams: ingredientGrams);
  }

  void dispose() {
    name.dispose();
    grams.dispose();
  }
}

class _RecipeIngredientEditor extends StatelessWidget {
  final _EditableRecipeIngredient ingredient;
  final VoidCallback onRemove;

  const _RecipeIngredientEditor({
    required this.ingredient,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: ingredient.name,
              decoration: _composerInputDecoration('食材名稱'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: TextField(
              controller: ingredient.grams,
              keyboardType: TextInputType.number,
              decoration: _composerInputDecoration('克數'),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline, size: 18),
          ),
        ],
      ),
    );
  }
}

class _RecipeNutritionPreview extends StatelessWidget {
  final NutritionSummary nutrition;

  const _RecipeNutritionPreview({required this.nutrition});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC7DCFF)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _NutritionPill(label: '${nutrition.calories} 大卡'),
          _NutritionPill(label: '${nutrition.carbs.toStringAsFixed(1)}g 碳水'),
          _NutritionPill(label: '${nutrition.protein.toStringAsFixed(1)}g 蛋白質'),
          _NutritionPill(label: '${nutrition.fat.toStringAsFixed(1)}g 脂肪'),
        ],
      ),
    );
  }
}

class _NutritionPill extends StatelessWidget {
  final String label;

  const _NutritionPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF2563EB),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

const Map<String, NutritionSummary> _ingredientNutritionPer100g = {
  'chicken breast':
      NutritionSummary(calories: 165, carbs: 0, protein: 31, fat: 3.6),
  'egg': NutritionSummary(calories: 155, carbs: 1.1, protein: 13, fat: 11),
  'rice': NutritionSummary(calories: 130, carbs: 28.2, protein: 2.7, fat: 0.3),
  'oats': NutritionSummary(calories: 389, carbs: 66.3, protein: 16.9, fat: 6.9),
  'banana': NutritionSummary(calories: 89, carbs: 22.8, protein: 1.1, fat: 0.3),
  'broccoli':
      NutritionSummary(calories: 35, carbs: 7.2, protein: 2.4, fat: 0.4),
  'salmon': NutritionSummary(calories: 208, carbs: 0, protein: 20, fat: 13),
  'tofu': NutritionSummary(calories: 76, carbs: 1.9, protein: 8, fat: 4.8),
  'milk': NutritionSummary(calories: 42, carbs: 5, protein: 3.4, fat: 1),
  'greek yogurt':
      NutritionSummary(calories: 59, carbs: 3.6, protein: 10, fat: 0.4),
  'avocado': NutritionSummary(calories: 160, carbs: 8.5, protein: 2, fat: 14.7),
};

NutritionSummary _calculateNutrition(List<RecipeIngredient> ingredients) {
  double totalCalories = 0;
  double totalCarbs = 0;
  double totalProtein = 0;
  double totalFat = 0;

  for (final ingredient in ingredients) {
    final match = _ingredientNutritionPer100g.entries
        .firstWhere(
          (entry) =>
              ingredient.name.toLowerCase().contains(entry.key) ||
              entry.key.contains(ingredient.name.toLowerCase()),
          orElse: () => const MapEntry(
            '',
            NutritionSummary(calories: 0, carbs: 0, protein: 0, fat: 0),
          ),
        )
        .value;
    final multiplier = ingredient.grams / 100;
    totalCalories += match.calories * multiplier;
    totalCarbs += match.carbs * multiplier;
    totalProtein += match.protein * multiplier;
    totalFat += match.fat * multiplier;
  }

  return NutritionSummary(
    calories: totalCalories.round(),
    carbs: totalCarbs,
    protein: totalProtein,
    fat: totalFat,
  );
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
  final VoidCallback onProfileTap;
  final String initial;
  final String name;
  final String timeAgo;
  final String content;
  final List<String> tags;
  final CommunityPostType type;
  final WorkoutPlanData? plan;
  final RecipeData? recipe;
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
    required this.onProfileTap,
    required this.initial,
    required this.name,
    required this.timeAgo,
    required this.content,
    required this.tags,
    required this.type,
    required this.plan,
    required this.recipe,
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
                InkWell(
                  onTap: onProfileTap,
                  borderRadius: BorderRadius.circular(999),
                  child: _Avatar(initial: initial),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: onProfileTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
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
          if (type == CommunityPostType.plan && plan != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: _WorkoutPlanCard(plan: plan!),
            ),
          if (type == CommunityPostType.recipe && recipe != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: _RecipeCard(recipe: recipe!),
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
                          '分享',
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

class _WorkoutPlanCard extends StatelessWidget {
  final WorkoutPlanData plan;

  const _WorkoutPlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7FF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFC7DCFF), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.fitness_center,
                color: Color(0xFF2563EB),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  plan.title,
                  style: const TextStyle(
                    color: Color(0xFF1D4ED8),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            plan.summary,
            style: const TextStyle(
              color: Color(0xFF2563EB),
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(plan.steps.length, (index) {
            final step = plan.steps[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == plan.steps.length - 1 ? 0 : 10,
              ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFFE8F0FF),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.name,
                            style: const TextStyle(
                              color: Color(0xFF1F2937),
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${step.minutes} 分鐘',
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _PlanMetricPill(
                icon: Icons.schedule_outlined,
                label: '${plan.totalMinutes} 分鐘',
              ),
              _PlanMetricPill(
                icon: Icons.local_fire_department_outlined,
                label: plan.difficulty,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanMetricPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PlanMetricPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF2563EB)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF2563EB),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final RecipeData recipe;

  const _RecipeCard({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF3),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF3D69A), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.restaurant_menu,
                  color: Color(0xFFD97706), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  recipe.title,
                  style: const TextStyle(
                    color: Color(0xFFB45309),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (recipe.description.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              recipe.description,
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '食材',
                  style: TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                ...recipe.ingredients.map(
                  (ingredient) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.circle,
                            size: 7, color: Color(0xFFD97706)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ingredient.name,
                            style: const TextStyle(
                              color: Color(0xFF374151),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${ingredient.grams.toStringAsFixed(0)} 克',
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _RecipeMetricPill(label: '${recipe.cookMinutes} 分鐘'),
              _RecipeMetricPill(label: '${recipe.nutrition.calories} 大卡'),
              _RecipeMetricPill(
                  label: '${recipe.nutrition.protein.toStringAsFixed(1)}g 蛋白質'),
              _RecipeMetricPill(
                  label: '${recipe.nutrition.carbs.toStringAsFixed(1)}g 碳水'),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecipeMetricPill extends StatelessWidget {
  final String label;

  const _RecipeMetricPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFB45309),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
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
  final List<_RunInviteFriend> _friends = List<_RunInviteFriend>.from(
    _sharedFriendsSeed,
  );
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
          lastRun: '尚未一起運動',
        ),
      );
    });
    _showMessage('已將 ${request.name} 加為好友');
  }

  void _declineRequest(_FriendRequest request) {
    setState(() {
      _requests.removeWhere((item) => item.name == request.name);
    });
    _showMessage('已拒絕 ${request.name} 的好友請求');
  }

  void _cancelPending(_FriendRequest request) {
    setState(() {
      _pendingRequests.removeWhere((item) => item.name == request.name);
    });
    _showMessage('已取消對 ${request.name} 的好友邀請');
  }

  void _addSuggestion(_FriendSuggestion suggestion) {
    setState(() {
      _suggestions.removeWhere((item) => item.name == suggestion.name);
      _pendingRequests.add(
        _FriendRequest(initial: suggestion.initial, name: suggestion.name),
      );
    });
    _showMessage('已送出好友邀請給 ${suggestion.name}');
  }

  void _removeFriend(_RunInviteFriend friend) {
    setState(() {
      _friends.removeWhere((item) => item.name == friend.name);
    });
    _showMessage('已將 ${friend.name} 從好友移除');
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
          _SectionLabel('你的運動好友 (${_friends.length})'),
          const SizedBox(height: 12),
          if (_friends.isEmpty)
            const _EmptyState(text: '目前還沒有運動好友。')
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
          _SectionLabel('好友請求 (${_requests.length})'),
          const SizedBox(height: 12),
          if (_requests.isEmpty)
            const _EmptyState(text: '目前沒有新的好友請求。')
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
          _SectionLabel('待處理 (${_pendingRequests.length})'),
          const SizedBox(height: 12),
          if (_pendingRequests.isEmpty)
            const _EmptyState(text: '目前沒有待處理請求。')
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
          const _SectionLabel('你可能認識的人'),
          const SizedBox(height: 12),
          if (_suggestions.isEmpty)
            const _EmptyState(text: '目前沒有推薦對象。')
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
            label: '好友\n($friendsCount)',
            isSelected: selectedIndex == 0,
            onTap: () => onChanged(0),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: _FriendTabButton(
            label: '請求',
            badge: requestsCount > 0 ? '$requestsCount' : null,
            isSelected: selectedIndex == 1,
            onTap: () => onChanged(1),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: _FriendTabButton(
            label: '建議',
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
              '搜尋好友...',
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
                      '一起運動 $runsTogether 次',
                      style: _friendMetaStyle,
                    ),
                    const SizedBox(width: 18),
                    const Icon(Icons.emoji_events_outlined,
                        color: Color(0xFFD69E2E), size: 14),
                    const SizedBox(width: 4),
                    Text('連續 $streak 天', style: _friendMetaStyle),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        color: Color(0xFF718096), size: 14),
                    const SizedBox(width: 5),
                    Text('最後一次跑步：$lastRun', style: _friendMetaStyle),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _SmallFriendButton(
                      label: '邀請\n跑步',
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
                      label: '訊息',
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
        ? '已送出邀請給 ${widget.friend.name}'
        : '已送出邀請給 ${widget.friend.name}：$note';

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
                          '一起運動 ${widget.friend.runsTogether} 次',
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
                  '最近一次一起運動：${widget.friend.lastRun}',
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
                '安排這次活動',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              const _InviteFieldLabel(
                icon: Icons.calendar_today_outlined,
                text: '選擇日期',
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
                text: '選擇時間',
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
                text: '額外備註（選填）',
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: '補充配速、距離\n或集合說明...',
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
                    '送出邀請',
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
                            '一起運動 ${widget.friend.runsTogether} 次',
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
                      hintText: '寫下訊息...',
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
                '跑步邀請',
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
            '日期：${invitation.date}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '時間：${invitation.time}',
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
                  '接受',
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
                '等待對方回覆',
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
                '已接受',
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
                  '想與你成為好友',
                  style: _friendMetaStyle,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _WideFriendButton(
                        label: '接受',
                        icon: Icons.check,
                        isPrimary: true,
                        onTap: onAccept,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _WideFriendButton(
                        label: '拒絕',
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
                    Text('請求待處理', style: _friendMetaStyle),
                  ],
                ),
              ],
            ),
          ),
          _WideFriendButton(
            label: '取消',
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
            label: '新增',
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

class _GoalAdjustButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GoalAdjustButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xFFF1F5F9),
          foregroundColor: Colors.black,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Icon(icon, size: 20),
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

String _groupMetricUnit(String exerciseType) {
  switch (exerciseType) {
    case 'mixed':
      return '次活動';
    case 'squat':
      return '次深蹲';
    case 'slow_jogging':
    default:
      return '次慢跑';
  }
}

String _groupMetricLabel(String exerciseType, int value) {
  return '$value ${_groupMetricUnit(exerciseType)}';
}

String _groupWeeklyGoalLabel(
  String exerciseType,
  int current,
  int target,
) {
  return '$current/$target ${_groupMetricUnit(exerciseType)}';
}

class _GroupsPanel extends StatefulWidget {
  final VoidCallback onBack;
  final ValueChanged<_RunInviteFriend> onMessageTap;
  final void Function(_RunInviteFriend friend, String message) onSystemMessage;
  final void Function(
    _MyGroup group,
    String title,
    String date,
    String time,
    String activityLabel,
  ) onScheduleEventReminder;

  const _GroupsPanel({
    super.key,
    required this.onBack,
    required this.onMessageTap,
    required this.onSystemMessage,
    required this.onScheduleEventReminder,
  });

  @override
  State<_GroupsPanel> createState() => _GroupsPanelState();
}

class _GroupsPanelState extends State<_GroupsPanel> {
  static const String _currentUserName = 'Catherine';
  static const int _maxGroupMembers = 30;
  int _selectedTab = 0;
  bool _isCreateGroupOpen = false;
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _groupDescriptionController =
      TextEditingController();
  bool _createPrivateGroup = false;
  final List<_RunInviteFriend> _availableInviteFriends =
      List<_RunInviteFriend>.from(_sharedFriendsSeed);
  final List<_MyGroup> _myGroups = [
    const _MyGroup(
      ownerName: 'Lamei',
      ownerInitial: 'L',
      name: 'Morning Runners Club',
      description: '喜歡日出慢跑的晨跑夥伴',
      members: 24,
      runs: 856,
      weeklyGoalCurrent: 32,
      weeklyGoalTarget: 50,
      progressText: '32/50 次慢跑',
      progress: 0.64,
      isPrivate: false,
      exerciseType: 'slow_jogging',
      showCrown: true,
      showSettings: true,
      memberPreview: [
        _GroupMember(
          initial: 'L',
          name: 'Lamei',
          badge: '👑',
          totalRuns: 145,
          runsThisWeek: 5,
          totalSquats: 82,
          squatsThisWeek: 3,
          joinedDate: '2024/1/15',
          canMessage: false,
        ),
        _GroupMember(
          initial: 'A',
          name: 'Sarah Chen',
          totalRuns: 98,
          runsThisWeek: 4,
          totalSquats: 54,
          squatsThisWeek: 2,
          joinedDate: '2024/1/20',
        ),
        _GroupMember(
          initial: 'M',
          name: 'Mike Johnson',
          totalRuns: 87,
          runsThisWeek: 3,
          totalSquats: 41,
          squatsThisWeek: 1,
          joinedDate: '2024/2/1',
        ),
        _GroupMember(
          initial: 'E',
          name: 'Emma Wilson',
          totalRuns: 112,
          runsThisWeek: 6,
          totalSquats: 67,
          squatsThisWeek: 4,
          joinedDate: '2024/1/25',
        ),
      ],
      activities: [
        _GroupActivityEntry(
          title: '日出跑步',
          subtitle: '6名成員參加了今天的早晨活動',
          timestamp: '今天',
        ),
        _GroupActivityEntry(
          title: '每週目標更新',
          subtitle: '本週群組達成32次跑步',
          timestamp: '2h ago',
        ),
      ],
    ),
    const _MyGroup(
      ownerName: 'Catherine',
      ownerInitial: 'C',
      name: 'City Park Joggers',
      description: '每週固定相約一起運動',
      members: 18,
      runs: 432,
      weeklyGoalCurrent: 32,
      weeklyGoalTarget: 30,
      progressText: '32/30 次慢跑',
      progress: 1,
      isPrivate: false,
      exerciseType: 'slow_jogging',
      memberPreview: [
        _GroupMember(
          initial: 'C',
          name: 'Catherine',
          totalRuns: 67,
          runsThisWeek: 4,
          totalSquats: 36,
          squatsThisWeek: 2,
          joinedDate: '2024/2/12',
        ),
        _GroupMember(
          initial: 'R',
          name: 'Ryan',
          totalRuns: 80,
          runsThisWeek: 5,
          totalSquats: 45,
          squatsThisWeek: 3,
          joinedDate: '2024/1/20',
        ),
      ],
      activities: [
        _GroupActivityEntry(
          title: '中央公園集合',
          subtitle: '週六跑步活動開放報名中',
          timestamp: '昨天',
        ),
      ],
    ),
  ];
  final List<_DiscoverGroup> _discoverGroups = [
    const _DiscoverGroup(
      name: 'Weekend Warriors',
      description: '週末一起運動的活力夥伴',
      members: 20,
      isPrivate: false,
    ),
    const _DiscoverGroup(
      name: 'Post-Work Runners',
      description: '下班後一起動一動的夜跑群',
      members: 22,
      isPrivate: true,
    ),
  ];

  @override
  void dispose() {
    _groupNameController.dispose();
    _groupDescriptionController.dispose();
    super.dispose();
  }

  void openCreateGroup() {
    setState(() {
      _isCreateGroupOpen = true;
      _selectedTab = 0;
    });
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _closeCreateGroup() {
    setState(() {
      _isCreateGroupOpen = false;
      _groupNameController.clear();
      _groupDescriptionController.clear();
      _createPrivateGroup = false;
    });
  }

  void _createGroup() {
    final name = _groupNameController.text.trim();
    final description = _groupDescriptionController.text.trim();
    if (name.isEmpty || description.isEmpty) {
      return;
    }

    setState(() {
      _myGroups.insert(
        0,
        _MyGroup(
          ownerName: _currentUserName,
          ownerInitial: 'C',
          name: name,
          description: description,
          members: 1,
          runs: 0,
          weeklyGoalCurrent: 0,
          weeklyGoalTarget: 20,
          progressText: '0/20 次活動',
          progress: 0,
          isPrivate: _createPrivateGroup,
          exerciseType: 'mixed',
          memberPreview: const [
            _GroupMember(
              initial: 'C',
              name: 'Catherine',
              totalRuns: 0,
              runsThisWeek: 0,
              totalSquats: 0,
              squatsThisWeek: 0,
              joinedDate: '今天',
              canMessage: false,
            ),
          ],
          activities: const [
            _GroupActivityEntry(
              title: '群組已建立',
              subtitle: '歡迎來到你的新運動群組',
              timestamp: '剛剛',
            ),
          ],
        ),
      );
      if (!_createPrivateGroup) {
        _discoverGroups.insert(
          0,
          _DiscoverGroup(
            name: name,
            description: description,
            members: 1,
            isPrivate: false,
            joined: true,
            exerciseType: 'mixed',
          ),
        );
      }
      _selectedTab = 0;
    });

    _closeCreateGroup();
    _showMessage('已建立群組「$name」');
  }

  void _viewGroup(_MyGroup group) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _GroupDetailScreen(
          group: group,
          onGroupUpdated: _updateGroup,
          onMessageTap: widget.onMessageTap,
          inviteableFriends: _availableInviteFriends,
          onInviteFriend: _inviteFriendToGroup,
          onRequestInvite: _requestFriendForGroup,
          onLeaveGroup: () => _leaveGroup(group),
          onScheduleEventReminder: widget.onScheduleEventReminder,
        ),
      ),
    );
  }

  void _updateGroup(_MyGroup updatedGroup) {
    setState(() {
      final index =
          _myGroups.indexWhere((item) => item.name == updatedGroup.name);
      if (index != -1) {
        _myGroups[index] = updatedGroup;
      }

      final discoverIndex =
          _discoverGroups.indexWhere((item) => item.name == updatedGroup.name);
      if (discoverIndex != -1) {
        _discoverGroups[discoverIndex] =
            _discoverGroups[discoverIndex].copyWith(
          exerciseType: updatedGroup.exerciseType,
        );
      }
    });
  }

  void _leaveGroup(_MyGroup group) {
    setState(() {
      _myGroups.removeWhere((item) => item.name == group.name);

      final discoverIndex =
          _discoverGroups.indexWhere((item) => item.name == group.name);
      if (discoverIndex != -1) {
        final discoverGroup = _discoverGroups[discoverIndex];
        _discoverGroups[discoverIndex] = discoverGroup.copyWith(
          joined: false,
          requestSent: false,
          members: (discoverGroup.members - 1).clamp(0, _maxGroupMembers),
        );
      }
    });

    _showMessage('你已退出 ${group.name}');
  }

  _MyGroup _inviteFriendToGroup(_MyGroup group, _RunInviteFriend friend) {
    if (group.members >= _maxGroupMembers) {
      _showMessage('${group.name} 已達 30 人上限');
      return group;
    }

    final updatedGroup = group.copyWith(
      members: (group.members + 1).clamp(0, _maxGroupMembers),
      memberPreview: [
        ...group.memberPreview,
        _GroupMember(
          initial: friend.initial,
          name: friend.name,
          totalRuns: friend.runsTogether,
          runsThisWeek: friend.streak,
          totalSquats: 0,
          squatsThisWeek: 0,
          joinedDate: '今天',
        ),
      ],
      activities: [
        _GroupActivityEntry(
          title: '${friend.name} 加入了群組',
          subtitle: '由 $_currentUserName 邀請',
          timestamp: '剛剛',
        ),
        ...group.activities,
      ],
    );

    setState(() {
      final index = _myGroups.indexWhere((item) => item.name == group.name);
      if (index != -1) {
        _myGroups[index] = updatedGroup;
      }
      final discoverIndex =
          _discoverGroups.indexWhere((item) => item.name == group.name);
      if (discoverIndex != -1) {
        _discoverGroups[discoverIndex] =
            _discoverGroups[discoverIndex].copyWith(
          members: (_discoverGroups[discoverIndex].members + 1)
              .clamp(0, _maxGroupMembers),
        );
      }
    });

    widget.onSystemMessage(
      friend,
      '$_currentUserName invited you to join "${group.name}".',
    );
    _showMessage('${friend.name} 已加入 ${group.name}');
    return updatedGroup;
  }

  void _requestFriendForGroup(_MyGroup group, _RunInviteFriend friend) {
    final ownerThread = _RunInviteFriend(
      initial: group.ownerInitial,
      name: group.ownerName,
      runsTogether: 0,
      streak: 0,
      lastRun: '群組聊天',
    );

    widget.onSystemMessage(
      ownerThread,
      '$_currentUserName requested to add ${friend.name} to "${group.name}". Please review this member invite request.',
    );
    _showMessage('已送出邀請請求給 ${group.ownerName}');
  }

  void _openGroupSettings(String name) {
    _showMessage('已開啟 $name 的設定');
  }

  void _joinGroup(_DiscoverGroup group) {
    if (group.members >= _maxGroupMembers) {
      _showMessage('${group.name} 已達 30 人上限');
      return;
    }

    setState(() {
      _myGroups.add(
        _MyGroup(
          ownerName: '群組管理員',
          ownerInitial: 'G',
          name: group.name,
          description: group.description,
          members: group.members + 1,
          runs: 0,
          weeklyGoalCurrent: 0,
          weeklyGoalTarget: 20,
          progressText: '0/20 activities',
          progress: 0,
          isPrivate: group.isPrivate,
          exerciseType: group.exerciseType,
          memberPreview: const [
            _GroupMember(
              initial: 'Y',
              name: '你',
              totalRuns: 0,
              runsThisWeek: 0,
              totalSquats: 0,
              squatsThisWeek: 0,
              joinedDate: '今天',
              canMessage: false,
            ),
          ],
          activities: const [
            _GroupActivityEntry(
              title: '歡迎加入群組',
              subtitle: '你的會員資格已建立',
              timestamp: '剛剛',
            ),
          ],
        ),
      );
      final discoverIndex =
          _discoverGroups.indexWhere((item) => item.name == group.name);
      if (discoverIndex != -1) {
        _discoverGroups[discoverIndex] =
            _discoverGroups[discoverIndex].copyWith(
          joined: true,
          members: (group.members + 1).clamp(0, _maxGroupMembers),
        );
      }
      _selectedTab = 0;
    });
    _showMessage('已加入 ${group.name}');
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
    _showMessage('已送出加入 ${group.name} 的請求');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: widget.onBack,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chevron_left,
                        size: 24, color: Color(0xFF4A5568)),
                    SizedBox(width: 2),
                    Text(
                      '返回',
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
            const CircleAvatar(
              radius: 12,
              backgroundColor: Color(0xFFE2E8F0),
              child: Icon(Icons.directions_run,
                  size: 14, color: Color(0xFF4A5568)),
            ),
            const Spacer(),
            _CreateGroupButton(
              onTap: openCreateGroup,
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Row(
          children: [
            Expanded(
              child: _GroupSearchField(),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _GroupTabButton(
                label: '我的群組 (${_myGroups.length})',
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
                label: '探索',
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
        if (_isCreateGroupOpen) ...[
          const SizedBox(height: 14),
          _CreateGroupForm(
            nameController: _groupNameController,
            descriptionController: _groupDescriptionController,
            isPrivate: _createPrivateGroup,
            onPrivacyChanged: (value) {
              setState(() {
                _createPrivateGroup = value;
              });
            },
            onClose: _closeCreateGroup,
            onCreate: _createGroup,
          ),
        ],
        const SizedBox(height: 14),
        _SectionLabel(
            _selectedTab == 0 ? '我的群組 (${_myGroups.length})' : '推薦群組'),
        const SizedBox(height: 12),
        if (_selectedTab == 0) ...[
          if (_myGroups.isEmpty)
            const _EmptyState(text: '目前還沒有群組。')
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
                  weeklyGoalCurrent: group.weeklyGoalCurrent,
                  weeklyGoalTarget: group.weeklyGoalTarget,
                  progress: group.progress,
                  actionLabel: '查看群組',
                  isPrivate: group.isPrivate,
                  exerciseType: group.exerciseType,
                  showCrown: group.showCrown,
                  showSettings: group.showSettings,
                  onActionTap: () => _viewGroup(group),
                  onSettingsTap: group.showSettings
                      ? () => _openGroupSettings(group.name)
                      : null,
                ),
              );
            }),
        ] else ...[
          if (_discoverGroups.isEmpty)
            const _EmptyState(text: '目前沒有推薦群組。')
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
                  actionLabel: group.joined
                      ? '已加入'
                      : group.requestSent
                          ? '已申請'
                          : (group.isPrivate ? '申請加入' : '加入群組'),
                  isPrivate: group.isPrivate,
                  isDisabled: group.joined || group.requestSent,
                  onTap: group.joined || group.requestSent
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
              '搜尋群組...',
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

class _CreateGroupForm extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final bool isPrivate;
  final ValueChanged<bool> onPrivacyChanged;
  final VoidCallback onClose;
  final VoidCallback onCreate;

  const _CreateGroupForm({
    required this.nameController,
    required this.descriptionController,
    required this.isPrivate,
    required this.onPrivacyChanged,
    required this.onClose,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final canCreate = nameController.text.trim().isNotEmpty &&
        descriptionController.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '建立新群組',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
              InkWell(
                onTap: onClose,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            '群組名稱',
            style: TextStyle(
              color: Color(0xFF4A5568),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: nameController,
            decoration: InputDecoration(
              hintText: '例如：週末勇士',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            onChanged: (_) => (context as Element).markNeedsBuild(),
          ),
          const SizedBox(height: 14),
          const Text(
            '群組描述',
            style: TextStyle(
              color: Color(0xFF4A5568),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: descriptionController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: '你的群組是關於什麼的？',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            onChanged: (_) => (context as Element).markNeedsBuild(),
          ),
          const SizedBox(height: 14),
          const Text(
            '群組權限',
            style: TextStyle(
              color: Color(0xFF4A5568),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _GroupPrivacyCard(
                  title: '公開',
                  subtitle: '任何人皆可加入',
                  icon: Icons.public,
                  isSelected: !isPrivate,
                  onTap: () => onPrivacyChanged(false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GroupPrivacyCard(
                  title: '私密',
                  subtitle: '僅限邀請',
                  icon: Icons.lock_outline,
                  isSelected: isPrivate,
                  onTap: () => onPrivacyChanged(true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              children: [
                Icon(Icons.groups_2_outlined, color: Colors.black, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '群組建立後可自由進行超慢跑或深蹲活動，最多 30 人。',
                    style: TextStyle(
                      color: Color(0xFF4A5568),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: TextButton(
              onPressed: canCreate ? onCreate : null,
              style: TextButton.styleFrom(
                backgroundColor:
                    canCreate ? Colors.black : const Color(0xFF9CA3AF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                '建立群組',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupPrivacyCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _GroupPrivacyCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.black : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.black, size: 22),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF718096),
              ),
            ),
          ],
        ),
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
                        Text('$members/30 人', style: _friendMetaStyle),
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
  final int weeklyGoalCurrent;
  final int weeklyGoalTarget;
  final double progress;
  final String actionLabel;
  final bool isPrivate;
  final String exerciseType;
  final bool showCrown;
  final bool showSettings;
  final VoidCallback onActionTap;
  final VoidCallback? onSettingsTap;

  const _GroupCard({
    required this.name,
    required this.description,
    required this.members,
    required this.runs,
    required this.weeklyGoalCurrent,
    required this.weeklyGoalTarget,
    required this.progress,
    required this.actionLabel,
    this.isPrivate = false,
    this.exerciseType = 'slow_jogging',
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
                        Icon(
                          isPrivate ? Icons.lock_outline : Icons.public,
                          color: const Color(0xFF718096),
                          size: 15,
                        ),
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
                        Text('$members/30 人', style: _friendMetaStyle),
                        const SizedBox(width: 12),
                        const Icon(Icons.trending_up,
                            color: Color(0xFF718096), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          _groupMetricLabel(exerciseType, runs),
                          style: _friendMetaStyle,
                        ),
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
                      '每週目標',
                      style: TextStyle(
                        color: Color(0xFF4A5568),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _groupWeeklyGoalLabel(
                        exerciseType,
                        weeklyGoalCurrent,
                        weeklyGoalTarget,
                      ),
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

class _GroupDetailScreen extends StatefulWidget {
  final _MyGroup group;
  final ValueChanged<_MyGroup> onGroupUpdated;
  final void Function(
    _MyGroup group,
    String title,
    String date,
    String time,
    String activityLabel,
  ) onScheduleEventReminder;
  final ValueChanged<_RunInviteFriend> onMessageTap;
  final List<_RunInviteFriend> inviteableFriends;
  final _MyGroup Function(_MyGroup group, _RunInviteFriend friend)
      onInviteFriend;
  final void Function(_MyGroup group, _RunInviteFriend friend) onRequestInvite;
  final VoidCallback onLeaveGroup;

  const _GroupDetailScreen({
    required this.group,
    required this.onGroupUpdated,
    required this.onScheduleEventReminder,
    required this.onMessageTap,
    required this.inviteableFriends,
    required this.onInviteFriend,
    required this.onRequestInvite,
    required this.onLeaveGroup,
  });

  @override
  State<_GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<_GroupDetailScreen> {
  static const int _maxGroupMembers = 30;
  int _selectedTab = 0;
  late _MyGroup _group;
  bool _isCreateEventOpen = false;
  final TextEditingController _eventTitleController = TextEditingController();
  final TextEditingController _eventDateController = TextEditingController();
  final TextEditingController _eventNotesController = TextEditingController();
  String _selectedEventActivityType = 'slow_jogging';
  String? _selectedEventTime;

  static const List<String> _eventTimeOptions = [
    '06:00 AM',
    '07:00 AM',
    '08:00 AM',
    '06:00 PM',
    '07:00 PM',
  ];

  @override
  void initState() {
    super.initState();
    _group = widget.group;
  }

  @override
  void dispose() {
    _eventTitleController.dispose();
    _eventDateController.dispose();
    _eventNotesController.dispose();
    super.dispose();
  }

  bool get _isOwner => _group.ownerName == _GroupsPanelState._currentUserName;
  bool get _canDirectInvite => _isOwner || !_group.isPrivate;

  Future<void> _handleLeaveGroup() async {
    final bool? shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('退出群組'),
          content: Text('確定要退出「${_group.name}」嗎？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('退出'),
            ),
          ],
        );
      },
    );

    if (shouldLeave != true || !mounted) {
      return;
    }

    widget.onLeaveGroup();
    Navigator.of(context).pop();
  }

  Future<void> _pickEventDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(2026, 5, 10),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );

    if (pickedDate == null) {
      return;
    }

    final month = pickedDate.month.toString().padLeft(2, '0');
    final day = pickedDate.day.toString().padLeft(2, '0');
    setState(() {
      _eventDateController.text = '${pickedDate.year} / $month / $day';
    });
  }

  void _toggleCreateEvent() {
    setState(() {
      _isCreateEventOpen = !_isCreateEventOpen;
    });
  }

  Future<void> _openWeeklyGoalSheet() async {
    int selectedTarget = _group.weeklyGoalTarget.clamp(1, 999);

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '設定每週目標',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '設定這個群組每週想完成的${_groupMetricUnit(_group.exerciseType)}。',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _GoalAdjustButton(
                          icon: Icons.remove,
                          onTap: () {
                            setSheetState(() {
                              selectedTarget =
                                  (selectedTarget - 1).clamp(1, 999);
                            });
                          },
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '$selectedTarget',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _groupMetricUnit(_group.exerciseType),
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _GoalAdjustButton(
                          icon: Icons.add,
                          onTap: () {
                            setSheetState(() {
                              selectedTarget =
                                  (selectedTarget + 1).clamp(1, 999);
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final current = _group.weeklyGoalCurrent;
                          final progress =
                              (current / selectedTarget).clamp(0.0, 1.0);
                          final updatedGroup = _group.copyWith(
                            weeklyGoalTarget: selectedTarget,
                            progressText: _groupWeeklyGoalLabel(
                              _group.exerciseType,
                              current,
                              selectedTarget,
                            ),
                            progress: progress,
                          );

                          setState(() {
                            _group = updatedGroup;
                          });
                          widget.onGroupUpdated(updatedGroup);
                          Navigator.of(sheetContext).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已更新每週目標')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          '儲存目標',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _submitGroupRunEvent() {
    final title = _eventTitleController.text.trim();
    final date = _eventDateController.text.trim();
    final time = _selectedEventTime;
    final activityLabel = _groupExerciseOptions
        .firstWhere((option) => option.value == _selectedEventActivityType)
        .label;

    if (title.isEmpty || date.isEmpty || time == null) {
      return;
    }

    setState(() {
      _group = _group.copyWith(
        exerciseType: _selectedEventActivityType,
        activities: [
          _GroupActivityEntry(
            title: title,
            subtitle: '$activityLabel • $date • $time',
            timestamp: '剛剛',
          ),
          ..._group.activities,
        ],
      );
      _isCreateEventOpen = false;
      _eventTitleController.clear();
      _eventDateController.clear();
      _eventNotesController.clear();
      _selectedEventActivityType = 'slow_jogging';
      _selectedEventTime = null;
      _selectedTab = 1;
    });

    widget.onGroupUpdated(_group);
    widget.onScheduleEventReminder(_group, title, date, time, activityLabel);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已建立群組活動：$title')),
    );
  }

  Future<void> _openInviteSheet() async {
    if (_group.members >= _maxGroupMembers) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('此群組已達 30 人上限')),
      );
      return;
    }

    if (widget.inviteableFriends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('目前沒有可邀請的好友')),
      );
      return;
    }

    final selected = await showModalBottomSheet<_RunInviteFriend>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _canDirectInvite ? '邀請你的好友' : '請求新成員加入',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _canDirectInvite
                      ? '只有你的好友可以直接受邀加入此群組。'
                      : '只能推薦你自己的好友，且必須先由群組擁有者核准。',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                ...widget.inviteableFriends.map(
                  (friend) {
                    final alreadyInGroup = _group.memberPreview.any(
                      (member) => member.name == friend.name,
                    );

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: _DarkInitialAvatar(initial: friend.initial),
                      title: Text(
                        friend.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: alreadyInGroup
                              ? const Color(0xFF94A3B8)
                              : Colors.black,
                        ),
                      ),
                      subtitle: Text(
                        alreadyInGroup
                            ? '已在群組中'
                            : '一起運動 ${friend.runsTogether} 次',
                        style: TextStyle(
                          color: alreadyInGroup
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: Icon(
                        alreadyInGroup
                            ? Icons.check_circle_outline
                            : Icons.chevron_right_rounded,
                        color: alreadyInGroup
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF111827),
                      ),
                      onTap: alreadyInGroup
                          ? null
                          : () => Navigator.of(context).pop(friend),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null) {
      return;
    }

    if (_canDirectInvite) {
      final updated = widget.onInviteFriend(_group, selected);
      setState(() {
        _group = updated;
      });
    } else {
      widget.onRequestInvite(_group, selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    final percentRemaining =
        ((1 - group.progress.clamp(0.0, 1.0)) * 100).round().clamp(0, 100);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: Color(0xFF4A5568)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '群組',
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 17,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu_rounded, color: Color(0xFF4A5568)),
            onSelected: (value) {
              if (value == 'invite') {
                _openInviteSheet();
              } else if (value == 'leave') {
                _handleLeaveGroup();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'invite',
                child: Text(_canDirectInvite ? '邀請好友進群組' : '請求邀請成員'),
              ),
              const PopupMenuItem<String>(
                value: 'leave',
                child: Text('退出群組'),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: _friendCardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.groups_2_outlined,
                            color: Colors.white, size: 31),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    group.name,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                                if (group.showCrown)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 6),
                                    child: Text('👑',
                                        style: TextStyle(fontSize: 14)),
                                  ),
                                Icon(
                                  group.isPrivate
                                      ? Icons.lock_outline
                                      : Icons.public,
                                  color: const Color(0xFF94A3B8),
                                  size: 16,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              group.description,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _GroupStatTile(
                          label: '成員',
                          value: '${group.members}',
                          icon: Icons.people_outline,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _GroupStatTile(
                          label:
                              group.exerciseType == 'squat' ? '總深蹲次數' : '總跑步次數',
                          value:
                              _groupMetricLabel(group.exerciseType, group.runs),
                          icon: Icons.trending_up,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.emoji_events_outlined,
                                size: 15, color: Color(0xFFD69E2E)),
                            const SizedBox(width: 6),
                            const Text(
                              '每週目標',
                              style: TextStyle(
                                color: Color(0xFF475569),
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: _openWeeklyGoalSheet,
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF64748B),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                minimumSize: Size.zero,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                              ),
                              icon: const Icon(Icons.edit_outlined, size: 15),
                              label: const Text(
                                '設定',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _groupWeeklyGoalLabel(
                                group.exerciseType,
                                group.weeklyGoalCurrent,
                                group.weeklyGoalTarget,
                              ),
                              style: const TextStyle(
                                color: Color(0xFF111827),
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: group.progress.clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.black),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            '$percentRemaining% to go',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _GroupTabButton(
                    label: '成員 (${group.memberPreview.length})',
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
                    label: '活動',
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
            const SizedBox(height: 14),
            SizedBox(
              height: 46,
              child: TextButton.icon(
                onPressed: _toggleCreateEvent,
                style: _friendButtonStyle(true),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(
                  _isCreateEventOpen ? '隱藏群組活動表單' : '建立群組活動',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            if (_isCreateEventOpen) ...[
              const SizedBox(height: 12),
              _CreateGroupRunEventForm(
                titleController: _eventTitleController,
                dateController: _eventDateController,
                notesController: _eventNotesController,
                selectedActivityType: _selectedEventActivityType,
                selectedTime: _selectedEventTime,
                timeOptions: _eventTimeOptions,
                onPickDate: _pickEventDate,
                onActivityTypeSelected: (value) {
                  setState(() {
                    _selectedEventActivityType = value;
                  });
                },
                onTimeSelected: (time) {
                  setState(() {
                    _selectedEventTime = time;
                  });
                },
                onCreate: _submitGroupRunEvent,
              ),
            ],
            const SizedBox(height: 14),
            if (_selectedTab == 0) ...[
              if (group.memberPreview.isEmpty)
                const _EmptyState(text: '目前沒有成員可顯示。')
              else
                ...group.memberPreview.map(
                  (member) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _GroupMemberCard(
                      member: member,
                      onMessageTap: member.canMessage
                          ? () => widget.onMessageTap(
                                _RunInviteFriend(
                                  initial: member.initial,
                                  name: member.name,
                                  runsTogether: member.totalRuns,
                                  streak: member.runsThisWeek,
                                  lastRun: '本週',
                                ),
                              )
                          : null,
                    ),
                  ),
                ),
            ] else ...[
              if (group.activities.isEmpty)
                const _EmptyState(text: '目前沒有最近的活動。')
              else
                ...group.activities.map(
                  (activity) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _GroupActivityCard(activity: activity),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GroupStatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _GroupStatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 31,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupMemberCard extends StatelessWidget {
  final _GroupMember member;
  final VoidCallback? onMessageTap;

  const _GroupMemberCard({
    required this.member,
    this.onMessageTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _friendCardDecoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                member.initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${member.name}${member.badge.isNotEmpty ? ' ${member.badge}' : ''}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.route_outlined,
                        size: 14, color: Color(0xFF718096)),
                    const SizedBox(width: 4),
                    Text(
                      '累積慢跑 ${member.totalRuns} 次',
                      style: _friendMetaStyle,
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.calendar_today_outlined,
                        size: 14, color: Color(0xFF718096)),
                    const SizedBox(width: 4),
                    Text('本週 ${member.runsThisWeek} 次',
                        style: _friendMetaStyle),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.fitness_center_outlined,
                        size: 14, color: Color(0xFF718096)),
                    const SizedBox(width: 4),
                    Text(
                      '累積深蹲 ${member.totalSquats} 次',
                      style: _friendMetaStyle,
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.calendar_today_outlined,
                        size: 14, color: Color(0xFF718096)),
                    const SizedBox(width: 4),
                    Text('本週 ${member.squatsThisWeek} 次',
                        style: _friendMetaStyle),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '加入於 ${member.joinedDate}',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (onMessageTap != null) ...[
            const SizedBox(width: 10),
            _IconSquareButton(
              icon: Icons.chat_bubble_outline_rounded,
              onTap: onMessageTap!,
            ),
          ],
        ],
      ),
    );
  }
}

class _GroupActivityCard extends StatelessWidget {
  final _GroupActivityEntry activity;

  const _GroupActivityCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _friendCardDecoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                const Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  activity.subtitle,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            activity.timestamp,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateGroupRunEventForm extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController dateController;
  final TextEditingController notesController;
  final String selectedActivityType;
  final String? selectedTime;
  final List<String> timeOptions;
  final VoidCallback onPickDate;
  final ValueChanged<String> onActivityTypeSelected;
  final ValueChanged<String> onTimeSelected;
  final VoidCallback onCreate;

  const _CreateGroupRunEventForm({
    required this.titleController,
    required this.dateController,
    required this.notesController,
    required this.selectedActivityType,
    required this.selectedTime,
    required this.timeOptions,
    required this.onPickDate,
    required this.onActivityTypeSelected,
    required this.onTimeSelected,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final canCreate = titleController.text.trim().isNotEmpty &&
        dateController.text.trim().isNotEmpty &&
        selectedTime != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _friendCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '建立團跑活動',
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          const _InviteFieldLabel(
            icon: Icons.flag_outlined,
            text: '活動標題',
          ),
          const SizedBox(height: 8),
          TextField(
            controller: titleController,
            decoration: InputDecoration(
              hintText: '例如：早晨訓練',
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
            onChanged: (_) => (context as Element).markNeedsBuild(),
          ),
          const SizedBox(height: 18),
          const _InviteFieldLabel(
            icon: Icons.sports_gymnastics_outlined,
            text: '活動類型',
          ),
          const SizedBox(height: 10),
          Row(
            children: _groupExerciseOptions
                .where((option) => option.value != 'mixed')
                .map((option) {
              final isSelected = selectedActivityType == option.value;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: option.value == 'slow_jogging' ? 10 : 0,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onActivityTypeSelected(option.value),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? Colors.black
                              : const Color(0xFFE2E8F0),
                          width: isSelected ? 2 : 1.2,
                        ),
                        color:
                            isSelected ? const Color(0xFFF8FAFC) : Colors.white,
                      ),
                      child: Column(
                        children: [
                          Icon(option.icon, color: Colors.black, size: 20),
                          const SizedBox(height: 6),
                          Text(
                            option.label,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          const _InviteFieldLabel(
            icon: Icons.calendar_today_outlined,
            text: '選擇日期',
          ),
          const SizedBox(height: 8),
          TextField(
            controller: dateController,
            readOnly: true,
            onTap: onPickDate,
            decoration: InputDecoration(
              hintText: '年 / 月 / 日',
              suffixIcon: IconButton(
                onPressed: onPickDate,
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
            onChanged: (_) => (context as Element).markNeedsBuild(),
          ),
          const SizedBox(height: 18),
          const _InviteFieldLabel(
            icon: Icons.access_time_outlined,
            text: '選擇時間',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: timeOptions.map((time) {
              final isSelected = selectedTime == time;
              return ChoiceChip(
                label: Text(time),
                selected: isSelected,
                onSelected: (_) => onTimeSelected(time),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF4A5568),
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
          const SizedBox(height: 18),
          const _InviteFieldLabel(
            icon: Icons.edit_note_outlined,
            text: '額外備註（選填）',
          ),
          const SizedBox(height: 8),
          TextField(
            controller: notesController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: '新增配速、距離或集合指示...',
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
              onPressed: canCreate ? onCreate : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
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
                '建立活動',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyGroup {
  final String ownerName;
  final String ownerInitial;
  final String name;
  final String description;
  final int members;
  final int runs;
  final int weeklyGoalCurrent;
  final int weeklyGoalTarget;
  final String progressText;
  final double progress;
  final bool isPrivate;
  final String exerciseType;
  final bool showCrown;
  final bool showSettings;
  final List<_GroupMember> memberPreview;
  final List<_GroupActivityEntry> activities;

  const _MyGroup({
    required this.ownerName,
    required this.ownerInitial,
    required this.name,
    required this.description,
    required this.members,
    required this.runs,
    required this.weeklyGoalCurrent,
    required this.weeklyGoalTarget,
    required this.progressText,
    required this.progress,
    this.isPrivate = false,
    this.exerciseType = 'slow_jogging',
    this.showCrown = false,
    this.showSettings = false,
    this.memberPreview = const [],
    this.activities = const [],
  });

  _MyGroup copyWith({
    String? ownerName,
    String? ownerInitial,
    String? name,
    String? description,
    int? members,
    int? runs,
    int? weeklyGoalCurrent,
    int? weeklyGoalTarget,
    String? progressText,
    double? progress,
    bool? isPrivate,
    String? exerciseType,
    bool? showCrown,
    bool? showSettings,
    List<_GroupMember>? memberPreview,
    List<_GroupActivityEntry>? activities,
  }) {
    return _MyGroup(
      ownerName: ownerName ?? this.ownerName,
      ownerInitial: ownerInitial ?? this.ownerInitial,
      name: name ?? this.name,
      description: description ?? this.description,
      members: members ?? this.members,
      runs: runs ?? this.runs,
      weeklyGoalCurrent: weeklyGoalCurrent ?? this.weeklyGoalCurrent,
      weeklyGoalTarget: weeklyGoalTarget ?? this.weeklyGoalTarget,
      progressText: progressText ?? this.progressText,
      progress: progress ?? this.progress,
      isPrivate: isPrivate ?? this.isPrivate,
      exerciseType: exerciseType ?? this.exerciseType,
      showCrown: showCrown ?? this.showCrown,
      showSettings: showSettings ?? this.showSettings,
      memberPreview: memberPreview ?? this.memberPreview,
      activities: activities ?? this.activities,
    );
  }
}

class _GroupMember {
  final String initial;
  final String name;
  final String badge;
  final int totalRuns;
  final int runsThisWeek;
  final int totalSquats;
  final int squatsThisWeek;
  final String joinedDate;
  final bool canMessage;

  const _GroupMember({
    required this.initial,
    required this.name,
    this.badge = '',
    required this.totalRuns,
    required this.runsThisWeek,
    this.totalSquats = 0,
    this.squatsThisWeek = 0,
    required this.joinedDate,
    this.canMessage = true,
  });
}

class _GroupActivityEntry {
  final String title;
  final String subtitle;
  final String timestamp;

  const _GroupActivityEntry({
    required this.title,
    required this.subtitle,
    required this.timestamp,
  });
}

class _DiscoverGroup {
  final String name;
  final String description;
  final int members;
  final bool isPrivate;
  final bool requestSent;
  final bool joined;
  final String exerciseType;

  const _DiscoverGroup({
    required this.name,
    required this.description,
    required this.members,
    required this.isPrivate,
    this.requestSent = false,
    this.joined = false,
    this.exerciseType = 'slow_jogging',
  });

  _DiscoverGroup copyWith({
    String? name,
    String? description,
    int? members,
    bool? isPrivate,
    bool? requestSent,
    bool? joined,
    String? exerciseType,
  }) {
    return _DiscoverGroup(
      name: name ?? this.name,
      description: description ?? this.description,
      members: members ?? this.members,
      isPrivate: isPrivate ?? this.isPrivate,
      requestSent: requestSent ?? this.requestSent,
      joined: joined ?? this.joined,
      exerciseType: exerciseType ?? this.exerciseType,
    );
  }
}

class _GroupExerciseOption {
  final String value;
  final String label;
  final IconData icon;

  const _GroupExerciseOption({
    required this.value,
    required this.label,
    required this.icon,
  });
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

enum CommunityPostType { journey, plan, recipe }

class CommunityPost {
  final String initial;
  final String name;
  final String timeAgo;
  final String content;
  final List<String> tags;
  final int likes;
  final List<String> commentThreads;
  final bool isLiked;
  final bool isSaved;
  final CommunityPostType type;
  final WorkoutPlanData? plan;
  final RecipeData? recipe;

  const CommunityPost({
    required this.initial,
    required this.name,
    required this.timeAgo,
    required this.content,
    required this.tags,
    required this.likes,
    required this.commentThreads,
    this.isLiked = false,
    this.isSaved = false,
    this.type = CommunityPostType.journey,
    this.plan,
    this.recipe,
  });

  int get commentCount => commentThreads.length;

  CommunityPost copyWith({
    String? initial,
    String? name,
    String? timeAgo,
    String? content,
    List<String>? tags,
    int? likes,
    List<String>? commentThreads,
    bool? isLiked,
    bool? isSaved,
    CommunityPostType? type,
    WorkoutPlanData? plan,
    RecipeData? recipe,
  }) {
    return CommunityPost(
      initial: initial ?? this.initial,
      name: name ?? this.name,
      timeAgo: timeAgo ?? this.timeAgo,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      likes: likes ?? this.likes,
      commentThreads: commentThreads ?? this.commentThreads,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      type: type ?? this.type,
      plan: plan ?? this.plan,
      recipe: recipe ?? this.recipe,
    );
  }
}

class WorkoutPlanData {
  final String title;
  final String summary;
  final String difficulty;
  final int totalMinutes;
  final List<WorkoutPlanStep> steps;

  const WorkoutPlanData({
    required this.title,
    required this.summary,
    required this.difficulty,
    required this.totalMinutes,
    required this.steps,
  });
}

class WorkoutPlanStep {
  final String name;
  final int minutes;

  const WorkoutPlanStep({
    required this.name,
    required this.minutes,
  });
}

class RecipeData {
  final String title;
  final String description;
  final int cookMinutes;
  final List<RecipeIngredient> ingredients;
  final NutritionSummary nutrition;

  const RecipeData({
    required this.title,
    required this.description,
    required this.cookMinutes,
    required this.ingredients,
    required this.nutrition,
  });
}

class RecipeIngredient {
  final String name;
  final double grams;

  const RecipeIngredient({
    required this.name,
    required this.grams,
  });
}

class NutritionSummary {
  final int calories;
  final double carbs;
  final double protein;
  final double fat;

  const NutritionSummary({
    required this.calories,
    required this.carbs,
    required this.protein,
    required this.fat,
  });
}

class CommunityStore extends ChangeNotifier {
  final List<CommunityPost> _posts = [
    const CommunityPost(
      initial: 'S',
      name: 'Sarah Chen',
      timeAgo: '2 小時前',
      content: '剛完成了我的第一個5公里超慢跑！感覺超棒，完全沒有疼痛。關鍵在於耐心和持之以恆！',
      tags: ['#晨跑', '#零疼痛', '#進步比完美更重要'],
      likes: 24,
      commentThreads: ['很喜歡你的進步！', '真的很激勵人心'],
    ),
    const CommunityPost(
      initial: 'M',
      name: 'Mike Johnson',
      timeAgo: '5 小時前',
      content: '超慢跑第三週，我的膝蓋痛完全消失了。這個方法真的有效！💪',
      tags: ['#超慢跑挑戰', '#健康習慣'],
      likes: 18,
      commentThreads: ['今天正需要看到這段話'],
      type: CommunityPostType.plan,
      plan: WorkoutPlanData(
        title: '超慢跑計畫',
        summary: '一個幫助你改善超慢跑技巧並減少膝蓋疼痛的4週計畫。',
        difficulty: '中等',
        totalMinutes: 40,
        steps: [
          WorkoutPlanStep(name: '暖身', minutes: 5),
          WorkoutPlanStep(name: '超慢跑', minutes: 30),
          WorkoutPlanStep(name: '緩和', minutes: 5),
        ],
      ),
    ),
    const CommunityPost(
      initial: 'A',
      name: 'Anna Lee',
      timeAgo: '昨天',
      content: '小步幅、穩定的呼吸，沒有壓力。今天的跑步感覺像是我第一次真的想再跑一次。',
      tags: ['#輕鬆跑', '#持續前進'],
      likes: 31,
      commentThreads: ['穩穩來真的最有用', '這個心態我要收藏起來'],
    ),
    const CommunityPost(
      initial: 'J',
      name: 'Jamie Wu',
      timeAgo: '昨天',
      content: '跑後快速的一餐，讓我吃飽又充滿能量。',
      tags: ['#恢復餐', '#高蛋白'],
      likes: 15,
      commentThreads: ['今晚就來試試看'],
      type: CommunityPostType.recipe,
      recipe: RecipeData(
        title: '雞肉飯恢復餐',
        description: '運動後均衡的碳水化合物和蛋白質。',
        cookMinutes: 20,
        ingredients: [
          RecipeIngredient(name: '雞胸肉', grams: 120),
          RecipeIngredient(name: '白飯', grams: 150),
          RecipeIngredient(name: '花椰菜', grams: 80),
        ],
        nutrition: NutritionSummary(
          calories: 430,
          carbs: 47,
          protein: 35,
          fat: 8,
        ),
      ),
    ),
  ];

  List<CommunityPost> get posts => List.unmodifiable(_posts);

  List<CommunityPost> get savedPosts =>
      _posts.where((post) => post.isSaved).toList(growable: false);

  int get savedCount => savedPosts.length;

  void addPost({
    required String initial,
    required String name,
    required String timeAgo,
    required String content,
    required List<String> tags,
    CommunityPostType type = CommunityPostType.journey,
    WorkoutPlanData? plan,
    RecipeData? recipe,
  }) {
    _posts.insert(
      0,
      CommunityPost(
        initial: initial,
        name: name,
        timeAgo: timeAgo,
        content: content,
        tags: tags,
        likes: 0,
        commentThreads: const [],
        type: type,
        plan: plan,
        recipe: recipe,
      ),
    );
    notifyListeners();
  }

  void updatePost(
    int index, {
    required String content,
    required List<String> tags,
    required CommunityPostType type,
    WorkoutPlanData? plan,
    RecipeData? recipe,
  }) {
    final post = _posts[index];
    _posts[index] = post.copyWith(
      content: content,
      tags: tags,
      type: type,
      plan: plan,
      recipe: recipe,
    );
    notifyListeners();
  }

  void toggleLike(int index) {
    final post = _posts[index];
    final isLiked = !post.isLiked;
    _posts[index] = post.copyWith(
      isLiked: isLiked,
      likes: post.likes + (isLiked ? 1 : -1),
    );
    notifyListeners();
  }

  void toggleSave(int index) {
    final post = _posts[index];
    _posts[index] = post.copyWith(isSaved: !post.isSaved);
    notifyListeners();
  }

  void addComment(int index, String comment) {
    final post = _posts[index];
    _posts[index] = post.copyWith(
      commentThreads: [...post.commentThreads, comment],
    );
    notifyListeners();
  }
}

class CommunityProfileScreen extends StatelessWidget {
  final CommunityStore store;
  final String profileInitial;
  final String profileName;

  CommunityProfileScreen({
    super.key,
    required this.store,
    String? profileInitial,
    String? profileName,
  })  : profileInitial = profileInitial ?? UserSession.displayInitial,
        profileName = profileName ?? UserSession.displayName;

  List<CommunityPost> get _profilePosts => store.posts
      .where((post) => post.name == profileName)
      .toList(growable: false);

  bool get _isCurrentUserProfile => profileName == UserSession.displayName;

  List<_ReplyEntry> get _replies => _profilePosts
      .expand(
        (post) => post.commentThreads.map(
          (reply) => _ReplyEntry(
            reply: reply,
            postPreview: post.content,
            timeAgo: post.timeAgo,
          ),
        ),
      )
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.keyboard_arrow_down,
                          color: Color(0xFF4A5568),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 38,
                        backgroundColor: Colors.black,
                        child: Text(
                          profileInitial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        profileName,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          _isCurrentUserProfile ? '僅對你可見' : '社群主頁',
                          style: const TextStyle(
                            color: Color(0xFF718096),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            _ProfileStat(
                              label: '文章',
                              value: _profilePosts.length.toString(),
                            ),
                            Container(
                              width: 1,
                              height: 36,
                              color: const Color(0xFFE2E8F0),
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 20),
                            ),
                            _ProfileStat(
                              label: '回覆',
                              value: _replies.length.toString(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: const TabBar(
                    indicatorColor: Colors.black,
                    labelColor: Colors.black,
                    unselectedLabelColor: Color(0xFF718096),
                    labelStyle: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    tabs: [
                      Tab(text: '文章'),
                      Tab(text: '回覆'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _ArticleTab(posts: _profilePosts),
                      _RepliesTab(replies: _replies),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArticleTab extends StatelessWidget {
  final List<CommunityPost> posts;

  const _ArticleTab({required this.posts});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const _EmptyProfileState(
        title: '目前沒有文章',
        subtitle: '從社群頁面分享你的第一則慢跑近況。',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      itemCount: posts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final post = posts[index];
        return _ProfilePostCard(post: post);
      },
    );
  }
}

class _RepliesTab extends StatelessWidget {
  final List<_ReplyEntry> replies;

  const _RepliesTab({required this.replies});

  @override
  Widget build(BuildContext context) {
    if (replies.isEmpty) {
      return const _EmptyProfileState(
        title: '目前還沒有回覆',
        subtitle: '其他人對你的貼文的回覆將顯示在這裡。',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      itemCount: replies.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final reply = replies[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.black,
                    child: Icon(Icons.reply, size: 14, color: Colors.white),
                  ),
                  SizedBox(width: 10),
                  Text(
                    '有人回覆了你的貼文',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                reply.timeAgo,
                style: const TextStyle(
                  color: Color(0xFF718096),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                reply.reply,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '於：${reply.postPreview}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF4A5568),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfilePostCard extends StatelessWidget {
  final CommunityPost post;

  const _ProfilePostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: Colors.black,
                child: Text(
                  post.initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.name,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      post.timeAgo,
                      style: const TextStyle(
                        color: Color(0xFF718096),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            post.content,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 15,
              height: 1.45,
            ),
          ),
          if (post.plan != null) ...[
            const SizedBox(height: 12),
            _WorkoutPlanCard(plan: post.plan!),
          ],
          if (post.recipe != null) ...[
            const SizedBox(height: 12),
            _RecipeCard(recipe: post.recipe!),
          ],
          if (post.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: post.tags
                  .map(
                    (tag) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECEFF3),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          color: Color(0xFF4A5568),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              _MetaChip(
                icon: Icons.favorite_border,
                label: '${post.likes} 個讚',
              ),
              const SizedBox(width: 10),
              _MetaChip(
                icon: Icons.chat_bubble_outline,
                label: '${post.commentCount} 則回覆',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF4A5568)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF4A5568),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF718096),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyProfileState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyProfileState({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(
                Icons.forum_outlined,
                color: Color(0xFF4A5568),
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF718096),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplyEntry {
  final String reply;
  final String postPreview;
  final String timeAgo;

  const _ReplyEntry({
    required this.reply,
    required this.postPreview,
    required this.timeAgo,
  });
}
