import 'package:flutter/material.dart';

class AdminContentScreen extends StatelessWidget {
  const AdminContentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 頂部黑底 Header
              _buildHeader(context),

              // 2. 導覽頁籤 TabBar (選中：內容管理)
              _buildTabBar(),

              const SizedBox(height: 16),

              // 3. 上方三欄統計卡片 (待處理 / 已審核 / 已下架)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildBadgeStatCard(
                        title: '待處理\n檢舉',
                        value: '0',
                        valueColor: const Color(0xFFD97706), // 琥珀黃
                        badgeIcon: Icons.outlined_flag,
                        badgeIconColor: const Color(0xFFD97706),
                        badgeBgColor: const Color(0xFFFEF3C7),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildBadgeStatCard(
                        title: '已審核\n',
                        value: '0',
                        valueColor: const Color(0xFF2563EB), // 藍色
                        badgeIcon: Icons.visibility_outlined,
                        badgeIconColor: const Color(0xFF2563EB),
                        badgeBgColor: const Color(0xFFDBEAFE),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildBadgeStatCard(
                        title: '已下架\n',
                        value: '0',
                        valueColor: const Color(0xFFDC2626), // 紅色
                        badgeIcon: Icons.delete_outline,
                        badgeIconColor: const Color(0xFFDC2626),
                        badgeBgColor: const Color(0xFFFEE2E2),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 4. 被檢舉貼文管理卡片
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildReportedPostsCard(),
              ),

              const SizedBox(height: 24),
            ],
          ),
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

  // 頁籤導覽 (選中：內容管理)
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          _buildTabItem(Icons.chat_bubble_outline, '內容管理', isSelected: true),
          const SizedBox(width: 24),
          _buildTabItem(Icons.show_chart, '數據分析', isSelected: false),
          const SizedBox(width: 24),
          _buildTabItem(Icons.settings_outlined, '系統設定', isSelected: false),
        ],
      ),
    );
  }

  Widget _buildTabItem(IconData icon, String title,
      {required bool isSelected}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon,
                size: 18, color: isSelected ? Colors.black : Colors.grey),
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
        if (isSelected) ...[
          const SizedBox(height: 6),
          Container(height: 2, width: 65, color: Colors.black),
        ],
      ],
    );
  }

  // 帶有邊緣圓形徽章的統計卡片
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
        // 浮動在卡片右上側邊緣的小圓形徽章
        Positioned(
          top: 18,
          right: -8,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: badgeBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              badgeIcon,
              size: 16,
              color: badgeIconColor,
            ),
          ),
        ),
      ],
    );
  }

  // 被檢舉貼文區塊
  Widget _buildReportedPostsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black, width: 1.5),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.outlined_flag, size: 22, color: Colors.black),
              SizedBox(width: 8),
              Text(
                '被檢舉貼文',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            '審核與管理社群發布內容',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}
