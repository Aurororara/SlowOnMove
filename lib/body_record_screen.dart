import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/user_session.dart';
import 'health_record_card.dart';

class BodyRecordScreen extends StatefulWidget {
  const BodyRecordScreen({super.key});

  @override
  State<BodyRecordScreen> createState() => _BodyRecordScreenState();
}

class _BodyRecordScreenState extends State<BodyRecordScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();

  final heightController = TextEditingController();
  final weightController = TextEditingController();
  final systolicController = TextEditingController();
  final diastolicController = TextEditingController();
  final pulseController = TextEditingController();

  bool loading = true;
  List<Map<String, dynamic>> bodyRecords = [];
  List<Map<String, dynamic>> bloodRecords = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchRecords();
  }

  @override
  void dispose() {
    _tabController.dispose();
    heightController.dispose();
    weightController.dispose();
    systolicController.dispose();
    diastolicController.dispose();
    pulseController.dispose();
    super.dispose();
  }

  // 取得台灣本地時區的 YYYY-MM-DD
  String formatDate(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  // 解析伺服器回傳時間並轉為本地時間字串
  String parseToLocalDateString(dynamic rawDate) {
    if (rawDate == null) return '';
    final parsed = DateTime.tryParse(rawDate.toString());
    if (parsed == null) return rawDate.toString();
    return formatDate(parsed);
  }

  Future<void> fetchRecords() async {
    try {
      final responses = await Future.wait([
        http
            .get(Uri.parse('${ApiConfig.baseUrl}body-records/'))
            .timeout(const Duration(seconds: 5)),
        http
            .get(Uri.parse('${ApiConfig.baseUrl}blood-pressure-records/'))
            .timeout(const Duration(seconds: 5)),
      ]);

      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        final memberId = UserSession.memberId;
        final List rawBody = json.decode(responses[0].body);
        final List rawBlood = json.decode(responses[1].body);

        final filteredBody = rawBody
            .where((e) => e['member'] == memberId)
            .map<Map<String, dynamic>>((e) {
          final map = Map<String, dynamic>.from(e);
          map['local_date'] =
              parseToLocalDateString(map['record_date'] ?? map['created_at']);
          map['record_type'] = 'body';
          return map;
        }).toList();

        final filteredBlood = rawBlood
            .where((e) => e['member'] == memberId)
            .map<Map<String, dynamic>>((e) {
          final map = Map<String, dynamic>.from(e);
          map['local_date'] =
              parseToLocalDateString(map['record_date'] ?? map['created_at']);
          map['record_type'] = 'blood';
          return map;
        }).toList();

        // 依時間由新到舊降序排列
        int sortDesc(Map<String, dynamic> a, Map<String, dynamic> b) {
          final dtA = DateTime.tryParse(a['record_date']?.toString() ?? '') ??
              DateTime(1970);
          final dtB = DateTime.tryParse(b['record_date']?.toString() ?? '') ??
              DateTime(1970);
          return dtB.compareTo(dtA);
        }

        filteredBody.sort(sortDesc);
        filteredBlood.sort(sortDesc);

        setState(() {
          bodyRecords = filteredBody;
          bloodRecords = filteredBlood;
          loading = false;

          // 自動帶入前次身高
          if (heightController.text.isEmpty && filteredBody.isNotEmpty) {
            heightController.text =
                filteredBody.first['height']?.toString() ?? '';
          }
        });
      } else {
        setState(() => loading = false);
        showMessage("取得健康紀錄失敗");
      }
    } catch (e) {
      setState(() => loading = false);
      showMessage("網路連線錯誤");
    }
  }

  Future<void> addBodyRecord() async {
    final height = double.tryParse(heightController.text);
    final weight = double.tryParse(weightController.text);

    if (height == null || weight == null) {
      showMessage("請填寫完整身高與體重數值");
      return;
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}body-records/'),
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "member": UserSession.memberId,
        "height": height,
        "weight": weight,
        "record_date": formatDate(_selectedDate),
      }),
    );

    if (response.statusCode == 201) {
      Navigator.pop(context);
      weightController.clear();
      showMessage("體態紀錄已儲存");
      fetchRecords();
    } else {
      showMessage("新增失敗");
    }
  }

  Future<void> addBloodPressure() async {
    final sys = int.tryParse(systolicController.text);
    final dia = int.tryParse(diastolicController.text);
    final pulse = int.tryParse(pulseController.text);

    if (sys == null || dia == null || pulse == null) {
      showMessage("請填寫完整收縮壓、舒張壓及心率");
      return;
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}blood-pressure-records/'),
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "member": UserSession.memberId,
        "systolic": sys,
        "diastolic": dia,
        "pulse": pulse,
        "record_date": formatDate(_selectedDate),
      }),
    );

    if (response.statusCode == 201) {
      Navigator.pop(context);
      systolicController.clear();
      diastolicController.clear();
      pulseController.clear();
      showMessage("血壓紀錄已儲存");
      fetchRecords();
    } else {
      showMessage("血壓新增失敗");
    }
  }

  void showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // 底部彈出新增視窗
  void _openAddModal() {
    final isBodyTab = _tabController.index == 0;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isBodyTab
                      ? "記錄體態 (${formatDate(_selectedDate)})"
                      : "記錄血壓 (${formatDate(_selectedDate)})",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                )
              ],
            ),
            const SizedBox(height: 12),
            if (isBodyTab) ...[
              TextField(
                controller: heightController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: "身高 (cm)", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: weightController,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: "體重 (kg)", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: addBodyRecord,
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text("儲存體態紀錄", style: TextStyle(fontSize: 16)),
                ),
              )
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: systolicController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: "收縮壓 SYS", border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: diastolicController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: "舒張壓 DIA", border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: pulseController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: "心率", border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: addBloodPressure,
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text("儲存血壓紀錄", style: TextStyle(fontSize: 16)),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }

  // 頂部橫向日期選擇器（週/月簡約月曆條）
  Widget _buildCalendarBar() {
    final selectedStr = formatDate(_selectedDate);
    return Container(
      color: Theme.of(context).primaryColor.withOpacity(0.05),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(
        height: 70,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 30, // 顯示過去 30 天
          reverse: true, // 最新在右邊
          itemBuilder: (context, index) {
            final date = DateTime.now().subtract(Duration(days: index));
            final dateStr = formatDate(date);
            final isSelected = dateStr == selectedStr;

            return GestureDetector(
              onTap: () => setState(() => _selectedDate = date),
              child: Container(
                width: 58,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade300,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "${date.month}/${date.day}",
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isSelected ? Colors.white70 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ["一", "二", "三", "四", "五", "六", "日"][date.weekday - 1],
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // 日誌列表視圖
  Widget _buildRecordList(List<Map<String, dynamic>> records) {
    final selectedStr = formatDate(_selectedDate);
    final dayRecords =
        records.where((r) => r['local_date'] == selectedStr).toList();

    if (dayRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note, size: 50, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text("$selectedStr 尚無紀錄",
                style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: dayRecords.length,
      itemBuilder: (context, idx) => HealthRecordCard(record: dayRecords[idx]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("健康日誌"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.accessibility_new), text: "體態 (身高/體重)"),
            Tab(icon: Icon(Icons.favorite), text: "血壓 / 心率"),
          ],
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildCalendarBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRecordList(bodyRecords),
                      _buildRecordList(bloodRecords),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddModal,
        icon: const Icon(Icons.add),
        label: const Text("新增紀錄"),
      ),
    );
  }
}
