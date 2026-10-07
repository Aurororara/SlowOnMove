import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:show_on_move/admin/admin_dashboard_screen.dart';

import 'body_record_screen.dart';
import 'badge_collection_screen.dart';
import 'community/community_store.dart';
import 'community/models/community_post.dart';
import 'community/widgets/posts/comments_sheet.dart';
import 'community/widgets/posts/post_card.dart';
import 'community/widgets/posts/post_share_sheet.dart';
import 'edit_profile_screen.dart';
import 'exercise_history_screen.dart';
import 'login_screen.dart';
import 'monthly_recap_screen.dart';
import 'purchase_screen.dart';
import 'services/api_service.dart';
import 'services/badge_progress_service.dart';
import 'services/user_session.dart';
import 'services/line_binding_service.dart';
import 'my_workout_menu_screen.dart';

class ProfileScreen extends StatefulWidget {
  final CommunityStore store;

  const ProfileScreen({
    super.key,
    required this.store,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  int _workoutCount = 0;
  int _totalCalories = 0;
  int _totalSteps = 0;
  int _badgeCount = 0;
  final ApiService _api = ApiService();

  String _exerciseGoal = 'health';
  String _exerciseFrequency = '1_2';

  // LINE 綁定狀態
  bool _lineBound = false;
  bool _lineBusy = false;

  // LINE SDK 只支援 Android / iOS
  bool get _lineSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  String get _fullName => UserSession.displayName;
  String get _email => UserSession.email;

  @override
  void initState() {
    super.initState();

    _fetchProfileData();
    _loadLineBindingStatus();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.store.loadSavedPosts();
    });
  }

  Future<void> _fetchProfileData() async {
    final int currentMemberId = UserSession.memberId;

    var workoutCount = _workoutCount;
    var totalCalories = _totalCalories;
    var totalSteps = _totalSteps;
    var badgeCount = _badgeCount;

    var exerciseGoal = _exerciseGoal;
    var exerciseFrequency = _exerciseFrequency;

    // 取得運動統計
    try {
      final response = await _api.dio.get(
        'training-logs/my-stats/',
      );

      final stats = Map<String, dynamic>.from(response.data);

      workoutCount = (stats['total_time'] as num?)?.toInt() ?? 0;

      totalCalories = (stats['total_calories'] as num?)?.toInt() ?? 0;

      totalSteps = (stats['total_steps'] as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint(
        '抓取運動統計失敗: '
        '${_api.getErrorMessage(e)}',
      );
    }

    // 取得會員資料與運動習慣
    try {
      final memberResponse = await _api.dio.get(
        'members/$currentMemberId/',
      );

      if (memberResponse.statusCode == 200 && memberResponse.data != null) {
        final memberData = Map<String, dynamic>.from(memberResponse.data);
        exerciseGoal = memberData['exercise_goal'] ?? 'health';
        exerciseFrequency = memberData['exercise_frequency'] ?? '1_2';
      }
    } catch (e) {
      debugPrint('抓取運動習慣失敗: ${_api.getErrorMessage(e)}');
    }

    // 取得勳章數量
    try {
      final earnedDates = await BadgeProgressService().loadEarnedDates(
        memberId: currentMemberId,
      );

      badgeCount = earnedDates.length;
    } catch (e) {
      debugPrint('抓取勳章數量失敗: $e');
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _workoutCount = workoutCount;
      _totalCalories = totalCalories;
      _totalSteps = totalSteps;
      _badgeCount = badgeCount;
      _exerciseGoal = exerciseGoal;
      _exerciseFrequency = exerciseFrequency;
      _isLoading = false;
    });
  }

  Future<void> _refreshProfile() async {
    await Future.wait([
      _fetchProfileData(),
      widget.store.loadSavedPosts(),
    ]);
  }

  String _goalLabel(String goal) {
    switch (goal) {
      case 'weight_loss':
        return '減脂';

      case 'muscle_gain':
        return '增肌';

      case 'health':
      default:
        return '維持健康';
    }
  }

