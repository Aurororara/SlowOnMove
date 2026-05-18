class UserSession {
  static int memberId = 6; 
  static String displayName = 'Lamei';
  static String email = 'lamei@example.com';
  static String avatar = '';

  static void updateSession({
    required int newMemberId,
    required String newName,
    required String newEmail,
    String newAvatar = '',
  }) {
    memberId = newMemberId;
    displayName = newName;
    email = newEmail;
    avatar = newAvatar;
  }

  static void clearSession() {
    memberId = 0;
    displayName = '';
    email = '';
    avatar = '';
  }

  static String get displayInitial =>
      displayName.trim().isEmpty
          ? 'U'
          : displayName.trim()[0].toUpperCase();
}