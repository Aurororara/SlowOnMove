class UserModel {
  final String uid;
  final String username;
  final String email;
  final DateTime joinDate;

  UserModel({
    required this.uid,
    required this.username,
    required this.email,
    required this.joinDate,
  });

  factory UserModel.fromJson(Map<String, dynamic> json, String uid) {
    return UserModel(
      uid: uid,
      username: json['username'] as String? ?? 'New User',
      email: json['email'] as String? ?? '',
      joinDate: json['join_date'] != null ? DateTime.parse(json['join_date']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'email': email,
      'join_date': joinDate.toIso8601String(),
    };
  }
}
