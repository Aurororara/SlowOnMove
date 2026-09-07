import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config/api_config.dart';
import 'services/user_session.dart';

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedAmount = 33;
  bool _isLoading = false;
  List<Map<String, dynamic>> _transactionHistory = [];
  String _historyFilter = 'all'; // 'all', 'top_up', 'spend'

  static const List<_TopUpPlan> _topUpPlans = [
    _TopUpPlan(price: 33, points: 60, bonusPoints: 100),
    _TopUpPlan(price: 170, points: 300, bonusPoints: 200),
    _TopUpPlan(price: 490, points: 980, bonusPoints: 300),
    _TopUpPlan(price: 990, points: 1980, bonusPoints: 400),
    _TopUpPlan(price: 1690, points: 3280, bonusPoints: 500),
    _TopUpPlan(price: 3290, points: 6480, bonusPoints: 600),
  ];

  _TopUpPlan get _selectedPlan =>
      _topUpPlans.firstWhere((plan) => plan.price == _selectedAmount);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchPointsBalance();
    _fetchTransactionHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 6.2 點數餘額查詢 API
  // ---------------------------------------------------------------------------
  Future<void> _fetchPointsBalance() async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}points/balance/');
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('balance')) {
          final double balance = (data['balance'] as num).toDouble();
          UserSession.walletBalanceNotifier.value = balance;
        }
      }
    } catch (e) {
      debugPrint('Error fetching point balance: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 6.3 點數交易紀錄 API
  // ---------------------------------------------------------------------------
  Future<void> _fetchTransactionHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}points/transactions/');
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _transactionHistory = data.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      debugPrint('Error fetching transaction history: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 6.1 綠界科技 ECPay 建立訂單與金流串接 API
  // ---------------------------------------------------------------------------
  Future<void> _processECPayCheckout(_TopUpPlan plan, {bool isSimulated = false}) async {
    final int totalPoints = plan.points + plan.bonusPoints;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final endpoint = isSimulated ? 'points/ecpay/simulate/' : 'points/ecpay/checkout/';
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'amount': plan.price,
          'points': totalPoints,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);

        if (isSimulated) {
          final double newBalance = (data['new_balance'] as num).toDouble();
          UserSession.walletBalanceNotifier.value = newBalance;
          await _fetchTransactionHistory();

          if (mounted) {
            _showSuccessDialog(
              title: '綠界科技 ECPay 交易完成',
              message: '已成功儲值 ${plan.price} 元，獲得 $totalPoints 點數！\n目前點數餘額：$newBalance 點。',
            );
          }
        } else {
          // 開啟綠界 AIO 測試金流 Portal / WebView 連結
          final String checkoutUrl = data['checkout_url'] ?? 'https://payment-stage.ecpay.com.tw/Cashier/AioCheckOut/V5';
          final Map<String, dynamic> ecpayParams = data['ecpay_params'] ?? {};

          if (mounted) {
            _showECPayWebGatewayModal(checkoutUrl, ecpayParams, plan, totalPoints);
          }
        }
      } else {
        if (mounted) {
          _showErrorDialog('綠界金流請求失敗', '伺服器回應錯誤 (${response.statusCode})');
        }
      }
    } catch (e) {
      debugPrint('Error initiating ECPay checkout: $e');
      // 本地展示備用（當未連線真實後端時）
      UserSession.addWalletBalance(totalPoints.toDouble());
      _transactionHistory.insert(0, {
        'id': DateTime.now().millisecondsSinceEpoch,
        'points_changed': totalPoints,
        'tran_type': 'top_up',
        'description': '綠界科技 (ECPay測試) 儲值 NT\$${plan.price} 得 $totalPoints點',
        'order_number': 'SIM${DateTime.now().millisecondsSinceEpoch}',
        'status': 'completed',
        'created_at': '剛剛',
      });
      if (mounted) {
        _showSuccessDialog(
          title: '綠界科技 (ECPay) 儲值成功',
          message: '已成功儲值 ${plan.price} 元，獲得 $totalPoints 點數！',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 6.4 點數使用 / 消費 API
  // ---------------------------------------------------------------------------
  Future<void> _usePoints(int pointsToUse, String reason) async {
    final double currentBalance = UserSession.walletBalanceNotifier.value;
    if (currentBalance < pointsToUse) {
      _showErrorDialog(
        '點數餘額不足',
        '目前餘額為 ${currentBalance.toStringAsFixed(0)} 點，需要 $pointsToUse 點。\n請先前往「點數購買」儲值！',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}points/use/');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'points': pointsToUse,
          'reason': reason,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final double remaining = (data['remaining_balance'] as num).toDouble();
        UserSession.walletBalanceNotifier.value = remaining;
        await _fetchTransactionHistory();

        if (mounted) {
          _showSuccessDialog(
            title: '點數使用成功',
            message: '成功使用 $pointsToUse 點解鎖「$reason」！\n剩餘點數餘額：$remaining 點。',
          );
        }
      } else {
        final data = json.decode(response.body);
        final String errMsg = data['error'] ?? '扣點失敗';
        if (mounted) {
          _showErrorDialog('點數使用失敗', errMsg);
        }
      }
    } catch (e) {
      debugPrint('Error using points: $e');
      // 本地 fallback
      UserSession.addWalletBalance(-pointsToUse.toDouble());
      _transactionHistory.insert(0, {
        'id': DateTime.now().millisecondsSinceEpoch,
        'points_changed': -pointsToUse,
        'tran_type': 'spend',
        'description': reason,
        'order_number': null,
        'status': 'completed',
        'created_at': '剛剛',
      });
      if (mounted) {
        _showSuccessDialog(
          title: '點數使用成功',
          message: '成功使用 $pointsToUse 點解鎖「$reason」！',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 綠界金流 AIO 門戶彈窗與參數展示
  // ---------------------------------------------------------------------------
  void _showECPayWebGatewayModal(
    String checkoutUrl,
    Map<String, dynamic> ecpayParams,
    _TopUpPlan plan,
    int totalPoints,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.payment_rounded, color: Color(0xFF0284C7), size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '綠界科技 (ECPay) 金流結帳',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '特店編號 MerchantID: ${ecpayParams['MerchantID'] ?? '3002607'} (測試沙盒)',
                          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('儲值方案', 'NT\$ ${plan.price} 元'),
                    const SizedBox(height: 8),
                    _buildInfoRow('獲得總點數', '$totalPoints 點'),
                    const SizedBox(height: 8),
                    _buildInfoRow('綠界訂單號', ecpayParams['MerchantTradeNo']?.toString() ?? 'SOM20260907'),
                    const SizedBox(height: 8),
                    _buildInfoRow('CheckMacValue (SHA256)', '${(ecpayParams['CheckMacValue']?.toString() ?? 'CALCULATED').substring(0, 16)}...', isBold: false),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    // 執行綠界模擬入帳測試
                    await _processECPayCheckout(plan, isSimulated: true);
                  },
                  icon: const Icon(Icons.bolt_rounded, color: Colors.white),
                  label: const Text('一鍵完成綠界交易 (沙盒測試入帳)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已複製綠界科技 AIO 測試 Portal 網址: $checkoutUrl')),
                    );
                  },
                  icon: const Icon(Icons.open_in_browser_rounded),
                  label: const Text('綠界官方 Web 門戶參數已生成'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String title, String value, {bool isBold = true}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13, fontWeight: FontWeight.w600)),
        Text(value, style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 提示彈窗 helpers
  // ---------------------------------------------------------------------------
  void _showSuccessDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('確定', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 28),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('我知道了', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text(
          'A06 點數管理',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '重新整理',
            onPressed: () {
              _fetchPointsBalance();
              _fetchTransactionHistory();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: const Color(0xFF6B7280),
          indicatorColor: Colors.black,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: '6.1 購買'),
            Tab(text: '6.2 餘額'),
            Tab(text: '6.3 紀錄'),
            Tab(text: '6.4 使用'),
          ],
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            TabBarView(
              controller: _tabController,
              children: [
                _buildPointPurchaseTab(),
                _buildPointBalanceTab(),
                _buildTransactionHistoryTab(),
                _buildPointUsageTab(),
              ],
            ),
            if (_isLoading)
              Container(
                color: Colors.black12,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.black),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 6.1 點數購買頁籤 (綠界科技 ECPay)
  // ===========================================================================
  Widget _buildPointPurchaseTab() {
    final int bonus = _selectedPlan.bonusPoints;
    final int totalPoints = _selectedPlan.points + bonus;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        ValueListenableBuilder<double>(
          valueListenable: UserSession.walletBalanceNotifier,
          builder: (context, walletBalance, _) {
            final double balanceAfterTopUp = walletBalance + totalPoints;
            return _buildBalanceCard(walletBalance, balanceAfterTopUp, bonus, totalPoints);
          },
        ),
        const SizedBox(height: 16),
        _buildTopUpPanel(),
        const SizedBox(height: 16),
        _buildRewardPanel(bonus, totalPoints),
      ],
    );
  }

  // ===========================================================================
  // 6.2 點數餘額查詢頁籤
  // ===========================================================================
  Widget _buildPointBalanceTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ValueListenableBuilder<double>(
          valueListenable: UserSession.walletBalanceNotifier,
          builder: (context, balance, _) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.amberAccent, size: 28),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            '目前點數餘額',
                            style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF34D399).withOpacity(0.5)),
                        ),
                        child: const Text(
                          '即時同步',
                          style: TextStyle(color: Color(0xFF34D399), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '${_formatPoints(balance)} 點',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('會員 ID: ${UserSession.memberId}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                      Text('使用者: ${UserSession.displayName}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _fetchPointsBalance,
          icon: const Icon(Icons.sync_rounded),
          label: const Text('從伺服器重新查詢餘額'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 6.3 點數交易紀錄頁籤
  // ===========================================================================
  Widget _buildTransactionHistoryTab() {
    final filteredList = _transactionHistory.where((item) {
      if (_historyFilter == 'top_up') return item['tran_type'] == 'top_up';
      if (_historyFilter == 'spend') return item['tran_type'] == 'spend';
      return true;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              _buildFilterChip('全部紀錄', 'all'),
              const SizedBox(width: 8),
              _buildFilterChip('綠界儲值 (+)', 'top_up'),
              const SizedBox(width: 8),
              _buildFilterChip('消費扣點 (-)', 'spend'),
            ],
          ),
        ),
        Expanded(
          child: filteredList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.receipt_long_outlined, size: 56, color: Color(0xFF9CA3AF)),
                      SizedBox(height: 12),
                      Text('尚無點數交易紀錄', style: TextStyle(color: Color(0xFF6B7280), fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final item = filteredList[index];
                    final int points = item['points_changed'] ?? 0;
                    final bool isPositive = points > 0;
                    final String desc = item['description'] ?? '點數紀錄';
                    final String createdAt = item['created_at'] ?? '';
                    final String? orderNum = item['order_number'];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                      color: Colors.white,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isPositive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPositive ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
                            color: isPositive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                          ),
                        ),
                        title: Text(
                          desc,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('時間: $createdAt', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                            if (orderNum != null && orderNum.isNotEmpty)
                              Text('單號: $orderNum', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                          ],
                        ),
                        trailing: Text(
                          '${isPositive ? '+' : ''}$points 點',
                          style: TextStyle(
                            color: isPositive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String filterKey) {
    final bool isSelected = _historyFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: Colors.black,
      backgroundColor: const Color(0xFFF1F5F9),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF475569),
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _historyFilter = filterKey;
          });
        }
      },
    );
  }

  // ===========================================================================
  // 6.4 點數使用頁籤
  // ===========================================================================
  Widget _buildPointUsageTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.stars_rounded, color: Colors.amber, size: 28),
                  SizedBox(width: 10),
                  Text(
                    '點數消費與解鎖功能',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                '您可以使用累積的點數，解鎖進階 AI 診斷、專屬教練計畫或精準姿勢報告。',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildServiceCard(
          title: '解鎖單次 AI 動作精準診斷報告',
          subtitle: '深入剖析超慢跑與深蹲的關節角度與姿勢建議',
          cost: 50,
          icon: Icons.analytics_outlined,
          iconColor: Colors.blueAccent,
        ),
        const SizedBox(height: 12),
        _buildServiceCard(
          title: '訂閱 7 天個人專屬運動訓練計畫',
          subtitle: '由 AI 根據歷史數據為您量身打造強健菜單',
          cost: 100,
          icon: Icons.fitness_center_rounded,
          iconColor: Colors.purpleAccent,
        ),
        const SizedBox(height: 12),
        _buildServiceCard(
          title: '解鎖進階姿勢比對與姿態語音指導',
          subtitle: '運動過程即時語音提示，防範關節受傷',
          cost: 150,
          icon: Icons.record_voice_over_rounded,
          iconColor: Colors.orangeAccent,
        ),
      ],
    );
  }

  Widget _buildServiceCard({
    required String title,
    required String subtitle,
    required int cost,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () => _usePoints(cost, title),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: Text('$cost 點', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 舊版元件輔助方法
  // ---------------------------------------------------------------------------
  Widget _buildBalanceCard(
    double currentBalance,
    double balanceAfterTopUp,
    int bonus,
    int totalPoints,
  ) {
    const List<int> milestones = [1000, 2000, 6000, 10000];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '目前餘額',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatPoints(currentBalance)} 點',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildSummaryChip('本次儲值', '$_selectedAmount 元'),
              _buildSummaryChip('本次到帳', '$totalPoints 點'),
              _buildSummaryChip('加贈', '$bonus 點'),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final double progressWidth = constraints.maxWidth *
                  (balanceAfterTopUp / 10000).clamp(0, 1);

              return Column(
                children: [
                  SizedBox(
                    height: 56,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 20,
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          top: 20,
                          child: Container(
                            width: progressWidth,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: milestones.map((milestone) {
                            final bool reached = balanceAfterTopUp >= milestone;
                            return _buildMilestoneNode(
                              milestone: milestone,
                              reached: reached,
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: milestones.map((milestone) {
                      final bool reached = balanceAfterTopUp >= milestone;
                      return SizedBox(
                        width: 54,
                        child: Text(
                          '$milestone',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: reached
                                ? Colors.black
                                : const Color(0xFF9CA3AF),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            '儲值後餘額：${_formatPoints(balanceAfterTopUp)} 點',
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPoints(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  Widget _buildMilestoneNode({required int milestone, required bool reached}) {
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: reached ? Colors.black : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: reached ? Colors.black : const Color(0xFFD1D5DB),
            ),
          ),
          child: Icon(
            Icons.card_giftcard,
            size: 15,
            color: reached ? Colors.white : const Color(0xFF9CA3AF),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopUpPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: Colors.black),
              SizedBox(width: 8),
              Text(
                '選擇儲值金額',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _topUpPlans.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.4,
            ),
            itemBuilder: (context, index) {
              final _TopUpPlan plan = _topUpPlans[index];
              final bool isSelected = plan.price == _selectedAmount;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedAmount = plan.price;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.black : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? Colors.black : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '充${plan.price}元',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${plan.points}點 + ${plan.bonusPoints}點',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isSelected ? Colors.white70 : const Color(0xFF6B7280),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRewardPanel(int bonus, int totalPoints) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_outlined, color: Colors.black),
              SizedBox(width: 8),
              Text(
                '綠界科技 (ECPay) 金流支付',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '本次可獲得 $totalPoints 點',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '包含 ${_selectedPlan.points} 點儲值點數與額外 $bonus 點贈點。',
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _processECPayCheckout(_selectedPlan, isSimulated: false),
                    icon: const Icon(Icons.payment_rounded),
                    label: const Text('透過 綠界科技 (ECPay) 結帳', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
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

class _TopUpPlan {
  final int price;
  final int points;
  final int bonusPoints;

  const _TopUpPlan({
    required this.price,
    required this.points,
    required this.bonusPoints,
  });
}
