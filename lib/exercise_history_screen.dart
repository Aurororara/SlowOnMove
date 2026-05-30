import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'services/user_session.dart';
import 'config/api_config.dart';

class ExerciseHistoryScreen extends StatefulWidget {
  const ExerciseHistoryScreen({super.key});

  @override
  State<ExerciseHistoryScreen> createState() => _ExerciseHistoryScreenState();
}

class _ExerciseHistoryScreenState extends State<ExerciseHistoryScreen> {
  bool _isLoading = true;
  List<dynamic> _historyLogs = [];

  // 分頁設定
  int _currentPage = 1;
  final int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _fetchHistoryData();
  }

  // 抓取資料 (全面統一版本)
  Future<void> _fetchHistoryData() async {
    // 1. 統一採用組員寫好的 ApiConfig IP 機制
    final String baseUrl = ApiConfig.baseUrl;

    // 2. 統一從 UserSession 拿取目前登入者的 Member ID
    final int currentMemberId = UserSession.memberId;

    try {
      // 3. 拼接正確的 baseUrl 路徑
      final response = await http.get(Uri.parse('${baseUrl}training-logs/'));

      if (response.statusCode == 200) {
        final List allLogs = json.decode(response.body);

        // 4. 動態過濾自己的紀錄 (currentMemberId 是誰就過濾誰)
        final myLogs =
            allLogs.where((log) => log['member'] == currentMemberId).toList();

        // 時間排序（最新在前）
        myLogs.sort(
          (a, b) => b['start_time'].compareTo(a['start_time']),
        );

        if (mounted) {
          setState(() {
            _historyLogs = myLogs;
            _isLoading = false;
            _currentPage = 1;
          });
        }
      } else {
        debugPrint("API 錯誤，狀態碼: ${response.statusCode}");
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      debugPrint("抓取歷史失敗: $e");

      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 分頁資料切割
    final int startIndex = (_currentPage - 1) * _itemsPerPage;

    final int endIndex =
        (startIndex + _itemsPerPage).clamp(0, _historyLogs.length);

    final currentPageLogs = _historyLogs.sublist(startIndex, endIndex);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '運動歷史紀錄',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: const Color(0xFFF7F9FC),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _historyLogs.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _fetchHistoryData,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: currentPageLogs.length,
                          itemBuilder: (context, index) =>
                              _buildRealHistoryCard(
                            currentPageLogs[index],
                          ),
                        ),
                      ),
                    ),

                    // 分頁控制
                    _buildPagination(),
                  ],
                ),
    );
  }

  // 歷史紀錄卡片
  Widget _buildRealHistoryCard(dynamic log) {
    String fullStartTime = log['start_time']?.toString() ?? "";

    String fullEndTime = log['end_time']?.toString() ?? "";

    String dateStr =
        fullStartTime.isNotEmpty ? fullStartTime.split('T')[0] : "未知日期";

    String startTimeFull = fullStartTime.contains('T')
        ? fullStartTime.split('T')[1].substring(0, 8)
        : "00:00:00";

    String endTimeFull = fullEndTime.contains('T')
        ? fullEndTime.split('T')[1].substring(0, 8)
        : "00:00:00";

    int accuracy = log['posture_score'] ?? 0;
    final int duration = log['total_mins'] ?? 0;

    final int calories = ((log['calories'] as num?)?.toDouble() ?? 0.0).round();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Colors.grey[200]!,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            8,
          ),
          title: Row(
            children: [
              _buildLeadingCircle(),
              const SizedBox(width: 12),
              _buildMainInfo(
                dateStr,
                startTimeFull,
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '$duration 分鐘',
                    '運動時間',
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '$calories 大卡',
                    '消耗熱量',
                  ),
                ),
              ],
            ),
          ),
          children: [
            const Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: Color(0xFFEDF2F7),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    Icons.timer_outlined,
                    "時間範圍",
                    "$startTimeFull - $endTimeFull",
                    Colors.blueGrey,
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.gps_fixed,
                    "姿勢準確度",
                    "$accuracy%",
                    Colors.green,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 分頁 UI
  Widget _buildPagination() {
    final int totalPages = (_historyLogs.length / _itemsPerPage).ceil();

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 16,
        top: 4,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _currentPage > 1
                ? () {
                    setState(() {
                      _currentPage--;
                    });
                  }
                : null,
            icon: const Icon(
              Icons.chevron_left,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$_currentPage / $totalPages',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: _currentPage < totalPages
                ? () {
                    setState(() {
                      _currentPage++;
                    });
                  }
                : null,
            icon: const Icon(
              Icons.chevron_right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadingCircle() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.show_chart,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  Widget _buildMainInfo(
    String date,
    String start,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '超慢跑紀錄',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.calendar_today,
                size: 12,
                color: Colors.blueGrey,
              ),
              const SizedBox(width: 4),
              Text(
                date,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.blueGrey,
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.access_time,
                size: 12,
                color: Colors.blueGrey,
              ),
              const SizedBox(width: 4),
              Text(
                start,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.blueGrey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String value,
    String label,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_toggle_off,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const Text(
            "尚未有任何運動紀錄",
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
