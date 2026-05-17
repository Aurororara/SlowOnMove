import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../api_service.dart';
import '../user_session.dart';

class GoogleAuthService {
  static final GoogleAuthService _instance = GoogleAuthService._internal();

  factory GoogleAuthService() => _instance;

  GoogleAuthService._internal();

  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '231442028986-mo83ph02ucmr0vg0jl34224f1gomsgsr.apps.googleusercontent.com',
  );

  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? googleWebClientId : null,
    serverClientId: kIsWeb ? null : googleWebClientId,
    scopes: const [
      'email',
      'profile',
      'openid',
    ],
  );

  Future<bool?> signIn() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final String? idToken = googleAuth.idToken;

      final String? accessToken = googleAuth.accessToken;

      if (idToken == null && accessToken == null) {
        throw Exception(
          '無法取得 Google 登入憑證',
        );
      }

      final response = await ApiService().dio.post(
        'auth/google/',
        data: {
          'id_token': idToken,
          'access_token': accessToken,
          'platform': kIsWeb ? 'web' : 'mobile',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;

        final String jwtAccessToken = data['access'];

        await ApiService().saveToken(
          jwtAccessToken,
        );

        final userData = data['user'];

        UserSession.updateSession(
          newMemberId: userData['id'],
          newName: userData['name'] ?? '',
          newEmail: userData['email'] ?? '',
        );

        return data['is_new_user'] == true;
      }

      return null;
    } catch (e) {
      print('Google 登入發生錯誤: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();

    await ApiService().clearToken();

    UserSession.clearSession();
  }
}
