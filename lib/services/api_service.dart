import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/api_config.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();

  factory ApiService() => _instance;

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
          final token = await getToken();

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            await clearToken();
          }

          handler.next(e);
        },
      ),
    );
  }

  late final Dio dio;

  final FlutterSecureStorage storage = const FlutterSecureStorage();

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
        return '請求資料格式錯誤';
      }

      if (statusCode == 401) {
        return '登入已過期，請重新登入';
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
