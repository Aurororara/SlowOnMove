import 'package:flutter/foundation.dart';

class ApiConfig {
  // Android 模擬器用：10.0.2.2
  // Web 瀏覽器用：localhost (127.0.0.1)
  // 真手機用：電腦區網 IP，例如 http://192.168.50.58:8000/api/
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000/api/';
    }
    return 'http://192.168.50.58:8000/api/';
  }
}
