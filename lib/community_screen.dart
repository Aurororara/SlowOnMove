import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'community/community_store.dart';
import 'community/models/community_post.dart';
import 'services/user_session.dart';
import 'community/friend_store.dart';
import 'community/models/community_friend.dart';
import 'community/chat_store.dart';
import 'community/models/community_chat.dart';
import 'community/run_invitation_store.dart';
import 'community/models/run_invitation.dart';
import 'community/group_store.dart';
import 'community/models/community_group.dart';
import 'community/group_invitation_store.dart';
import 'community/models/community_group_invitation.dart';
import 'community/group_activity_store.dart';
import 'community/models/community_group_activity.dart';
import 'community/utils/group_formatters.dart';
import 'community/widgets/groups/group_activity_card.dart';
import 'community/widgets/common/community_avatar.dart';
import 'community/widgets/groups/group_tab_button.dart';
import 'community/widgets/common/community_card_styles.dart';
import 'community/widgets/groups/group_activity_form.dart';
import 'community/widgets/groups/group_detail_panel.dart';
import 'community/widgets/groups/group_stat_tile.dart';
import 'community/widgets/common/community_section_label.dart';
import 'community/widgets/common/community_empty_state.dart';
import 'community/widgets/common/community_button.dart';
import 'community/widgets/groups/group_invitation_card.dart';
import 'community/widgets/posts/post_card.dart';
import 'community/widgets/posts/workout_plan_card.dart';
import 'community/widgets/posts/recipe_card.dart';
import 'community/widgets/common/community_tag_pill.dart';
import 'community/widgets/posts/post_composer.dart';
import 'community/widgets/common/community_input.dart';

enum _CommunityChatEntryType {
  message,
  runInvitation,
}

class _CommunityChatEntry {
  final _CommunityChatEntryType type;
  final DateTime createdAt;
  final CommunityChatMessage? message;
  final CommunityRunInvitation? invitation;

  _CommunityChatEntry.message({
    required CommunityChatMessage message,
  })  : type = _CommunityChatEntryType.message,
        createdAt = message.createdAt,
        message = message,
        invitation = null;

