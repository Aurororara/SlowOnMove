import 'package:dio/dio.dart';
import 'package:flutter_line_sdk/flutter_line_sdk.dart';

import 'api_service.dart';

/// LINE 帳號綁定服務
///
/// 使用方式：
/// 1. 先用 LINE Login SDK（例如 flutter_line_sdk）登入並取得 access token
/// 2. 呼叫 [LineBindingService.bind] 把 token 交給後端驗證並綁定到目前登入的帳號
class LineBindingService {
  LineBindingService._();

  static final Dio _dio = ApiService().dio;

  /// 查詢目前帳號是否已綁定 LINE
  static Future<bool> isBound() async {
    final res = await _dio.get('line/bind/');
    return res.data['is_bound'] == true;
  }

  /// 綁定 LINE 帳號，成功回傳 LINE 顯示名稱（可能為 null）
  /// 失敗時會丟出 [DioException]，可用 `ApiService().getErrorMessage(e)` 取得訊息
  static Future<String?> bind(String lineAccessToken) async {
    final res = await _dio.post(
      'line/bind/',
      data: {'access_token': lineAccessToken},
    );
    return res.data['line_display_name'] as String?;
  }

  /// 解除 LINE 綁定
  static Future<void> unbind() async {
    await _dio.delete('line/bind/');
  }

  /// 一步完成：LINE 登入 → 取得 access token → 綁定到目前 App 帳號
  /// 回傳 LINE 顯示名稱。使用者取消登入時丟出 [PlatformException]。
  static Future<String?> loginAndBind() async {
    final result = await LineSDK.instance.login(scopes: ['profile']);
    final displayName = await bind(result.accessToken.value);
    return displayName ?? result.userProfile?.displayName;
  }
}
