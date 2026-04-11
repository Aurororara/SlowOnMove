import 'package:flutter/material.dart';
import 'pose_detector_view.dart';

class ExerciseSelectionScreen extends StatelessWidget {
  const ExerciseSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        useMaterial3: false,
        primaryColor: Colors.black,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            '選擇運動',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  '選擇運動類型',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '點擊卡片即可開始運動',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                _buildExerciseCard(
                  context: context,
                  iconEmoji: '🏃',
                  title: '超慢跑',
                  titleIcon: Icons.monitor_heart_outlined,
                  subtitle: '低衝擊有氧運動，適合在家進行',
                  bulletPoints: ['提升心肺功能', '燃燒卡路里', '改善耐力', '減少關節壓力'],
                  onStart: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PoseDetectorView()),
                    );
                  },
                ),
                const SizedBox(height: 20),
                _buildExerciseCard(
                  context: context,
                  iconEmoji: '💪',
                  title: '深蹲',
                  titleIcon: Icons.fitness_center_outlined,
                  subtitle: '下肢力量訓練，強化核心穩定',
                  bulletPoints: ['增強腿部肌力', '提升核心穩定', '改善下肢線條', '提高代謝率'],
                  onStart: () {},
                ),
                const SizedBox(height: 20),
                _buildTipCard(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseCard({
    required BuildContext context,
    required String iconEmoji,
    required String title,
    required IconData titleIcon,
    required String subtitle,
    required List<String> bulletPoints,
    required VoidCallback onStart,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300, width: 2),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(iconEmoji, style: const TextStyle(fontSize: 32)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(titleIcon, size: 24, color: Colors.black),
                      ],
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onStart,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 76),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: bulletPoints.map((point) {
                return Row(
                  children: [
                    const CircleAvatar(radius: 3, backgroundColor: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      point,
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 2),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const Text('💡', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '運動小提示',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                Text(
                  '根據今天的身體狀況選擇最適合的運動。',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}