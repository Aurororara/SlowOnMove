import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config/api_config.dart';
import 'services/user_session.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController nameController;
  late TextEditingController weightController;
  late TextEditingController heightController;

  String _exerciseGoal = 'health';
  String _exerciseFrequency = '1_2';

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(text: UserSession.displayName);

    weightController = TextEditingController(text: '65');
    heightController = TextEditingController(text: '170');

    _loadMemberData();
  }

  Future<void> _loadMemberData() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}members/${UserSession.memberId}/',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (!mounted) return;

        setState(() {
          nameController.text =
              data['username']?.toString() ?? UserSession.displayName;

          _exerciseGoal = data['exercise_goal']?.toString() ?? 'health';

          _exerciseFrequency = data['exercise_frequency']?.toString() ?? '1_2';
        });
      } else {
        debugPrint(
          '取得會員資料失敗：${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('取得會員資料錯誤：$e');
    }
  }

  Future<void> _saveChanges() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final response = await http.patch(
        Uri.parse(
          '${ApiConfig.baseUrl}members/${UserSession.memberId}/',
        ),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'username': nameController.text.trim(),
          'exercise_goal': _exerciseGoal,
          'exercise_frequency': _exerciseFrequency,
        }),
      );

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        UserSession.displayName = nameController.text.trim();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('資料已更新！'),
          ),
        );

        Navigator.pop(context, true);
      } else {
        debugPrint(
          '更新會員資料失敗：${response.statusCode}',
        );
        debugPrint(response.body);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '更新失敗：${response.statusCode}',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('更新會員資料錯誤：$e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('無法連線到伺服器'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    weightController.dispose();
    heightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1522),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.grey[200]!,
                          width: 4,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          UserSession.displayInitial,
                          style: const TextStyle(
                            fontSize: 40,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              _buildEditField(
                label: 'Full Name',
                controller: nameController,
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 20),
              _buildEditField(
                label: 'Email Address',
                controller: TextEditingController(
                  text: UserSession.email,
                ),
                icon: Icons.mail_outline,
                enabled: false,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildEditField(
                      label: 'Weight (kg)',
                      controller: weightController,
                      icon: Icons.monitor_weight_outlined,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildEditField(
                      label: 'Height (cm)',
                      controller: heightController,
                      icon: Icons.straighten,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              _buildDropdownSection(
                title: '運動目標',
                icon: Icons.flag_outlined,
                value: _exerciseGoal,
                items: const [
                  DropdownMenuItem(
                    value: 'weight_loss',
                    child: Text('減脂'),
                  ),
                  DropdownMenuItem(
                    value: 'muscle_gain',
                    child: Text('增肌'),
                  ),
                  DropdownMenuItem(
                    value: 'health',
                    child: Text('維持健康'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    _exerciseGoal = value;
                  });
                },
              ),
              const SizedBox(height: 20),
              _buildDropdownSection(
                title: '每週運動頻率',
                icon: Icons.calendar_month_outlined,
                value: _exerciseFrequency,
                items: const [
                  DropdownMenuItem(
                    value: '1_2',
                    child: Text('每週 1–2 次'),
                  ),
                  DropdownMenuItem(
                    value: '3_4',
                    child: Text('每週 3–4 次'),
                  ),
                  DropdownMenuItem(
                    value: '5_plus',
                    child: Text('每週 5 次以上'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    _exerciseFrequency = value;
                  });
                },
              ),
              const SizedBox(height: 50),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F1522),
                    disabledBackgroundColor: Colors.grey[400],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownSection({
    required String title,
    required IconData icon,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF718096),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey[200]!,
            ),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            items: items,
            onChanged: onChanged,
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                color: const Color(0xFF4A5568),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF718096),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              color: const Color(0xFF4A5568),
            ),
            filled: true,
            fillColor: enabled ? Colors.white : Colors.grey[100],
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Colors.grey[200]!,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Colors.grey[200]!,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
