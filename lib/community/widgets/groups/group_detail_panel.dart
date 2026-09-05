import 'package:flutter/material.dart';

import '../../../services/user_session.dart';
import '../../group_activity_store.dart';
import '../../group_store.dart';
import '../../group_invitation_store.dart';
import '../../models/community_friend.dart';
import '../../models/community_group.dart';
import '../common/community_avatar.dart';
import '../common/community_card_styles.dart';
import '../common/community_section_label.dart';
import '../common/community_empty_state.dart';
import '../common/community_button.dart';
import '../../utils/group_formatters.dart';
import 'group_stat_tile.dart';
import 'group_activity_card.dart';
import 'group_activity_form.dart';
import 'group_member_card.dart';
import 'group_tab_button.dart';
import '../../models/community_group_activity.dart';

class GroupDetailPanel extends StatefulWidget {
  final CommunityGroup group;
  final List<CommunityFriend> friends;
  final GroupStore groupStore;
  final GroupInvitationStore groupInvitationStore;
  final GroupActivityStore groupActivityStore;
  final VoidCallback onBack;

  const GroupDetailPanel({
    super.key,
    required this.group,
    required this.friends,
    required this.groupStore,
    required this.groupInvitationStore,
    required this.groupActivityStore,
    required this.onBack,
  });

  @override
  State<GroupDetailPanel> createState() => GroupDetailPanelState();
}

class GroupDetailPanelState extends State<GroupDetailPanel> {
  int _selectedTab = 0;
  int? _updatingActivityId;
  bool _isCreateActivityOpen = false;
  final TextEditingController _eventTitleController = TextEditingController();

  final TextEditingController _eventDateController = TextEditingController();

  final TextEditingController _eventNotesController = TextEditingController();

  String _selectedEventActivityType = 'slow_jogging';
  String? _selectedEventTime;

  final List<String> _eventTimeOptions = const [
    '06:00 AM',
    '07:00 AM',
    '08:00 AM',
    '09:00 AM',
    '10:00 AM',
    '05:00 PM',
    '06:00 PM',
    '07:00 PM',
    '08:00 PM',
  ];

  CommunityGroup get group {
    final selectedGroup = widget.groupStore.selectedGroup;

    if (selectedGroup != null && selectedGroup.id == widget.group.id) {
      return selectedGroup;
    }

    return widget.group;
  }

  List<CommunityFriend> get friends => widget.friends;

  GroupStore get groupStore => widget.groupStore;

  GroupInvitationStore get groupInvitationStore => widget.groupInvitationStore;

  GroupActivityStore get groupActivityStore => widget.groupActivityStore;

