class UserSession {
  static int memberId = 6; // 開發測試用
 static String displayName = 'Lamei';
  static String email = 'lamei@example.com';

  static String get displayInitial =>
      displayName.trim().isEmpty ? 'U' : displayName.trim()[0].toUpperCase();
}