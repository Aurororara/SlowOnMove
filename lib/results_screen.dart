import 'dart:math';
import 'dart:convert'; //
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:http/http.dart' as http;
import 'services/ai_coach_service.dart';
import 'package:flutter/foundation.dart';
import 'services/user_session.dart';
import 'config/api_config.dart';

class ResultsScreen extends StatefulWidget {
  final int timeSeconds;
  final double averageAccuracy;
  final int stepCount;
  final List<String> finalFeedback;
  final String exerciseTitle;

  const ResultsScreen({
    super.key,
    required this.timeSeconds,
    required this.averageAccuracy,
    required this.stepCount,
    required this.finalFeedback,
    this.exerciseTitle = '超慢跑',
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  late ConfettiController _confettiController;
  String? _dynamicAiFeedback;
  bool _isLoadingAi = true;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    _confettiController.play();

    _fetchAiFeedback(); // 獲取 AI 建議
    _saveData();
  }

  Future<void> _saveData() async {
    final String baseUrl = ApiConfig.baseUrl;
    final String url = baseUrl.endsWith('/')
        ? '${baseUrl}training-logs/'
        : '$baseUrl/training-logs/';

    final bool isSquat = widget.exerciseTitle == '深蹲';
    final int totalMins = widget.timeSeconds ~/ 60;
    final int fixedCalories = caloriesBurned;
    final int fixedSteps = isSquat ? 0 : widget.stepCount;

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "member": UserSession.memberId,
          "exercise_type": isSquat ? "squat" : "slow_jogging",
          "start_time": DateTime.now()
              .subtract(Duration(seconds: widget.timeSeconds))
              .toIso8601String(),
          "end_time": DateTime.now().toIso8601String(),
          "total_mins": totalMins,
          "posture_score": widget.averageAccuracy.toInt(),
          "calories": fixedCalories,
          "step_count": fixedSteps,
        }),
      );
    } catch (e) {
      debugPrint("⚠️ 連線異常: $e");
    }
  }

  Future<void> _fetchAiFeedback() async {
    // 暫時停用 Gemini API，改用固定的教練建議
    String feedback = "";
    if (widget.exerciseTitle == '深蹲') {
      if (widget.averageAccuracy >= 80) {
        feedback = "深蹲姿勢非常標準！核心有收緊，膝蓋與腳尖方向一致，重心掌握得很好。請繼續保持這個好習慣，這對鍛鍊臀腿肌肉非常有幫助！";
      } else if (widget.averageAccuracy >= 60) {
        feedback = "做得不錯，但還有進步空間。注意深蹲時重心要放在腳跟，背部保持挺直，不要過度前傾。下蹲時感受臀部向後坐的感覺。";
      } else {
        feedback = "深蹲姿勢需要再調整喔。請注意：下蹲時臀部往後坐，膝蓋不要內夾，保持呼吸節奏。建議對著鏡子慢慢練習，感受肌肉發力。";
      }
    } else {
      if (widget.averageAccuracy >= 80) {
        feedback = "超慢跑節奏掌握得很完美！步伐輕盈，落地姿勢正確。繼續保持這樣的步頻與姿勢，能有效燃燒脂肪並保護膝蓋！";
      } else if (widget.averageAccuracy >= 60) {
        feedback = "表現不錯，但要注意落地時盡量使用前腳掌或全腳掌，避免腳跟重落地，以減少膝蓋負擔。保持身體微微前傾會更輕鬆喔。";
      } else {
        feedback = "超慢跑姿勢需要微調。請保持身體微微前傾，步伐縮小，提高步頻，並注意手臂自然擺動。不要急，跟著自己的節奏慢慢來。";
      }
    }

    // 延遲一下模擬 AI 載入感
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      setState(() {
        _dynamicAiFeedback = feedback;
        _isLoadingAi = false;
      });
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  int get caloriesBurned {
    double minutes = widget.timeSeconds / 60.0;
    return (minutes * 8.0).round();
  }

  @override
  Widget build(BuildContext context) {
    final String minutesStr =
        (widget.timeSeconds ~/ 60).toString().padLeft(2, '0');
    final String secondsStr =
        (widget.timeSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: const Color(0xFFE9F1F5),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('運動完成！',
                      style:
                          TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('恭喜你完成了這段時間的${widget.exerciseTitle}',
                      style:
                          const TextStyle(fontSize: 16, color: Colors.black54)),
                  const SizedBox(height: 40),

                  // 數據網格
                  Row(
                    children: [
                      Expanded(
                          child: _buildStatCard(
                              '運動時間',
                              '$minutesStr:$secondsStr',
                              Icons.timer_outlined,
                              Colors.blueAccent)),
                      const SizedBox(width: 16),
                      Expanded(
                          child: _buildStatCard(
                              '消耗熱量',
                              '$caloriesBurned kcal',
                              Icons.local_fire_department_outlined,
                              Colors.redAccent)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                          child: _buildStatCard(
                              '平均準確率',
                              '${widget.averageAccuracy.toStringAsFixed(1)}%',
                              Icons.check_circle_outline,
                              widget.averageAccuracy > 80
                                  ? Colors.green
                                  : Colors.orange)),
                      const SizedBox(width: 16),
                      if (widget.exerciseTitle != '深蹲')
                        Expanded(
                            child: _buildStatCard(
                                '步數',
                                '${widget.stepCount} 步',
                                Icons.directions_walk_outlined,
                                Colors.purpleAccent))
                      else
                        Expanded(child: Container()), // 保持排版平衡
                    ],
                  ),

                  const SizedBox(height: 48),

                  // AI 建議區塊
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 5))
                        ]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.tips_and_updates, color: Colors.amber),
                            SizedBox(width: 8),
                            Text('AI 教練悄悄話',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_isLoadingAi)
                          const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.amber))
                        else
                          Text(_dynamicAiFeedback ?? '沒有建議',
                              style:
                                  const TextStyle(fontSize: 16, height: 1.6)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 60),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text('回到主頁',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 慶祝彩帶
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2,
              maxBlastForce: 5,
              minBlastForce: 2,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.1,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 4))
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(fontSize: 14, color: Colors.black54)),
          const SizedBox(height: 4),
          FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}
