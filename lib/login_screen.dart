import 'package:flutter/material.dart';
import 'onboarding_setup_screen.dart';
import 'exercise_selection_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future<void> _showTermsDialog(BuildContext context, String loginType) async {
    final agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            '使用條款與隱私權政策',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const SingleChildScrollView(
            child: Text(
              '在繼續登入前，請先閱讀並同意我們的服務條款與隱私權政策。\n\n'
              '1. 您同意依照本平台規範使用服務。\n'
              '2. 我們將依隱私權政策蒐集與使用必要資料。\n'
              '3. 若您繼續登入，即表示您已閱讀並同意相關條款面。',
              style: TextStyle(height: 1.6),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('不同意'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: const Text('同意並繼續'),
            ),
          ],
        );
      },
    );

    // 模擬第一次註冊 (如果是測試舊版跳轉，請檢查這裡是否被改動)
    const bool isFirstTimeUser = true; 

    if (agreed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$loginType 登入成功')),
      );

      if (isFirstTimeUser) {
        // 跳轉到新手設定頁面
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const OnboardingSetupScreen(),
          ),
        );
      } else {
        // 如果不是第一次，直接跳到運動選擇頁面
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const ExerciseSelectionScreen(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(40),
                topRight: Radius.circular(40),
              ),
              child: Image.asset(
                'assets/background1.png',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (context, error, stackTrace) =>
                    Container(color: Colors.grey[300]),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00FFFFFF),
                    Color(0x10FFFFFF),
                    Color(0x55FFFFFF),
                    Color(0xCCFFFFFF),
                    Color(0xFFFFFFFF),
                    Color(0xFFFFFFFF),
                  ],
                  stops: [0.0, 0.32, 0.42, 0.52, 0.62, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: SizedBox(
                height: MediaQuery.of(context).size.height,
                child: Column(
                  children: [
                    const Spacer(flex: 5),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        children: [
                          const Text(
                            '慢動作運動',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            '每一步都算數',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                              letterSpacing: 2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 28),
                          const Text(
                            '養成健康習慣，\n從每一步開始',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            '透過超慢跑與日常運動，幫助你追蹤進度、維持動力，逐步達成健康目標。',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.8,
                              color: Color(0xFF5B6B7A),
                            ),
                          ),
                          const SizedBox(height: 34),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStatItem('5萬+', '使用者'),
                              _buildStatItem('200萬+', '運動次數'),
                              _buildStatItem('4.9★', '評分'),
                            ],
                          ),
                          const SizedBox(height: 30),
                          const Text(
                            '選擇登入方式',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF9CA3AF),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildSocialButton(
                            icon: Icons.g_mobiledata,
                            label: '使用 Google 登入',
                            onTap: () => _showTermsDialog(context, 'Google'),
                          ),
                          const SizedBox(height: 12),
                          _buildSocialButton(
                            icon: Icons.apple,
                            label: '使用 Apple 登入',
                            onTap: () => _showTermsDialog(context, 'Apple'),
                          ),
                          const SizedBox(height: 12),
                          _buildSocialButton(
                            icon: Icons.facebook,
                            label: '使用 Facebook 登入',
                            onTap: () => _showTermsDialog(context, 'Facebook'),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            '點選登入即會先顯示服務條款與隱私權政策',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildStatItem(String value, String label) {
    return Container(
      width: 90,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  static Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.black87),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey[300]!),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.white,
        ),
      ),
    );
  }
}