  _CommunityChatEntry.runInvitation({
    required CommunityRunInvitation invitation,
  })  : type = _CommunityChatEntryType.runInvitation,
        createdAt = invitation.createdAt,
        invitation = invitation,
        message = null;
}

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
  Timer? _searchDebounce;
  final Map<String, Timer> _groupEventReminderTimers = {};
  final FriendStore _friendStore = FriendStore();
  final ChatStore _chatStore = ChatStore();
  final RunInvitationStore _runInvitationStore = RunInvitationStore();
  final GroupStore _groupStore = GroupStore();
  final GroupInvitationStore _groupInvitationStore = GroupInvitationStore();
  final GroupActivityStore _groupActivityStore = GroupActivityStore();

  Timer? _chatPollingTimer;
  Timer? _notificationPollingTimer;

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
  CommunityFriend? _inviteFriend;
  CommunityFriend? _chatFriend;
  CommunityGroup? _groupDetail;

  List<CommunityPost> get _posts => widget.store.posts;
  String get _searchQuery => _searchController.text.trim().toLowerCase();

  List<({int index, CommunityPost post})> get _filteredPosts {
    return List.generate(
      _posts.length,
      (index) => (
        index: index,
        post: _posts[index],
      ),
    );
  }

  List<_CommunityChatEntry> _chatEntriesFor(
    int friendId,
  ) {
    final entries = <_CommunityChatEntry>[
      ..._chatStore.messagesFor(friendId).map(
            (message) => _CommunityChatEntry.message(
              message: message,
            ),
          ),
      ..._runInvitationStore.invitationsFor(friendId).map(
            (invitation) => _CommunityChatEntry.runInvitation(
              invitation: invitation,
            ),
          ),
    ];

    entries.sort(
      (a, b) => a.createdAt.compareTo(
        b.createdAt,
      ),
    );

    return entries;
  }

  void _openLegacyChat(_RunInviteFriend friend) {
    // 群組目前仍是假資料，
    // 不接真正好友 Chat API。
  }

  void _startNotificationPolling() {
    _stopNotificationPolling();

    _notificationPollingTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        if (!mounted) {
          return;
        }

        _chatStore.loadUnread();
        _runInvitationStore.loadPending();
        _groupInvitationStore.loadPending();
      },
    );
  }

  void _stopNotificationPolling() {
    _notificationPollingTimer?.cancel();
    _notificationPollingTimer = null;
  }

  void _startChatPolling(int friendId) {
    _stopChatPolling();

    _chatPollingTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) {
        if (!mounted || _chatFriend?.id != friendId) {
          return;
        }

        _chatStore.loadMessages(
          friendId,
          showLoading: false,
          preserveFirstUnread: true,
        );

        _runInvitationStore.loadInvitations(
          friendId,
        );
      },
    );
  }

  void _stopChatPolling() {
    _chatPollingTimer?.cancel();
    _chatPollingTimer = null;
  }

  @override
  void initState() {
    super.initState();

    widget.store.addListener(_handleStoreChanged);
    _friendStore.addListener(_handleFriendStoreChanged);
    _searchController.addListener(_handleSearchChanged);
    _chatStore.addListener(_handleChatStoreChanged);
    _runInvitationStore.addListener(_handleRunInvitationStoreChanged);
    _groupStore.addListener(_handleGroupStoreChanged);
    _groupInvitationStore.addListener(_handleGroupInvitationStoreChanged);
    _groupActivityStore.addListener(_handleGroupActivityStoreChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.store.loadPosts();
      _friendStore.loadAll();
      _chatStore.loadUnread();
      _runInvitationStore.loadPending();
      _groupInvitationStore.loadPending();

      _startNotificationPolling();
    });
  }

  void _handleGroupActivityStoreChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  void _handleGroupInvitationStoreChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  void _handleGroupStoreChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  void _handleRunInvitationStoreChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  void _handleFriendStoreChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  void _handleStoreChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  void _handleSearchChanged() {
    _searchDebounce?.cancel();

    _searchDebounce = Timer(
      const Duration(milliseconds: 400),
      () {
        final keyword = _searchController.text.trim();

        widget.store.searchPosts(keyword);
      },
    );
  }

  void _handleChatStoreChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _stopChatPolling();
    _stopNotificationPolling();

    for (final timer in _groupEventReminderTimers.values) {
      timer.cancel();
    }

    widget.store.removeListener(_handleStoreChanged);
    _friendStore.removeListener(_handleFriendStoreChanged);
    _chatStore.removeListener(_handleChatStoreChanged);
    _runInvitationStore.removeListener(_handleRunInvitationStoreChanged);
    _groupStore.removeListener(_handleGroupStoreChanged);
    _groupInvitationStore.removeListener(_handleGroupInvitationStoreChanged);
    _groupActivityStore.removeListener(_handleGroupActivityStoreChanged);

    _searchController
      ..removeListener(_handleSearchChanged)
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

  Future<void> _submitPost(PostComposerSubmission submission) async {
    final success = await widget.store.addPost(
      content: submission.content,
      tags: submission.tags,
      type: submission.type,
      plan: submission.plan,
      recipe: submission.recipe,
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.store.errorMessage ?? '發文失敗',
          ),
        ),
      );

      return;
    }

    setState(() {
      _isComposerOpen = false;
    });

    FocusScope.of(context).unfocus();
  }

  PostComposerSubmission _submissionFromPost(CommunityPost post) {
    return PostComposerSubmission(
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
            child: PostComposer(
              initialSubmission: _submissionFromPost(post),
              submitLabel: '儲存',
              onPost: (submission) async {
                final success = await widget.store.updatePost(
                  index,
                  content: submission.content,
                  tags: submission.tags,
                  type: submission.type,
                  plan: submission.plan,
                  recipe: submission.recipe,
                );

                if (!sheetContext.mounted) {
                  return;
                }

                if (success) {
                  Navigator.of(sheetContext).pop();
                  return;
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        widget.store.errorMessage ?? '修改貼文失敗',
                      ),
                    ),
                  );
                }
              },
              onClose: () => Navigator.of(sheetContext).pop(),
            ),
          ),
        );
      },
    );
  }

  void _openFriends() {
    _stopChatPolling();

    FocusScope.of(context).unfocus();
    setState(() {
      _isComposerOpen = false;
      _isGroupsOpen = false;
      _inviteFriend = null;
      _chatFriend = null;
      _isFriendsOpen = true;
    });

    _friendStore.loadAll();
    _chatStore.loadUnread();
    _runInvitationStore.loadPending();
    _groupInvitationStore.loadPending();
  }

  void _openGroups() {
    _stopChatPolling();

    FocusScope.of(context).unfocus();
    setState(() {
      _isComposerOpen = false;
      _isFriendsOpen = false;
      _isGroupsOpen = true;
      _chatFriend = null;
      _inviteFriend = null;
      _groupDetail = null;
    });

    _groupStore.loadGroups();
    _groupInvitationStore.loadPending();
  }

  void _openGroupDetail(
    CommunityGroup group,
  ) {
    _stopChatPolling();

    FocusScope.of(context).unfocus();

    setState(() {
      _isComposerOpen = false;
      _isFriendsOpen = false;
      _isGroupsOpen = false;

      _inviteFriend = null;
      _chatFriend = null;

      _groupDetail = group;
    });

    _groupActivityStore.loadActivities(
      group.id,
    );
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
    _stopChatPolling();

    final chatFriendId = _chatFriend?.id;

    final returningToFriends = _chatFriend != null || _inviteFriend != null;

    final returningToGroups = _groupDetail != null;

    if (chatFriendId != null) {
      _chatStore.clearFirstUnreadMessageId(
        chatFriendId,
      );
    }

    setState(() {
      if (returningToFriends) {
        _isFriendsOpen = true;
        _isGroupsOpen = false;

        _inviteFriend = null;
        _chatFriend = null;
        _groupDetail = null;
      } else if (returningToGroups) {
        _isFriendsOpen = false;
        _isGroupsOpen = true;

        _inviteFriend = null;
        _chatFriend = null;
        _groupDetail = null;
      } else {
        _isFriendsOpen = false;
        _isGroupsOpen = false;

        _inviteFriend = null;
        _chatFriend = null;
        _groupDetail = null;
      }
    });

    if (returningToFriends) {
      _chatStore.loadUnread();
      _runInvitationStore.loadPending();
      _groupInvitationStore.loadPending();
    }

    if (returningToGroups) {
      _groupStore.loadGroups();
      _groupInvitationStore.loadPending();
    }
  }

  void _openInviteToRun(CommunityFriend friend) {
    _stopChatPolling();

    FocusScope.of(context).unfocus();
    setState(() {
      _isComposerOpen = false;
      _isFriendsOpen = false;
      _isGroupsOpen = false;
      _inviteFriend = friend;
      _chatFriend = null;
    });
  }

  Future<void> _openChat(
    CommunityFriend friend,
  ) async {
    FocusScope.of(context).unfocus();

    setState(() {
      _isComposerOpen = false;
      _isFriendsOpen = false;
      _isGroupsOpen = false;
      _inviteFriend = null;
      _chatFriend = friend;
    });

    await Future.wait([
      _chatStore.loadMessages(friend.id),
      _runInvitationStore.loadInvitations(
        friend.id,
      ),
    ]);

    if (!mounted || _chatFriend?.id != friend.id) {
      return;
    }

    _startChatPolling(friend.id);
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

  Future<void> _toggleLike(int index) async {
    final success = await widget.store.toggleLike(index);

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.store.errorMessage ?? '按讚失敗',
          ),
        ),
      );
    }
  }

  Future<void> _toggleSave(int index) async {
    final isSaving = !_posts[index].isSaved;

    final success = await widget.store.toggleSave(index);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (isSaving ? '已加入我的珍藏' : '已從我的珍藏移除')
              : widget.store.errorMessage ?? '收藏失敗',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openComments(int index) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _CommentsSheet(
          store: widget.store,
          postIndex: index,
        );
      },
    );
  }

  Future<void> _showPostMenu(int index) async {
    final post = _posts[index];
    final isOwnPost = post.memberId == UserSession.memberId;
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
                    _showReportReasons(
                      index,
                      post.name,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showReportReasons(
    int postIndex,
    String authorName,
  ) async {
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
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    18,
                    14,
                    18,
                    20,
                  ),
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
                            child: Icon(Icons.flag_outlined,
                                color: Colors.redAccent),
                          ),
                          title: Text(
                            reason,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          onTap: () async {
                            Navigator.pop(sheetContext);

                            final success = await widget.store.reportPost(
                              postIndex,
                              reason,
                            );

                            if (!mounted) {
                              return;
                            }

                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  success
                                      ? '檢舉已提交：$reason'
                                      : widget.store.errorMessage ?? '檢舉失敗',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ));
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
      isScrollControlled: true,
      builder: (sheetContext) {
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
                    key: ValueKey('chat-${_chatFriend!.id}'),
                    friend: _chatFriend!,
                    entries: _chatEntriesFor(_chatFriend!.id),
                    firstUnreadMessageId: _chatStore.firstUnreadMessageIdFor(
                      _chatFriend!.id,
                    ),
                    isLoading: _chatStore.isLoading,
                    isSending: _chatStore.isSending,
                    onCancelInvitation: (
                      invitation,
                    ) async {
                      final friend = _chatFriend;

                      if (friend == null) {
                        return false;
                      }

                      final success =
                          await _runInvitationStore.cancelInvitation(
                        friendId: friend.id,
                        invitationId: invitation.id,
                      );

                      if (!mounted) {
                        return success;
                      }

                      if (!success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _runInvitationStore.errorMessage ?? '取消跑步邀請失敗',
                            ),
                          ),
                        );
                      }

                      return success;
                    },
                    onRespondInvitation: (
                      invitation,
                      accept,
                    ) async {
                      final friend = _chatFriend;

                      if (friend == null) {
                        return false;
                      }

                      final success =
                          await _runInvitationStore.respondInvitation(
                        friendId: friend.id,
                        invitationId: invitation.id,
                        accept: accept,
                      );

                      if (!mounted) {
                        return success;
                      }

                      if (!success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _runInvitationStore.errorMessage ?? '跑步邀請處理失敗',
                            ),
                          ),
                        );
                      }

                      return success;
                    },
                    onSendMessage: (message) async {
                      final success = await _chatStore.sendMessage(
                        _chatFriend!.id,
                        message,
                      );

                      if (!mounted || success) {
                        return;
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            _chatStore.errorMessage ?? '訊息傳送失敗',
                          ),
                        ),
                      );
                    },
                  )
                : _inviteFriend != null
                    ? _InviteToRunPanel(
                        key: ValueKey('invite-${_inviteFriend!.id}'),
                        friend: _inviteFriend!,
                        onSendInvitation: ({
                          required scheduledAt,
                          targetDistanceKm,
                          targetDurationMinutes,
                          required notes,
                        }) async {
                          final friend = _inviteFriend;

                          if (friend == null) {
                            return false;
                          }

                          final success =
                              await _runInvitationStore.sendInvitation(
                            inviteeId: friend.id,
                            scheduledAt: scheduledAt,
                            targetDistanceKm: targetDistanceKm,
                            targetDurationMinutes: targetDurationMinutes,
                            notes: notes,
                          );

                          if (!mounted) {
                            return success;
                          }

                          if (!success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  _runInvitationStore.errorMessage ??
                                      '跑步邀請送出失敗',
                                ),
                              ),
                            );

                            return false;
                          }

                          setState(() {
                            _inviteFriend = null;
                            _isFriendsOpen = true;
                          });

                          return true;
                        },
                      )
                    : _groupDetail != null
                        ? GroupDetailPanel(
                            key: ValueKey(
                              'group-detail-${_groupDetail!.id}',
                            ),
                            group: _groupDetail!,
                            friends: _friendStore.friends,
                            groupStore: _groupStore,
                            groupInvitationStore: _groupInvitationStore,
                            groupActivityStore: _groupActivityStore,
                            onBack: _closeSecondaryPage,
                          )
                        : _isFriendsOpen
                            ? _FriendsPanel(
                                key: const ValueKey('friends'),
                                store: _friendStore,
                                chatStore: _chatStore,
                                runInvitationStore: _runInvitationStore,
                                onInviteTap: _openInviteToRun,
                                onMessageTap: _openChat,
                              )
                            : _isGroupsOpen
                                ? SafeArea(
                                    top: true,
                                    bottom: false,
                                    child: _GroupsPanel(
                                      key: _groupsPanelKey,
                                      groupStore: _groupStore,
                                      friendStore: _friendStore,
                                      groupInvitationStore:
                                          _groupInvitationStore,
                                      onGroupDetailTap: _openGroupDetail,
                                      onBack: _closeSecondaryPage,
                                      onMessageTap: _openLegacyChat,
                                      onSystemMessage: _appendSystemChatMessage,
                                      onScheduleEventReminder:
                                          _scheduleGroupEventReminder,
                                    ),
                                  )
                                : ListView(
                                    key: const ValueKey('community-feed'),
                                    padding: const EdgeInsets.fromLTRB(
                                        18, 14, 18, 24),
                                    children: [
                                      _SearchField(
                                        controller: _searchController,
                                        onClear: _searchQuery.isEmpty
                                            ? null
                                            : () => _searchController.clear(),
                                      ),
                                      const SizedBox(height: 14),
                                      AnimatedSwitcher(
                                        duration:
                                            const Duration(milliseconds: 220),
                                        switchInCurve: Curves.easeOutCubic,
                                        switchOutCurve: Curves.easeInCubic,
                                        child: _isComposerOpen
                                            ? PostComposer(
                                                key: const ValueKey(
                                                    'composer-open'),
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
                                      const CommunitySectionLabel('社群動態'),
                                      const SizedBox(height: 12),
                                      if (_filteredPosts.isEmpty)
                                        const CommunityEmptyState(
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
                                            child: PostCard(
                                              onMoreTap: () =>
                                                  _showPostMenu(index),
                                              onLikeTap: () =>
                                                  _toggleLike(index),
                                              onCommentTap: () =>
                                                  _openComments(index),
                                              onSaveTap: () =>
                                                  _toggleSave(index),
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
                    _groupDetail != null ||
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
          if (_chatFriend != null ||
              _inviteFriend != null ||
              _groupDetail != null)
            const SizedBox(width: 56)
          else if (_isGroupsOpen)
            _CreateGroupButton(
              onTap: () {
                _groupsPanelKey.currentState?.openCreateGroup();
              },
            )
          else ...[
            _FriendRequestsButton(
              onTap: _openFriends,
              count: _friendStore.requests.length +
                  _chatStore.unreadTotal +
                  _runInvitationStore.pendingTotal +
                  _groupInvitationStore.pendingTotal,
            ),
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
                  child: CommunityAvatar(initial: UserSession.displayInitial),
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
            color: Colors.black.withOpacity(0.08),
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
                        CommunityChoicePicker<_ComposerMode>(
                          options: const [
                            _ComposerMode.journey,
                            _ComposerMode.plan,
                          ],
                          value: _mode,
                          labelBuilder: (mode) {
                            switch (mode) {
                              case _ComposerMode.journey:
                                return '分享你的旅程';
                              case _ComposerMode.plan:
                                return '分享你的計畫';
                              case _ComposerMode.recipe:
                                return '分享你的食譜';
                            }
                          },
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
                decoration: communityInputDecoration(_hintText),
              ),
              if (_mode == _ComposerMode.plan) ...[
                const SizedBox(height: 14),
                const CommunityFieldLabel(
                  icon: Icons.route_outlined,
                  text: '計畫詳情',
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _planTitleController,
                  decoration: communityInputDecoration('計畫標題，例如：4週友善膝蓋計畫'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _planSummaryController,
                  maxLines: 2,
                  decoration: communityInputDecoration(
                    '簡短的計畫摘要或目標',
                  ),
                ),
                const SizedBox(height: 10),
                CommunityChoicePicker<String>(
                  options: const [
                    '簡單',
                    '中等',
                    '進階',
                  ],
                  value: _planDifficulty,
                  labelBuilder: (option) => option,
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
                CommunitySecondaryButton(
                  icon: Icons.add,
                  label: '新增步驟',
                  onTap: _addPlanStep,
                ),
              ],
              if (_mode == _ComposerMode.recipe) ...[
                const SizedBox(height: 14),
                const CommunityFieldLabel(
                  icon: Icons.restaurant_menu_outlined,
                  text: '食譜詳情',
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _recipeTitleController,
                  decoration: communityInputDecoration('食譜標題，例如：跑後高蛋白餐'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _recipeDescriptionController,
                  minLines: 2,
                  maxLines: 3,
                  textInputAction: TextInputAction.newline,
                  decoration: communityInputDecoration(
                    '食譜描述（顯示在食譜卡片內）',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _recipeCookMinutesController,
                  keyboardType: TextInputType.number,
                  decoration: communityInputDecoration('烹調時間（分鐘）'),
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
                CommunitySecondaryButton(
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
                        (tag) => CommunityTagPill(
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
                  decoration: communityInputDecoration('動作名稱'),
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
                decoration: communityInputDecoration('分鐘數'),
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
              decoration: communityInputDecoration('食材名稱'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: TextField(
              controller: ingredient.grams,
              keyboardType: TextInputType.number,
              decoration: communityInputDecoration('克數'),
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

class _FriendsPanel extends StatefulWidget {
  final ValueChanged<CommunityFriend>? onInviteTap;
  final ValueChanged<CommunityFriend>? onMessageTap;
  final FriendStore store;
  final ChatStore chatStore;
  final RunInvitationStore runInvitationStore;

  const _FriendsPanel({
    super.key,
    required this.store,
    required this.chatStore,
    required this.runInvitationStore,
    required this.onInviteTap,
    required this.onMessageTap,
  });

  @override
  State<_FriendsPanel> createState() => _FriendsPanelState();
}

class _FriendsPanelState extends State<_FriendsPanel> {
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _acceptRequest(
    CommunityFriendRequest request,
  ) async {
    final success = await widget.store.acceptRequest(
      request.id,
    );

    if (!mounted) {
      return;
    }

    _showMessage(
      success
          ? '已將 ${request.sender.name} 加為好友'
          : widget.store.errorMessage ?? '接受好友邀請失敗',
    );
  }

  Future<void> _declineRequest(
    CommunityFriendRequest request,
  ) async {
    final success = await widget.store.rejectRequest(
      request.id,
    );

    if (!mounted) {
      return;
    }

    _showMessage(
      success
          ? '已拒絕 ${request.sender.name} 的好友請求'
          : widget.store.errorMessage ?? '拒絕好友邀請失敗',
    );
  }

  Future<void> _cancelPending(
    CommunityFriendRequest request,
  ) async {
    final success = await widget.store.cancelRequest(
      request.id,
    );

    if (!mounted) {
      return;
    }

    _showMessage(
      success
          ? '已取消對 ${request.receiver.name} 的好友邀請'
          : widget.store.errorMessage ?? '取消好友邀請失敗',
    );
  }

  Future<void> _addSuggestion(
    CommunityFriend suggestion,
  ) async {
    final success = await widget.store.sendRequest(
      suggestion.id,
    );

    if (!mounted) {
      return;
    }

    _showMessage(
      success
          ? '已送出好友邀請給 ${suggestion.name}'
          : widget.store.errorMessage ?? '好友邀請送出失敗',
    );
  }

  Future<void> _removeFriend(
    CommunityFriend friend,
  ) async {
    final success = await widget.store.removeFriend(
      friend.id,
    );

    if (!mounted) {
      return;
    }

    _showMessage(
      success
          ? '已將 ${friend.name} 從好友移除'
          : widget.store.errorMessage ?? '刪除好友失敗',
    );
  }

  @override
  Widget build(BuildContext context) {
    final friends = widget.store.friends;
    final requests = widget.store.requests;
    final pendingRequests = widget.store.pendingRequests;
    final suggestions = widget.store.suggestions;
    final searchResults = widget.store.searchResults;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        _FriendTabs(
          friendsCount: friends.length,
          requestsCount: requests.length + pendingRequests.length,
          selectedIndex: _selectedTab,
          onChanged: (index) {
            setState(() {
              _selectedTab = index;
            });
          },
        ),
        const SizedBox(height: 20),
        if (_selectedTab == 0) ...[
          _FriendSearchField(
            onChanged: widget.store.searchMembers,
          ),
          if (searchResults.isNotEmpty) ...[
            const SizedBox(height: 16),
            const CommunitySectionLabel('搜尋結果'),
            const SizedBox(height: 8),
            ...searchResults.map(
              (friend) => _FriendSearchResultTile(
                friend: friend,
                onAdd: () async {
                  final success = await widget.store.sendRequest(friend.id);

                  if (!mounted) {
                    return;
                  }

                  _showMessage(
                    success
                        ? '已送出好友邀請給 ${friend.name}'
                        : widget.store.errorMessage ?? '好友邀請送出失敗',
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
          const SizedBox(height: 14),
          CommunitySectionLabel(
            '你的運動好友 (${friends.length})',
          ),
          const SizedBox(height: 12),
          if (widget.store.isLoading && friends.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (friends.isEmpty)
            const CommunityEmptyState(
              text: '目前還沒有運動好友。',
            )
          else
            ...List.generate(
              friends.length,
              (index) {
                final friend = friends[index];

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == friends.length - 1 ? 0 : 12,
                  ),
                  child: _RunningBuddyCard(
                    friend: friend,

                    // v1 尚未串 TrainingLog 統計
                    runsTogether: 0,
                    streak: 0,
                    lastRun: '尚無資料',
                    unreadCount: widget.chatStore.unreadCountFor(friend.id) +
                        widget.runInvitationStore.pendingCountFor(friend.id),
                    onInviteTap: widget.onInviteTap,
                    onMessageTap: widget.onMessageTap,
                    onRemoveTap: () => _removeFriend(friend),
                  ),
                );
              },
            ),
        ] else if (_selectedTab == 1) ...[
          CommunitySectionLabel(
            '好友請求 (${requests.length})',
          ),
          const SizedBox(height: 12),
          if (widget.store.isLoading &&
              requests.isEmpty &&
              pendingRequests.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            if (requests.isEmpty)
              const CommunityEmptyState(
                text: '目前沒有新的好友請求。',
              )
            else
              ...List.generate(
                requests.length,
                (index) {
                  final request = requests[index];

                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == requests.length - 1 ? 0 : 12,
                    ),
                    child: _FriendRequestCard(
                      request: request,
                      onAccept: () => _acceptRequest(request),
                      onDecline: () => _declineRequest(request),
                    ),
                  );
                },
              ),
            const SizedBox(height: 18),
            CommunitySectionLabel(
              '待處理 (${pendingRequests.length})',
            ),
            const SizedBox(height: 12),
            if (pendingRequests.isEmpty)
              const CommunityEmptyState(
                text: '目前沒有待處理請求。',
              )
            else
              ...List.generate(
                pendingRequests.length,
                (index) {
                  final request = pendingRequests[index];

                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == pendingRequests.length - 1 ? 0 : 12,
                    ),
                    child: _PendingFriendCard(
                      request: request,
                      onCancel: () => _cancelPending(request),
                    ),
                  );
                },
              ),
          ],
        ] else ...[
          const CommunitySectionLabel('你可能認識的人'),
          const SizedBox(height: 12),
          if (widget.store.isLoading && suggestions.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (suggestions.isEmpty)
            const CommunityEmptyState(
              text: '目前沒有推薦對象。',
            )
          else
            ...List.generate(
              suggestions.length,
              (index) {
                final suggestion = suggestions[index];

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == suggestions.length - 1 ? 0 : 12,
                  ),
                  child: _SuggestionCard(
                    initial: suggestion.initial,
                    name: suggestion.name,

                    // v1 尚未實作共同好友數
                    mutualFriends: 0,

                    onAdd: () => _addSuggestion(suggestion),
                  ),
                );
              },
            ),
        ],
        if (widget.store.errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            widget.store.errorMessage!,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
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

class _FriendSearchField extends StatefulWidget {
  final ValueChanged<String> onChanged;

  const _FriendSearchField({
    required this.onChanged,
  });

  @override
  State<_FriendSearchField> createState() => _FriendSearchFieldState();
}

class _FriendSearchFieldState extends State<_FriendSearchField> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged(String value) {
    setState(() {});

    _debounce?.cancel();

    _debounce = Timer(
      const Duration(milliseconds: 400),
      () {
        widget.onChanged(value);
      },
    );
  }

  void _clear() {
    _controller.clear();
    _debounce?.cancel();
    widget.onChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: _handleChanged,
      decoration: InputDecoration(
        hintText: '搜尋姓名、帳號或 Email',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controller.text.isNotEmpty
            ? IconButton(
                onPressed: _clear,
                icon: const Icon(Icons.close),
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF7F8FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}

class _FriendSearchResultTile extends StatelessWidget {
  final CommunityFriend friend;
  final VoidCallback onAdd;

  const _FriendSearchResultTile({
    required this.friend,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final relationship = friend.relationship;

    String buttonText;
    VoidCallback? action;

    switch (relationship) {
      case 'friend':
        buttonText = '已是好友';
        action = null;
        break;

      case 'sent':
        buttonText = '已送出';
        action = null;
        break;

      case 'received':
        buttonText = '待回應';
        action = null;
        break;

      default:
        buttonText = '加好友';
        action = onAdd;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE8E8E8),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundImage: friend.avatar != null && friend.avatar!.isNotEmpty
                ? NetworkImage(friend.avatar!)
                : null,
            child: friend.avatar == null || friend.avatar!.isEmpty
                ? Text(friend.initial)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              friend.name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: action,
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }
}

class _RunningBuddyCard extends StatelessWidget {
  final CommunityFriend friend;
  final int runsTogether;
  final int streak;
  final String lastRun;
  final int unreadCount;
  final ValueChanged<CommunityFriend>? onInviteTap;
  final ValueChanged<CommunityFriend>? onMessageTap;
  final VoidCallback? onRemoveTap;

  const _RunningBuddyCard({
    required this.friend,
    required this.runsTogether,
    required this.streak,
    required this.lastRun,
    required this.unreadCount,
    this.onInviteTap,
    this.onMessageTap,
    this.onRemoveTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: communityCardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommunityAvatar(initial: friend.initial),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.name,
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
                      style: communityMetaStyle,
                    ),
                    const SizedBox(width: 18),
                    const Icon(Icons.emoji_events_outlined,
                        color: Color(0xFFD69E2E), size: 14),
                    const SizedBox(width: 4),
                    Text('連續 $streak 天', style: communityMetaStyle),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        color: Color(0xFF718096), size: 14),
                    const SizedBox(width: 5),
                    Text('最後一次跑步：$lastRun', style: communityMetaStyle),
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
                        onInviteTap?.call(friend);
                      },
                    ),
                    const SizedBox(width: 8),
                    Badge(
                      isLabelVisible: unreadCount > 0,
                      label: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                      ),
                      child: _SmallFriendButton(
                        label: '訊息',
                        icon: Icons.chat_bubble_outline,
                        onTap: () {
                          onMessageTap?.call(friend);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GroupCardIconButton(
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
  final String? targetDistance;
  final String? targetDuration;
  final String notes;
  final _RunInvitationStatus status;

  const _RunInvitation({
    required this.date,
    required this.time,
    this.targetDistance,
    this.targetDuration,
    required this.notes,
    this.status = _RunInvitationStatus.pending,
  });

  _RunInvitation copyWith({
    String? date,
    String? time,
    String? targetDistance,
    String? targetDuration,
    String? notes,
    _RunInvitationStatus? status,
  }) {
    return _RunInvitation(
      date: date ?? this.date,
      time: time ?? this.time,
      targetDistance: targetDistance ?? this.targetDistance,
      targetDuration: targetDuration ?? this.targetDuration,
      notes: notes ?? this.notes,
      status: status ?? this.status,
    );
  }
}

class _InviteToRunPanel extends StatefulWidget {
  final CommunityFriend friend;

  final Future<bool> Function({
    required DateTime scheduledAt,
    double? targetDistanceKm,
    int? targetDurationMinutes,
    required String notes,
  }) onSendInvitation;

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
  static const List<String> _distanceOptions = [
    '1 km',
    '3 km',
    '5 km',
    '10 km',
  ];
  static const List<String> _durationOptions = [
    '15 分鐘',
    '30 分鐘',
    '45 分鐘',
    '60 分鐘',
  ];

  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String? _selectedTime;
  String? _selectedDistance;
  String? _selectedDuration;
  bool _isSending = false;

  @override
  void dispose() {
    _dateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  DateTime? _buildScheduledAt() {
    final dateMatch = RegExp(
      r'^(\d{4})\s*/\s*(\d{2})\s*/\s*(\d{2})$',
    ).firstMatch(
      _dateController.text.trim(),
    );

    final timeMatch = RegExp(
      r'^(\d{2}):(\d{2})\s*(AM|PM)$',
    ).firstMatch(
      _selectedTime ?? '',
    );

    if (dateMatch == null || timeMatch == null) {
      return null;
    }

    final year = int.parse(dateMatch.group(1)!);
    final month = int.parse(dateMatch.group(2)!);
    final day = int.parse(dateMatch.group(3)!);

    var hour = int.parse(timeMatch.group(1)!);
    final minute = int.parse(timeMatch.group(2)!);
    final period = timeMatch.group(3)!;

    if (period == 'PM' && hour != 12) {
      hour += 12;
    }

    if (period == 'AM' && hour == 12) {
      hour = 0;
    }

    return DateTime(
      year,
      month,
      day,
      hour,
      minute,
    );
  }

  double? _buildDistanceKm() {
    final value = _selectedDistance;

    if (value == null) {
      return null;
    }

    return double.tryParse(
      value.replaceAll('km', '').trim(),
    );
  }

  int? _buildDurationMinutes() {
    final value = _selectedDuration;

    if (value == null) {
      return null;
    }

    return int.tryParse(
      value.replaceAll('分鐘', '').trim(),
    );
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

  Future<void> _sendInvitation() async {
    if (_isSending) {
      return;
    }

    final scheduledAt = _buildScheduledAt();

    if (scheduledAt == null) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    final success = await widget.onSendInvitation(
      scheduledAt: scheduledAt,
      targetDistanceKm: _buildDistanceKm(),
      targetDurationMinutes: _buildDurationMinutes(),
      notes: _notesController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSending = false;
    });

    if (!success) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已送出跑步邀請給 ${widget.friend.name}',
        ),
      ),
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
          decoration: communityCardDecoration(),
          child: Column(
            children: [
              Row(
                children: [
                  CommunityAvatar(initial: widget.friend.initial),
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
                        const Text(
                          '一起運動 0 次',
                          style: communityMetaStyle,
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
                child: const Text(
                  '最近一次一起運動：尚無資料',
                  textAlign: TextAlign.center,
                  style: TextStyle(
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
          decoration: communityCardDecoration(),
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
              const CommunityFieldLabel(
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
              const CommunityFieldLabel(
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
              const CommunityFieldLabel(
                icon: Icons.straighten_outlined,
                text: '跑多遠（選填）',
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _distanceOptions.map((distance) {
                  final isSelected = _selectedDistance == distance;
                  return ChoiceChip(
                    label: Text(distance),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _selectedDistance = isSelected ? null : distance;
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
              const SizedBox(height: 18),
              const CommunityFieldLabel(
                icon: Icons.hourglass_bottom_outlined,
                text: '跑多久（選填）',
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _durationOptions.map((duration) {
                  final isSelected = _selectedDuration == duration;
                  return ChoiceChip(
                    label: Text(duration),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _selectedDuration = isSelected ? null : duration;
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
              const SizedBox(height: 18),
              const CommunityFieldLabel(
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
                  onPressed: canSend && !_isSending ? _sendInvitation : null,
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
                  label: Text(
                    _isSending ? '送出中...' : '送出邀請',
                    style: const TextStyle(
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
  final CommunityFriend friend;
  final List<_CommunityChatEntry> entries;
  final int? firstUnreadMessageId;
  final Future<void> Function(String) onSendMessage;
  final Future<bool> Function(
    CommunityRunInvitation invitation,
    bool accept,
  ) onRespondInvitation;
  final Future<bool> Function(
    CommunityRunInvitation invitation,
  ) onCancelInvitation;
  final bool isLoading;
  final bool isSending;

  const _FriendChatPanel({
    super.key,
    required this.friend,
    required this.entries,
    required this.firstUnreadMessageId,
    required this.onSendMessage,
    required this.onRespondInvitation,
    required this.onCancelInvitation,
    required this.isLoading,
    required this.isSending,
  });

  @override
  State<_FriendChatPanel> createState() => _FriendChatPanelState();
}

class _FriendChatPanelState extends State<_FriendChatPanel> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _entryKeys = {};

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleInitialScroll();
    });
  }

  String _entryKey(_CommunityChatEntry entry) {
    if (entry.type == _CommunityChatEntryType.message) {
      return 'message-${entry.message!.id}';
    }

    return 'invitation-${entry.invitation!.id}';
  }

  void _scheduleInitialScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _scrollToTarget();
    });
  }

  @override
  void didUpdateWidget(
    covariant _FriendChatPanel oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    final entriesChanged = oldWidget.entries.length != widget.entries.length;

    final firstUnreadChanged =
        oldWidget.firstUnreadMessageId != widget.firstUnreadMessageId;

    final loadingFinished = oldWidget.isLoading && !widget.isLoading;

    if (entriesChanged || firstUnreadChanged || loadingFinished) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        _scrollToTarget();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTarget() {
    if (widget.entries.isEmpty) {
      return;
    }

    final firstUnreadMessageId = widget.firstUnreadMessageId;

    // 沒有未讀訊息，就直接顯示最新內容
    if (firstUnreadMessageId == null) {
      _scrollToBottom();
      return;
    }

    _CommunityChatEntry? target;

    for (final entry in widget.entries) {
      if (entry.type == _CommunityChatEntryType.message &&
          entry.message?.id == firstUnreadMessageId) {
        target = entry;
        break;
      }
    }

    // 找不到指定訊息，也直接到底
    if (target == null) {
      _scrollToBottom();
      return;
    }

    final targetContext = _entryKeys[_entryKey(target)]?.currentContext;

    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(
          milliseconds: 300,
        ),
        curve: Curves.easeOut,
        alignment: 0.15,
      );

      return;
    }

    // 目標尚未 build 出來，先到底部讓 ListView 建立更多 widget
    if (!_scrollController.hasClients) {
      return;
    }

    _scrollController.jumpTo(
      _scrollController.position.maxScrollExtent,
    );

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!mounted) {
          return;
        }

        final retryContext = _entryKeys[_entryKey(target!)]?.currentContext;

        if (retryContext == null) {
          return;
        }

        Scrollable.ensureVisible(
          retryContext,
          duration: const Duration(
            milliseconds: 300,
          ),
          curve: Curves.easeOut,
          alignment: 0.15,
        );
      },
    );
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }

    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(
        milliseconds: 300,
      ),
      curve: Curves.easeOut,
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();

    if (text.isEmpty || widget.isSending) {
      return;
    }

    _controller.clear();

    await widget.onSendMessage(text);

    if (!mounted) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: communityCardDecoration(),
                child: Row(
                  children: [
                    CommunityAvatar(initial: widget.friend.initial),
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
                          const Text(
                            '運動好友',
                            style: communityMetaStyle,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (widget.isLoading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (widget.entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('目前還沒有訊息'),
                  ),
                )
              else
                ...widget.entries.map(
                  (entry) {
                    if (entry.type == _CommunityChatEntryType.message) {
                      final message = entry.message!;
                      final key = _entryKeys.putIfAbsent(
                        _entryKey(entry),
                        () => GlobalKey(),
                      );
                      final isFirstUnread =
                          widget.firstUnreadMessageId != null &&
                              message.id == widget.firstUnreadMessageId;

                      return Column(
                        key: key,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (isFirstUnread) ...[
                            const _UnreadDivider(),
                            const SizedBox(height: 12),
                          ],
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: 12,
                            ),
                            child: Align(
                              alignment: message.isMine
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 280,
                                ),
                                child: _TextMessageBubble(
                                  text: message.content,
                                  isMine: message.isMine,
                                  timestamp: _formatChatTime(
                                    message.createdAt,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    final invitation = entry.invitation!;

                    final isMine = invitation.inviterId == UserSession.memberId;
                    final key = _entryKeys.putIfAbsent(
                      _entryKey(entry),
                      () => GlobalKey(),
                    );

                    return Padding(
                      key: key,
                      padding: const EdgeInsets.only(
                        bottom: 12,
                      ),
                      child: Align(
                        alignment: isMine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 300,
                          ),
                          child: _BackendInvitationBubble(
                            invitation: invitation,
                            isMine: isMine,
                            onAccept: () => widget.onRespondInvitation(
                              invitation,
                              true,
                            ),
                            onReject: () => widget.onRespondInvitation(
                              invitation,
                              false,
                            ),
                            onCancel: () => widget.onCancelInvitation(
                              invitation,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
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
                      onPressed: value.text.trim().isEmpty || widget.isSending
                          ? null
                          : _send,
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

class _UnreadDivider extends StatelessWidget {
  const _UnreadDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: Divider(
            color: Color(0xFFCBD5E1),
            thickness: 1,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 10,
          ),
          child: Text(
            '未讀訊息',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: Color(0xFFCBD5E1),
            thickness: 1,
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

String _formatChatTime(DateTime dateTime) {
  final local = dateTime.toLocal();

  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');

  return '$hour:$minute';
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
          if (invitation.targetDistance != null) ...[
            const SizedBox(height: 4),
            Text(
              '距離：${invitation.targetDistance}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
          ],
          if (invitation.targetDuration != null) ...[
            const SizedBox(height: 4),
            Text(
              '時長：${invitation.targetDuration}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
          ],
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

class _FriendRequestCard extends StatelessWidget {
  final CommunityFriendRequest request;
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
      decoration: communityCardDecoration(),
      child: Row(
        children: [
          CommunityAvatar(initial: request.sender.initial),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.sender.name,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  '想與你成為好友',
                  style: communityMetaStyle,
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
  final CommunityFriendRequest request;
  final VoidCallback onCancel;

  const _PendingFriendCard({
    required this.request,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: communityCardDecoration(),
      child: Row(
        children: [
          CommunityAvatar(
            initial: request.receiver.initial,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.receiver.name,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      color: Color(0xFF718096),
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '請求待處理',
                      style: communityMetaStyle,
                    ),
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
      decoration: communityCardDecoration(),
      child: Row(
        children: [
          CommunityAvatar(initial: initial),
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
                  style: communityMetaStyle,
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
        style: communityButtonStyle(isPrimary),
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
              style: communityButtonStyle(isPrimary),
              child: text,
            )
          : TextButton.icon(
              onPressed: onTap,
              style: communityButtonStyle(isPrimary),
              icon: Icon(icon, size: 15),
              label: text,
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

class _GroupsPanel extends StatefulWidget {
  final VoidCallback onBack;
  final GroupStore groupStore;
  final FriendStore friendStore;
  final GroupInvitationStore groupInvitationStore;
  final ValueChanged<CommunityGroup> onGroupDetailTap;
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
    required this.groupStore,
    required this.friendStore,
    required this.groupInvitationStore,
    required this.onGroupDetailTap,
    required this.onMessageTap,
    required this.onSystemMessage,
    required this.onScheduleEventReminder,
  });

  @override
  State<_GroupsPanel> createState() => _GroupsPanelState();
}

class _BackendInvitationBubble extends StatelessWidget {
  final CommunityRunInvitation invitation;
  final bool isMine;
  final Future<bool> Function()? onAccept;
  final Future<bool> Function()? onReject;
  final Future<bool> Function()? onCancel;

  const _BackendInvitationBubble({
    required this.invitation,
    required this.isMine,
    this.onAccept,
    this.onReject,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final scheduled = invitation.scheduledAt.toLocal();

    final date =
        '${scheduled.year}/${scheduled.month.toString().padLeft(2, '0')}/${scheduled.day.toString().padLeft(2, '0')}';

    final time =
        '${scheduled.hour.toString().padLeft(2, '0')}:${scheduled.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isMine ? const Color(0xFFF3F4F6) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.directions_run,
                size: 17,
              ),
              SizedBox(width: 8),
              Text(
                '跑步邀請',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '日期：$date',
          ),
          const SizedBox(height: 4),
          Text(
            '時間：$time',
          ),
          if (invitation.targetDistanceKm != null) ...[
            const SizedBox(height: 4),
            Text(
              '距離：${invitation.targetDistanceKm} km',
            ),
          ],
          if (invitation.targetDurationMinutes != null) ...[
            const SizedBox(height: 4),
            Text(
              '時長：${invitation.targetDurationMinutes} 分鐘',
            ),
          ],
          if (invitation.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(invitation.notes),
          ],
          const SizedBox(height: 10),
          if (!isMine && invitation.status == 'pending')
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await onReject?.call();
                    },
                    child: const Text(
                      '拒絕',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await onAccept?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text(
                      '接受',
                    ),
                  ),
                ),
              ],
            )
          else if (isMine && invitation.status == 'pending')
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  await onCancel?.call();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  side: const BorderSide(
                    color: Color(0xFFFCA5A5),
                  ),
                ),
                child: const Text(
                  '取消邀請',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            )
          else
            Text(
              _runInvitationStatusText(
                invitation.status,
              ),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }
}

String _runInvitationStatusText(
  String status,
) {
  switch (status) {
    case 'accepted':
      return '已接受';

    case 'rejected':
      return '已拒絕';

    case 'cancelled':
      return '已取消';

    case 'pending':
    default:
      return '等待回覆';
  }
}

class _GroupsPanelState extends State<_GroupsPanel> {
  static const String _currentUserName = 'Catherine';
  int _selectedTab = 0;
  bool _isCreateGroupOpen = false;
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _groupDescriptionController =
      TextEditingController();
  bool _createPrivateGroup = false;
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

  String _groupSearchKeyword = '';

  @override
  void dispose() {
    _groupNameController.dispose();
    _groupDescriptionController.dispose();
    super.dispose();
  }

  void _searchGroups(String keyword) {
    _groupSearchKeyword = keyword.trim();

    if (_selectedTab == 0) {
      widget.groupStore.loadGroups(
        search: _groupSearchKeyword,
      );
    } else {
      widget.groupStore.loadDiscoverGroups(
        search: _groupSearchKeyword,
      );
    }
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

  Future<void> _createGroup() async {
    final name = _groupNameController.text.trim();
    final description = _groupDescriptionController.text.trim();

    if (name.isEmpty || description.isEmpty) {
      return;
    }

    final success = await widget.groupStore.createGroup(
      name: name,
      description: description,
      isPrivate: _createPrivateGroup,
      exerciseType: 'mixed',
      weeklyGoalTarget: 20,
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      _showMessage(
        widget.groupStore.errorMessage ?? '建立群組失敗',
      );
      return;
    }

    _selectedTab = 0;

    _closeCreateGroup();

    _showMessage(
      '已建立群組「$name」',
    );
  }

  Future<void> _respondGroupInvitation(
    CommunityGroupInvitation invitation,
    bool accept,
  ) async {
    final success = await widget.groupInvitationStore.respondInvitation(
      invitationId: invitation.id,
      accept: accept,
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      _showMessage(
        widget.groupInvitationStore.errorMessage ?? '群組邀請處理失敗',
      );
      return;
    }

    if (accept) {
      await widget.groupStore.loadGroups();

      if (!mounted) {
        return;
      }

      _showMessage(
        '已加入「${invitation.groupName}」',
      );
    } else {
      _showMessage(
        '已拒絕「${invitation.groupName}」的邀請',
      );
    }
  }

  Future<void> _viewBackendGroup(
    CommunityGroup group,
  ) async {
    final success = await widget.groupStore.loadGroup(
      group.id,
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      _showMessage(
        widget.groupStore.errorMessage ?? '群組資料載入失敗',
      );
      return;
    }

    final detail = widget.groupStore.selectedGroup;

    if (detail == null) {
      _showMessage('群組資料載入失敗');
      return;
    }

    widget.onGroupDetailTap(detail);
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
    _showMessage('已送出加入 ${group.name} 的申請，等待群組邀請通過');
  }

  @override
  Widget build(BuildContext context) {
    final groupInvitations = widget.groupInvitationStore.pendingInvitations;

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
        if (groupInvitations.isNotEmpty) ...[
          const SizedBox(height: 14),
          CommunitySectionLabel(
            '待處理邀請 (${groupInvitations.length})',
          ),
          const SizedBox(height: 12),
          ...List.generate(
            groupInvitations.length,
            (index) {
              final invitation = groupInvitations[index];

              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == groupInvitations.length - 1 ? 0 : 12,
                ),
                child: GroupInvitationCard(
                  invitation: invitation,
                  isResponding: widget.groupInvitationStore.isResponding,
                  onAccept: () {
                    _respondGroupInvitation(
                      invitation,
                      true,
                    );
                  },
                  onReject: () {
                    _respondGroupInvitation(
                      invitation,
                      false,
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _GroupSearchField(
                onChanged: _searchGroups,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: GroupTabButton(
                label: '我的群組 (${widget.groupStore.groups.length})',
                isSelected: _selectedTab == 0,
                onTap: () {
                  setState(() {
                    _selectedTab = 0;
                  });

                  widget.groupStore.loadGroups(
                    search: _groupSearchKeyword,
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GroupTabButton(
                label: '探索',
                isSelected: _selectedTab == 1,
                onTap: () {
                  setState(() {
                    _selectedTab = 1;
                  });

                  widget.groupStore.loadDiscoverGroups(
                    search: _groupSearchKeyword,
                  );
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
        CommunitySectionLabel(
          _selectedTab == 0
              ? '我的群組 (${widget.groupStore.groups.length})'
              : '推薦群組',
        ),
        const SizedBox(height: 12),
        if (_selectedTab == 0) ...[
          if (widget.groupStore.isLoading && widget.groupStore.groups.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (widget.groupStore.groups.isEmpty)
            const CommunityEmptyState(
              text: '目前還沒有群組。',
            )
          else
            ...List.generate(
              widget.groupStore.groups.length,
              (index) {
                final group = widget.groupStore.groups[index];

                return Padding(
                  padding: EdgeInsets.only(
                    bottom:
                        index == widget.groupStore.groups.length - 1 ? 0 : 12,
                  ),
                  child: _GroupCard(
                    name: group.name,
                    description: group.description,
                    members: group.memberCount,

                    // 目前尚未串 TrainingLog 群組統計
                    weeklyGoalCurrent: 0,

                    weeklyGoalTarget: group.weeklyGoalTarget,

                    progress: 0,

                    actionLabel: '查看群組',

                    isPrivate: group.isPrivate,

                    exerciseType: group.exerciseType,

                    showCrown: group.owner.id == UserSession.memberId,

                    showSettings: false,

                    onActionTap: () {
                      _viewBackendGroup(group);
                    },
                  ),
                );
              },
            ),
        ] else ...[
          if (widget.groupStore.isLoading &&
              widget.groupStore.discoverGroups.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (widget.groupStore.discoverGroups.isEmpty)
            const CommunityEmptyState(
              text: '目前沒有推薦群組。',
            )
          else
            ...List.generate(
              widget.groupStore.discoverGroups.length,
              (index) {
                final group = widget.groupStore.discoverGroups[index];

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == widget.groupStore.discoverGroups.length - 1
                        ? 0
                        : 12,
                  ),
                  child: _SuggestedGroupCard(
                    name: group.name,
                    description: group.description,
                    members: group.memberCount,
                    actionLabel: group.isPrivate ? '申請加入' : '加入群組',
                    isPrivate: group.isPrivate,
                    isDisabled: false,
                    onTap: group.isPrivate
                        ? () async {
                            final success =
                                await widget.groupStore.requestJoinGroup(
                              group.id,
                            );

                            if (!mounted) {
                              return;
                            }

                            if (!success) {
                              _showMessage(
                                widget.groupStore.errorMessage ?? '申請加入群組失敗',
                              );
                              return;
                            }

                            _showMessage(
                              '已送出加入「${group.name}」的申請',
                            );
                          }
                        : () async {
                            final success = await widget.groupStore.joinGroup(
                              group.id,
                            );

                            if (!mounted) {
                              return;
                            }

                            if (!success) {
                              _showMessage(
                                widget.groupStore.errorMessage ?? '加入群組失敗',
                              );
                              return;
                            }

                            _showMessage(
                              '已加入「${group.name}」',
                            );
                          },
                  ),
                );
              },
            ),
        ],
      ],
    );
  }
}

class _GroupSearchField extends StatefulWidget {
  final ValueChanged<String> onChanged;

  const _GroupSearchField({
    required this.onChanged,
  });

  @override
  State<_GroupSearchField> createState() => _GroupSearchFieldState();
}

class _GroupSearchFieldState extends State<_GroupSearchField> {
  final TextEditingController _controller = TextEditingController();

  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged(String value) {
    setState(() {});

    _debounce?.cancel();

    _debounce = Timer(
      const Duration(milliseconds: 400),
      () {
        widget.onChanged(
          value.trim(),
        );
      },
    );
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();

    widget.onChanged('');

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search,
            color: Color(0xFFA0AEC0),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: _handleChanged,
              decoration: const InputDecoration(
                hintText: '搜尋群組...',
                hintStyle: TextStyle(
                  color: Color(0xFF718096),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          if (_controller.text.isNotEmpty)
            InkWell(
              onTap: _clear,
              borderRadius: BorderRadius.circular(999),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  color: Color(0xFFA0AEC0),
                  size: 18,
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
      decoration: communityCardDecoration(),
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
                      style: communityMetaStyle,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.people_outline,
                            color: Color(0xFF718096), size: 14),
                        const SizedBox(width: 4),
                        Text('$members/30 人', style: communityMetaStyle),
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
              style: communityButtonStyle(true).copyWith(
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
      decoration: communityCardDecoration(),
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
                      style: communityMetaStyle,
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Icon(Icons.people_outline,
                            color: Color(0xFF718096), size: 14),
                        const SizedBox(width: 4),
                        Text('$members/30 人', style: communityMetaStyle),
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
                    style: communityButtonStyle(true),
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
                GroupCardIconButton(
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
                      groupWeeklyGoalLabel(
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
  bool get _canDirectInvite => _isOwner;

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
    if (!_isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('只有創立群組的人可以更改每週目標')),
      );
      return;
    }

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
                      '設定這個群組每週想完成的${groupMetricUnit(_group.exerciseType)}。',
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
                                  groupMetricUnit(_group.exerciseType),
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
                            progressText: groupWeeklyGoalLabel(
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
                  _canDirectInvite ? '邀請好友加入群組' : '請求創群者邀請成員',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _canDirectInvite
                      ? '送出邀請後，對方必須接受群組邀請才會正式加入。'
                      : '你可以推薦自己的好友，但必須先由創群者送出邀請。',
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
                      leading: CommunityAvatar(initial: friend.initial),
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
    final totalSquats = group.memberPreview.fold<int>(
      0,
      (sum, member) => sum + member.totalSquats,
    );

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
                child: Text(_canDirectInvite ? '邀請好友進群組' : '請求創群者邀請成員'),
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
              decoration: communityCardDecoration(),
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
                                if (_isOwner)
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
                        child: GroupStatTile(
                          label: '成員',
                          value: '${group.members}',
                          icon: Icons.people_outline,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _GroupTotalsTile(
                          totalRuns: group.runs,
                          totalSquats: totalSquats,
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
                            if (_isOwner) ...[
                              TextButton.icon(
                                onPressed: _openWeeklyGoalSheet,
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF64748B),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
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
                            ],
                            Text(
                              groupWeeklyGoalLabel(
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
                  child: GroupTabButton(
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
                  child: GroupTabButton(
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
                style: communityButtonStyle(true),
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
              GroupActivityForm(
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
                const CommunityEmptyState(text: '目前沒有成員可顯示。')
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
                const CommunityEmptyState(text: '目前沒有最近的活動。')
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

class _GroupTotalsTile extends StatelessWidget {
  final int totalRuns;
  final int totalSquats;

  const _GroupTotalsTile({
    required this.totalRuns,
    required this.totalSquats,
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
          const Row(
            children: [
              Icon(Icons.trending_up, size: 14, color: Color(0xFF94A3B8)),
              SizedBox(width: 5),
              Text(
                '總累積次數',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _GroupMetricLine(
            label: '慢跑',
            value: '$totalRuns 次',
          ),
          const SizedBox(height: 4),
          _GroupMetricLine(
            label: '深蹲',
            value: '$totalSquats 次',
          ),
        ],
      ),
    );
  }
}

class _GroupMetricLine extends StatelessWidget {
  final String label;
  final String value;

  const _GroupMetricLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w900,
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
      decoration: communityCardDecoration(),
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
                      style: communityMetaStyle,
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.calendar_today_outlined,
                        size: 14, color: Color(0xFF718096)),
                    const SizedBox(width: 4),
                    Text('本週 ${member.runsThisWeek} 次',
                        style: communityMetaStyle),
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
                      style: communityMetaStyle,
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.calendar_today_outlined,
                        size: 14, color: Color(0xFF718096)),
                    const SizedBox(width: 4),
                    Text('本週 ${member.squatsThisWeek} 次',
                        style: communityMetaStyle),
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
            GroupCardIconButton(
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
      decoration: communityCardDecoration(),
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
  final int count;

  const _FriendRequestsButton({
    required this.onTap,
    required this.count,
  });

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
            if (count > 0)
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
                  child: Text(
                    '$count',
                    style: const TextStyle(
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

  List<({int index, CommunityPost post})> get _profilePosts => store.posts
      .asMap()
      .entries
      .where((entry) => entry.value.name == profileName)
      .map((entry) => (index: entry.key, post: entry.value))
      .toList(growable: false);

  bool get _isCurrentUserProfile => profileName == UserSession.displayName;

  List<_ReplyEntry> get _replies => const <_ReplyEntry>[];

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
                      _ArticleTab(
                        posts: _profilePosts,
                        isCurrentUserProfile: _isCurrentUserProfile,
                        onDeletePost: (index) => store.deletePost(index),
                      ),
                      _RepliesTab(
                        replies: _replies,
                        profileName: profileName,
                        isCurrentUserProfile: _isCurrentUserProfile,
                      ),
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
  final List<({int index, CommunityPost post})> posts;
  final bool isCurrentUserProfile;
  final ValueChanged<int> onDeletePost;

  const _ArticleTab({
    required this.posts,
    required this.isCurrentUserProfile,
    required this.onDeletePost,
  });

  Future<void> _confirmDelete(BuildContext context, int index) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('刪除貼文'),
          content: const Text('確定要刪除這則貼文嗎？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                '刪除',
                style: TextStyle(color: Color(0xFFDC2626)),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      onDeletePost(index);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('貼文已刪除')),
        );
      }
    }
  }

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
        final entry = posts[index];
        return _ProfilePostCard(
          post: entry.post,
          trailing: isCurrentUserProfile
              ? IconButton(
                  onPressed: () => _confirmDelete(context, entry.index),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFDC2626),
                  ),
                  tooltip: '刪除貼文',
                )
              : null,
        );
      },
    );
  }
}

class _RepliesTab extends StatelessWidget {
  final List<_ReplyEntry> replies;
  final String profileName;
  final bool isCurrentUserProfile;

  const _RepliesTab({
    required this.replies,
    required this.profileName,
    required this.isCurrentUserProfile,
  });

  @override
  Widget build(BuildContext context) {
    if (replies.isEmpty) {
      return _EmptyProfileState(
        title: '目前還沒有回覆',
        subtitle: isCurrentUserProfile
            ? '其他人對你的貼文的回覆將顯示在這裡。'
            : '其他人對 $profileName 的貼文的回覆將顯示在這裡。',
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
              Row(
                children: [
                  const CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.black,
                    child: Icon(Icons.reply, size: 14, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isCurrentUserProfile
                        ? '有人回覆了你的貼文'
                        : '有人回覆了 $profileName 的貼文',
                    style: const TextStyle(
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
  final Widget? trailing;

  const _ProfilePostCard({
    required this.post,
    this.trailing,
  });

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
              if (trailing != null) trailing!,
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
            WorkoutPlanCard(plan: post.plan!),
          ],
          if (post.recipe != null) ...[
            const SizedBox(height: 12),
            RecipeCard(recipe: post.recipe!),
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

class _CommentsSheet extends StatefulWidget {
  final CommunityStore store;
  final int postIndex;

  const _CommentsSheet({required this.store, required this.postIndex});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  late final TextEditingController _controller;

  List<Map<String, dynamic>> _comments = [];

  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController();

    _loadComments();
  }

  Future<void> _loadComments() async {
    if (widget.postIndex < 0 || widget.postIndex >= widget.store.posts.length) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      return;
    }

    final post = widget.store.posts[widget.postIndex];

    final comments = await widget.store.loadComments(
      post.id,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _comments = comments;
      _isLoading = false;
    });
  }

  Future<void> _submitComment() async {
    final text = _controller.text.trim();

    if (text.isEmpty || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final success = await widget.store.addComment(
      widget.postIndex,
      text,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      _controller.clear();

      FocusScope.of(context).unfocus();

      await _loadComments();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.store.errorMessage ?? '留言失敗',
          ),
        ),
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(
              18,
              18,
              18,
              20,
            ),
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
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 24,
                    ),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_comments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(
                      bottom: 16,
                    ),
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
                    constraints: const BoxConstraints(
                      maxHeight: 260,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _comments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (
                        context,
                        commentIndex,
                      ) {
                        final comment = _comments[commentIndex];

                        final name =
                            (comment['member_name'] ?? '社群成員').toString();

                        final initial =
                            (comment['member_initial'] ?? 'U').toString();

                        final content = (comment['content'] ?? '').toString();

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CommunityAvatar(
                                initial: initial.isEmpty ? 'U' : initial,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 4,
                                    ),
                                    Text(
                                      content,
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
                        controller: _controller,
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
                      valueListenable: _controller,
                      builder: (
                        context,
                        value,
                        child,
                      ) {
                        final canSubmit =
                            value.text.trim().isNotEmpty && !_isSubmitting;

                        return ElevatedButton(
                          onPressed: canSubmit ? _submitComment : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF65C16F),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFDDEDDD),
                            disabledForegroundColor: const Color(0xFF8DAA90),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  '送出',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
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
