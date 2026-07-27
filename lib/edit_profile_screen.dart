import 'package:flutter/material.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // 建議初始化數據（之後可從 Firebase 抓取）
  late TextEditingController nameController;
  late TextEditingController weightController;
  late TextEditingController heightController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: 'Lamei');
    weightController = TextEditingController(text: '65');
    heightController = TextEditingController(text: '170');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 保持底色純白
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Edit Profile', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 頂部大頭貼編輯區（風格延續 Dark Card）
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1522),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey[200]!, width: 4),
                      ),
                      child: const Center(
                        child: Text('L', style: TextStyle(fontSize: 40, color: Colors.white)),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // 輸入框區塊
              _buildEditField(label: 'Full Name', controller: nameController, icon: Icons.person_outline),
              const SizedBox(height: 20),
              
              // Email 設為唯讀，避免第三方登入出錯
              _buildEditField(
                label: 'Email Address', 
                controller: TextEditingController(text: 'lamei@example.com'), 
                icon: Icons.mail_outline, 
                enabled: false // 鎖定不給改
              ),
              const SizedBox(height: 20),
              
              Row(
                children: [
                  Expanded(child: _buildEditField(label: 'Weight (kg)', controller: weightController, icon: Icons.monitor_weight_outlined)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildEditField(label: 'Height (cm)', controller: heightController, icon: Icons.straighten)),
                ],
              ),
              
              const SizedBox(height: 60),

              // 儲存按鈕（寬版深色風格）
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Django API Update Logic
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F1522),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 封裝輸入框，讓排版看起來整齊且與主頁面風格統一
  Widget _buildEditField({
    required String label, 
    required TextEditingController controller, 
    required IconData icon,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF718096))),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF4A5568)),
            filled: true,
            fillColor: enabled ? Colors.white : Colors.grey[100],
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
          ),
        ),
      ],
    );
  }
}