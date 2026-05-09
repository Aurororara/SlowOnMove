import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../services/user_session.dart'; // 確保路徑指向妳的 services 資料夾

class ExerciseHistoryScreen extends StatefulWidget {
  const ExerciseHistoryScreen({super.key});

  @override
  State<ExerciseHistoryScreen> createState() => _ExerciseHistoryScreenState();
}

class _ExerciseHistoryScreenState extends State<ExerciseHistoryScreen> {
  bool _isLoading = true;
  List<dynamic> _historyLogs = [];

  @override
  void initState() {
    super.initState();
    _fetchHistoryData();
  }

  // 1. 去後端拿資料
  Future<void> _fetchHistoryData() async {
    final String baseUrl = kIsWeb ? "http://localhost:8000/api" : "http://10.0.2.2:8000/api";
    final int currentMemberId = UserSession.memberId;

    try {
      final response = await http.get(Uri.parse('$baseUrl/training-logs/'));

      if (response.statusCode == 200) {
        final List allLogs = json.decode(response.body);

        // 過濾屬於自己的紀錄並按時間排序
        final myLogs = allLogs.where((log) => log['member'] == currentMemberId).toList();
        myLogs.sort((a, b) => b['start_time'].compareTo(a['start_time']));

        if (mounted) {
          setState(() {
            _historyLogs = myLogs;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("抓取失敗: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise History', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: const Color(0xFFF7F9FC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _historyLogs.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _fetchHistoryData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _historyLogs.length,
                    itemBuilder: (context, index) => _buildRealHistoryCard(_historyLogs[index]),
                  ),
                ),
    );
  }

  // 2. 歷史紀錄卡片 (核心 UI)
  Widget _buildRealHistoryCard(dynamic log) {
    // 時間字串處理
    String fullStartTime = log['start_time']?.toString() ?? "";
    String fullEndTime = log['end_time']?.toString() ?? "";
    String dateStr = fullStartTime.isNotEmpty ? fullStartTime.split('T')[0] : "未知日期";
    
    // 擷取時:分:秒 (例如 14:30:05)
    String startTimeFull = fullStartTime.contains('T') ? fullStartTime.split('T')[1].substring(0, 8) : "00:00:00";
    String endTimeFull = fullEndTime.contains('T') ? fullEndTime.split('T')[1].substring(0, 8) : "00:00:00";

    int accuracy = log['posture_score'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          // 外面看到的標題：日期 + 開始時間
          title: Row(
            children: [
              _buildLeadingCircle(),
              const SizedBox(width: 12),
              _buildMainInfo(dateStr, startTimeFull), 
            ],
          ),
          // 運動三大數據
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem('${log['total_mins'] ?? 0} min', 'Duration'),
                _buildStatItem('${log['calories'] ?? 0} kcal', 'Calories'),
                _buildStatItem('${(log['distance'] as num?)?.toDouble() ?? 0.0} km', 'Distance'),
              ],
            ),
          ),
          // 展開後顯示詳細資訊
          children: [
            const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFEDF2F7)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  _buildDetailRow(Icons.timer_outlined, "Time Range", "$startTimeFull - $endTimeFull", Colors.blueGrey),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.gps_fixed, "Posture Accuracy", "$accuracy%", Colors.green),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 以下為小零件 (Helper Methods) ---

  Widget _buildLeadingCircle() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
      child: const Icon(Icons.show_chart, color: Colors.white, size: 20),
    );
  }

  // 標題區域：日期 + 開始時間
  Widget _buildMainInfo(String date, String start) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Slow Jog Session', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 12, color: Colors.blueGrey),
              const SizedBox(width: 4),
              Text(date, style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
              const SizedBox(width: 10),
              const Icon(Icons.access_time, size: 12, color: Colors.blueGrey),
              const SizedBox(width: 4),
              Text(start, style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3748))),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("尚未有任何運動紀錄", style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }
}