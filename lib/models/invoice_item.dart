class InvoiceItem {
  final String productId;
  final String productName;
  final int quantity;
  final double price; // Фактическая цена (со скидкой)
  final double originalPrice; // Цена по прайсу (из каталога)
  final double totalPrice;
  final bool isBonus;
  final String? satushiCode;

  const InvoiceItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.originalPrice,
    required this.totalPrice,
    this.isBonus = false,
    this.satushiCode,
  }) : assert(quantity > 0, 'Количество должно быть больше 0'),
       assert(price >= 0, 'Цена не может быть отрицательной'),
       assert(originalPrice >= 0, 'Оригинальная цена не может быть отрицательной'),
       assert(totalPrice >= 0, 'Итоговая сумма не может быть отрицательной');

  /// Фабричный метод для создания товара с автоматическим расчетом итоговой суммы
  factory InvoiceItem.create({
    required String productId,
    required String productName,
    required int quantity,
    required double price,
    required double originalPrice,
    bool isBonus = false,
    String? satushiCode,
  }) {
    final totalPrice = isBonus ? 0.0 : quantity * price;
    return InvoiceItem(
      productId: productId,
      productName: productName,
      quantity: quantity,
      price: price,
      originalPrice: originalPrice,
      totalPrice: totalPrice,
      isBonus: isBonus,
      satushiCode: satushiCode,
    );
  }

  /// Фабричный метод для обратной совместимости со старыми данными
  factory InvoiceItem.fromLegacyData(Map<String, dynamic> map) {
    final price = (map['price'] as num).toDouble();
    return InvoiceItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      quantity: map['quantity'] ?? 0,
      price: price,
      originalPrice: price, // Для старых данных используем ту же цену
      totalPrice: (map['totalPrice'] as num).toDouble(),
      isBonus: map['isBonus'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'price': price,
      'originalPrice': originalPrice,
      'totalPrice': totalPrice,
      'isBonus': isBonus,
      if (satushiCode != null) 'satushiCode': satushiCode,
    };
  }

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    // Проверяем, есть ли originalPrice в данных
    final hasOriginalPrice = map.containsKey('originalPrice') && map['originalPrice'] != null;
    
    if (hasOriginalPrice) {
      // Новые данные с originalPrice
      return InvoiceItem(
        productId: map['productId'] ?? '',
        productName: map['productName'] ?? '',
        quantity: map['quantity'] ?? 0,
        price: (map['price'] as num).toDouble(),
        originalPrice: (map['originalPrice'] as num).toDouble(),
        totalPrice: (map['totalPrice'] as num).toDouble(),
        isBonus: map['isBonus'] ?? false,
        satushiCode: map['satushiCode'],
      );
    } else {
      // Старые данные без originalPrice - используем специальный метод
      return InvoiceItem.fromLegacyData(map);
    }
  }

  /// Получить размер скидки в процентах
  double get discountPercentage {
    if (originalPrice <= 0) return 0.0;
    return ((originalPrice - price) / originalPrice * 100).clamp(0.0, 100.0);
  }

  /// Получить размер скидки в абсолютном значении
  double get discountAmount {
    return (originalPrice - price).clamp(0.0, originalPrice);
  }

  /// Проверить, есть ли скидка
  bool get hasDiscount => price < originalPrice;

  /// Создать копию с новыми значениями
  InvoiceItem copyWith({
    String? productId,
    String? productName,
    int? quantity,
    double? price,
    double? originalPrice,
    double? totalPrice,
    bool? isBonus,
    String? satushiCode,
  }) {
    return InvoiceItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      isBonus: isBonus ?? this.isBonus,
      satushiCode: satushiCode ?? this.satushiCode,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InvoiceItem &&
        other.productId == productId &&
        other.productName == productName &&
        other.quantity == quantity &&
        other.price == price &&
        other.originalPrice == originalPrice &&
        other.totalPrice == totalPrice &&
        other.isBonus == isBonus &&
        other.satushiCode == satushiCode;
  }

  @override
  int get hashCode {
    return Object.hash(
      productId,
      productName,
      quantity,
      price,
      originalPrice,
      totalPrice,
      isBonus,
      satushiCode,
    );
  }

  @override
  String toString() {
    return 'InvoiceItem(productId: $productId, productName: $productName, quantity: $quantity, price: $price, originalPrice: $originalPrice, totalPrice: $totalPrice, isBonus: $isBonus, satushiCode: $satushiCode)';
  }
} 