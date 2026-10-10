import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../services/user_session.dart';

class HealthChartScreen extends StatefulWidget {
  const HealthChartScreen({super.key});

  @override
  State<HealthChartScreen> createState() => _HealthChartScreenState();
}

class _HealthChartScreenState extends State<HealthChartScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _bpRecords = [];
  List<Map<String, dynamic>> _bodyRecords = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchHealthData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchHealthData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bpResponse = await _api.dio.get('blood-pressure-records/');
      final bodyResponse = await _api.dio.get('body-records/');

      final currentMemberId = UserSession.memberId;

      List<Map<String, dynamic>> rawBp = bpResponse.data is List
          ? List<Map<String, dynamic>>.from(bpResponse.data)
          : [];
      List<Map<String, dynamic>> rawBody = bodyResponse.data is List
          ? List<Map<String, dynamic>>.from(bodyResponse.data)
          : [];

      // 篩選當前使用者
      if (currentMemberId != null) {
        rawBp = rawBp.where((e) => e['member'] == currentMemberId).toList();
        rawBody = rawBody.where((e) => e['member'] == currentMemberId).toList();
      }

      // 依日期由舊到新排序 (繪圖需要從左到右)
      int sortAsc(Map<String, dynamic> a, Map<String, dynamic> b) {
        final dtA = DateTime.tryParse(a['record_date']?.toString() ?? '') ??
            DateTime(1970);
        final dtB = DateTime.tryParse(b['record_date']?.toString() ?? '') ??
            DateTime(1970);
        return dtA.compareTo(dtB);
      }

      rawBp.sort(sortAsc);
      rawBody.sort(sortAsc);

      // 最多顯示最近 20 筆，避免塞爆
      if (rawBp.length > 20) {
        rawBp = rawBp.sublist(rawBp.length - 20);
      }
      if (rawBody.length > 20) {
        rawBody = rawBody.sublist(rawBody.length - 20);
      }

      if (!mounted) return;

      setState(() {
        _bpRecords = rawBp;
        _bodyRecords = rawBody;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _api.getErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Text(
          '健康數據趨勢',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.black,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: '血壓趨勢'),
            Tab(text: '體重趨勢'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _errorMessage != null
              ? _buildErrorView()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBloodPressureTab(),
                    _buildBodyWeightTab(),
                  ],
                ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _fetchHealthData,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            child: const Text('重試', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==================== 血壓 Tab ====================
  Widget _buildBloodPressureTab() {
    if (_bpRecords.isEmpty) {
      return _buildEmptyState('尚無血壓紀錄資料');
    }

    final List<FlSpot> systolicSpots = [];
    final List<FlSpot> diastolicSpots = [];
    double minVal = 200;
    double maxVal = 40;

    for (int i = 0; i < _bpRecords.length; i++) {
      final sys = (_bpRecords[i]['systolic'] as num?)?.toDouble() ?? 0.0;
      final dia = (_bpRecords[i]['diastolic'] as num?)?.toDouble() ?? 0.0;
      systolicSpots.add(FlSpot(i.toDouble(), sys));
      diastolicSpots.add(FlSpot(i.toDouble(), dia));

      minVal = [minVal, sys, dia].reduce(min);
      maxVal = [maxVal, sys, dia].reduce(max);
    }

    final double chartMinY = (minVal - 15).clamp(30.0, 220.0);
    final double chartMaxY = (maxVal + 15).clamp(60.0, 240.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLegend([
            {'color': const Color(0xFFEF4444), 'label': '收縮壓 (SYS)'},
            {'color': const Color(0xFF3B82F6), 'label': '舒張壓 (DIA)'},
          ]),
          const SizedBox(height: 16),
          _buildChartCard(
            LineChart(
              LineChartData(
                minX: 0,
                maxX: max((_bpRecords.length - 1).toDouble(), 1.0),
                minY: chartMinY,
                maxY: chartMaxY,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final idx = spot.x.toInt();
                        final date = _formatDateStr(
                            _bpRecords[idx]['record_date']?.toString());
                        final isSys = spot.barIndex == 0;
                        return LineTooltipItem(
                          '${isSys ? "收縮壓" : "舒張壓"}: ${spot.y.toInt()} mmHg\n($date)',
                          TextStyle(
                            color: isSys
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF3B82F6),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.withOpacity(0.15),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                titlesData: _buildCleanTitlesData(
                  dates: _bpRecords
                      .map((e) => e['record_date']?.toString() ?? '')
                      .toList(),
                  stepY: 20,
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: systolicSpots,
                    isCurved: true,
                    curveSmoothness: 0.2, // 溫和弧度，不失真
                    color: const Color(0xFFEF4444),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 3.5,
                        color: Colors.white,
                        strokeWidth: 2.5,
                        strokeColor: const Color(0xFFEF4444),
                      ),
                    ),
                  ),
                  LineChartBarData(
                    spots: diastolicSpots,
                    isCurved: true,
                    curveSmoothness: 0.2,
                    color: const Color(0xFF3B82F6),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 3.5,
                        color: Colors.white,
                        strokeWidth: 2.5,
                        strokeColor: const Color(0xFF3B82F6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 體重 Tab ====================
  Widget _buildBodyWeightTab() {
    if (_bodyRecords.isEmpty) {
      return _buildEmptyState('尚無體重紀錄資料');
    }

    final List<FlSpot> weightSpots = [];
    double minW = 200;
    double maxW = 30;

    for (int i = 0; i < _bodyRecords.length; i++) {
      final w = (_bodyRecords[i]['weight'] as num?)?.toDouble() ?? 0.0;
      weightSpots.add(FlSpot(i.toDouble(), w));
      if (w < minW) minW = w;
      if (w > maxW) maxW = w;
    }

    final double chartMinY = (minW - 3).clamp(30.0, 180.0);
    final double chartMaxY = (maxW + 3).clamp(40.0, 200.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLegend([
            {'color': const Color(0xFF0D9488), 'label': '體重 (kg)'},
          ]),
          const SizedBox(height: 16),
          _buildChartCard(
            LineChart(
              LineChartData(
                minX: 0,
                maxX: max((_bodyRecords.length - 1).toDouble(), 1.0),
                minY: chartMinY,
                maxY: chartMaxY,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final idx = spot.x.toInt();
                        final date = _formatDateStr(
                            _bodyRecords[idx]['record_date']?.toString());
                        return LineTooltipItem(
                          '體重: ${spot.y.toStringAsFixed(1)} kg\n($date)',
                          const TextStyle(
                            color: Color(0xFF0D9488),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.withOpacity(0.15),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                titlesData: _buildCleanTitlesData(
                  dates: _bodyRecords
                      .map((e) => e['record_date']?.toString() ?? '')
                      .toList(),
                  stepY: 5,
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: weightSpots,
                    isCurved: true,
                    curveSmoothness: 0.2,
                    color: const Color(0xFF0D9488),
                    barWidth: 3.5,
                    isStrokeCapRound: true,
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF0D9488).withOpacity(0.1),
                    ),
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 4,
                        color: Colors.white,
                        strokeWidth: 3,
                        strokeColor: const Color(0xFF0D9488),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 乾淨的 X / Y 軸座標計算 ====================
  FlTitlesData _buildCleanTitlesData({
    required List<String> dates,
    required double stepY,
  }) {
    // 依據資料量動態決定間隔，最多只印出 5 個標籤，絕不重疊
    final int count = dates.length;
    double xInterval = 1.0;
    if (count > 5) {
      xInterval = (count - 1) / 4.0;
    }

    return FlTitlesData(
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 32,
          interval: xInterval,
          getTitlesWidget: (value, meta) {
            final int index = value.round();
            if (index < 0 || index >= dates.length)
              return const SizedBox.shrink();

            // 只在接近算出的整數點繪製，防止小數浮水印標籤
            if ((value - index).abs() > 0.1) return const SizedBox.shrink();

            final dateStr = _formatDateStr(dates[index]);
            return Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                dateStr,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          interval: stepY,
          getTitlesWidget: (value, meta) {
            return Text(
              value.toInt().toString(),
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatDateStr(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      if (raw.length >= 5) return raw.substring(raw.length - 5);
      return raw;
    }
  }

  Widget _buildChartCard(Widget chart) {
    return Container(
      height: 340,
      padding: const EdgeInsets.fromLTRB(10, 24, 20, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: chart,
    );
  }

  Widget _buildLegend(List<Map<String, dynamic>> items) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: item['color'] as Color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  item['label'] as String,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.show_chart, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(text,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
        ],
      ),
    );
  }
}
