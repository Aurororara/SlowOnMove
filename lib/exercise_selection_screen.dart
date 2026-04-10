import 'package:flutter/material.dart';
import 'pose_detector_view.dart';

class ExerciseSelectionScreen extends StatelessWidget {
  const ExerciseSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {}, // Handle back if needed
        ),
        title: const Text(
          '選擇運動',
          style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
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
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32),
              
              // Card 1: 超慢跑
              _buildExerciseCard(
                context: context,
                iconEmoji: '🏃',
                title: '超慢跑',
                titleIcon: Icons.monitor_heart_outlined,
                subtitle: '低衝擊有氧運動，適合在家進行',
                bulletPoints: [
                  '提升心肺功能',
                  '燃燒卡路里',
                  '改善耐力',
                  '減少關節壓力',
                ],
                onStart: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PoseDetectorView()),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Card 2: 深蹲
              _buildExerciseCard(
                context: context,
                iconEmoji: '💪',
                title: '深蹲',
                titleIcon: Icons.fitness_center_outlined,
                subtitle: '下肢力量訓練，強化核心穩定',
                bulletPoints: [
                  '增強腿部肌力',
                  '提升核心穩定',
                  '改善下肢線條',
                  '提高代謝率',
                ],
                onStart: () {
                  // TODO: Navigate to Squat detector if available
                },
              ),
              const SizedBox(height: 20),

              // Card 3: 運動小提示
              _buildTipCard(),
            ],
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Container
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    iconEmoji,
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Content
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
                        Icon(titleIcon, size: 24, color: Colors.black87),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              // Action Button
              GestureDetector(
                onTap: onStart,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.arrow_forward, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Bullet points
          Padding(
            padding: const EdgeInsets.only(left: 76.0), // match indentation with text
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: bulletPoints.map((point) => Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 3,
                      backgroundColor: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      point,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )).toList(),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '運動小提示',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '每種運動都有其獨特的好處。您可以根據今天的身體狀況和訓練目標來選擇最適合的運動項目。',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.5,
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
