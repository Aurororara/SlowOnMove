import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000/api/';
    }

    return 'http://10.0.2.2:8000/api/';
  }
}