  @override
  void initState() {
    super.initState();

    final isOwner = widget.group.owner.id == UserSession.memberId;

    if (isOwner) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await widget.groupStore.loadJoinRequests(
          widget.group.id,
        );

        if (!mounted) {
          return;
        }

        setState(() {});
      });
    }
  }

  Future<void> _respondJoinRequest(
    int requestId,
    bool accept,
  ) async {
    final success = await groupStore.respondJoinRequest(
      groupId: group.id,
      requestId: requestId,
      accept: accept,
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            groupStore.errorMessage ?? '處理加入申請失敗',
          ),
        ),
      );

      return;
    }

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? accept
                  ? '已接受加入申請'
                  : '已拒絕加入申請'
              : groupStore.errorMessage ?? '處理加入申請失敗',
        ),
      ),
    );

    if (success) {
      setState(() {});
    }
  }

  Future<void> _joinActivity(
    CommunityGroupActivity activity,
  ) async {
    if (_updatingActivityId != null) {
      return;
    }

    setState(() {
      _updatingActivityId = activity.id;
    });

    final success = await groupActivityStore.joinActivity(
      groupId: group.id,
      activityId: activity.id,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _updatingActivityId = null;
    });

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            groupActivityStore.errorMessage ?? '加入活動失敗',
          ),
        ),
      );
    }
  }

  Future<void> _leaveActivity(
    CommunityGroupActivity activity,
  ) async {
    if (_updatingActivityId != null) {
      return;
    }

    setState(() {
      _updatingActivityId = activity.id;
    });

    final success = await groupActivityStore.leaveActivity(
      groupId: group.id,
      activityId: activity.id,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _updatingActivityId = null;
    });

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            groupActivityStore.errorMessage ?? '取消參加失敗',
          ),
        ),
      );
    }
  }

  Future<void> _openInviteSheet() async {
    final isOwner = group.owner.id == UserSession.memberId;

    if (!isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '只有群組創立者可以邀請成員',
          ),
        ),
      );
      return;
    }

    if (group.memberCount >= 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '此群組已達 30 人上限',
          ),
        ),
      );
      return;
    }

    final memberIds = group.members.map((item) => item.member.id).toSet();

    final availableFriends = friends
        .where(
          (friend) =>
              friend.id != UserSession.memberId &&
              !memberIds.contains(friend.id),
        )
        .toList();

    if (availableFriends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '目前沒有可邀請的好友',
          ),
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<CommunityFriend>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              18,
              14,
              18,
              18,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '邀請好友加入群組',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '送出邀請後，對方接受才會正式加入群組。',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                ...availableFriends.map(
                  (friend) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CommunityAvatar(
                      initial: friend.initial,
                    ),
                    title: Text(
                      friend.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                    ),
                    onTap: () {
                      Navigator.of(
                        sheetContext,
                      ).pop(friend);
                    },
                  ),
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

    final success = await groupInvitationStore.sendInvitation(
      groupId: group.id,
      inviteeId: selected.id,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '已送出群組邀請給 ${selected.name}'
              : groupInvitationStore.errorMessage ?? '群組邀請送出失敗',
        ),
      ),
    );
  }

  String _formatJoinedDate(
    DateTime dateTime,
  ) {
    final local = dateTime.toLocal();

    final month = local.month.toString().padLeft(2, '0');

    final day = local.day.toString().padLeft(2, '0');

    return '${local.year}/$month/$day';
  }

  DateTime? _buildScheduledAt() {
    final date = _eventDateController.text.trim();
    final time = _selectedEventTime;

    if (date.isEmpty || time == null) {
      return null;
    }

    final dateMatch = RegExp(
      r'^(\d{4})/(\d{2})/(\d{2})$',
    ).firstMatch(date);

    final timeMatch = RegExp(
      r'^(\d{2}):(\d{2})\s*(AM|PM)$',
    ).firstMatch(time);

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

  Future<void> _submitBackendActivity() async {
    final title = _eventTitleController.text.trim();
    final scheduledAt = _buildScheduledAt();

    if (title.isEmpty || scheduledAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請填寫活動名稱、日期與時間'),
        ),
      );
      return;
    }

    final success = await widget.groupActivityStore.createActivity(
      groupId: widget.group.id,
      title: title,
      exerciseType: _selectedEventActivityType,
      scheduledAt: scheduledAt,
      notes: _eventNotesController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.groupActivityStore.errorMessage ?? '建立群組活動失敗',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isCreateActivityOpen = false;

      _eventTitleController.clear();
      _eventDateController.clear();
      _eventNotesController.clear();

      _selectedEventActivityType = 'slow_jogging';
      _selectedEventTime = null;
      _selectedTab = 1;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已建立群組活動：$title',
        ),
      ),
    );
  }

  void _openCreateActivity() {
    setState(() {
      _isCreateActivityOpen = !_isCreateActivityOpen;
    });
  }

  Future<void> _pickEventDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(
        now.year + 2,
        12,
        31,
      ),
    );

    if (picked == null) {
      return;
    }

    _eventDateController.text = '${picked.year}/'
        '${picked.month.toString().padLeft(2, '0')}/'
        '${picked.day.toString().padLeft(2, '0')}';

    setState(() {});
  }

  @override
  void dispose() {
    _eventTitleController.dispose();
    _eventDateController.dispose();
    _eventNotesController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = group.owner.id == UserSession.memberId;

    final activities = groupActivityStore.activitiesFor(group.id);

    final joinRequests = groupStore.joinRequestsFor(group.id);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        18,
        14,
        18,
        24,
      ),
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
                    child: const Icon(
                      Icons.groups_2_outlined,
                      color: Colors.white,
                      size: 31,
                    ),
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
                            if (isOwner)
                              const Padding(
                                padding: EdgeInsets.only(
                                  right: 6,
                                ),
                                child: Text(
                                  '👑',
                                  style: TextStyle(
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            Icon(
                              group.isPrivate
                                  ? Icons.lock_outline
                                  : Icons.public,
                              color: const Color(
                                0xFF94A3B8,
                              ),
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
                        const SizedBox(height: 8),
                        Text(
                          '創立者：${group.owner.name}',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
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
                      value: '${group.memberCount}',
                      icon: Icons.people_outline,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(
                          0xFFF8FAFC,
                        ),
                        borderRadius: BorderRadius.circular(
                          16,
                        ),
                        border: Border.all(
                          color: const Color(
                            0xFFE2E8F0,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.emoji_events_outlined,
                                size: 14,
                                color: Color(
                                  0xFF94A3B8,
                                ),
                              ),
                              SizedBox(width: 5),
                              Text(
                                '每週目標',
                                style: TextStyle(
                                  color: Color(
                                    0xFF64748B,
                                  ),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 8,
                          ),
                          Text(
                            '${group.weeklyGoalTarget} '
                            '${groupMetricUnit(group.exerciseType)}',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (isOwner) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: _openInviteSheet,
                    icon: const Icon(
                      Icons.person_add_alt_1_outlined,
                      size: 17,
                    ),
                    label: const Text(
                      '邀請好友加入群組',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(
                        color: Color(0xFFD1D5DB),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: GroupTabButton(
                label: '成員 (${group.members.length})',
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
            if (isOwner) ...[
              const SizedBox(width: 8),
              Expanded(
                child: GroupTabButton(
                  label: '申請 (${joinRequests.length})',
                  isSelected: _selectedTab == 2,
                  onTap: () {
                    setState(() {
                      _selectedTab = 2;
                    });
                  },
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        if (_selectedTab == 0) ...[
          CommunitySectionLabel(
            '成員 (${group.members.length})',
          ),
          const SizedBox(height: 12),
          if (group.members.isEmpty)
            const CommunityEmptyState(
              text: '目前沒有成員可顯示。',
            )
          else
            ...group.members.map(
              (groupMember) {
                final member = groupMember.member;

                final isGroupOwner = member.id == group.owner.id;

                return Padding(
                  padding: const EdgeInsets.only(
                    bottom: 12,
                  ),
                  child: BackendGroupMemberCard(
                    name: member.name,
                    initial: member.initial,
                    joinedDate: _formatJoinedDate(
                      groupMember.joinedAt,
                    ),
                    isOwner: isGroupOwner,
                  ),
                );
              },
            ),
        ] else if (_selectedTab == 1) ...[
          SizedBox(
            width: double.infinity,
            height: 46,
            child: TextButton.icon(
              onPressed: widget.groupActivityStore.isCreating
                  ? null
                  : _openCreateActivity,
              style: communityButtonStyle(true),
              icon: const Icon(
                Icons.play_arrow_rounded,
                size: 18,
              ),
              label: Text(
                _isCreateActivityOpen ? '隱藏群組活動表單' : '建立群組活動',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          if (_isCreateActivityOpen) ...[
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
              onCreate: _submitBackendActivity,
            ),
          ],
          const SizedBox(height: 14),
          CommunitySectionLabel(
            '最近活動 (${activities.length})',
          ),
          const SizedBox(height: 12),
          if (groupActivityStore.isLoading && activities.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (activities.isEmpty)
            const CommunityEmptyState(
              text: '目前還沒有群組活動。',
            )
          else
            ...activities.map(
              (activity) => Padding(
                padding: const EdgeInsets.only(
                  bottom: 12,
                ),
                child: BackendGroupActivityCard(
                  activity: activity,
                  isUpdating: _updatingActivityId == activity.id,
                  onJoin: () {
                    _joinActivity(activity);
                  },
                  onLeave: () {
                    _leaveActivity(activity);
                  },
                ),
              ),
            ),
        ] else ...[
          CommunitySectionLabel(
            '待審核申請 (${joinRequests.length})',
          ),
          const SizedBox(height: 12),
          if (joinRequests.isEmpty)
            const CommunityEmptyState(
              text: '目前沒有待審核的加入申請。',
            )
          else
            ...joinRequests.map(
              (request) => Container(
                margin: const EdgeInsets.only(
                  bottom: 12,
                ),
                padding: const EdgeInsets.all(14),
                decoration: communityCardDecoration(),
                child: Row(
                  children: [
                    CommunityAvatar(
                      initial: request.requester.initial,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        request.requester.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        _respondJoinRequest(
                          request.id,
                          false,
                        );
                      },
                      child: const Text('拒絕'),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: () {
                        _respondJoinRequest(
                          request.id,
                          true,
                        );
                      },
                      style: communityButtonStyle(true),
                      child: const Text('接受'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}
