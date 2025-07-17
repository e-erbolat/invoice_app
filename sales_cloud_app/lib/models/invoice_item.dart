class InvoiceItem {
  final String productId;
  final String productName;
  final int quantity;
  final double price;
  final double discount;
  final bool isBonus;

  InvoiceItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    this.discount = 0.0,
    this.isBonus = false,
  });

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      quantity: map['quantity'] ?? 0,
      price: (map['price'] ?? 0).toDouble(),
      discount: (map['discount'] ?? 0).toDouble(),
      isBonus: map['isBonus'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'price': price,
      'discount': discount,
      'isBonus': isBonus,
    };
  }
} 