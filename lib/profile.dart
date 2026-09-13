import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:show_on_move/admin/admin_dashboard_screen.dart';

import 'body_record_screen.dart';
import 'badge_collection_screen.dart';
import 'community/community_store.dart';
import 'community/models/community_post.dart';
import 'community/widgets/posts/comments_sheet.dart';
import 'community/widgets/posts/post_card.dart';
import 'community/widgets/posts/post_share_sheet.dart';
import 'config/api_config.dart';
import 'edit_profile_screen.dart';
import 'exercise_history_screen.dart';
import 'login_screen.dart';
import 'monthly_recap_screen.dart';
import 'purchase_screen.dart';
import 'services/api_service.dart';
import 'services/user_session.dart';

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

  String get _fullName => UserSession.displayName;
  String get _email => UserSession.email;

  @override
  void initState() {
    super.initState();

    _fetchProfileData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.store.loadSavedPosts();
    });
  }

  Future<void> _fetchProfileData() async {
    final String baseUrl = ApiConfig.baseUrl;
    final int currentMemberId = UserSession.memberId;

    try {
      final logStatsResponse = await http.get(
        Uri.parse(
          '${baseUrl}training-logs/my-stats/?member_id=$currentMemberId',
        ),
      );

      if (logStatsResponse.statusCode == 200) {
        final Map<String, dynamic> stats = json.decode(logStatsResponse.body);

        if (!mounted) {
          return;
        }

        setState(() {
          _workoutCount = stats['total_time'] ?? 0;
          _totalCalories = stats['total_calories'] ?? 0;
          _totalSteps = stats['total_steps'] ?? 0;
          _isLoading = false;
        });

        return;
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('抓取資料失敗: $e');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshProfile() async {
    await Future.wait([
      _fetchProfileData(),
      widget.store.loadSavedPosts(),
    ]);
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
                            _buildDarkProfileCard(context),
                            const SizedBox(height: 24),
                            _buildStatsGrid(),
                            const SizedBox(height: 32),
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
                              icon: Icons.restaurant_menu,
                              title: '我的菜單',
                              subtitle: '個人飲食營養追蹤',
                              iconColor: Colors.greenAccent,
                              onTap: () {
                                debugPrint('跳轉到我的菜單');
                              },
                            ),
                            const SizedBox(height: 32),
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
                            const SizedBox(height: 32),
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
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 32),
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
                '12',
                '獎牌',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BadgeCollectionScreen(),
                    ),
                  );
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF718096),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
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

  Future<void> _toggleLike(CommunityPost post) async {
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

  Future<void> _openComments(CommunityPost post) async {
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

  Future<void> _toggleSave(CommunityPost post) async {
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

  void _openDetail(CommunityPost post) {
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
                                  const SizedBox(height: 160),
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
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
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

  Future<void> _openShare(CommunityPost post) async {
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

    // 在「我的珍藏」詳細頁取消收藏後，
    // 該貼文已經不屬於收藏內容，所以返回上一頁。
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
                  child: Text('這則內容已從收藏移除'),
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
