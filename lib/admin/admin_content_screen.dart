import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class AdminContentScreen extends StatefulWidget {
  const AdminContentScreen({super.key});

  @override
  State<AdminContentScreen> createState() => _AdminContentScreenState();
}

class _AdminContentScreenState extends State<AdminContentScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _reports = [];

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  // 抓取被檢舉貼文列表
  Future<void> _fetchReports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final String url = '${ApiConfig.baseUrl}post-reports/admin-reports/';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _reports = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = '載入失敗 (狀態碼: ${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('抓取檢舉資料失敗: $e');
      setState(() {
        _errorMessage = '連線伺服器失敗，請確認後端已啟動';
        _isLoading = false;
      });
    }
  }

  // 處理檢舉 (action: 'take_down' 下架 / 'dismiss' 駁回)
  Future<void> _handleReportAction(
      int reportId, String action, int index) async {
    final bool isTakeDown = action == 'take_down';
    final String actionTitle = isTakeDown ? '下架貼文' : '保留貼文';
    final String actionPrompt =
        isTakeDown ? '下架後該貼文將從社群中移除，確定要執行嗎？' : '將標記此檢舉為已審核並保留貼文，確定嗎？';

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(actionTitle,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(actionPrompt),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isTakeDown
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            child: Text('確定$actionTitle'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final String url = '${ApiConfig.baseUrl}post-reports/$reportId/resolve/';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'action': action}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _reports[index]['status'] = data['status'];
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isTakeDown ? '貼文已成功下架' : '已標記為審核通過'),
              backgroundColor:
                  isTakeDown ? Colors.redAccent : Colors.blueAccent,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('操作失敗 (狀態碼: ${response.statusCode})')),
          );
        }
      }
    } catch (e) {
      debugPrint('處理檢舉錯誤: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('網路連線異常，無法完成操作')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 動態統計卡片數據
    final int pendingCount =
        _reports.where((r) => r['status'] == 'pending').length;
    final int reviewedCount =
        _reports.where((r) => r['status'] == 'reviewed').length;
    final int removedCount =
        _reports.where((r) => r['status'] == 'removed').length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // 1. 上方三欄統計卡片
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildBadgeStatCard(
                    title: '待處理\n檢舉',
                    value: '$pendingCount',
                    valueColor: const Color(0xFFD97706),
                    badgeIcon: Icons.outlined_flag,
                    badgeIconColor: const Color(0xFFD97706),
                    badgeBgColor: const Color(0xFFFEF3C7),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildBadgeStatCard(
                    title: '已審核\n',
                    value: '$reviewedCount',
                    valueColor: const Color(0xFF2563EB),
                    badgeIcon: Icons.visibility_outlined,
                    badgeIconColor: const Color(0xFF2563EB),
                    badgeBgColor: const Color(0xFFDBEAFE),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildBadgeStatCard(
                    title: '已下架\n',
                    value: '$removedCount',
                    valueColor: const Color(0xFFDC2626),
                    badgeIcon: Icons.delete_outline,
                    badgeIconColor: const Color(0xFFDC2626),
                    badgeBgColor: const Color(0xFFFEE2E2),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. 被檢舉貼文管理區塊
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildReportedPostsCard(),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // 頂部統計卡片
  Widget _buildBadgeStatCard({
    required String title,
    required String value,
    required Color valueColor,
    required IconData badgeIcon,
    required Color badgeIconColor,
    required Color badgeBgColor,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 14.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF4B5563),
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 18,
          right: -8,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: badgeBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(badgeIcon, size: 16, color: badgeIconColor),
          ),
        ),
      ],
    );
  }

  // 被檢舉貼文卡片主清單
  Widget _buildReportedPostsCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.outlined_flag, size: 22, color: Colors.black),
                    SizedBox(width: 8),
                    Text(
                      '被檢舉貼文管理',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _fetchReports,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else if (_reports.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 40, color: Color(0xFF0FB862)),
                    SizedBox(height: 8),
                    Text('目前沒有任何被檢舉的貼文', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _reports.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
              itemBuilder: (context, index) {
                final report = _reports[index];
                return _buildReportItem(report, index);
              },
            ),
        ],
      ),
    );
  }

  // 單則檢舉貼文 Item
  Widget _buildReportItem(Map<String, dynamic> report, int index) {
    final int reportId = report['id'] ?? 0;
    final String authorName = report['author_name'] ?? '未知作者';
    final String reporterName = report['reporter_name'] ?? '匿名用戶';
    final String postContent = report['post_content'] ?? '(無文字內容或貼文已刪除)';
    final String reason = report['reason'] ?? '未註明原因';
    final String status = report['status'] ?? 'pending';
    final String createdAt = report['created_at'] ?? '';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 頂部：作者、狀態標籤
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.grey.shade200,
                    child: Text(
                      authorName.isNotEmpty ? authorName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    authorName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              _buildReportStatusBadge(status),
            ],
          ),

          const SizedBox(height: 10),

          // 被檢舉貼文內容框
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              postContent,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(height: 10),

          // 檢舉理由與檢舉人
          Row(
            children: [
              const Icon(Icons.report_problem_outlined,
                  size: 14, color: Color(0xFFD97706)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '理由：$reason  (由 $reporterName 檢舉)',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
                ),
              ),
            ],
          ),

          if (createdAt.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              createdAt,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
          ],

          // 操作按鈕 (只在待處理時顯示操作按鈕)
          if (status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () =>
                      _handleReportAction(reportId, 'dismiss', index),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFF93C5FD)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('保留貼文', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () =>
                      _handleReportAction(reportId, 'take_down', index),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('下架貼文', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // 檢舉狀態標籤
  Widget _buildReportStatusBadge(String status) {
    if (status == 'pending') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: const Text(
          '待處理',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFFD97706)),
        ),
      );
    } else if (status == 'reviewed') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFDBEAFE),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: const Text(
          '已保留',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2563EB)),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: const Text(
          '已下架',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFFDC2626)),
        ),
      );
    }
  }
}
