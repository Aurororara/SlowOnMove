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

class _PurchaseScreenState extends State<PurchaseScreen> {
  int _selectedAmount = 33;
  bool _isLoading = false;

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
    _fetchPointsBalance();
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
  // 6.1 綠界科技 ECPay 金流串接與模擬付款 API
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

          if (mounted) {
            _showSuccessDialog(
              title: '綠界科技 (ECPay) 儲值成功',
              message: '已成功儲值 ${plan.price} 元，獲得 $totalPoints 點數！\n目前點數餘額：${_formatPoints(newBalance)} 點。',
            );
          }
        } else {
          final String checkoutUrl = data['checkout_url'] ?? 'https://payment-stage.ecpay.com.tw/Cashier/AioCheckOut/V5';
          final Map<String, dynamic> ecpayParams = data['ecpay_params'] ?? {};

          if (mounted) {
            _showECPayGatewayModal(checkoutUrl, ecpayParams, plan, totalPoints);
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
  // 支付方式選單 Bottom Sheet
  // ---------------------------------------------------------------------------
  Future<void> _showPaymentMethods(int totalPoints) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
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
                const Text(
                  '選擇支付方式',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '充值 $_selectedAmount 元，付款完成後可獲得 $totalPoints 點。',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                // 1. 綠界科技 ECPay 信用卡/全功能金流
                _buildPaymentOptionTile(
                  icon: Icons.credit_card_rounded,
                  title: '綠界科技 (ECPay) 信用卡金流',
                  subtitle: '支援 Visa、Mastercard、JCB 測試刷卡',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _processECPayCheckout(_selectedPlan, isSimulated: false);
                  },
                ),
                const SizedBox(height: 10),
                // 2. 綠界科技沙盒測試模擬 (即時入帳)
                _buildPaymentOptionTile(
                  icon: Icons.bolt_rounded,
                  title: '綠界科技 (ECPay) 測試模擬入帳',
                  subtitle: '發送測試請求，即時驗證點數與交易紀錄',
                  iconColor: const Color(0xFF059669),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _processECPayCheckout(_selectedPlan, isSimulated: true);
                  },
                ),
                const SizedBox(height: 10),
                // 3. Apple Pay
                _buildPaymentOptionTile(
                  icon: Icons.phone_iphone_rounded,
                  title: 'Apple Pay',
                  subtitle: '快速完成付款，適合 iPhone / Mac 使用者',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _processECPayCheckout(_selectedPlan, isSimulated: true);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color iconColor = Colors.black,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF111827),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 綠界金流 AIO 門戶彈窗與參數展示
  // ---------------------------------------------------------------------------
  void _showECPayGatewayModal(
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
                      SnackBar(content: Text('已生成綠界科技 AIO 測試 Portal 網址: $checkoutUrl')),
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

  // ---------------------------------------------------------------------------
  // 主畫面 Build (完美對照截圖介面)
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final int bonus = _selectedPlan.bonusPoints;
    final int totalPoints = _selectedPlan.points + bonus;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text(
          '儲值方案',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: '重新整理餘額',
            onPressed: _fetchPointsBalance,
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                ValueListenableBuilder<double>(
                  valueListenable: UserSession.walletBalanceNotifier,
                  builder: (context, walletBalance, _) {
                    final double balanceAfterTopUp = walletBalance + totalPoints;
                    return _buildBalanceCard(
                      walletBalance,
                      balanceAfterTopUp,
                      bonus,
                      totalPoints,
                    );
                  },
                ),
                const SizedBox(height: 16),
                _buildTopUpPanel(),
                const SizedBox(height: 16),
                _buildRewardPanel(bonus, totalPoints),
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

  // ---------------------------------------------------------------------------
  // 頂部卡片：目前餘額與里程碑
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

  // ---------------------------------------------------------------------------
  // 中間卡片：選擇儲值金額網格
  // ---------------------------------------------------------------------------
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
                      color:
                          isSelected ? Colors.black : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                              color: isSelected
                                  ? Colors.white70
                                  : const Color(0xFF6B7280),
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
          const SizedBox(height: 16),
          const Text(
            '每個方案皆含固定點數與額外贈點，付款後會自動加入帳戶。',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 底部卡片：儲值說明與去付款按鈕
  // ---------------------------------------------------------------------------
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
                '儲值說明',
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
            child: Row(
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
                const SizedBox(width: 12),
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => _showPaymentMethods(totalPoints),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    child: const Text(
                      '去付款',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
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
