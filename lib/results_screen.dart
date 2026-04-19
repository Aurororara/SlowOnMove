import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'services/ai_coach_service.dart';

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
    // Start the celebration!
    _confettiController.play();
    
    _fetchAiFeedback();
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
    // Rough estimate for super slow running: ~8 kcal per minute.
    double minutes = widget.timeSeconds / 60.0;
    return (minutes * 8.0).round();
  }

  @override
  Widget build(BuildContext context) {
    final String minutesStr = (widget.timeSeconds ~/ 60).toString().padLeft(2, '0');
    final String secondsStr = (widget.timeSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: const Color(0xFFE9F1F5), // Light pastel background
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    '運動完成！',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '恭喜你完成了這段時間的超慢跑',
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                  const SizedBox(height: 40),
                  
                  // Summary Stats Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          '運動時間',
                          '$minutesStr:$secondsStr',
                          Icons.timer_outlined,
                          Colors.blueAccent,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          '消耗熱量',
                          '$caloriesBurned kcal',
                          Icons.local_fire_department_outlined,
                          Colors.redAccent,
                        ),
                      ),
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
                          widget.averageAccuracy > 80 ? Colors.green : Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          '步數',
                          '${widget.stepCount} 步',
                          Icons.directions_walk_outlined,
                          Colors.purpleAccent,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Feedback Section
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
                          offset: const Offset(0, 5),
                        )
                      ]
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.tips_and_updates, color: Colors.amber),
                            const SizedBox(width: 8),
                            const Text(
                              'AI 教練悄悄話',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_isLoadingAi)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(12.0),
                              child: Column(
                                children: [
                                  CircularProgressIndicator(color: Colors.amber),
                                  SizedBox(height: 12),
                                  Text('教練正在撰寫你的量身建議...', style: TextStyle(color: Colors.black54)),
                                ],
                              ),
                            ),
                          )
                        else
                          Text(
                            _dynamicAiFeedback ?? '沒有建議',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.6,
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 60),
                  
                  // Back to home button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // Pop back to the main selection screen (pops the results screen)
                        Navigator.pop(context);
                      },
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
          
          // Confetti Overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2, // fall straight down
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 14, color: Colors.black54)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }
}
