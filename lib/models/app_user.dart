class AppUser {
  final String uid;
  final String email;
  final String role; // 'admin' или 'sales'

  AppUser({
    required this.uid,
    required this.email,
    required this.role,
  });

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'role': role,
  };

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
    uid: map['uid'],
    email: map['email'],
    role: map['role'],
  );
} 