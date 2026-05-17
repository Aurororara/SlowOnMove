class UserSession {
  static int memberId = 6; // 保留預設值，可根據需要改為可空
  static String displayName = 'Lamei';
  static String email = 'lamei@example.com';

  static void updateSession({required int newMemberId, required String newName, required String newEmail}) {
    memberId = newMemberId;
    displayName = newName;
    email = newEmail;
  }

  static void clearSession() {
    memberId = 0;
    displayName = '';
    email = '';
  }

  static String get displayInitial =>
      displayName.trim().isEmpty ? 'U' : displayName.trim()[0].toUpperCase();
}