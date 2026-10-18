import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:show_on_move/community/group_run_screen.dart';
import 'package:show_on_move/community/models/community_group.dart';
import 'package:show_on_move/services/api_service.dart';

class _DeniedRoomAdapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    request = options;
    return ResponseBody.fromString(
      '{"detail":"僅群組成員可加入揪團視訊。"}',
      403,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  testWidgets(
      'Camera sharing requires an explicit join; denied entry stays out of room',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({'jwt_token': 'test-jwt'});
    final api = ApiService();
    final oldAdapter = api.dio.httpClientAdapter;
    final adapter = _DeniedRoomAdapter();
    api.dio.httpClientAdapter = adapter;
    addTearDown(() => api.dio.httpClientAdapter = oldAdapter);

    await tester.pumpWidget(MaterialApp(
      home: GroupRunScreen(
        group: CommunityGroup.fromJson({'id': 12, 'name': '測試跑團'}),
      ),
    ));
    expect(adapter.request, isNull);
    expect(find.text('開啟相機並加入'), findsOneWidget);
    expect(find.byTooltip('關閉相機'), findsNothing);

    await tester.tap(find.text('開啟相機並加入'));
    await tester.pumpAndSettle();
    expect(adapter.request?.data, {'group_id': 12});
    expect(adapter.request?.headers['Authorization'], 'Bearer test-jwt');
    expect(find.text('僅群組成員可加入揪團視訊。'), findsOneWidget);
    expect(find.byTooltip('離開房間'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
