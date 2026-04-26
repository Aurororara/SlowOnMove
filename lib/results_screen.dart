import 'dart:math';
import 'dart:convert'; // ⭐ 處理 JSON 必備
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:http/http.dart' as http; // ⭐ 處理網路請求必備
import 'services/ai_coach_service.dart';
import 'package:flutter/foundation.dart'; // ⭐ 判斷是否為網頁版

class ResultsScreen extends StatefulWidget {
  final int timeSeconds;
  final double averageAccuracy;
  final int stepCount;
  final List<String> finalFeedback;

  const ResultsScreen({
    super.key,
    required this.timeSeconds,
    required this.averageAccuracy,
    required this.stepCount,
    required this.finalFeedback,
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
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _confettiController.play();
    
    _fetchAiFeedback(); // 獲取 AI 建議
    _saveData();       // ⭐ 呼叫儲存函數，這下不會有紅字了！
  }

  // ⭐ 核心功能：將運動數據寫入資料庫
  Future<void> _saveData() async {
  final String baseUrl = kIsWeb ? "http://localhost:8000/api" : "http://10.0.2.2:8000/api";
  
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/training-logs/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "member": 6, // ⭐ 這裡填入妳在後台看到的那個數字
        "exercise_type": "slow_jogging",
        "start_time": DateTime.now().subtract(Duration(seconds: widget.timeSeconds)).toIso8601String(),
        "end_time": DateTime.now().toIso8601String(),
        "total_mins": widget.timeSeconds ~/ 60,
        "posture_score": widget.averageAccuracy.toInt(),
        "calories": caloriesBurned,
        "step_count": widget.stepCount,
      }),
    );

    if (response.statusCode == 201) {
      debugPrint("✅ 終於成功存進去了！數據已同步。");
    } else {
      // ⭐ 這樣改才不會讓 HTML 刷屏
      debugPrint("❌ 儲存還是失敗，錯誤碼：${response.statusCode}");
      debugPrint("請看 Django 那個黑色的視窗，那裡的錯誤比較清楚。");
    }
  } catch (e) {
    debugPrint("⚠️ 連線異常: $e");
  }
}


  Future<void> _fetchAiFeedback() async {
    final feedback = await AiCoachService.generateFeedback(
      timeSeconds: widget.timeSeconds,
      averageAccuracy: widget.averageAccuracy,
      stepCount: widget.stepCount,
      calories: caloriesBurned,
    );
    
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
    final String minutesStr = (widget.timeSeconds ~/ 60).toString().padLeft(2, '0');
    final String secondsStr = (widget.timeSeconds % 60).toString().padLeft(2, '0');

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
                  const Text('運動完成！', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('恭喜你完成了這段時間的超慢跑', style: TextStyle(fontSize: 16, color: Colors.black54)),
                  const SizedBox(height: 40),
                  
                  // 數據網格
                  Row(
                    children: [
                      Expanded(child: _buildStatCard('運動時間', '$minutesStr:$secondsStr', Icons.timer_outlined, Colors.blueAccent)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildStatCard('消耗熱量', '$caloriesBurned kcal', Icons.local_fire_department_outlined, Colors.redAccent)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildStatCard('平均準確率', '${widget.averageAccuracy.toStringAsFixed(1)}%', Icons.check_circle_outline, widget.averageAccuracy > 80 ? Colors.green : Colors.orange)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildStatCard('步數', '${widget.stepCount} 步', Icons.directions_walk_outlined, Colors.purpleAccent)),
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
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.tips_and_updates, color: Colors.amber),
                            SizedBox(width: 8),
                            Text('AI 教練悄悄話', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_isLoadingAi)
                          const Center(child: CircularProgressIndicator(color: Colors.amber))
                        else
                          Text(_dynamicAiFeedback ?? '沒有建議', style: const TextStyle(fontSize: 16, height: 1.6)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text('回到主頁', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
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
              colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 14, color: Colors.black54)),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}