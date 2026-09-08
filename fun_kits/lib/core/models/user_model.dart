// ─── USER MODEL ─────────────────────────────────────────────────────────────
class UserModel {
  final String uid;
  final String displayName;
  final String email;
  final String role; // 'admin' or 'visitor'
  final int points;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    this.role = 'visitor',
    this.points = 0,
    required this.createdAt,
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid: uid,
      displayName: map['displayName'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'visitor',
      points: map['points'] ?? 0,
      createdAt: (map['createdAt'] as dynamic).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'email': email,
        'role': role,
        'points': points,
        'createdAt': createdAt,
      };

  UserModel copyWith({int? points}) => UserModel(
        uid: uid,
        displayName: displayName,
        email: email,
        role: role,
        points: points ?? this.points,
        createdAt: createdAt,
      );
}