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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _buildHeader(),
                const SizedBox(height: 24),
                _buildTimeTabs(),
                const SizedBox(height: 24),
                const _ScoreInfoCard(),
                const SizedBox(height: 24),
                _buildSectionTitle('前三名'),
                const SizedBox(height: 16),
                _PodiumCard(
                  first: topThree.firstWhere((e) => e.rank == 1),
                  second: topThree.firstWhere((e) => e.rank == 2),
                  third: topThree.firstWhere((e) => e.rank == 3),
                ),
                const SizedBox(height: 32),
                _buildSectionTitle('完整排行榜'),
                const SizedBox(height: 16),
                ...rankings.map(
                  (user) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: RankingListCard(user: user),
                  ),
                ),
                const SizedBox(height: 24),
                _OriginalPerformanceCard(user: currentUser),
                const SizedBox(height: 18),
                _OriginalMotivationCard(user: currentUser),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1522),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Column(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.emoji_events_outlined,
                  size: 34,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 16),
              Text(
                '排行榜',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 6),
              Text(
                '查看你的排名、分數與運動表現',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
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
}

class _ScoreInfoCard extends StatelessWidget {
  const _ScoreInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF6AD55).withOpacity(0.5),
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.workspace_premium_outlined,
            color: Color(0xFFF6AD55),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              '排名分數 = 姿勢準確度 + 距離',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A202C),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _PodiumPerson(
              user: second,
              avatarSize: 84,
              podiumHeight: 110,
              podiumColor: const Color(0xFFC9CED6),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _PodiumPerson(
              user: first,
              avatarSize: 104,
              podiumHeight: 150,
              podiumColor: const Color(0xFFF6B300),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _PodiumPerson(
              user: third,
              avatarSize: 84,
              podiumHeight: 90,
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
          child: Text(
            user.avatarLetter,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(medalEmoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 8),
        Text(
          user.name,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          user.score.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: user.rank == 1
                ? const Color(0xFFC96A00)
                : const Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          height: podiumHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: podiumColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
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
            radius: 26,
            backgroundColor: const Color(0xFF1F2A44),
            child: Text(
              user.avatarLetter,
              style: const TextStyle(
                fontSize: 22,
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
          const SizedBox(width: 12),
          SizedBox(
            width: 68,
            child: Column(
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
          ),
        ],
      ),
    );
  }
}

class _OriginalPerformanceCard extends StatelessWidget {
  final LeaderboardUser user;

  const _OriginalPerformanceCard({required this.user});

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
                child: _StatBox(
                  title: '目前排名',
                  value: '#${user.rank}',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _StatBox(
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
                child: _StatBox(
                  title: '姿勢準確度',
                  value: '${user.accuracy}%',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _StatBox(
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
}

class _StatBox extends StatelessWidget {
  final String title;
  final String value;

  const _StatBox({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
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

class _OriginalMotivationCard extends StatelessWidget {
  final LeaderboardUser user;

  const _OriginalMotivationCard({required this.user});

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
