class SalesRep {
  final String id;
  final String name;
  final String phone;

  SalesRep({
    required this.id,
    required this.name,
    required this.phone,
  });

  factory SalesRep.fromMap(Map<String, dynamic> map, String id) {
    return SalesRep(
      id: id,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
    };
  }
} 