import 'package:cloud_firestore/cloud_firestore.dart';

enum PurchaseItemStatus {
  ordered,           // Заказано
  received,          // Получено
  inStock,           // Оприходовано на склад
  onSale,            // Выставлено на продажу
  shortageWaiting,   // Недостача в ожидании
  shortageReceived,  // Недостача получена
  shortageNotReceived, // Недостача не получена
}

class PurchaseItem {
  final String id;
  final String purchaseId;
  final String productId;
  final String productName;
  final int orderedQty;      // Заказанное количество
  final double purchasePrice; // Цена закупки
  final double totalPrice;    // Общая стоимость
  final int? receivedQty;     // Фактически полученное количество
  final int? missingQty;      // Количество недостачи
  final PurchaseItemStatus status;
  final String? notes;
  final Timestamp? receivedAt;    // Дата получения
  final Timestamp? stockedAt;     // Дата оприходования
  final Timestamp? onSaleAt;      // Дата выставки на продажу
  final String? receivedByUserId; // Кто принял
  final String? receivedByUserName; // Имя принявшего

  const PurchaseItem({
    required this.id,
    required this.purchaseId,
    required this.productId,
    required this.productName,
    required this.orderedQty,
    required this.purchasePrice,
    required this.totalPrice,
    this.receivedQty,
    this.missingQty,
    required this.status,
    this.notes,
    this.receivedAt,
    this.stockedAt,
    this.onSaleAt,
    this.receivedByUserId,
    this.receivedByUserName,
  });

  factory PurchaseItem.create({
    required String purchaseId,
    required String productId,
    required String productName,
    required int orderedQty,
    required double purchasePrice,
    String? notes,
  }) {
    final total = orderedQty * purchasePrice;
    return PurchaseItem(
      id: 'item_${DateTime.now().millisecondsSinceEpoch}',
      purchaseId: purchaseId,
      productId: productId,
      productName: productName,
      orderedQty: orderedQty,
      purchasePrice: purchasePrice,
      totalPrice: total,
      status: PurchaseItemStatus.ordered,
      notes: notes,
    );
  }

