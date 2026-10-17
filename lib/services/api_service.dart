import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/api_config.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();

  factory ApiService() => _instance;

  late final Dio dio;

  final FlutterSecureStorage storage = const FlutterSecureStorage();

  ApiService._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          const publicAuthPaths = [
            'auth/google/',
            'auth/login/',
          ];

          final isPublicAuthRequest = publicAuthPaths.any(
            (path) => options.path.contains(path),
          );

          // 避免沿用前一次請求的 Authorization
          options.headers.remove('Authorization');

          if (!isPublicAuthRequest) {
            final token = await getToken();

            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }

            if (kDebugMode) {
              debugPrint(
                '[API] ${options.method} ${options.path} '
                'token=${token != null && token.isNotEmpty}',
              );
            }
          }

          handler.next(options);
        },
        onError: (error, handler) {
          if (kDebugMode) {
            debugPrint(
              '[API ERROR] ${error.requestOptions.path} '
              'status=${error.response?.statusCode}',
            );

            if (error.response?.statusCode == 401) {
              debugPrint(
                '[API AUTH ERROR] ${error.response?.data}',
              );
            }
          }

          // 不因單一 API 401 就刪除整個登入狀態
          // Token 清除應由登出流程統一處理
          handler.next(error);
        },
      ),
    );
  }

  Future<void> saveToken(String token) async {
    await storage.write(
      key: 'jwt_token',
      value: token,
    );
  }

  Future<String?> getToken() async {
    return storage.read(key: 'jwt_token');
  }

  Future<void> clearToken() async {
    await storage.delete(key: 'jwt_token');
  }

  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  String getErrorMessage(Object error) {
    if (error is DioException) {
      if (error.error is SocketException ||
          error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout) {
        return '無法連線到伺服器，請確認網路或稍後再試';
      }

      if (error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return '伺服器回應逾時，請稍後再試';
      }

      final statusCode = error.response?.statusCode;

      if (statusCode == 400) {
        final data = error.response?.data;

        if (data is Map) {
          final message = data['error'] ?? data['detail'] ?? data['message'];

          if (message != null) {
            return message.toString();
          }
        }

        return '請求資料格式錯誤';
      }

      if (statusCode == 401) {
        return '登入驗證失敗，請重新登入';
      }

      if (statusCode == 403) {
        return '沒有權限執行此操作';
      }

      if (statusCode == 404) {
        return '找不到資料';
      }

      if (statusCode != null && statusCode >= 500) {
        return '伺服器發生錯誤，請稍後再試';
      }

      return '請求失敗，請稍後再試';
    }

    return '發生未知錯誤，請稍後再試';
  }
}
