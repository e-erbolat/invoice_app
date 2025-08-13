class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final int stockQuantity;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String barcode;
  final String? satushiCode;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.stockQuantity,
    required this.createdAt,
    required this.updatedAt,
    required this.barcode,
    this.satushiCode,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'stockQuantity': stockQuantity,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'barcode': barcode,
      if (satushiCode != null && satushiCode!.isNotEmpty) 'satushiCode': satushiCode,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      category: map['category'] ?? '',
      stockQuantity: map['stockQuantity'] ?? 0,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      barcode: map['barcode'] ?? '',
      satushiCode: map['satushiCode'],
    );
  }
} 