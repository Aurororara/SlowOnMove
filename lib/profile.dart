import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'edit_profile_screen.dart';
import 'package:flutter/foundation.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  int _workoutCount = 0;
  int timeSum = 0;
  int _totalCalories = 0;
  int _totalSteps = 0; 
  String _height = "--";
  String _weight = "--";
  String _fullName = "Lamei";
  String _email = "lamei@example.com";

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    final String baseUrl = kIsWeb ? "http://localhost:8000/api" : "http://10.0.2.2:8000/api";
    // ⭐ 設定目標 Member ID 為 6
    final int targetMemberId = 6; 

    try {
      final logResponse = await http.get(Uri.parse('$baseUrl/training-logs/'));
      final bodyResponse = await http.get(Uri.parse('$baseUrl/body-records/'));

      if (logResponse.statusCode == 200 && bodyResponse.statusCode == 200) {
        // 1. 先抓回所有人原始資料
        final List allLogs = json.decode(logResponse.body);
        final List allBodyRecords = json.decode(bodyResponse.body);

        // 2. ⭐ 過濾資料：只留下 member 為 6 的那些紀錄
        final List myLogs = allLogs.where((log) => log['member'] == targetMemberId).toList();
        final List myBodyRecords = allBodyRecords.where((rec) => rec['member'] == targetMemberId).toList();

        int calSum = 0;
        int stepSum = 0; 
        int timeSum = 0; 

        // 3. 只針對過濾後的 myLogs 進行累加計算
        for (var log in myLogs) {
          calSum += (log['calories'] as num).toInt();
          stepSum += (log['step_count'] as num? ?? 0).toInt();
          timeSum += (log['total_mins'] as num? ?? 0).toInt();
        }

        if (mounted) {
          setState(() {
            // ⭐ 更新狀態：現在這些數據都是 Member 6 專屬的了
            _workoutCount = timeSum; 
            _totalCalories = calSum;
            _totalSteps = stepSum; 
            
            if (myBodyRecords.isNotEmpty) {
              _height = myBodyRecords.last['height'].toString();
              _weight = myBodyRecords.last['weight'].toString();
            }
            _isLoading = false;
          });
        }
      } else {
        debugPrint("API 報錯: Logs(${logResponse.statusCode}), Body(${bodyResponse.statusCode})");
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("抓取資料失敗: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : RefreshIndicator(
              onRefresh: _fetchProfileData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _buildDarkProfileCard(context),
                      const SizedBox(height: 24),
                      _buildStatsGrid(), 
                      const SizedBox(height: 32),
                      _buildSectionTitle('PERSONAL INFORMATION'),
                      const SizedBox(height: 16),
                      _buildInfoTile(icon: Icons.person_outline, label: 'Full Name', value: _fullName),
                      const SizedBox(height: 12),
                      _buildInfoTile(icon: Icons.mail_outline, label: 'Email Address', value: _email),
                      const SizedBox(height: 12),
                      _buildInfoTile(icon: Icons.monitor_weight_outlined, label: 'Weight (kg)', value: '$_weight kg'),
                      const SizedBox(height: 12),
                      _buildInfoTile(icon: Icons.straighten, label: 'Height (cm)', value: '$_height cm'),
                      const SizedBox(height: 32),
                      _buildLogOutButton(context),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildDarkProfileCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(color: const Color(0xFF0F1522), borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Container(
            width: 90, height: 90,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
            child: Center(child: Text(_fullName[0], style: const TextStyle(fontSize: 40, color: Colors.black))),
          ),
          const SizedBox(height: 16),
          Text(_fullName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(_email, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildStatCard(Icons.emoji_events_outlined, '12', 'Achievements')),
            const SizedBox(width: 16),
            Expanded(child: _buildStatCard(Icons.access_time, '$_workoutCount min', // 加上單位，例如 120 min
  'Total Time')),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildStatCard(
              Icons.local_fire_department_outlined, 
              _totalCalories >= 1000 ? '${(_totalCalories/1000).toStringAsFixed(1)}k' : '$_totalCalories', 
              'Calories'
            )),
            const SizedBox(width: 16),
            Expanded(child: _buildStatCard(Icons.directions_walk_outlined, _totalSteps.toString(), '步數')), 
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
      child: Column(
        children: [
          Icon(icon, size: 28, color: const Color(0xFF4A5568)),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF718096))),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2C4364)));
  }

  Widget _buildInfoTile({required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4A5568)),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF718096))),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
        ],
      ),
    );
  }

  Widget _buildLogOutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity, height: 54,
      child: OutlinedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.logout, color: Color(0xFFE53935)),
        label: const Text('Log Out'),
        style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFE53935))),
      ),
    );
  }
}