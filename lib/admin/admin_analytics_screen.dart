import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  String _selectedTimeframe = 'all'; // '7d', '30d', 'all'
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _analyticsData;

  @override
  void initState() {
    super.initState();
    _fetchAnalyticsData();
  }

  Future<void> _fetchAnalyticsData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final String url = '${ApiConfig.baseUrl}admin/analytics/?timeframe=$_selectedTimeframe';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _analyticsData = data as Map<String, dynamic>;
          _isLoading = false;
        });
      } else {
        // Try fallback route
        final fallbackUrl = '${ApiConfig.baseUrl}members/admin-analytics/?timeframe=$_selectedTimeframe';
        final fallbackResp = await http.get(Uri.parse(fallbackUrl));

        if (fallbackResp.statusCode == 200) {
          final data = json.decode(utf8.decode(fallbackResp.bodyBytes));
          setState(() {
            _analyticsData = data as Map<String, dynamic>;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = '數據載入失敗 (狀態碼: ${response.statusCode})';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = '連線失敗：$e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: RefreshIndicator(
        onRefresh: _fetchAnalyticsData,
        color: Colors.black,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 頂部標題與時間選擇按鈕
              _buildHeaderTimeframeSelector(),
              const SizedBox(height: 16),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60.0),
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.black),
                  ),
                )
              else if (_errorMessage != null)
                _buildErrorCard()
              else if (_analyticsData != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 2. 核心 KPI 數據概覽卡片
                    _buildKpiOverviewGrid(),
                    const SizedBox(height: 20),

                    // 3. 使用者分析區塊
                    _buildUserAnalyticsSection(),
                    const SizedBox(height: 20),

                    // 4. 運動數據統計區塊
                    _buildExerciseAnalyticsSection(),
                    const SizedBox(height: 20),

                    // 5. 社群互動與檢舉區塊
                    _buildCommunityAnalyticsSection(),
                    const SizedBox(height: 20),

                    // 6. 點數與綠界營收區塊
                    _buildPointsRevenueSection(),
                    const SizedBox(height: 24),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  // 1. 頂部標題與時間範圍切換
  Widget _buildHeaderTimeframeSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '數據分析中心',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 2),
            Text(
              '平台即時營運與使用者運動指標彙整',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              _buildTimeChip('7d', '7 天'),
              _buildTimeChip('30d', '30 天'),
              _buildTimeChip('all', '全部'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeChip(String value, String label) {
    final bool isSelected = _selectedTimeframe == value;
    return GestureDetector(
      onTap: () {
        if (_selectedTimeframe != value) {
          setState(() {
            _selectedTimeframe = value;
          });
          _fetchAnalyticsData();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  // 錯誤提示卡片
  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 36),
          const SizedBox(height: 10),
          Text(
            _errorMessage ?? '載入發生未知錯誤',
            style: const TextStyle(color: Colors.red, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _fetchAnalyticsData,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('重試'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          )
        ],
      ),
    );
  }

  // 2. 核心 KPI 總覽 Grid
  Widget _buildKpiOverviewGrid() {
    final uData = _analyticsData?['user_analytics'] ?? {};
    final eData = _analyticsData?['exercise_analytics'] ?? {};
    final cData = _analyticsData?['community_analytics'] ?? {};
    final pData = _analyticsData?['points_analytics'] ?? {};

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: '總會員數',
                value: '${uData['total_users'] ?? 0}',
                unit: '人',
                icon: Icons.people_alt_outlined,
                color: Colors.blue.shade700,
                bg: Colors.blue.shade50,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                title: '運動總時長',
                value: '${eData['total_mins'] ?? 0}',
                unit: '分鐘',
                icon: Icons.timer_outlined,
                color: Colors.orange.shade800,
                bg: Colors.orange.shade50,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: '社群發帖數',
                value: '${cData['total_posts'] ?? 0}',
                unit: '篇',
                icon: Icons.article_outlined,
                color: Colors.purple.shade700,
                bg: Colors.purple.shade50,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                title: 'ECPay 總收益',
                value: '\$${pData['total_ecpay_revenue_twd'] ?? 0}',
                unit: 'TWD',
                icon: Icons.monetization_on_outlined,
                color: Colors.green.shade700,
                bg: Colors.green.shade50,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
    required Color bg,
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
              Text(
                title,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, size: 18, color: color),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 3. 使用者分析區塊
  Widget _buildUserAnalyticsSection() {
    final uData = _analyticsData?['user_analytics'] ?? {};
    final providers = uData['login_providers'] ?? {};
    final int emailCnt = providers['email'] ?? 0;
    final int googleCnt = providers['google'] ?? 0;
    final int fbCnt = providers['facebook'] ?? 0;
    final int totalProv = (emailCnt + googleCnt + fbCnt).clamp(1, 999999);

    final regTrend = List<Map<String, dynamic>>.from(uData['registration_trend'] ?? []);

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
          _buildSectionHeader(
            icon: Icons.person_search_outlined,
            title: '使用者分析 (User Growth & Cohorts)',
          ),
          const SizedBox(height: 14),

          // 子 KPI
          Row(
            children: [
              Expanded(
                child: _buildSubStatChip('30天新會員', '${uData['new_users_30d'] ?? 0} 人', Colors.blue),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSubStatChip('7天活躍會員', '${uData['active_users_7d'] ?? 0} 人', Colors.teal),
              ),
            ],
          ),
          const SizedBox(height: 16),

          const Text(
            '登入方式分佈 (Login Providers)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),

          // 比例進度條
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  if (emailCnt > 0)
                    Expanded(
                      flex: emailCnt,
                      child: Container(color: Colors.grey.shade700),
                    ),
                  if (googleCnt > 0)
                    Expanded(
                      flex: googleCnt,
                      child: Container(color: Colors.red.shade400),
                    ),
                  if (fbCnt > 0)
                    Expanded(
                      flex: fbCnt,
                      child: Container(color: Colors.blue.shade600),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 圖例 Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendDot('Email / 密碼', '$emailCnt人 (${(emailCnt / totalProv * 100).toStringAsFixed(0)}%)', Colors.grey.shade700),
              _buildLegendDot('Google 登入', '$googleCnt人 (${(googleCnt / totalProv * 100).toStringAsFixed(0)}%)', Colors.red.shade400),
              _buildLegendDot('Facebook 登入', '$fbCnt人 (${(fbCnt / totalProv * 100).toStringAsFixed(0)}%)', Colors.blue.shade600),
            ],
          ),

          if (regTrend.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              '近期註冊趨勢 (Registration Trend)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            _buildBarTrendChart(
              items: regTrend.map((e) => {'label': e['date'] ?? '', 'value': (e['count'] ?? 0).toDouble()}).toList(),
              barColor: Colors.blue.shade600,
            ),
          ],
        ],
      ),
    );
  }

  // 4. 運動數據統計區塊
  Widget _buildExerciseAnalyticsSection() {
    final eData = _analyticsData?['exercise_analytics'] ?? {};
    final exTypes = eData['exercise_types'] ?? {};
    final int jogCnt = exTypes['slow_jogging'] ?? 0;
    final int squatCnt = exTypes['squat'] ?? 0;
    final int totalEx = (jogCnt + squatCnt).clamp(1, 999999);

    final postureScore = eData['posture_score'] ?? {};
    final double avgScore = (postureScore['average'] ?? 0.0).toDouble();
    final int goodCnt = postureScore['good'] ?? 0;
    final int fairCnt = postureScore['fair'] ?? 0;
    final int needsWorkCnt = postureScore['needs_work'] ?? 0;
    final int totalPosture = (goodCnt + fairCnt + needsWorkCnt).clamp(1, 999999);

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
          _buildSectionHeader(
            icon: Icons.fitness_center_outlined,
            title: '運動數據統計 (Exercise Performance)',
          ),
          const SizedBox(height: 14),

          // 核心數據 Card
          Row(
            children: [
              Expanded(
                child: _buildSubStatChip('累積消耗熱量', '${eData['total_calories'] ?? 0} kcal', Colors.orange.shade700),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSubStatChip('累積訓練次數', '${eData['total_sessions'] ?? 0} 次', Colors.indigo),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSubStatChip('平均姿勢分', '$avgScore 分', Colors.green.shade700),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 運動項目比例
          const Text(
            '運動項目分佈 (Slow Jogging vs Squat)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  if (jogCnt > 0)
                    Expanded(
                      flex: jogCnt,
                      child: Container(color: Colors.blue.shade500),
                    ),
                  if (squatCnt > 0)
                    Expanded(
                      flex: squatCnt,
                      child: Container(color: Colors.orange.shade500),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendDot('超慢跑 (Slow Jogging)', '$jogCnt次 (${(jogCnt / totalEx * 100).toStringAsFixed(0)}%)', Colors.blue.shade500),
              _buildLegendDot('深蹲 (Squat)', '$squatCnt次 (${(squatCnt / totalEx * 100).toStringAsFixed(0)}%)', Colors.orange.shade500),
            ],
          ),
          const SizedBox(height: 16),

          // 姿勢評分等級分佈
          const Text(
            '姿勢品質分佈 (Posture Accuracy Rate)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 10),
          _buildProgressBarItem('優良 (>=80分)', goodCnt, totalPosture, Colors.green),
          const SizedBox(height: 6),
          _buildProgressBarItem('良好 (60-79分)', fairCnt, totalPosture, Colors.amber.shade700),
          const SizedBox(height: 6),
          _buildProgressBarItem('待改進 (<60分)', needsWorkCnt, totalPosture, Colors.red.shade400),
        ],
      ),
    );
  }

  // 5. 社群與檢舉分析區塊
  Widget _buildCommunityAnalyticsSection() {
    final cData = _analyticsData?['community_analytics'] ?? {};
    final postTypes = cData['post_types'] ?? {};
    final int journeyCnt = postTypes['journey'] ?? 0;
    final int planCnt = postTypes['plan'] ?? 0;
    final int recipeCnt = postTypes['recipe'] ?? 0;
    final int totalPostType = (journeyCnt + planCnt + recipeCnt).clamp(1, 999999);

    final reports = cData['report_status'] ?? {};
    final int pendingRep = reports['pending'] ?? 0;

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
          _buildSectionHeader(
            icon: Icons.mark_chat_read_outlined,
            title: '社群互動與風控檢舉 (Community & Moderation)',
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _buildSubStatChip('總按讚數', '${cData['total_likes'] ?? 0} ❤️', Colors.pink),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSubStatChip('總留言數', '${cData['total_comments'] ?? 0} 💬', Colors.purple.shade600),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSubStatChip('待處理檢舉', '$pendingRep 件', pendingRep > 0 ? Colors.red : Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 16),

          const Text(
            '貼文類型分佈 (Post Categories)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  if (journeyCnt > 0)
                    Expanded(flex: journeyCnt, child: Container(color: Colors.teal.shade400)),
                  if (planCnt > 0)
                    Expanded(flex: planCnt, child: Container(color: Colors.purple.shade400)),
                  if (recipeCnt > 0)
                    Expanded(flex: recipeCnt, child: Container(color: Colors.amber.shade600)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendDot('旅程', '$journeyCnt篇 (${(journeyCnt / totalPostType * 100).toStringAsFixed(0)}%)', Colors.teal.shade400),
              _buildLegendDot('計畫', '$planCnt篇 (${(planCnt / totalPostType * 100).toStringAsFixed(0)}%)', Colors.purple.shade400),
              _buildLegendDot('食譜', '$recipeCnt篇 (${(recipeCnt / totalPostType * 100).toStringAsFixed(0)}%)', Colors.amber.shade600),
            ],
          ),
        ],
      ),
    );
  }

  // 6. 點數與綠界營收區塊
  Widget _buildPointsRevenueSection() {
    final pData = _analyticsData?['points_analytics'] ?? {};
    final tTypes = pData['transaction_types'] ?? {};
    final int topupCnt = tTypes['top_up'] ?? 0;
    final int spendCnt = tTypes['spend'] ?? 0;
    final int rewardCnt = tTypes['reward'] ?? 0;

    final topupAmounts = Map<String, dynamic>.from(pData['topup_amounts'] ?? {});

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
          _buildSectionHeader(
            icon: Icons.payments_outlined,
            title: '點數與綠界 (ECPay) 金流營收 (Points & Financials)',
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _buildSubStatChip('變動總點數', '${pData['total_points_changed'] ?? 0} 點', Colors.green.shade700),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSubStatChip('成功交易數', '${pData['total_transactions'] ?? 0} 筆', Colors.blue.shade700),
              ),
            ],
          ),
          const SizedBox(height: 16),

          const Text(
            '交易類型比例 (Top-up / Spend / Reward)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildChipBadge('綠界儲值', '$topupCnt 筆', Colors.green.shade700, Colors.green.shade50),
              const SizedBox(width: 8),
              _buildChipBadge('點數消費', '$spendCnt 筆', Colors.orange.shade800, Colors.orange.shade50),
              const SizedBox(width: 8),
              _buildChipBadge('任務獎勵', '$rewardCnt 筆', Colors.blue.shade700, Colors.blue.shade50),
            ],
          ),
          const SizedBox(height: 16),

          const Text(
            '儲值金額方案購買次數 (Tier Distribution)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 10),

          // 方案次數 Grid
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['33', '170', '490', '990', '1690', '3290'].map((amt) {
              final cnt = topupAmounts[amt] ?? 0;
              return Container(
                width: 100,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Text(
                      '\$$amt 元',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$cnt 次',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 區塊 Header Helper
  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: Colors.black),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
          ),
        ),
      ],
    );
  }

  // Sub Stat Chip Helper
  Widget _buildSubStatChip(String label, String value, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: accentColor)),
        ],
      ),
    );
  }

  // Progress Bar Line Item
  Widget _buildProgressBarItem(String label, int count, int total, Color color) {
    final double pct = total > 0 ? (count / total) : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 65,
          child: Text(
            '$count次 (${(pct * 100).toStringAsFixed(0)}%)',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  // Legend Item Helper
  Widget _buildLegendDot(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text('$label: ', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }

  Widget _buildChipBadge(String title, String count, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        '$title: $count',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  // Simple Trend Bar Chart Builder
  Widget _buildBarTrendChart({required List<Map<String, dynamic>> items, required Color barColor}) {
    if (items.isEmpty) return const SizedBox.shrink();
    final double maxVal = items.map((e) => e['value'] as double).reduce((a, b) => a > b ? a : b).clamp(1.0, 9999.0);

    return SizedBox(
      height: 80,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: items.map((item) {
          final double val = item['value'] as double;
          final double heightPct = (val / maxVal).clamp(0.1, 1.0);
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('${val.toInt()}', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
              const SizedBox(height: 2),
              Container(
                width: 14,
                height: 45 * heightPct,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 4),
              Text(item['label'] ?? '', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ],
          );
        }).toList(),
      ),
    );
  }
}
