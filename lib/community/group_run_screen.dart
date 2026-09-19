import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/user_session.dart';
import 'models/community_group.dart';
import 'models/community_group_activity.dart';

class GroupRunParticipant {
  final int id;
  final String name;
  final String avatarUrl;
  final bool isMe;
  final bool isLeader;
  double distanceKm;
  int spm;
  int postureScore;
  int calories;
  bool isSpeaking;
  bool isCameraOn;

  GroupRunParticipant({
    required this.id,
    required this.name,
    required this.avatarUrl,
    this.isMe = false,
    this.isLeader = false,
    required this.distanceKm,
    required this.spm,
    required this.postureScore,
    required this.calories,
    this.isSpeaking = false,
    this.isCameraOn = true,
  });
}

class GroupRunScreen extends StatefulWidget {
  final CommunityGroupActivity? activity;
  final CommunityGroup? group;
  final String title;
  final String exerciseType;

  const GroupRunScreen({
    super.key,
    this.activity,
    this.group,
    this.title = '30人線上揪團超慢跑房',
    this.exerciseType = 'slow_jogging',
  });

  @override
  State<GroupRunScreen> createState() => _GroupRunScreenState();
}

class _GroupRunScreenState extends State<GroupRunScreen> {
  late List<GroupRunParticipant> _participants;
  late int _featuredParticipantId;
  Timer? _liveMetricsTimer;
  int _secondsElapsed = 0;
  double _groupTargetKm = 50.0;
  bool _showSkeletonOverlay = true;

  @override
  void initState() {
    super.initState();
    _initParticipants();
    _featuredParticipantId = _participants.first.id; // Default featured is Me
    _startLiveSimulation();
  }

  @override
  void dispose() {
    _liveMetricsTimer?.cancel();
    super.dispose();
  }

  void _initParticipants() {
    final String myName = UserSession.displayName.isNotEmpty ? UserSession.displayName : '我 (Me)';
    final String myAvatar = UserSession.avatar.isNotEmpty
        ? UserSession.avatar
        : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150';

    _participants = [
      GroupRunParticipant(
        id: 100,
        name: myName,
        avatarUrl: myAvatar,
        isMe: true,
        isLeader: true,
        distanceKm: 2.84,
        spm: 180,
        postureScore: 96,
        calories: 185,
        isSpeaking: true,
      ),
      GroupRunParticipant(
        id: 101,
        name: 'Lamei Chen',
        avatarUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=150',
        isLeader: false,
        distanceKm: 3.12,
        spm: 184,
        postureScore: 94,
        calories: 210,
        isSpeaking: true,
      ),
      GroupRunParticipant(
        id: 102,
        name: 'Sarah Lin',
        avatarUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150',
        distanceKm: 2.55,
        spm: 178,
        postureScore: 91,
        calories: 165,
      ),
      GroupRunParticipant(
        id: 103,
        name: 'Mike Wang',
        avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
        distanceKm: 2.90,
        spm: 182,
        postureScore: 88,
        calories: 195,
      ),
      GroupRunParticipant(
        id: 104,
        name: 'Olivia Wu',
        avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
        distanceKm: 2.10,
        spm: 176,
        postureScore: 95,
        calories: 140,
      ),
      GroupRunParticipant(
        id: 105,
        name: 'James Chang',
        avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
        distanceKm: 3.40,
        spm: 186,
        postureScore: 92,
        calories: 230,
      ),
      GroupRunParticipant(
        id: 106,
        name: 'Emily Huang',
        avatarUrl: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150',
        distanceKm: 1.95,
        spm: 175,
        postureScore: 89,
        calories: 130,
      ),
      GroupRunParticipant(
        id: 107,
        name: 'David Lee',
        avatarUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150',
        distanceKm: 2.70,
        spm: 180,
        postureScore: 90,
        calories: 175,
      ),
      GroupRunParticipant(
        id: 108,
        name: 'Jessica Tsai',
        avatarUrl: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=150',
        distanceKm: 2.30,
        spm: 179,
        postureScore: 93,
        calories: 150,
      ),
      GroupRunParticipant(
        id: 109,
        name: 'Kevin Chen',
        avatarUrl: 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=150',
        distanceKm: 2.80,
        spm: 181,
        postureScore: 87,
        calories: 180,
      ),
      GroupRunParticipant(
        id: 110,
        name: 'Chloe Yang',
        avatarUrl: 'https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?w=150',
        distanceKm: 1.80,
        spm: 174,
        postureScore: 94,
        calories: 120,
      ),
      GroupRunParticipant(
        id: 111,
        name: 'Alex Liu',
        avatarUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=150',
        distanceKm: 3.05,
        spm: 183,
        postureScore: 91,
        calories: 200,
      ),
      GroupRunParticipant(
        id: 112,
        name: 'Grace Kao',
        avatarUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=150',
        distanceKm: 2.20,
        spm: 177,
        postureScore: 88,
        calories: 145,
      ),
      GroupRunParticipant(
        id: 113,
        name: 'Brian Ho',
        avatarUrl: 'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=150',
        distanceKm: 2.65,
        spm: 180,
        postureScore: 89,
        calories: 170,
      ),
      GroupRunParticipant(
        id: 114,
        name: 'Hannah Hsu',
        avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
        distanceKm: 1.60,
        spm: 172,
        postureScore: 96,
        calories: 105,
      ),
      GroupRunParticipant(
        id: 115,
        name: 'Jason Cheng',
        avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
        distanceKm: 2.95,
        spm: 185,
        postureScore: 90,
        calories: 190,
      ),
      GroupRunParticipant(
        id: 116,
        name: 'Mia Tang',
        avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
        distanceKm: 2.45,
        spm: 179,
        postureScore: 92,
        calories: 160,
      ),
      GroupRunParticipant(
        id: 117,
        name: 'Eric Lo',
        avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
        distanceKm: 3.25,
        spm: 184,
        postureScore: 86,
        calories: 215,
      ),
    ];
  }

