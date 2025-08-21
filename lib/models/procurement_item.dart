class ProcurementItem {
  final String productId;
  final String productName;
  final int quantity; // Заказанное количество (orderedQty)
  final double purchasePrice;
  final double totalPrice;
  final String? note;
  final String? procurementId;
  final int? receivedQty; // Фактически принятое количество
  final int? missingQty; // Количество недостачи

  const ProcurementItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.purchasePrice,
    required this.totalPrice,
    this.note,
    this.procurementId,
    this.receivedQty,
    this.missingQty,
  });

  factory ProcurementItem.create({
    required String productId,
    required String productName,
    required int quantity,
    required double purchasePrice,
    String? note,
    String? procurementId,
    int? receivedQty,
    int? missingQty,
  }) {
    final total = quantity * purchasePrice;
    return ProcurementItem(
      productId: productId,
      productName: productName,
      quantity: quantity,
      purchasePrice: purchasePrice,
      totalPrice: total,
      note: note,
      procurementId: procurementId,
      receivedQty: receivedQty,
      missingQty: missingQty,
    );
  }

  ProcurementItem copyWith({
    String? productId,
    String? productName,
    int? quantity,
    double? purchasePrice,
    double? totalPrice,
    String? note,
    String? procurementId,
    int? receivedQty,
    int? missingQty,
  }) {
    final newQuantity = quantity ?? this.quantity;
    final newPurchasePrice = purchasePrice ?? this.purchasePrice;
    final newTotalPrice = totalPrice ?? (newQuantity * newPurchasePrice);
    
    return ProcurementItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: newQuantity,
      purchasePrice: newPurchasePrice,
      totalPrice: newTotalPrice,
      note: note ?? this.note,
      procurementId: procurementId ?? this.procurementId,
      receivedQty: receivedQty ?? this.receivedQty,
      missingQty: missingQty ?? this.missingQty,
    );
  }

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'productName': productName,
    'quantity': quantity,
    'purchasePrice': purchasePrice,
    'totalPrice': totalPrice,
    'note': note,
    'procurementId': procurementId,
    'receivedQty': receivedQty,
    'missingQty': missingQty,
  };

  factory ProcurementItem.fromMap(Map<String, dynamic> map) => ProcurementItem(
    productId: map['productId'] ?? '',
    productName: map['productName'] ?? '',
    quantity: map['quantity'] ?? 0,
    purchasePrice: (map['purchasePrice'] as num?)?.toDouble() ?? 0.0,
    totalPrice: (map['totalPrice'] as num?)?.toDouble() ?? 0.0,
    note: map['note'],
    procurementId: map['procurementId'],
    receivedQty: map['receivedQty'],
    missingQty: map['missingQty'],
  );

  // Вычисляем недостачу
  int get calculatedMissingQty => (receivedQty ?? 0) < quantity ? quantity - (receivedQty ?? 0) : 0;
  
  // Проверяем, полностью ли принят товар
  bool get isFullyReceived => (receivedQty ?? 0) >= quantity;
  
  // Проверяем, есть ли недостача
  bool get hasShortage => calculatedMissingQty > 0;
}


