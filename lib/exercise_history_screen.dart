import 'package:flutter/material.dart';

import 'services/api_service.dart';
import 'services/points_service.dart';
import 'services/user_session.dart';

class ExerciseHistoryScreen extends StatefulWidget {
  const ExerciseHistoryScreen({super.key});

  @override
  State<ExerciseHistoryScreen> createState() => _ExerciseHistoryScreenState();
}

class _ExerciseHistoryScreenState extends State<ExerciseHistoryScreen> {
  final ApiService _api = ApiService();
  final PointsService _pointsService = PointsService();

  bool _isLoading = true;
  List<dynamic> _historyLogs = [];
  Set<String> _unlockedReferenceIds = {};
  final Set<int> _unlockingLogIds = {};

  // 分頁設定
  int _currentPage = 1;
  final int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _fetchHistoryData();
  }

  // 抓取資料與解鎖清單
  // 抓取資料與解鎖清單
  Future<void> _fetchHistoryData() async {
    try {
      final responseLogs = await _api.dio.get('training-logs/');
      final responseUnlocks = await _pointsService.getUnlocks();

      final List<dynamic> logs = responseLogs.data is List
          ? List<dynamic>.from(responseLogs.data)
          : [];

      logs.sort(
        (a, b) => (b['start_time'] ?? '').toString().compareTo(
              (a['start_time'] ?? '').toString(),
            ),
      );

      final Set<String> unlockedIds = responseUnlocks
          .where((item) => item['feature_code'] == 'deep_analysis')
          .map<String>((item) => item['reference_id']?.toString() ?? '')
          .toSet();

      if (!mounted) return;

      setState(() {
        _historyLogs = logs;
        _unlockedReferenceIds = unlockedIds;
        _isLoading = false;
        _currentPage = 1;
      });
    } catch (e) {
      debugPrint('抓取歷史失敗: ${_api.getErrorMessage(e)}');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  // 取得該筆運動的 AI 建議文字（優先讀取後端資料，若無則依分數產生）
  String _getAdviceText(dynamic log, String exerciseType, int score) {
    final String rawAdvice = log['ai_advice']?.toString() ?? '';
    if (rawAdvice.isNotEmpty) return rawAdvice;

    if (exerciseType == 'squat') {
      if (score >= 80) {
        return "深蹲姿勢非常標準！核心有收緊，膝蓋與腳尖方向一致，重心掌握得很好。請繼續保持這個好習慣，這對鍛鍊臀腿肌肉非常有幫助！";
      } else if (score >= 60) {
        return "做得不錯，但還有進步空間。注意深蹲時重心要放在腳跟，背部保持挺直，不要過度前傾。下蹲時感受臀部向後坐的感覺。";
      } else {
        return "深蹲姿勢需要再調整喔。請注意：下蹲時臀部往後坐，膝蓋不要內夾，保持呼吸節奏。建議對著鏡子慢慢練習，感受肌肉發力。";
      }
    } else {
      if (score >= 80) {
        return "超慢跑節奏掌握得很完美！步伐輕盈，落地姿勢正確。繼續保持這樣的步頻與姿勢，能有效燃燒脂肪並保護膝蓋！";
      } else if (score >= 60) {
        return "表現不錯，但要注意落地時盡量使用前腳掌或全腳掌，避免腳跟重落地，以減少膝蓋負擔。保持身體微微前傾會更輕鬆喔。";
      } else {
        return "超慢跑姿勢需要微調。請保持身體微微前傾，步伐縮小，提高步頻，並注意手臂自然擺動。不要急，跟著自己的節奏慢慢來。";
      }
    }
  }

  // 執行點數解鎖
  Future<void> _handleUnlock(dynamic log) async {
    final int? logId = log['id'] is int
        ? log['id']
        : int.tryParse(log['id']?.toString() ?? '');
    if (logId == null) return;

    final referenceId = 'training_log:$logId';

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.tips_and_updates, color: Colors.amber),
            SizedBox(width: 8),
            Text("解鎖 AI 姿勢建議",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text("解鎖本筆紀錄之專屬深度建議將消耗 50 SP，是否確定解鎖？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("取消", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child:
                const Text("確定 (50 SP)", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _unlockingLogIds.add(logId);
    });

    try {
      final result = await _pointsService.unlockFeature(
        featureCode: 'deep_analysis',
        referenceId: referenceId,
      );

      final remainingBalance = result['remaining_balance'];
      if (remainingBalance is num) {
        UserSession.walletBalanceNotifier.value = remainingBalance.toDouble();
      }

      if (!mounted) return;

      setState(() {
        _unlockedReferenceIds.add(referenceId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已成功解鎖 AI 姿勢建議！')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_pointsService.getErrorMessage(e))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _unlockingLogIds.remove(logId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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

    final String exerciseType =
        log['exercise_type']?.toString() ?? 'slow_jogging';

    final int? logId = log['id'] is int
        ? log['id']
        : int.tryParse(log['id']?.toString() ?? '');
    final String referenceId = 'training_log:$logId';
    final bool isUnlocked = _unlockedReferenceIds.contains(referenceId);
    final bool isUnlocking = logId != null && _unlockingLogIds.contains(logId);

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
          tilePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          title: Row(
            children: [
              _buildLeadingCircle(exerciseType),
              const SizedBox(width: 12),
              _buildMainInfo(
                dateStr,
                startTimeFull,
                exerciseType,
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
                  const SizedBox(height: 16),
                  _buildAiAdviceCard(
                    log: log,
                    exerciseType: exerciseType,
                    score: accuracy,
                    isUnlocked: isUnlocked,
                    isUnlocking: isUnlocking,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // AI 建議卡片
  Widget _buildAiAdviceCard({
    required dynamic log,
    required String exerciseType,
    required int score,
    required bool isUnlocked,
    required bool isUnlocking,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tips_and_updates, color: Colors.amber, size: 18),
              const SizedBox(width: 6),
              const Text(
                'AI 姿勢建議',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              if (isUnlocked)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '已解鎖',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (isUnlocked)
            Text(
              _getAdviceText(log, exerciseType, score),
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xFF334155),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '點擊解鎖以檢視此訓練之動作建議與步頻調整技巧',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isUnlocking ? null : () => _handleUnlock(log),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: isUnlocking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            '使用 50 SP 解鎖建議',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
        ],
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

  Widget _buildLeadingCircle(String exerciseType) {
    final bool isSquat = exerciseType == 'squat';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isSquat ? Colors.orange.shade700 : Colors.black,
        shape: BoxShape.circle,
      ),
      child: Icon(
        isSquat ? Icons.fitness_center : Icons.directions_run,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  Widget _buildMainInfo(
    String date,
    String start,
    String exerciseType,
  ) {
    final bool isSquat = exerciseType == 'squat';
    final String title = isSquat ? '深蹲紀錄' : '超慢跑紀錄';

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSquat ? Colors.orange.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isSquat ? '深蹲' : '超慢跑',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSquat ? Colors.orange.shade800 : Colors.black87,
                  ),
                ),
              ),
            ],
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