  void _startLiveSimulation() {
    _liveMetricsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      final rand = Random();
      setState(() {
        _secondsElapsed++;

        // Update participants stats live
        for (var p in _participants) {
          p.distanceKm += 0.0025 + (rand.nextDouble() * 0.001);
          p.spm = (176 + rand.nextInt(9)).clamp(170, 190);
          p.calories += rand.nextInt(2) == 1 ? 1 : 0;
          // Randomly fluctuate speaking indicator
          if (rand.nextInt(15) == 0) {
            p.isSpeaking = !p.isSpeaking;
          }
        }
      });
    });
  }

  GroupRunParticipant get _featuredParticipant {
    return _participants.firstWhere(
      (p) => p.id == _featuredParticipantId,
      orElse: () => _participants.first,
    );
  }

  double get _totalGroupDistance {
    return _participants.fold(0.0, (sum, p) => sum + p.distanceKm);
  }

  String _formatDuration(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final String exerciseTitle = widget.exerciseType == 'squat' ? '深蹲揪團' : '超慢跑揪團';

    return Scaffold(
      backgroundColor: const Color(0xFF111318),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16181F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.activity?.title ?? widget.title,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  'LIVE • ${_participants.length} 人在線 (上限30人) • $exerciseTitle',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showSkeletonOverlay ? Icons.accessibility_new : Icons.accessibility_new_outlined,
              color: _showSkeletonOverlay ? Colors.greenAccent : Colors.white60,
              size: 22,
            ),
            tooltip: '切換 AI 姿態分析',
            onPressed: () {
              setState(() {
                _showSkeletonOverlay = !_showSkeletonOverlay;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. 上半部焦點大畫面 (Top Main Screen - Google Meet Featured Screen)
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: _buildFeaturedTopScreen(_featuredParticipant),
              ),
            ),

            // 2. 中間團體目標進度條 (Middle Group Total Milestone Bar)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: _buildGroupProgressMeter(),
            ),

            // 3. 下半部 30 人成員縮小圖塊列表 (Bottom Grid Tiles - Google Meet Tiles)
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: _buildParticipantsBottomGrid(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 1. 上半部焦點大畫面 Widget
  Widget _buildFeaturedTopScreen(GroupRunParticipant participant) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E222D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: participant.isSpeaking ? Colors.greenAccent : Colors.white12,
          width: participant.isSpeaking ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: participant.isSpeaking ? Colors.greenAccent.withOpacity(0.2) : Colors.black.withOpacity(0.5),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // 背景擬真畫面 / 頭像預覽
            Positioned.fill(
              child: Image.network(
                participant.avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.blueGrey.shade900,
                  child: const Center(child: Icon(Icons.person, size: 80, color: Colors.white30)),
                ),
              ),
            ),
            // 黑透明漸層遮罩，提昇文字閱讀性
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black45,
                      Colors.transparent,
                      Colors.black87,
                    ],
                  ),
                ),
              ),
            ),

            // AI 姿態分析骨架 Overlay 示意
            if (_showSkeletonOverlay)
              Positioned.fill(
                child: CustomPaint(
                  painter: _PoseSkeletonPainter(isSquat: widget.exerciseType == 'squat'),
                ),
              ),

            // 頂部左標籤：Pin 狀態與跑友名稱
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.push_pin, color: Colors.amber, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      participant.isMe ? '📌 焦點：我 (${participant.name})' : '📌 焦點跑友：${participant.name}',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    if (participant.isLeader) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade800,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('👑 領跑者', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // 頂部右標籤：姿態評分與步頻
            Positioned(
              top: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.greenAccent),
                    ),
                    child: Text(
                      '姿態分 ${participant.postureScore}',
                      style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blueAccent),
                    ),
                    child: Text(
                      '${participant.spm} SPM',
                      style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            // 底部個人即時數據 HUD
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildHudMetric('時間', _formatDuration(_secondsElapsed), Icons.timer_outlined, Colors.amber),
                  _buildHudMetric('里程', '${participant.distanceKm.toStringAsFixed(2)} km', Icons.directions_run, Colors.greenAccent),
                  _buildHudMetric('消耗', '${participant.calories} kcal', Icons.local_fire_department, Colors.orangeAccent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHudMetric(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
              Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  // 2. 中間團體總里程進度條 Widget
  Widget _buildGroupProgressMeter() {
    final double groupDist = _totalGroupDistance;
    final double pct = (groupDist / _groupTargetKm).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E222D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.flag_rounded, color: Colors.orangeAccent, size: 16),
                  const SizedBox(width: 6),
                  const Text('團體累積每日目標', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              Text(
                '${groupDist.toStringAsFixed(1)} / ${_groupTargetKm.toStringAsFixed(1)} km (${(pct * 100).toStringAsFixed(0)}%)',
                style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
            ),
          ),
        ],
      ),
    );
  }

  // 3. 下半部 30 人成員縮小圖塊列表 (Google Meet Tiles Grid)
  Widget _buildParticipantsBottomGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.grid_view_rounded, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '成員即時視訊圖塊 (${_participants.length}/30人)',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Text('點擊卡片置頂放大至上半部 📌', style: TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            itemCount: _participants.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, // 3 欄 Google Meet 風格網格
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.95,
            ),
            itemBuilder: (context, index) {
              final p = _participants[index];
              final bool isFeatured = p.id == _featuredParticipantId;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _featuredParticipantId = p.id;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('已將 ${p.name} 切換至上半部焦點大畫面 📌'),
                      duration: const Duration(milliseconds: 900),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Colors.black87,
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E222D),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isFeatured
                          ? Colors.amber
                          : (p.isSpeaking ? Colors.greenAccent : Colors.white12),
                      width: isFeatured ? 2.5 : (p.isSpeaking ? 2 : 1),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        // 背景頭像
                        Positioned.fill(
                          child: Image.network(
                            p.avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade900,
                              child: const Icon(Icons.person, color: Colors.white30, size: 30),
                            ),
                          ),
                        ),
                        // 漸層覆蓋
                        Positioned.fill(
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.black26, Colors.black87],
                              ),
                            ),
                          ),
                        ),

                        // 置頂標籤
                        if (isFeatured)
                          const Positioned(
                            top: 4,
                            right: 4,
                            child: CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.amber,
                              child: Icon(Icons.push_pin, size: 11, color: Colors.black),
                            ),
                          ),

                        // 姓名與 SPM 數據
                        Positioned(
                          bottom: 6,
                          left: 6,
                          right: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                p.isMe ? '我 (${p.name})' : p.name,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: p.isMe ? FontWeight.bold : FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${p.spm} SPM',
                                    style: const TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${p.distanceKm.toStringAsFixed(1)}km',
                                    style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// 姿態繪製示意 Painter
class _PoseSkeletonPainter extends CustomPainter {
  final bool isSquat;
  _PoseSkeletonPainter({required this.isSquat});

  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final paintDot = Paint()
      ..color = Colors.amberAccent
      ..style = PaintingStyle.fill;

    final double w = size.width;
    final double h = size.height;

    // Simplified pose points
    final head = Offset(w * 0.5, h * 0.25);
    final shoulderL = Offset(w * 0.4, h * 0.35);
    final shoulderR = Offset(w * 0.6, h * 0.35);
    final hipL = Offset(w * 0.42, isSquat ? h * 0.60 : h * 0.55);
    final hipR = Offset(w * 0.58, isSquat ? h * 0.60 : h * 0.55);
    final kneeL = Offset(w * 0.38, isSquat ? h * 0.72 : h * 0.75);
    final kneeR = Offset(w * 0.62, isSquat ? h * 0.72 : h * 0.75);
    final ankleL = Offset(w * 0.40, h * 0.88);
    final ankleR = Offset(w * 0.60, h * 0.88);

    // Draw Skeleton Lines
    canvas.drawLine(shoulderL, shoulderR, paintLine);
    canvas.drawLine(shoulderL, hipL, paintLine);
    canvas.drawLine(shoulderR, hipR, paintLine);
    canvas.drawLine(hipL, hipR, paintLine);
    canvas.drawLine(hipL, kneeL, paintLine);
    canvas.drawLine(hipR, kneeR, paintLine);
    canvas.drawLine(kneeL, ankleL, paintLine);
    canvas.drawLine(kneeR, ankleR, paintLine);

    // Draw Joint Dots
    for (var pt in [head, shoulderL, shoulderR, hipL, hipR, kneeL, kneeR, ankleL, ankleR]) {
      canvas.drawCircle(pt, 5, paintDot);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