  String _frequencyLabel(String frequency) {
    switch (frequency) {
      case '3_4':
        return '每週 3–4 次';

      case '5_plus':
        return '每週 5 次以上';

      case '1_2':
      default:
        return '每週 1–2 次';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final savedCount = widget.store.savedCount;

        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : RefreshIndicator(
                    onRefresh: _refreshProfile,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),

                            // 個人基本資料卡
                            _buildDarkProfileCard(context),

                            const SizedBox(height: 24),

                            // 運動統計
                            _buildStatsGrid(),

                            const SizedBox(height: 32),

                            // 我的資料與紀錄
                            _buildSectionTitle('我的資料與紀錄'),

                            _buildMenuButton(
                              icon: Icons.history,
                              title: '歷史紀錄',
                              subtitle: '查看所有運動紀錄',
                              iconColor: Colors.blueAccent,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ExerciseHistoryScreen(),
                                  ),
                                );
                              },
                            ),

                            _buildMenuButton(
                              icon: Icons.monitor_heart_outlined,
                              title: '健康紀錄',
                              subtitle: '查看身高、體重與血壓變化',
                              iconColor: Colors.redAccent,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const BodyRecordScreen(),
                                  ),
                                );
                              },
                            ),

                            _buildMenuButton(
                              icon: Icons.auto_awesome,
                              title: '月度回顧',
                              subtitle: '查看每個月的跑步 Recap',
                              iconColor: Colors.purpleAccent,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const MonthlyRecapScreen(),
                                  ),
                                );
                              },
                            ),

                            _buildMenuButton(
                              icon: Icons.shopping_bag_outlined,
                              title: '方案購買',
                              subtitle: '查看可購買方案與解鎖內容',
                              iconColor: Colors.amber,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const PurchaseScreen(),
                                  ),
                                );
                              },
                            ),

                            _buildMenuButton(
                              icon: Icons.favorite_border,
                              title: '我的珍藏',
                              subtitle: savedCount == 0
                                  ? '儲存的貼文與運動計畫'
                                  : '目前已收藏 $savedCount 則內容',
                              iconColor: Colors.pinkAccent,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SavedPostsScreen(
                                      store: widget.store,
                                    ),
                                  ),
                                );
                              },
                            ),

                            _buildMenuButton(
                              icon: Icons.fitness_center,
                              title: '我的菜單',
                              subtitle: '查看已套用的運動計畫',
                              iconColor: Colors.greenAccent,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const MyWorkoutMenuScreen(),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 32),

                            // 個人資料
                            _buildSectionTitle('個人資料'),

                            const SizedBox(height: 16),

                            _buildInfoTile(
                              icon: Icons.person_outline,
                              label: '姓名',
                              value: _fullName,
                            ),

                            const SizedBox(height: 12),

                            _buildInfoTile(
                              icon: Icons.mail_outline,
                              label: 'Email',
                              value: _email,
                            ),

                            const SizedBox(height: 24),

                            // 我的運動習慣
                            _buildSectionTitle('我的運動習慣'),

                            const SizedBox(height: 16),

                            _buildInfoTile(
                              icon: Icons.flag_outlined,
                              label: '運動目標',
                              value: _goalLabel(_exerciseGoal),
                            ),

                            const SizedBox(height: 12),

                            _buildInfoTile(
                              icon: Icons.calendar_month_outlined,
                              label: '運動頻率',
                              value: _frequencyLabel(
                                _exerciseFrequency,
                              ),
                            ),

                            const SizedBox(height: 24),

                            // 管理後台 (只對管理員開放)
                            if (UserSession.isAdmin) ...[
                              _buildMenuButton(
                                icon: Icons.admin_panel_settings,
                                title: '管理後台',
                                subtitle: 'Slow On Move 系統監控與管理',
                                iconColor: Colors.black,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const AdminDashboardScreen(),
                                    ),
                                  );
                                },
                              ),
                            ],

                            const SizedBox(height: 32),

                            // LINE 機器人綁定
                            if (_lineSupported)
                              _buildMenuButton(
                                icon: Icons.chat_bubble_outline,
                                title: _lineBound
                                    ? 'LINE 機器人：已綁定'
                                    : '綁定 LINE 機器人',
                                subtitle: _lineBound
                                    ? '點擊可解除綁定'
                                    : '綁定後可在 LINE 收到教練提醒',
                                iconColor: const Color(0xFF06C755),
                                onTap: _onLineTap,
                              ),

                            // 登出
                            _buildLogOutButton(context),

                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }

  Future<void> _loadLineBindingStatus() async {
    if (!_lineSupported) return;

    try {
      final bound = await LineBindingService.isBound();
      if (!mounted) return;
      setState(() => _lineBound = bound);
    } catch (e) {
      debugPrint('查詢 LINE 綁定狀態失敗: ${_api.getErrorMessage(e)}');
    }
  }

  void _showLineMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// 優先讀取後端回傳的 error 訊息（例如「此 LINE 帳號已綁定其他 App 帳號」）
  String _lineErrorMessage(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['error'] is String) {
        return data['error'] as String;
      }
    }
    return _api.getErrorMessage(e);
  }

  Future<void> _onLineTap() async {
    if (_lineBusy) return;
    setState(() => _lineBusy = true);

    try {
      if (_lineBound) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('解除 LINE 綁定？'),
            content: const Text('解除後將不再收到 LINE 機器人的個人化提醒。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('解除綁定'),
              ),
            ],
          ),
        );

        if (confirmed != true) return;

        await LineBindingService.unbind();
        if (!mounted) return;
        setState(() => _lineBound = false);
        _showLineMessage('已解除 LINE 綁定');
      } else {
        final name = await LineBindingService.loginAndBind();
        if (!mounted) return;
        setState(() => _lineBound = true);
        _showLineMessage(
          name == null ? 'LINE 綁定成功' : 'LINE 綁定成功：$name',
        );
      }
    } on PlatformException catch (e) {
      // 使用者取消登入或 LINE SDK 錯誤
      debugPrint('LINE SDK 錯誤: ${e.code} ${e.message}');
      _showLineMessage('LINE 登入已取消或失敗');
    } catch (e) {
      _showLineMessage(_lineErrorMessage(e));
    } finally {
      if (mounted) setState(() => _lineBusy = false);
    }
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey[100]!,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDarkProfileCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        20,
        8,
        8,
        32,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1522),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.edit_outlined,
                color: Colors.white70,
                size: 22,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EditProfileScreen(),
                  ),
                );
              },
            ),
          ),
          CircleAvatar(
            radius: 45,
            backgroundColor: Colors.white,
            backgroundImage: UserSession.avatar.isNotEmpty
                ? NetworkImage(UserSession.avatar)
                : null,
            child: UserSession.avatar.isEmpty
                ? Text(
                    _fullName.isNotEmpty ? _fullName[0] : 'U',
                    style: const TextStyle(
                      fontSize: 40,
                      color: Colors.black,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            _fullName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            _email,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                Icons.emoji_events_outlined,
                '$_badgeCount',
                '獎牌',
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BadgeCollectionScreen(),
                    ),
                  );

                  await _fetchProfileData();
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                Icons.access_time,
                '$_workoutCount 分鐘',
                '運動時數',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                Icons.local_fire_department_outlined,
                NumberFormat('#,###').format(_totalCalories),
                '消耗熱量',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                Icons.directions_walk_outlined,
                '${NumberFormat('#,###').format(_totalSteps)} 步',
                '總步數',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    IconData icon,
    String value,
    String label, {
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            vertical: 20,
            horizontal: 8,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey[200]!,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 28,
                color: const Color(0xFF4A5568),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF718096),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Color(0xFF2C4364),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFF4A5568),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF718096),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogOutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: () {
          _showLogoutConfirmDialog(context);
        },
        icon: const Icon(
          Icons.logout,
          color: Color(0xFFE53935),
        ),
        label: const Text('登出'),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(
            color: Color(0xFFE53935),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  void _showLogoutConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            '確定登出？',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            '登出後將返回登入畫面，您需要重新登入才能使用完整功能。',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                '取消',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);

                UserSession.clearSession();
                await ApiService().clearToken();

                if (!context.mounted) {
                  return;
                }

                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LoginScreen(),
                  ),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('確定登出'),
            ),
          ],
        );
      },
    );
  }
}

