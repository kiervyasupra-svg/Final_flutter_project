class UserModel {
  final String uid;
  final String name;
  final String email;
  final String photoUrl;
  final String role; // 'customer' or 'admin'
  final double walletBalance;
  final int rewardPoints;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.role,
    this.walletBalance = 0.0,
    this.rewardPoints = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'role': role,
      'walletBalance': walletBalance,
      'rewardPoints': rewardPoints,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      role: map['role'] ?? 'customer',
      walletBalance: (map['walletBalance'] as num?)?.toDouble() ?? 0.0,
      rewardPoints: map['rewardPoints'] ?? 0,
    );
  }
}
