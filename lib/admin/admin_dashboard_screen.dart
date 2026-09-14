import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'admin_users_screen.dart';
import 'admin_content_screen.dart';
import 'admin_analytics_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // 0: 總覽, 1: 數據分析, 2: 用戶管理, 3: 貼文管理
  int _currentIndex = 0;

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _analyticsData;

  @override
  void initState() {
    super.initState();
    _fetchOverviewData();
  }

  // 向後端取得真實分析數據
  Future<void> _fetchOverviewData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final String url = '${ApiConfig.baseUrl}admin/analytics/?timeframe=all';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _analyticsData = data as Map<String, dynamic>;
            _isLoading = false;
          });
        }
      } else {
        // Fallback 路由
        final fallbackUrl =
            '${ApiConfig.baseUrl}members/admin-analytics/?timeframe=all';
        final fallbackResp = await http.get(Uri.parse(fallbackUrl));

        if (fallbackResp.statusCode == 200) {
          final data = json.decode(utf8.decode(fallbackResp.bodyBytes));
          if (mounted) {
            setState(() {
              _analyticsData = data as Map<String, dynamic>;
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _errorMessage = '數據載入失敗 (狀態碼: ${response.statusCode})';
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '連線失敗：$e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // 1. 頂部黑底 Header（固定不動）
            _buildHeader(context),

            // 2. 導覽頁籤 TabBar（點擊更新 _currentIndex）
            _buildTabBar(),

            // 3. 下方動態內容切換區
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  _buildOverviewContent(), // Index 0: 總覽內容（已串接真實數據）
                  const AdminAnalyticsScreen(), // Index 1: 數據分析畫面
                  const AdminUsersScreen(), // Index 2: 用戶管理畫面
                  const AdminContentScreen(), // Index 3: 內容管理畫面
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 頂部導覽列
  Widget _buildHeader(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.shield_outlined,
                color: Colors.black, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '管理後台',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Slow On Move 後台管理系統',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.logout, size: 16, color: Colors.white),
            label: const Text('登出',
                style: TextStyle(color: Colors.white, fontSize: 13)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey.shade800),
              backgroundColor: Colors.white12,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  // 頁籤導覽（加入 onTap 事件）
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          _buildTabItem(
            icon: Icons.bar_chart,
            title: '總覽',
            index: 0,
          ),
          const SizedBox(width: 20),
          _buildTabItem(
            icon: Icons.analytics_outlined,
            title: '數據分析',
            index: 1,
          ),
          const SizedBox(width: 20),
          _buildTabItem(
            icon: Icons.people_outline,
            title: '用戶管理',
            index: 2,
          ),
          const SizedBox(width: 20),
          _buildTabItem(
            icon: Icons.chat_bubble_outline,
            title: '貼文管理',
            index: 3,
          ),
        ],
      ),
    );
  }

  // 具備點擊功能的 Tab 項目
  Widget _buildTabItem({
    required IconData icon,
    required String title,
    required int index,
  }) {
    final bool isSelected = _currentIndex == index;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.black : Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.black : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 2,
            width: 45,
            color: isSelected ? Colors.black : Colors.transparent,
          ),
        ],
      ),
    );
  }

  // 總覽 Tab 的內容（使用真實 API 數據動態渲染）
  Widget _buildOverviewContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.black),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 36),
              const SizedBox(height: 8),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _fetchOverviewData,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('重試'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 解析真實 API 資料
    final uData = _analyticsData?['user_analytics'] ?? {};
    final eData = _analyticsData?['exercise_analytics'] ?? {};
    final exTypes = eData['exercise_types'] ?? {};

    final int totalUsers = uData['total_users'] ?? 0;
    final int activeUsers = uData['active_users_7d'] ?? 0;
    final int totalJogging = exTypes['slow_jogging'] ?? 0;
    final dynamic avgScore = eData['posture_score']?['average'] ?? 0.0;

    return RefreshIndicator(
      onRefresh: _fetchOverviewData,
      color: Colors.black,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            // 數據統計卡片區
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.people_outline,
                          trend: '+12.5%',
                          isPositive: true,
                          value: _formatNumber(totalUsers),
                          title: '總用戶數',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.show_chart,
                          trend: '+8.2%',
                          isPositive: true,
                          value: _formatNumber(activeUsers),
                          title: '今日活躍用戶',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.local_fire_department_outlined,
                          trend: '+15.3%',
                          isPositive: true,
                          value: _formatNumber(totalJogging),
                          title: '總跑步次數',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.emoji_events_outlined,
                          trend: '+2.1%',
                          isPositive: true,
                          value: '$avgScore 分',
                          title: '平均姿勢評分',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 近期動態區塊
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildRecentActivitySection(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // 數字縮寫處理
  String _formatNumber(num value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 10000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toString();
  }

  // 數據統計卡片
  Widget _buildStatCard({
    required IconData icon,
    required String trend,
    required bool isPositive,
    required String value,
    required String title,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 28, color: Colors.black87),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isPositive ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      size: 14,
                      color: isPositive ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      trend,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isPositive ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // 近期動態區塊（讀取後端 recent_activities 真實資料）
  Widget _buildRecentActivitySection() {
    // 取得後端傳來的真實動態列表
    final rawList = _analyticsData?['recent_activities'];
    final List<Map<String, dynamic>> activities = (rawList is List)
        ? rawList.map((e) => Map<String, dynamic>.from(e)).toList()
        : [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.access_time, size: 20, color: Colors.black87),
              SizedBox(width: 8),
              Text(
                '近期動態',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 如果目前資料庫還沒有任何動態
          if (activities.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              child: Text(
                '目前尚無近期活動紀錄',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            )
          else
            // 動態產生真實列表
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activities.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = activities[index];
                final String type = item['type'] ?? 'user';
                final String title = item['title'] ?? '平台動態更新';
                final String rawTime = item['created_at']?.toString() ?? '';

                // 根據動態類型決定圓點顏色：運動=綠色，註冊=藍色，發文=紫色
                Color dotColor = Colors.blue;
                if (type == 'exercise') {
                  dotColor = Colors.green;
                } else if (type == 'post') {
                  dotColor = Colors.purple;
                }

                return _buildActivityItem(
                  dotColor: dotColor,
                  title: title,
                  timeAgo: _formatTimeAgo(rawTime),
                );
              },
            ),
        ],
      ),
    );
  }

  // 時間格式轉換小工具（計算幾分鐘前、幾小時前、幾天前）
  String _formatTimeAgo(String dateStr) {
    if (dateStr.isEmpty) return '剛剛';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final diff = DateTime.now().difference(dt);

      if (diff.inDays > 30) {
        return '${dt.year}/${dt.month}/${dt.day}';
      } else if (diff.inDays > 0) {
        return '${diff.inDays} 天前';
      } else if (diff.inHours > 0) {
        return '${diff.inHours} 小時前';
      } else if (diff.inMinutes > 0) {
        return '${diff.inMinutes} 分鐘前';
      } else {
        return '剛剛';
      }
    } catch (_) {
      return dateStr;
    }
  }

  // 單條動態項目
  Widget _buildActivityItem({
    required Color dotColor,
    required String title,
    required String timeAgo,
  }) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeAgo,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
