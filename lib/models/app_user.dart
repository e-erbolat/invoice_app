class AppUser {
  final String uid;
  final String email;
  final String role; // 'admin' или 'sales'
  final String? salesRepId; // id торгового представителя, если role == 'sales'

  AppUser({
    required this.uid,
    required this.email,
    required this.role,
    this.salesRepId,
  });

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'role': role,
    if (salesRepId != null) 'salesRepId': salesRepId,
  };

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
    uid: map['uid'],
    email: map['email'],
    role: map['role'],
    salesRepId: map['salesRepId'],
  );
} 