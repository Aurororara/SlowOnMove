import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildDarkProfileCard(),
              const SizedBox(height: 24),
              _buildStatsGrid(),
              const SizedBox(height: 32),
              _buildSectionTitle('PERSONAL INFORMATION'),
              const SizedBox(height: 16),
              _buildInfoTile(icon: Icons.person_outline, label: 'Full Name', value: 'Lamei'),
              const SizedBox(height: 12),
              _buildInfoTile(icon: Icons.mail_outline, label: 'Email Address', value: 'lamei@example.com'),
              const SizedBox(height: 12),
              _buildInfoTile(icon: Icons.monitor_weight_outlined, label: 'Weight (kg)', value: '65 kg'),
              const SizedBox(height: 12),
              _buildInfoTile(icon: Icons.straighten, label: 'Height (cm)', value: '170 cm'),
              const SizedBox(height: 32),
              _buildSectionTitle('MY DATA & PROGRESS'),
              const SizedBox(height: 16),
              _buildPointsAndRewardsTile(),
              const SizedBox(height: 12),
              _buildActionTile(icon: Icons.history, title: 'Exercise History', subtitle: 'View all workout records'),
              const SizedBox(height: 12),
              _buildActionTile(icon: Icons.bookmark_border, title: 'Favorites', subtitle: 'Saved posts and workouts'),
              const SizedBox(height: 32),
              _buildLogOutButton(context),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Color(0xFFE2E8F0),
            child: Icon(Icons.fitness_center, size: 14, color: Colors.blueGrey),
          ),
          SizedBox(width: 8),
          Text(
            'PROFILE',
            style: TextStyle(
              color: Color(0xFF1A202C),
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined, color: Color(0xFF4A5568)),
          onPressed: () {},
        ),
      ],
    );
  }

  // --- 以下 UI 組件維持原狀 ---

  Widget _buildDarkProfileCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1522),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: 90, height: 90,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
            child: const Center(child: Text('L', style: TextStyle(fontSize: 40, color: Colors.black))),
          ),
          const SizedBox(height: 16),
          const Text('Lamei', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const Text('lamei@example.com', style: TextStyle(fontSize: 14, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        Expanded(child: _buildStatCard(Icons.emoji_events_outlined, '12', 'Achievements')),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard(Icons.track_changes, '47', 'Workouts')),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: const Color(0xFF4A5568)),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF718096))),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4A5568)),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF718096))),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPointsAndRewardsTile() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF6AD55).withOpacity(0.5)),
      ),
      child: const Row(
        children: [
          Icon(Icons.workspace_premium_outlined, color: Color(0xFFF6AD55)),
          SizedBox(width: 16),
          Text('Points & Rewards: 1,250 points'),
          Spacer(),
          Icon(Icons.chevron_right, color: Color(0xFFA0AEC0)),
        ],
      ),
    );
  }

  Widget _buildActionTile({required IconData icon, required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4A5568)),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const Spacer(),
          const Icon(Icons.chevron_right, color: Color(0xFFA0AEC0)),
        ],
      ),
    );
  }

  Widget _buildLogOutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.logout, color: Color(0xFFE53935)),
        label: const Text('Log Out'),
        style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFE53935))),
      ),
    );
  }
}