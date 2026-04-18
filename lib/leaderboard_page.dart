import 'package:flutter/material.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  int selectedTab = 0; // 0: 本週, 1: 本月, 2: 全部時間

  final List<LeaderboardUser> rankings = [
    const LeaderboardUser(
      name: 'Sarah Chen',
      score: 237.5,
      accuracy: 95,
      distance: 142.5,
      rank: 1,
      avatarLetter: 'S',
      avatarColor: Color(0xFFF4A000),
      medalColor: Color(0xFFFFC107),
    ),
    const LeaderboardUser(
      name: 'Mike Johnson',
      score: 220.3,
      accuracy: 92,
      distance: 132.3,
      rank: 2,
      avatarLetter: 'M',
      avatarColor: Color(0xFF9CA3AF),
      medalColor: Color(0xFFBDBDBD),
    ),
    const LeaderboardUser(
      name: 'Emma Wilson',
      score: 203.8,
      accuracy: 89,
      distance: 120.4,
      rank: 3,
      avatarLetter: 'E',
      avatarColor: Color(0xFFC96A00),
      medalColor: Color(0xFFCD7F32),
    ),
    const LeaderboardUser(
      name: 'Olivia Brown',
      score: 198.6,
      accuracy: 87,
      distance: 115.9,
      rank: 4,
      avatarLetter: 'O',
      avatarColor: Color(0xFF1F2A44),
      medalColor: Color(0xFFE5E7EB),
    ),
    const LeaderboardUser(
      name: 'James Lee',
      score: 192.4,
      accuracy: 85,
      distance: 111.2,
      rank: 5,
      avatarLetter: 'J',
      avatarColor: Color(0xFF1F2A44),
      medalColor: Color(0xFFE5E7EB),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final topThree = [...rankings]..sort((a, b) => a.rank.compareTo(b.rank));
    final currentUser = rankings.firstWhere((e) => e.rank == 4);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(context),
      body: Center(
        child: Container(
          width: 390,
          decoration: const BoxDecoration(
            color: Color(0xFFF7F7F9),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(34),
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTimeTabs(),
                      const SizedBox(height: 20),
                      const _ScoreInfoCard(),
                      const SizedBox(height: 20),
                      _PodiumCard(
                        first: topThree.firstWhere((e) => e.rank == 1),
                        second: topThree.firstWhere((e) => e.rank == 2),
                        third: topThree.firstWhere((e) => e.rank == 3),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        '完整排行榜',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF6B7280),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ...rankings.map(
                        (user) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: RankingListCard(user: user),
                        ),
                      ),
                      const SizedBox(height: 22),
                      _PerformanceCard(user: currentUser),
                      const SizedBox(height: 18),
                      _MotivationCard(user: currentUser),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Color(0xFFE2E8F0),
            child: Icon(
              Icons.emoji_events_outlined,
              size: 14,
              color: Colors.blueGrey,
            ),
          ),
          SizedBox(width: 8),
          Text(
            '排行榜',
            style: TextStyle(
              color: Color(0xFF1A202C),
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeTabs() {
    final tabs = ['本週', '本月', '全部時間'];

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD8DADF), width: 2),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = selectedTab == index;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  selectedTab = index;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    tabs[index],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color:
                          isSelected ? Colors.white : const Color(0xFF4B5563),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ScoreInfoCard extends StatelessWidget {
  const _ScoreInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: const Color(0xFF020817),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.workspace_premium_outlined, color: Colors.white, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '排名分數 = 姿勢準確度 + 距離',
              style: TextStyle(
                fontSize: 16,
                height: 1.4,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PodiumCard extends StatelessWidget {
  final LeaderboardUser first;
  final LeaderboardUser second;
  final LeaderboardUser third;

  const _PodiumCard({
    required this.first,
    required this.second,
    required this.third,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F1E8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _PodiumPerson(
              user: second,
              avatarSize: 92,
              podiumHeight: 118,
              podiumColor: const Color(0xFFC9CED6),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _PodiumPerson(
              user: first,
              avatarSize: 116,
              podiumHeight: 168,
              podiumColor: const Color(0xFFF6B300),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _PodiumPerson(
              user: third,
              avatarSize: 92,
              podiumHeight: 94,
              podiumColor: const Color(0xFFC86400),
            ),
          ),
        ],
      ),
    );
  }
}

class _PodiumPerson extends StatelessWidget {
  final LeaderboardUser user;
  final double avatarSize;
  final double podiumHeight;
  final Color podiumColor;

  const _PodiumPerson({
    required this.user,
    required this.avatarSize,
    required this.podiumHeight,
    required this.podiumColor,
  });

  @override
  Widget build(BuildContext context) {
    final medalEmoji = user.rank == 1
        ? '🥇'
        : user.rank == 2
            ? '🥈'
            : '🥉';

    return Column(
      children: [
        CircleAvatar(
          radius: avatarSize / 2,
          backgroundColor: user.avatarColor,
          child: CircleAvatar(
            radius: avatarSize / 2 - 4,
            backgroundColor: user.avatarColor,
            child: Text(
              user.avatarLetter,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(medalEmoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 8),
        Text(
          user.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          user.score.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: user.rank == 1
                ? const Color(0xFFC96A00)
                : const Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          height: podiumHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: podiumColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
            boxShadow: const [
              BoxShadow(
                blurRadius: 16,
                offset: Offset(0, 8),
                color: Color(0x1A000000),
              ),
            ],
          ),
          child: Text(
            '${user.rank}',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class RankingListCard extends StatelessWidget {
  final LeaderboardUser user;

  const RankingListCard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final isFirst = user.rank == 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Icon(
              isFirst
                  ? Icons.workspace_premium_outlined
                  : Icons.military_tech_outlined,
              color:
                  isFirst ? const Color(0xFFF59E0B) : const Color(0xFF9CA3AF),
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFF1F2A44),
            child: Text(
              user.avatarLetter,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.name,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _MedalBadge(
                      rank: user.rank,
                      color: user.medalColor,
                      small: true,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '姿勢 ${user.accuracy}%',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        '姿勢 ${user.accuracy}%',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        '距離 ${user.distance.toStringAsFixed(1)} km',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                user.score.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '分數',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF6B7280),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  final LeaderboardUser user;

  const _PerformanceCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF000000), Color(0xFF0A1430)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.workspace_premium_outlined,
                  color: Colors.white, size: 28),
              SizedBox(width: 10),
              Text(
                '我的表現',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _statBox(
                  title: '目前排名',
                  value: '#${user.rank}',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _statBox(
                  title: '總分',
                  value: user.score.toStringAsFixed(1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _statBox(
                  title: '姿勢準確度',
                  value: '${user.accuracy}%',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _statBox(
                  title: '總距離',
                  value: '${user.distance.toStringAsFixed(1)}km',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: Color(0x22FFFFFF), height: 1),
          const SizedBox(height: 18),
          const Row(
            children: [
              Text(
                '距離第 3 名還差：',
                style: TextStyle(
                  color: Color(0xFFD1D5DB),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Spacer(),
              Text(
                '20.2 分',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statBox({required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF1C1C1E), Color(0xFF172033)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFD1D5DB),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MotivationCard extends StatelessWidget {
  final LeaderboardUser user;

  const _MotivationCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
      decoration: BoxDecoration(
        color: const Color(0xFFF1ECF8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD8B4FE), width: 2),
      ),
      child: Column(
        children: [
          const Text('💪', style: TextStyle(fontSize: 28)),
          const SizedBox(height: 14),
          Text(
            '繼續加油，${user.name}！',
            style: const TextStyle(
              color: Color(0xFF5B21B6),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '持續提升姿勢準確度與累積距離，排名還能再往上衝！',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF7C3AED),
              fontSize: 16,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MedalBadge extends StatelessWidget {
  final int rank;
  final Color color;
  final bool small;

  const _MedalBadge({
    required this.rank,
    required this.color,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: small ? 18 : 28,
      height: small ? 18 : 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: const [
          BoxShadow(
            blurRadius: 8,
            offset: Offset(0, 3),
            color: Color(0x22000000),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '$rank',
        style: TextStyle(
          fontSize: small ? 10 : 14,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }
}

class LeaderboardUser {
  final String name;
  final double score;
  final int accuracy;
  final double distance;
  final int rank;
  final String avatarLetter;
  final Color avatarColor;
  final Color medalColor;

  const LeaderboardUser({
    required this.name,
    required this.score,
    required this.accuracy,
    required this.distance,
    required this.rank,
    required this.avatarLetter,
    required this.avatarColor,
    required this.medalColor,
  });
}
