import '../api_service.dart';
import '../user_session.dart';
import 'package:dio/dio.dart';

class LocalAuthService {
  static final LocalAuthService _instance = LocalAuthService._internal();

  factory LocalAuthService() => _instance;

  LocalAuthService._internal();

  /// 一般帳號登入
  /// [usernameOrEmail] 可以是帳號或電子信箱
  /// 登入成功會回傳 false (表示不是新註冊使用者，直接進入主畫面)
  Future<bool?> signIn(String usernameOrEmail, String password) async {
    try {
      final response = await ApiService().dio.post(
        'auth/login/',
        data: {
          'username': usernameOrEmail,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final String jwtAccessToken = data['access'];

        await ApiService().saveToken(jwtAccessToken);

        final userData = data['user'];
        UserSession.updateSession(
          newMemberId: userData['id'],
          newName: userData['name'] ?? '',
          newEmail: userData['email'] ?? '',
          newAvatar: userData['avatar'] ?? '',
        );

        return false; // 不是新帳號，進入主頁面
      }
      return null;
    } on DioException catch (e) {
      final data = e.response?.data;

      if (data is Map && data['error'] != null) {
        throw Exception(data['error']);
      }

      throw Exception('登入失敗，請稍後再試');
    } catch (e) {
      throw Exception('登入失敗，請稍後再試');
    }
  }

  /// 一般帳號註冊
  /// 註冊成功會回傳 true (表示是新使用者，進入 Onboarding Setup 頁面)
  Future<bool?> signUp({
    required String username,
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final response = await ApiService().dio.post(
        'auth/register/',
        data: {
          'username': username,
          'email': email,
          'password': password,
          'name': name,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final String jwtAccessToken = data['access'];

        await ApiService().saveToken(jwtAccessToken);

        final userData = data['user'];
        UserSession.updateSession(
          newMemberId: userData['id'],
          newName: userData['name'] ?? '',
          newEmail: userData['email'] ?? '',
          newAvatar: userData['avatar'] ?? '',
        );

        return true; // 是新註冊帳號，引導至 Onboarding 頁面
      }
      return null;
    } on DioException catch (e) {
      final data = e.response?.data;

      if (data is Map && data['error'] != null) {
        throw Exception(data['error']);
      }

      throw Exception('註冊失敗，請稍後再試');
    } catch (e) {
      throw Exception('註冊失敗，請稍後再試');
    }
  }

  /// 登出
  Future<void> signOut() async {
    await ApiService().clearToken();
    UserSession.clearSession();
  }
}
