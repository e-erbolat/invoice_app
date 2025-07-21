class SalesRep {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String region;
  final double commissionRate;
  final DateTime createdAt;
  final DateTime updatedAt;

  SalesRep({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.region,
    required this.commissionRate,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'region': region,
      'commissionRate': commissionRate,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory SalesRep.fromMap(Map<String, dynamic> map) {
    return SalesRep(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      region: map['region'] ?? '',
      commissionRate: (map['commissionRate'] ?? 0.0).toDouble(),
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }
} 