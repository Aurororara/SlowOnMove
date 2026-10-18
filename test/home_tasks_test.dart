import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:show_on_move/main_screen.dart';
import 'package:show_on_move/monthly_recap_screen.dart';
import 'package:show_on_move/results_screen.dart';
import 'package:show_on_move/services/api_service.dart';
import 'package:show_on_move/services/user_session.dart';

class _HomeDataAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  bool denyLogs = false;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    if (denyLogs && options.path == 'training-logs/') {
      return ResponseBody.fromString(
          '{"detail":"Authentication required"}', 401,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          });
    }
    final Object data = options.path.startsWith('members/')
        ? {'exercise_goal': 'health', 'exercise_frequency': '1_2'}
        : [
            {
              'id': 1,
              'member': 7,
              'exercise_type': 'slow_jogging',
              'total_mins': 30,
              'posture_score': 90,
              'step_count': 8000,
              'calories': 200,
              'start_time': DateTime.now().toIso8601String(),
              'end_time': DateTime.now().toIso8601String(),
              'created_at': DateTime.now().toIso8601String(),
            }
          ];
    return ResponseBody.fromString(jsonEncode(data), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  testWidgets(
      'Failed single-workout save remains visible with retry instead of success',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({'jwt_token': 'expired-jwt'});
    final dio = ApiService().dio;
    final oldAdapter = dio.httpClientAdapter;
    final adapter = _HomeDataAdapter()..denyLogs = true;
    dio.httpClientAdapter = adapter;
    addTearDown(() => dio.httpClientAdapter = oldAdapter);
    await tester.pumpWidget(const MaterialApp(
        home: ResultsScreen(
      timeSeconds: 60,
      averageAccuracy: 90,
      stepCount: 180,
      finalFeedback: [],
    )));
    // Confetti animates independently of record persistence.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(adapter.requests.single.method, 'POST');
    expect(find.text('運動紀錄儲存失敗'), findsOneWidget);
    expect(find.text('登入驗證失敗，請重新登入'), findsOneWidget);
    expect(find.text('重試儲存'), findsOneWidget);
    expect(find.text('運動紀錄已儲存'), findsNothing);
    expect(find.text('完成回饋'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Monthly recap displays saved current-month training',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({'jwt_token': 'valid-jwt'});
    final dio = ApiService().dio;
    final oldAdapter = dio.httpClientAdapter;
    final adapter = _HomeDataAdapter();
    dio.httpClientAdapter = adapter;
    addTearDown(() => dio.httpClientAdapter = oldAdapter);
    await tester.pumpWidget(const MaterialApp(home: MonthlyRecapScreen()));
    await tester.pumpAndSettle();
    expect(
        adapter.requests.single.headers['Authorization'], 'Bearer valid-jwt');
    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('這個月還沒有跑步紀錄'), findsNothing);
    expect(find.text('月度紀錄讀取失敗'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'Monthly recap distinguishes failed authentication from an empty month',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({'jwt_token': 'expired-jwt'});
    final dio = ApiService().dio;
    final oldAdapter = dio.httpClientAdapter;
    final adapter = _HomeDataAdapter()..denyLogs = true;
    dio.httpClientAdapter = adapter;
    addTearDown(() => dio.httpClientAdapter = oldAdapter);
    await tester.pumpWidget(const MaterialApp(home: MonthlyRecapScreen()));
    await tester.pumpAndSettle();
    expect(find.text('月度紀錄讀取失敗'), findsOneWidget);
    expect(find.text('登入驗證失敗，請重新登入'), findsOneWidget);
    expect(find.text('這個月還沒有跑步紀錄'), findsNothing);
    expect(find.text('重新讀取'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'Home authenticates both requests and completes tasks from saved training',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({'jwt_token': 'home-test-jwt'});
    UserSession.updateSession(
        newMemberId: 7, newName: '測試會員', newEmail: 'test@example.test');
    final dio = ApiService().dio;
    final oldAdapter = dio.httpClientAdapter;
    final adapter = _HomeDataAdapter();
    dio.httpClientAdapter = adapter;
    addTearDown(() {
      dio.httpClientAdapter = oldAdapter;
      UserSession.clearSession();
    });
    var rewards = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: HomeScreen(
        onDailyRewardGranted: () => rewards++,
      )),
    ));
    await tester.pumpAndSettle();
    expect(adapter.requests.map((r) => r.path),
        containsAll(['members/7/', 'training-logs/']));
    expect(
        adapter.requests
            .every((r) => r.headers['Authorization'] == 'Bearer home-test-jwt'),
        isTrue);
    expect(find.text('(3/3)'), findsOneWidget);
    expect(find.text('已兌換 +0.1'), findsOneWidget);
    expect(rewards, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
