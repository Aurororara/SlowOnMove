import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config/api_config.dart';
import 'services/user_session.dart';

class BodyRecordScreen extends StatefulWidget {
  const BodyRecordScreen({super.key});

  @override
  State<BodyRecordScreen> createState() => _BodyRecordScreenState();
}

class _BodyRecordScreenState extends State<BodyRecordScreen> {
  final heightController = TextEditingController();

  final weightController = TextEditingController();

  final systolicController = TextEditingController();

  final diastolicController = TextEditingController();

  final pulseController = TextEditingController();

  bool loading = true;

  List bodyRecords = [];

  List bloodRecords = [];

  @override
  void initState() {
    super.initState();

    fetchRecords();
  }

  String today() {
    return DateTime.now().toString().substring(0, 10);
  }

  Future<void> fetchRecords() async {
    try {
      final bodyResponse = await http.get(
        Uri.parse('${ApiConfig.baseUrl}body-records/'),
      );

      final bloodResponse = await http.get(
        Uri.parse('${ApiConfig.baseUrl}blood-pressure-records/'),
      );

      if (bodyResponse.statusCode == 200 && bloodResponse.statusCode == 200) {
        final memberId = UserSession.memberId;

        final bodyData = json.decode(bodyResponse.body);

        final bloodData = json.decode(bloodResponse.body);

        setState(() {
          bodyRecords = bodyData.where((e) => e['member'] == memberId).toList();

          bloodRecords =
              bloodData.where((e) => e['member'] == memberId).toList();

          loading = false;
        });
      }
    } catch (e) {
      print(e);

      setState(() {
        loading = false;
      });
    }
  }

  Future<void> addBodyRecord() async {
    if (heightController.text.isEmpty || weightController.text.isEmpty) {
      showMessage("請輸入身高與體重");

      return;
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}body-records/'),
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "member": UserSession.memberId,
        "height": int.parse(heightController.text),
        "weight": int.parse(weightController.text),
        "record_date": today(),
      }),
    );

    print(response.statusCode);

    print(response.body);

    if (response.statusCode == 201) {
      showMessage("身體紀錄新增成功");

      heightController.clear();

      weightController.clear();

      fetchRecords();
    } else {
      showMessage("身體紀錄新增失敗");
    }
  }

  Future<void> addBloodPressure() async {
    if (systolicController.text.isEmpty ||
        diastolicController.text.isEmpty ||
        pulseController.text.isEmpty) {
      showMessage("請輸入完整血壓資料");

      return;
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}blood-pressure-records/'),
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "member": UserSession.memberId,
        "systolic": int.parse(systolicController.text),
        "diastolic": int.parse(diastolicController.text),
        "pulse": int.parse(pulseController.text),
        "record_date": today(),
      }),
    );

    print(response.statusCode);

    print(response.body);

    if (response.statusCode == 201) {
      showMessage("血壓紀錄新增成功");

      systolicController.clear();

      diastolicController.clear();

      pulseController.clear();

      fetchRecords();
    } else {
      showMessage("血壓新增失敗");
    }
  }

  void showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("每日健康紀錄"),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "身體資料",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextField(
                    controller: heightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "身高(cm)"),
                  ),
                  TextField(
                    controller: weightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "體重(kg)"),
                  ),
                  ElevatedButton(
                    onPressed: addBodyRecord,
                    child: const Text("新增身體紀錄"),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    "血壓紀錄",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextField(
                    controller: systolicController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "收縮壓 SYS"),
                  ),
                  TextField(
                    controller: diastolicController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "舒張壓 DIA"),
                  ),
                  TextField(
                    controller: pulseController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "心率"),
                  ),
                  ElevatedButton(
                    onPressed: addBloodPressure,
                    child: const Text("新增血壓紀錄"),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    "歷史紀錄",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ...bodyRecords.map((e) => Card(
                        child: ListTile(
                          title: Text(e['record_date'] ?? ""),
                          subtitle: Text("體重 ${e['weight']} kg"),
                        ),
                      )),
                  ...bloodRecords.map((e) => Card(
                        child: ListTile(
                          title: Text(e['record_date'] ?? ""),
                          subtitle: Text(
                              "血壓 ${e['systolic']}/${e['diastolic']}  心率 ${e['pulse']}"),
                        ),
                      ))
                ],
              ),
            ),
    );
  }
}