class SavedPostsScreen extends StatefulWidget {
  final CommunityStore store;

  const SavedPostsScreen({
    super.key,
    required this.store,
  });

  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.store.loadSavedPosts();
    });
  }

  List<CommunityPost> _filteredPosts(
    List<CommunityPost> posts,
  ) {
    switch (_selectedIndex) {
      case 1:
        return posts
            .where(
              (post) => post.type != CommunityPostType.plan,
            )
            .toList();

      case 2:
        return posts
            .where(
              (post) => post.type == CommunityPostType.plan,
            )
            .toList();

      default:
        return posts;
    }
  }

  Future<void> _openShare(
    CommunityPost post,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => PostShareSheet(
        post: post,
      ),
    );
  }

  Future<void> _toggleLike(
    CommunityPost post,
  ) async {
    final success = await widget.store.toggleLikeByPostId(
      post.id,
    );

    if (!mounted || success) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.store.errorMessage ?? '按讚失敗',
        ),
      ),
    );
  }

  Future<void> _openComments(
    CommunityPost post,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(
        store: widget.store,
        postId: post.id,
      ),
    );
  }

  Future<void> _toggleSave(
    CommunityPost post,
  ) async {
    final success = await widget.store.toggleSaveByPostId(
      post.id,
    );

    if (!mounted || success) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.store.errorMessage ?? '收藏失敗',
        ),
      ),
    );
  }

  void _openDetail(
    CommunityPost post,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SavedPostDetailScreen(
          postId: post.id,
          store: widget.store,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final savedPosts = widget.store.savedPosts;
        final posts = _filteredPosts(savedPosts);

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            title: const Text(
              '我的珍藏',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: widget.store.savedPostsLoading && savedPosts.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : Column(
                  children: [
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        12,
                      ),
                      child: Row(
                        children: [
                          _buildTab(
                            label: '全部',
                            index: 0,
                            count: savedPosts.length,
                          ),
                          const SizedBox(width: 8),
                          _buildTab(
                            label: '貼文',
                            index: 1,
                            count: savedPosts
                                .where(
                                  (post) => post.type != CommunityPostType.plan,
                                )
                                .length,
                          ),
                          const SizedBox(width: 8),
                          _buildTab(
                            label: '運動計畫',
                            index: 2,
                            count: widget.store.savedWorkoutPlans.length,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: widget.store.loadSavedPosts,
                        child: posts.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  const SizedBox(
                                    height: 160,
                                  ),
                                  Text(
                                    _selectedIndex == 2
                                        ? '還沒有收藏的運動計畫'
                                        : _selectedIndex == 1
                                            ? '還沒有收藏的貼文'
                                            : '還沒有收藏的內容',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )
                            : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(16),
                                itemCount: posts.length,
                                separatorBuilder: (_, __) => const SizedBox(
                                  height: 12,
                                ),
                                itemBuilder: (context, index) {
                                  final post = posts[index];

                                  return PostCard(
                                    onTap: () => _openDetail(post),
                                    onMoreTap: () {},
                                    onLikeTap: () => _toggleLike(post),
                                    onCommentTap: () => _openComments(post),
                                    onSaveTap: () => _toggleSave(post),
                                    onShareTap: () => _openShare(post),
                                    onProfileTap: () {},
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
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildTab({
    required String label,
    required int index,
    required int count,
  }) {
    final selected = _selectedIndex == index;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$label $count',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }
}

class SavedPostDetailScreen extends StatefulWidget {
  final int postId;
  final CommunityStore store;

  const SavedPostDetailScreen({
    super.key,
    required this.postId,
    required this.store,
  });

  @override
  State<SavedPostDetailScreen> createState() => _SavedPostDetailScreenState();
}

class _SavedPostDetailScreenState extends State<SavedPostDetailScreen> {
  CommunityPost? _findPost() {
    for (final post in widget.store.savedPosts) {
      if (post.id == widget.postId) {
        return post;
      }
    }

    return null;
  }

  Future<void> _openShare(
    CommunityPost post,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => PostShareSheet(
        post: post,
      ),
    );
  }

  Future<void> _toggleLike() async {
    final success = await widget.store.toggleLikeByPostId(
      widget.postId,
    );

    if (!mounted || success) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.store.errorMessage ?? '按讚失敗',
        ),
      ),
    );
  }

  Future<void> _openComments() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(
        store: widget.store,
        postId: widget.postId,
      ),
    );
  }

  Future<void> _toggleSave() async {
    final success = await widget.store.toggleSaveByPostId(
      widget.postId,
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.store.errorMessage ?? '收藏失敗',
          ),
        ),
      );
      return;
    }

    if (_findPost() == null) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final post = _findPost();

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            title: const Text(
              '貼文內容',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: post == null
              ? const Center(
                  child: Text(
                    '這則內容已從收藏移除',
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: PostCard(
                    onTap: null,
                    onMoreTap: () {},
                    onLikeTap: _toggleLike,
                    onCommentTap: _openComments,
                    onSaveTap: _toggleSave,
                    onShareTap: () => _openShare(post),
                    onProfileTap: () {},
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
                ),
        );
      },
    );
  }
}
