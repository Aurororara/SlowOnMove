import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

import '../api_service.dart';
import '../user_session.dart';

class FacebookAuthService {
  Future<bool?> signIn() async {
    try {
      if (!kIsWeb) {
        await FacebookAuth.instance.logOut();
      }

      final LoginResult result = await FacebookAuth.instance.login(
        permissions: [
          'email',
          'public_profile',
        ],
        loginBehavior: LoginBehavior.nativeWithFallback,
        loginTracking: LoginTracking.enabled,
      );

      if (result.status == LoginStatus.cancelled) {
        print('使用者取消 Facebook 登入');
        return null;
      }

      if (result.status == LoginStatus.failed) {
        print('Facebook 登入失敗');
        print(result.message);
        return null;
      }

      if (result.accessToken == null) {
        print('Facebook access token 為 null');
        return null;
      }

      final accessToken = result.accessToken!.tokenString;

      print('FB TOKEN: $accessToken');

      final fbUser = await FacebookAuth.instance.getUserData(
        fields:
            'id,name,first_name,last_name,email,picture.width(200).height(200)',
      );

      print('FB USER DATA: $fbUser');

      final avatarUrl = fbUser['picture']?['data']?['url']?.toString();

      final response = await ApiService().dio.post(
        'auth/facebook/',
        data: {
          'access_token': accessToken,
          'facebook_id': fbUser['id']?.toString(),
          'name': fbUser['name']?.toString() ?? '',
          'email': fbUser['email']?.toString() ?? '',
          'avatar': avatarUrl ?? '',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;

        await ApiService().saveToken(data['access']);

        final userData = data['user'];

        UserSession.updateSession(
          newMemberId: userData['id'],
          newName: userData['name'] ?? '',
          newEmail: userData['email'] ?? '',
          newAvatar: userData['avatar'] ?? avatarUrl ?? '',
        );

        print('Facebook 登入成功');

        return data['is_new_user'] == true;
      }

      print('後端登入失敗');
      print(response.data);

      return null;
    } on DioException catch (e) {
      print('Facebook 後端登入失敗');
      print('statusCode: ${e.response?.statusCode}');
      print('response data: ${e.response?.data}');
      print('request data: ${e.requestOptions.data}');
      return null;
    } catch (e) {
      print('Facebook 登入錯誤: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await FacebookAuth.instance.logOut();
    } catch (_) {}

    await ApiService().clearToken();
    UserSession.clearSession();
  }
}
