import 'package:flutter/material.dart';

import 'services/points_service.dart';
import 'services/user_session.dart';

class SpTransactionScreen extends StatefulWidget {
  const SpTransactionScreen({super.key});

  @override
  State<SpTransactionScreen> createState() => _SpTransactionScreenState();
}

class _SpTransactionScreenState extends State<SpTransactionScreen> {
  final PointsService _pointsService = PointsService();

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final transactions = await _pointsService.getTransactions();

      final balance = await _pointsService.getBalance();

      if (!mounted) return;

      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });

      UserSession.walletBalanceNotifier.value = balance.toDouble();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = _pointsService.getErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text(
          'SP 紀錄',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: RefreshIndicator(
        onRefresh: _loadTransactions,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 100),
          const Icon(
            Icons.error_outline_rounded,
            size: 52,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        _buildBalanceCard(),
        const SizedBox(height: 24),
        const Text(
          '交易紀錄',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        if (_transactions.isEmpty)
          _buildEmptyState()
        else
          ..._transactions.map(
            _buildTransactionCard,
          ),
      ],
    );
  }

  Widget _buildBalanceCard() {
    return ValueListenableBuilder<double>(
      valueListenable: UserSession.walletBalanceNotifier,
      builder: (context, balance, _) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '目前 SP',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${balance.toInt()} SP',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransactionCard(
    Map<String, dynamic> transaction,
  ) {
    final int points = (transaction['points_changed'] as num?)?.toInt() ?? 0;

    final String type = transaction['tran_type']?.toString() ?? '';

    final String description =
        transaction['description']?.toString().trim() ?? '';

    final String createdAt = transaction['created_at']?.toString() ?? '';

    final bool isPositive = points > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _getTransactionIcon(type),
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description.isNotEmpty
                      ? description
                      : _getTransactionName(
                          type,
                        ),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _formatDateTime(
                    createdAt,
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${isPositive ? '+' : ''}$points SP',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: isPositive ? Colors.green : Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTransactionIcon(
    String type,
  ) {
    switch (type) {
      case 'reward':
        return Icons.card_giftcard_rounded;

      case 'spend':
        return Icons.lock_open_rounded;

      case 'top_up':
        return Icons.account_balance_wallet_rounded;

      default:
        return Icons.stars_rounded;
    }
  }

  String _getTransactionName(
    String type,
  ) {
    switch (type) {
      case 'reward':
        return 'SP 獎勵';

      case 'spend':
        return 'SP 使用';

      case 'top_up':
        return 'SP 儲值';

      default:
        return 'SP 異動';
    }
  }

  String _formatDateTime(
    String value,
  ) {
    if (value.isEmpty) {
      return '';
    }

    try {
      final date = DateTime.parse(value).toLocal();

      return '${date.year}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.day.toString().padLeft(2, '0')} '
          '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return value;
    }
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 60,
      ),
      child: const Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 52,
            color: Colors.grey,
          ),
          SizedBox(height: 14),
          Text(
            '目前沒有 SP 紀錄',
            style: TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
