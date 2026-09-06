import 'package:flutter/material.dart';

import 'onboarding_setup_screen.dart';
import 'main_screen.dart';
import 'services/auth/google_auth_service.dart';
import 'services/auth/facebook_auth_service.dart';
import 'services/auth/local_auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _agreeToTerms = false;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _clearLocalForm() {
    _usernameController.clear();
    _emailController.clear();
    _nameController.clear();
    _passwordController.clear();
    _isSignUp = false;
    _obscurePassword = true;
  }

  void _showAlert(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            '提醒',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('確定'),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleLocalAuth({BuildContext? sheetContext}) async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showAlert('請填寫所有必要欄位');
      return;
    }

    if (_isSignUp) {
      final email = _emailController.text.trim();
      final name = _nameController.text.trim();

      if (email.isEmpty || name.isEmpty) {
        _showAlert('請填寫所有必要欄位');
        return;
      }

      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(email)) {
        _showAlert('請輸入有效的電子信箱格式');
        return;
      }

      if (password.length < 6) {
        _showAlert('密碼長度必須至少為 6 個字元');
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      bool? isNewUser;

      if (_isSignUp) {
        isNewUser = await LocalAuthService().signUp(
          username: username,
          email: _emailController.text.trim(),
          password: password,
          name: _nameController.text.trim(),
        );
      } else {
        isNewUser = await LocalAuthService().signIn(username, password);
      }

      if (!context.mounted) return;

      if (isNewUser != null) {
        if (sheetContext != null && sheetContext.mounted) {
          Navigator.pop(sheetContext);
        }

        _showSuccessMessage(_isSignUp ? '註冊成功！' : '登入成功！');

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => isNewUser == true
                ? const OnboardingSetupScreen()
                : const MainScreen(),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;

      final rawErr = e.toString().replaceAll('Exception: ', '').trim();
      String errorMessage = _isSignUp ? '註冊失敗' : '登入失敗，請檢查帳號與密碼';

      // 優先比對後端停權或其他特定訊息
      if (rawErr.contains('停權')) {
        errorMessage = rawErr;
      } else if (rawErr.contains('該用戶帳號已存在')) {
        errorMessage = '註冊失敗：該用戶帳號已存在';
      } else if (rawErr.contains('該電子信箱已被註冊')) {
        errorMessage = '註冊失敗：該電子信箱已被註冊';
      } else if (rawErr.contains('帳號或密碼錯誤') || rawErr.contains('401')) {
        errorMessage = '帳號或密碼錯誤';
      } else if (rawErr.isNotEmpty) {
        errorMessage = rawErr;
      }

      _showAlert(errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _ensureTermsAgreed() async {
    if (_agreeToTerms) return true;

    final agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
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
              '3. 若您繼續登入，即表示您已閱讀並同意相關條款。',
              style: TextStyle(height: 1.6),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('不同意'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
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

    if (agreed == true) {
      setState(() {
        _agreeToTerms = true;
      });
      return true;
    }

    return false;
  }

  Future<void> _showEmailLoginSheet() async {
    final agreed = await _ensureTermsAgreed();
    if (!agreed || !context.mounted) return;

    _clearLocalForm();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _isSignUp ? '建立帳號' : 'Email 登入',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setSheetState(() {
                                _isSignUp = !_isSignUp;
                              });
                            },
                            child: Text(
                              _isSignUp ? '切換至登入' : '切換至註冊',
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _buildTextField(
                        controller: _usernameController,
                        label: _isSignUp ? '用戶帳號' : '帳號或 Email',
                        hint: _isSignUp ? '請輸入用戶名稱' : '請輸入用戶名稱或信箱',
                        icon: Icons.person_outline,
                      ),
                      if (_isSignUp) ...[
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _nameController,
                          label: '暱稱 / 姓名',
                          hint: '請輸入顯示的暱稱',
                          icon: Icons.face_outlined,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _emailController,
                          label: '電子信箱',
                          hint: 'example@email.com',
                          icon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ],
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _passwordController,
                        label: '密碼',
                        hint: '請輸入密碼（至少 6 位數）',
                        icon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        keyboardType: TextInputType.visiblePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.grey[600],
                          ),
                          onPressed: () {
                            setSheetState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () =>
                              _handleLocalAuth(sheetContext: sheetContext),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            _isSignUp ? '註冊帳號' : '立即登入',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleSocialLogin(String loginType) async {
    final agreed = await _ensureTermsAgreed();
    if (!agreed || !context.mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      bool? isNewUser;

      if (loginType == 'Google') {
        isNewUser = await GoogleAuthService().signIn();
      } else if (loginType == 'Facebook') {
        isNewUser = await FacebookAuthService().signIn();
      } else if (loginType == 'Apple') {
        isNewUser = await LocalAuthService().signIn('dev', 'dev123456');
      } else {
        _showAlert('$loginType 登入尚未實作');
        return;
      }

      if (!context.mounted) return;

      if (isNewUser != null) {
        _showSuccessMessage('$loginType 登入成功');

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => isNewUser == true
                ? const OnboardingSetupScreen()
                : const MainScreen(),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      final rawErr = e.toString().replaceAll('Exception: ', '').trim();
      _showAlert(rawErr);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
                errorBuilder: (context, error, stackTrace) {
                  return Container(color: Colors.grey[300]);
                },
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
                  stops: [0.0, 0.22, 0.32, 0.42, 0.52, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 5),
                  const Text(
                    '慢動作運動',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '每一步都算數',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(flex: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Divider(color: Colors.grey[300], thickness: 1),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '選擇登入方式',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(color: Colors.grey[300], thickness: 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Column(
                    children: [
                      _buildLoginOptionButton(
                        icon: Icons.mail_outline,
                        text: '使用 Email 登入',
                        onTap: _showEmailLoginSheet,
                      ),
                      const SizedBox(height: 12),
                      _buildLoginOptionButton(
                        icon: Icons.g_mobiledata,
                        text: '使用 Google 登入',
                        onTap: () => _handleSocialLogin('Google'),
                      ),
                      const SizedBox(height: 12),
                      _buildLoginOptionButton(
                        icon: Icons.apple,
                        text: '使用 Apple 登入',
                        onTap: () => _handleSocialLogin('Apple'),
                      ),
                      const SizedBox(height: 12),
                      _buildLoginOptionButton(
                        icon: Icons.facebook,
                        text: '使用 Facebook 登入',
                        onTap: () => _handleSocialLogin('Facebook'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: _agreeToTerms,
                          activeColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _agreeToTerms = val ?? false;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: _ensureTermsAgreed,
                          child: Text.rich(
                            TextSpan(
                              text: '我已閱讀並同意 ',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              children: const [
                                TextSpan(
                                  text: '服務條款與隱私權政策',
                                  style: TextStyle(
                                    decoration: TextDecoration.underline,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static Widget _buildLoginOptionButton({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: icon == Icons.g_mobiledata ? 34 : 22,
              color: Colors.black87,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 36),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
            prefixIcon: Icon(icon, size: 20, color: Colors.black54),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.grey[50]!.withOpacity(0.8),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.black87, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
