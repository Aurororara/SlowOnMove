import 'package:flutter/material.dart';
import 'exercise_selection_screen.dart';
import 'login_screen.dart';

class OnboardingSetupScreen extends StatefulWidget {
  const OnboardingSetupScreen({super.key});

  @override
  State<OnboardingSetupScreen> createState() => _OnboardingSetupScreenState();
}

class _OnboardingSetupScreenState extends State<OnboardingSetupScreen> {
  int currentStep = 0;

  String? selectedFrequency;
  List<String> selectedGoals = [];
  String? selectedLevel;
  String? selectedTime;

  final List<Map<String, String>> frequencyOptions = [
    {'title': '從不 / 剛開始', 'subtitle': '我是運動新手'},
    {'title': '每週 1-2 次', 'subtitle': '偶爾運動'},
    {'title': '每週 3-4 次', 'subtitle': '已有固定習慣'},
    {'title': '每週 5-6 次', 'subtitle': '相當活躍'},
    {'title': '每天', 'subtitle': '高度自律訓練者'},
  ];

  final List<Map<String, String>> goalOptions = [
    {'title': '減重', 'emoji': '⚖️'},
    {'title': '增肌', 'emoji': '💪'},
    {'title': '耐力提升', 'emoji': '🏃'},
    {'title': '柔軟度', 'emoji': '🧘'},
    {'title': '整體健康', 'emoji': '🏋️'},
  ];

  final List<Map<String, String>> levelOptions = [
    {'title': '初學者', 'subtitle': '剛開始接觸運動'},
    {'title': '中階', 'subtitle': '已逐漸上手'},
    {'title': '進階', 'subtitle': '已有豐富經驗'},
  ];

  final List<Map<String, String>> timeOptions = [
    {'title': '早上', 'subtitle': '早起型'},
    {'title': '下午', 'subtitle': '白天活動'},
    {'title': '晚上', 'subtitle': '適合晚間運動'},
    {'title': '彈性安排', 'subtitle': '任何時間都可以'},
  ];

  int get totalSteps => 4;

  void nextStep() {
    if (currentStep < totalSteps - 1) {
      setState(() {
        currentStep++;
      });
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const ExerciseSelectionScreen(),
        ),
      );
    }
  }

  void previousStep() {
    if (currentStep > 0) {
      setState(() {
        currentStep--;
      });
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );
    }
  }

  bool canContinue() {
    switch (currentStep) {
      case 0:
        return selectedFrequency != null;
      case 1:
        return selectedGoals.isNotEmpty;
      case 2:
        return selectedLevel != null;
      case 3:
        return selectedTime != null;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (currentStep + 1) / totalSteps;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F6F6),
        elevation: 0,
        leading: IconButton(
          onPressed: previousStep,
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
        ),
        centerTitle: true,
        title: const Text(
          '設定',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${currentStep + 1}/$totalSteps',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.grey.shade300,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _buildStepContent(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: canContinue() ? nextStep : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      canContinue() ? Colors.black : Colors.grey.shade300,
                  foregroundColor:
                      canContinue() ? Colors.white : Colors.grey.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  currentStep == totalSteps - 1 ? '完成' : '繼續',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (currentStep) {
      case 0:
        return _buildFrequencyStep();
      case 1:
        return _buildGoalsStep();
      case 2:
        return _buildLevelStep();
      case 3:
        return _buildTimeStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTitle(String title, String subtitle) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildFrequencyStep() {
    return Column(
      children: [
        _buildTitle('你多久運動一次？', '這能幫助我們更了解你的目前狀況'),
        ...frequencyOptions.map((item) {
          final selected = selectedFrequency == item['title'];
          return _buildSingleChoiceCard(
            title: item['title']!,
            subtitle: item['subtitle']!,
            selected: selected,
            onTap: () {
              setState(() {
                selectedFrequency = item['title'];
              });
            },
          );
        }),
      ],
    );
  }

  Widget _buildGoalsStep() {
    return Column(
      children: [
        _buildTitle('你的運動目標是什麼？', '可多選'),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: goalOptions.map((item) {
            final selected = selectedGoals.contains(item['title']);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (selected) {
                    selectedGoals.remove(item['title']);
                  } else {
                    selectedGoals.add(item['title']!);
                  }
                });
              },
              child: Container(
                width: (MediaQuery.of(context).size.width - 80) / 2,
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: BoxDecoration(
                  color: selected ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: selected ? Colors.black : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      item['emoji']!,
                      style: const TextStyle(fontSize: 34),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      item['title']!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: selected ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: selected ? Colors.white : Colors.grey,
                    )
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        Text(
          '已選擇 ${selectedGoals.length} 項目標',
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF4B5563),
          ),
        ),
      ],
    );
  }

  Widget _buildLevelStep() {
    return Column(
      children: [
        _buildTitle('你目前的體能程度如何？', '這能幫助我們調整適合你的運動計畫'),
        ...levelOptions.map((item) {
          final selected = selectedLevel == item['title'];
          return _buildSingleChoiceCard(
            title: item['title']!,
            subtitle: item['subtitle']!,
            selected: selected,
            onTap: () {
              setState(() {
                selectedLevel = item['title'];
              });
            },
          );
        }),
      ],
    );
  }

  Widget _buildTimeStep() {
    return Column(
      children: [
        _buildTitle('你偏好什麼時段運動？', '這能幫助我們安排更適合的訓練時間'),
        ...timeOptions.map((item) {
          final selected = selectedTime == item['title'];
          return _buildSingleChoiceCard(
            title: item['title']!,
            subtitle: item['subtitle']!,
            selected: selected,
            onTap: () {
              setState(() {
                selectedTime = item['title'];
              });
            },
          );
        }),
      ],
    );
  }

  Widget _buildSingleChoiceCard({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: selected ? Colors.black : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? Colors.black : Colors.grey.shade300,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: selected ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            selected ? Colors.white70 : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 28,
                )
            ],
          ),
        ),
      ),
    );
  }
}
