import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'components/exercise_history.dart';
import 'edit_profile_screen.dart';
import 'models/community_post.dart';
import 'services/community_store.dart';
import 'services/user_session.dart';

class ProfileScreen extends StatefulWidget {
  final CommunityStore store;

  const ProfileScreen({super.key, required this.store});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  int _workoutCount = 0;
  int _totalCalories = 0;
  int _totalSteps = 0;
  double _totalDistance = 0.0;
  String _height = "--";
  String _weight = "--";
  String get _fullName => UserSession.displayName;
  String get _email => UserSession.email;

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    final String baseUrl =
        kIsWeb ? "http://localhost:8000/api" : "http://10.0.2.2:8000/api";
    final int currentMemberId = UserSession.memberId;

    try {
      final logStatsResponse = await http.get(
        Uri.parse('$baseUrl/training-logs/my-stats/?member_id=$currentMemberId'),
      );
      final bodyResponse = await http.get(Uri.parse('$baseUrl/body-records/'));

      if (logStatsResponse.statusCode == 200 && bodyResponse.statusCode == 200) {
        final Map<String, dynamic> stats = json.decode(logStatsResponse.body);
        final List allBodyRecords = json.decode(bodyResponse.body);

        final List myBodyRecords = allBodyRecords
            .where((rec) => rec['member'] == currentMemberId)
            .toList();

        if (mounted) {
          setState(() {
            _workoutCount = stats['total_time'] ?? 0;
            _totalCalories = stats['total_calories'] ?? 0;
            _totalSteps = stats['total_steps'] ?? 0;
            _totalDistance =
                (stats['total_distance'] as num?)?.toDouble() ?? 0.0;

            if (myBodyRecords.isNotEmpty) {
              _height = myBodyRecords.last['height'].toString();
              _weight = myBodyRecords.last['weight'].toString();
            }
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("抓取資料失敗: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final int savedCount = widget.store.savedCount;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _fetchProfileData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        _buildDarkProfileCard(context),
                        const SizedBox(height: 24),
                        _buildStatsGrid(),
                        const SizedBox(height: 32),
                        _buildSectionTitle('MY DATA & PROGRESS'),
                        const SizedBox(height: 16),
                        _buildMenuButton(
                          icon: Icons.history,
                          title: '歷史紀錄',
                          subtitle: '查看所有運動紀錄',
                          iconColor: Colors.blueAccent,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ExerciseHistoryScreen(),
                            ),
                          ),
                        ),
                        _buildMenuButton(
                          icon: Icons.favorite_border,
                          title: '我的珍藏',
                          subtitle: savedCount == 0
                              ? '儲存的貼文與訓練'
                              : '目前已收藏 $savedCount 則貼文',
                          iconColor: Colors.pinkAccent,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  SavedPostsScreen(store: widget.store),
                            ),
                          ),
                        ),
                        _buildMenuButton(
                          icon: Icons.restaurant_menu,
                          title: '我的菜單',
                          subtitle: '個人飲食營養追蹤',
                          iconColor: Colors.greenAccent,
                          onTap: () => debugPrint("跳轉到我的菜單"),
                        ),
                        const SizedBox(height: 32),
                        _buildSectionTitle('PERSONAL INFORMATION'),
                        const SizedBox(height: 16),
                        _buildInfoTile(
                          icon: Icons.person_outline,
                          label: 'Full Name',
                          value: _fullName,
                        ),
                        const SizedBox(height: 12),
                        _buildInfoTile(
                          icon: Icons.mail_outline,
                          label: 'Email Address',
                          value: _email,
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
          border: Border.all(color: Colors.grey[100]!),
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
              child: Icon(icon, color: iconColor),
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
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
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
                    builder: (context) => const EditProfileScreen(),
                  ),
                );
              },
            ),
          ),
          Container(
            width: 90,
            height: 90,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: Center(
              child: Text(
                _fullName.isNotEmpty ? _fullName[0] : "U",
                style: const TextStyle(fontSize: 40, color: Colors.black),
              ),
            ),
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
            style: const TextStyle(fontSize: 14, color: Colors.grey),
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
              child: _buildStatCard(Icons.emoji_events_outlined, '12', '獎牌'),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                Icons.access_time,
                '$_workoutCount min',
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
                _totalCalories >= 1000
                    ? '${(_totalCalories / 1000).toStringAsFixed(1)}k'
                    : '$_totalCalories',
                '消耗卡路里',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                Icons.directions_walk_outlined,
                '${_totalDistance.toStringAsFixed(2)} km',
                '總里程 ($_totalSteps 步)',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: const Color(0xFF4A5568)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF718096)),
          ),
        ],
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
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4A5568)),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF718096)),
              ),
              Text(
                value,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
        onPressed: () {},
        icon: const Icon(Icons.logout, color: Color(0xFFE53935)),
        label: const Text('Log Out'),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFE53935)),
        ),
      ),
    );
  }
}

class SavedPostsScreen extends StatelessWidget {
  final CommunityStore store;

  const SavedPostsScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final List<CommunityPost> posts = store.savedPosts;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            title: const Text(
              '我的珍藏',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: posts.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      '還沒有收藏的貼文。\n去 Community 頁按下書籤後，這裡就會顯示。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: posts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final CommunityPost post = posts[index];
                    return _SavedPostCard(post: post);
                  },
                ),
        );
      },
    );
  }
}

class _SavedPostCard extends StatelessWidget {
  final CommunityPost post;

  const _SavedPostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.black,
                child: Text(
                  post.initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      post.timeAgo,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF718096),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.bookmark, color: Colors.black),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            post.content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.black,
            ),
          ),
          if (post.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: post.tags
                  .map(
                    (tag) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.favorite_border,
                size: 18,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                '${post.likes}',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 16),
              const Icon(
                Icons.chat_bubble_outline,
                size: 18,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                '${post.commentCount}',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
