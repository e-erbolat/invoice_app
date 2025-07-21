class Outlet {
  final String id;
  final String name;
  final String contactName;
  final String contactPhone;
  final String address;

  Outlet({
    required this.id,
    required this.name,
    required this.contactName,
    required this.contactPhone,
    required this.address,
  });

  factory Outlet.fromMap(Map<String, dynamic> map, String id) {
    return Outlet(
      id: id,
      name: map['name'] ?? '',
      contactName: map['contactName'] ?? '',
      contactPhone: map['contactPhone'] ?? '',
      address: map['address'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'contactName': contactName,
      'contactPhone': contactPhone,
      'address': address,
    };
  }
} 