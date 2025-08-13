class PurchaseSource {
  final String id;
  final String name;
  final String? description;

  const PurchaseSource({
    required this.id,
    required this.name,
    this.description,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    if (description != null) 'description': description,
  };

  factory PurchaseSource.fromMap(Map<String, dynamic> map) => PurchaseSource(
    id: map['id'] ?? '',
    name: map['name'] ?? '',
    description: map['description'],
  );
}


