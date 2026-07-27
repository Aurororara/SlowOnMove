import 'package:flutter/foundation.dart';

class UserSession {
  static int memberId = 6;
  static String displayName = 'Lamei';
  static String email = 'lamei@example.com';
  static String avatar = '';
  static final ValueNotifier<double> walletBalanceNotifier =
      ValueNotifier<double>(1200.0);
  static final Set<String> _dailyRewardClaimedDates = <String>{};

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
    walletBalanceNotifier.value = 1200.0;
    _dailyRewardClaimedDates.clear();
  }

  static void addWalletBalance(double amount) {
    walletBalanceNotifier.value =
        double.parse((walletBalanceNotifier.value + amount).toStringAsFixed(1));
  }

  static bool claimDailyRewardForDate(DateTime date, {double amount = 0.1}) {
    final String key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    if (_dailyRewardClaimedDates.contains(key)) {
      return false;
    }

    _dailyRewardClaimedDates.add(key);
    addWalletBalance(amount);
    return true;
  }

  static String get displayInitial =>
      displayName.trim().isEmpty ? 'U' : displayName.trim()[0].toUpperCase();
}