  PurchaseItem copyWith({
    String? id,
    String? purchaseId,
    String? productId,
    String? productName,
    int? orderedQty,
    double? purchasePrice,
    double? totalPrice,
    int? receivedQty,
    int? missingQty,
    PurchaseItemStatus? status,
    String? notes,
    Timestamp? receivedAt,
    Timestamp? stockedAt,
    Timestamp? onSaleAt,
    String? receivedByUserId,
    String? receivedByUserName,
  }) {
    final newOrderedQty = orderedQty ?? this.orderedQty;
    final newPurchasePrice = purchasePrice ?? this.purchasePrice;
    final newTotalPrice = totalPrice ?? (newOrderedQty * newPurchasePrice);
    
    return PurchaseItem(
      id: id ?? this.id,
      purchaseId: purchaseId ?? this.purchaseId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      orderedQty: newOrderedQty,
      purchasePrice: newPurchasePrice,
      totalPrice: newTotalPrice,
      receivedQty: receivedQty ?? this.receivedQty,
      missingQty: missingQty ?? this.missingQty,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      receivedAt: receivedAt ?? this.receivedAt,
      stockedAt: stockedAt ?? this.stockedAt,
      onSaleAt: onSaleAt ?? this.onSaleAt,
      receivedByUserId: receivedByUserId ?? this.receivedByUserId,
      receivedByUserName: receivedByUserName ?? this.receivedByUserName,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'purchaseId': purchaseId,
    'productId': productId,
    'productName': productName,
    'orderedQty': orderedQty,
    'purchasePrice': purchasePrice,
    'totalPrice': totalPrice,
    'receivedQty': receivedQty,
    'missingQty': missingQty,
    'status': status.index,
    'notes': notes,
    'receivedAt': receivedAt,
    'stockedAt': stockedAt,
    'onSaleAt': onSaleAt,
    'receivedByUserId': receivedByUserId,
    'receivedByUserName': receivedByUserName,
  };

  factory PurchaseItem.fromMap(Map<String, dynamic> map) => PurchaseItem(
    id: map['id'] ?? '',
    purchaseId: map['purchaseId'] ?? '',
    productId: map['productId'] ?? '',
    productName: map['productName'] ?? '',
    orderedQty: map['orderedQty'] ?? 0,
    purchasePrice: (map['purchasePrice'] as num?)?.toDouble() ?? 0.0,
    totalPrice: (map['totalPrice'] as num?)?.toDouble() ?? 0.0,
    receivedQty: map['receivedQty'],
    missingQty: map['missingQty'],
    status: PurchaseItemStatus.values[map['status'] ?? 0],
    notes: map['notes'],
    receivedAt: map['receivedAt'],
    stockedAt: map['stockedAt'],
    onSaleAt: map['onSaleAt'],
    receivedByUserId: map['receivedByUserId'],
    receivedByUserName: map['receivedByUserName'],
  );

  // Вычисляемые свойства
  bool get isFullyReceived => receivedQty != null && receivedQty! >= orderedQty;
  bool get isPartiallyReceived => receivedQty != null && receivedQty! > 0 && receivedQty! < orderedQty;
  bool get hasShortage => missingQty != null && missingQty! > 0;
  bool get isReceived => receivedQty != null && receivedQty! > 0;
  bool get isStocked => stockedAt != null;
  bool get isOnSale => onSaleAt != null;

  // Статус для отображения
  String get statusDisplayName {
    switch (status) {
      case PurchaseItemStatus.ordered:
        return 'Заказано';
      case PurchaseItemStatus.received:
        return 'Получено';
      case PurchaseItemStatus.inStock:
        return 'На складе';
      case PurchaseItemStatus.onSale:
        return 'На продаже';
      case PurchaseItemStatus.shortageWaiting:
        return 'Ожидается';
      case PurchaseItemStatus.shortageReceived:
        return 'Довезли';
      case PurchaseItemStatus.shortageNotReceived:
        return 'Не довезли';
    }
  }

  // Цвет статуса для UI
  int get statusColor {
    switch (status) {
      case PurchaseItemStatus.ordered:
        return 0xFF2196F3; // Синий
      case PurchaseItemStatus.received:
        return 0xFF4CAF50; // Зеленый
      case PurchaseItemStatus.inStock:
        return 0xFF4CAF50; // Зеленый
      case PurchaseItemStatus.onSale:
        return 0xFF9C27B0; // Фиолетовый
      case PurchaseItemStatus.shortageWaiting:
        return 0xFFFF9800; // Оранжевый
      case PurchaseItemStatus.shortageReceived:
        return 0xFF4CAF50; // Зеленый
      case PurchaseItemStatus.shortageNotReceived:
        return 0xFFF44336; // Красный
    }
  }

  // Методы для обновления статуса
  PurchaseItem markAsReceived({
    required int receivedQty,
    required String receivedByUserId,
    required String receivedByUserName,
  }) {
    final missing = receivedQty < orderedQty ? orderedQty - receivedQty : 0;
    final newStatus = missing > 0 
        ? PurchaseItemStatus.shortageWaiting 
        : PurchaseItemStatus.received;
    
    return copyWith(
      receivedQty: receivedQty,
      missingQty: missing,
      status: newStatus,
      receivedAt: Timestamp.now(),
      receivedByUserId: receivedByUserId,
      receivedByUserName: receivedByUserName,
    );
  }

  PurchaseItem markAsStocked() {
    return copyWith(
      status: PurchaseItemStatus.inStock,
      stockedAt: Timestamp.now(),
    );
  }

  PurchaseItem markAsOnSale() {
    return copyWith(
      status: PurchaseItemStatus.onSale,
      onSaleAt: Timestamp.now(),
    );
  }

  PurchaseItem markShortageAsReceived() {
    return copyWith(
      status: PurchaseItemStatus.shortageReceived,
      receivedQty: (receivedQty ?? 0) + (missingQty ?? 0),
      missingQty: 0,
    );
  }

  PurchaseItem markShortageAsNotReceived() {
    return copyWith(
      status: PurchaseItemStatus.shortageNotReceived,
    );
  }
}
