class ProcurementItem {
  final String productId;
  final String productName;
  final int quantity;
  final double purchasePrice;
  final double totalPrice;

  const ProcurementItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.purchasePrice,
    required this.totalPrice,
  });

  factory ProcurementItem.create({
    required String productId,
    required String productName,
    required int quantity,
    required double purchasePrice,
  }) {
    final total = quantity * purchasePrice;
    return ProcurementItem(
      productId: productId,
      productName: productName,
      quantity: quantity,
      purchasePrice: purchasePrice,
      totalPrice: total,
    );
  }

  ProcurementItem copyWith({
    String? productId,
    String? productName,
    int? quantity,
    double? purchasePrice,
    double? totalPrice,
  }) {
    return ProcurementItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      totalPrice: totalPrice ?? this.totalPrice,
    );
  }

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'productName': productName,
    'quantity': quantity,
    'purchasePrice': purchasePrice,
    'totalPrice': totalPrice,
  };

  factory ProcurementItem.fromMap(Map<String, dynamic> map) => ProcurementItem(
    productId: map['productId'] ?? '',
    productName: map['productName'] ?? '',
    quantity: map['quantity'] ?? 0,
    purchasePrice: (map['purchasePrice'] as num?)?.toDouble() ?? 0.0,
    totalPrice: (map['totalPrice'] as num?)?.toDouble() ?? 0.0,
  );
}


