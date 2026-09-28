import 'package:flutter/material.dart';
import '../services/points_service.dart';

class AdminPointsScreen extends StatefulWidget {
  const AdminPointsScreen({super.key});

  @override
  State<AdminPointsScreen> createState() => _AdminPointsScreenState();
}

class _AdminPointsScreenState extends State<AdminPointsScreen> {
  final PointsService _pointsService = PointsService();
  String _selectedType = 'all'; // 'all', 'top_up', 'spend'
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list =
          await _pointsService.getAdminTransactions(type: _selectedType);
      setState(() {
        _transactions = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = _pointsService.getErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          '點數交易紀錄查詢',
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 17, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          // 頂部篩選標籤
          _buildFilterBar(),

          // 列表
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchTransactions,
              color: Colors.black,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _buildFilterChip('all', '全部'),
          const SizedBox(width: 8),
          _buildFilterChip('top_up', '儲值 (+P)'),
          const SizedBox(width: 8),
          _buildFilterChip('spend', '功能解鎖/消費 (-P)'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final bool isSelected = _selectedType == value;
    return GestureDetector(
      onTap: () {
        if (_selectedType != value) {
          setState(() {
            _selectedType = value;
          });
          _fetchTransactions();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.black));
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _fetchTransactions,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              child: const Text('重試', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (_transactions.isEmpty) {
      return const Center(
        child: Text('目前無符合條件的點數交易明細', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _transactions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final tx = _transactions[index];
        final String tranType = tx['tran_type'] ?? 'spend';
        final int pointsChanged = (tx['points_changed'] as num?)?.toInt() ?? 0;
        final bool isPositive = pointsChanged > 0;

        Color badgeColor = Colors.orange.shade800;
        IconData icon = Icons.shopping_bag_outlined;
        String typeLabel = '點數扣除';

        if (tranType == 'top_up') {
          badgeColor = Colors.green;
          icon = Icons.add_card;
          typeLabel = '儲值充值';
        } else if (tranType == 'reward') {
          badgeColor = Colors.blue;
          icon = Icons.card_giftcard;
          typeLabel = '任務獎勵';
        }

        // 取出會員名稱（相容巢狀物件與扁平欄位）
        String userName = '會員';
        if (tx['member'] is Map) {
          userName =
              tx['member']['username'] ?? tx['member']['nickname'] ?? '會員';
        } else if (tx['username'] != null) {
          userName = tx['username'];
        }

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: badgeColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            typeLabel,
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tx['description'] ?? '無說明',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(tx['created_at']),
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
              Text(
                '${isPositive ? '+' : ''}$pointsChanged P',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isPositive ? Colors.green : Colors.redAccent,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null || dateStr.toString().isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr.toString()).toLocal();
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr.toString();
    }
  }
}
