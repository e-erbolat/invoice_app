class Outlet {
  final String id;
  final String name;
  final String address;
  final String phone;
  final String contactPerson;
  final String region;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? creatorId;
  final String? creatorName;

  Outlet({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.contactPerson,
    required this.region,
    required this.createdAt,
    required this.updatedAt,
    this.creatorId,
    this.creatorName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone': phone,
      'contactPerson': contactPerson,
      'region': region,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'creatorId': creatorId,
      'creatorName': creatorName,
    };
  }

  factory Outlet.fromMap(Map<String, dynamic> map) {
    return Outlet(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      phone: map['phone'] ?? '',
      contactPerson: map['contactPerson'] ?? '',
      region: map['region'] ?? '',
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      creatorId: map['creatorId'],
      creatorName: map['creatorName'],
    );
  }
} 