class Product {
  final String id;
  final String name;
  final double price;
  final String? description;

  Product({
    required this.id,
    required this.name,
    required this.price,
    this.description,
  });

  factory Product.fromMap(Map<String, dynamic> map, String id) {
    return Product(
      id: id,
      name: map['name'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      description: map['description'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'description': description,
    };
  }
} 