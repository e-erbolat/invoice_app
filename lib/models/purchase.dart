import 'package:cloud_firestore/cloud_firestore.dart';
import 'purchase_item.dart';

enum PurchaseStatus {
  created,           // 1. Создание (ожидание)
  receiving,         // 2. Оприходывание
  stocked,           // 3. Принять на склад
  inStock,          // 4. Выставка на продажу
  onSale,           // 5. Архив заказов
  completed,         // Все товары получены, оприходованы и выставлены
  closedWithShortage, // Закуп закрыт, но часть товаров так и не поступила
  archived,          // Закуп перенесен в архив
}

class Purchase {
  final String id;
  final String supplierId;
  final String supplierName;
  final Timestamp dateCreated;
  final PurchaseStatus status;
  final List<PurchaseItem> items;
  final double totalAmount;
  final String? notes;
  final String createdByUserId;
  final String createdByUserName;
  final Timestamp? receivedAt;      // Дата оприходывания
  final Timestamp? stockedAt;       // Дата принятия на склад
  final Timestamp? onSaleAt;        // Дата выставки на продажу
  final Timestamp? completedAt;     // Дата завершения
  final Timestamp? archivedAt;      // Дата архивации

  const Purchase({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.dateCreated,
    required this.status,
    required this.items,
    required this.totalAmount,
    this.notes,
    required this.createdByUserId,
    required this.createdByUserName,
    this.receivedAt,      // Дата оприходывания
    this.stockedAt,       // Дата принятия на склад
    this.onSaleAt,        // Дата выставки на продажу
    this.completedAt,     // Дата завершения
    this.archivedAt,      // Дата архивации
  });

  factory Purchase.create({
    required String supplierId,
    required String supplierName,
    required List<PurchaseItem> items,
    String? notes,
    required String createdByUserId,
    required String createdByUserName,
  }) {
    final total = items.fold<double>(0.0, (total, item) => total + item.totalPrice);
    return Purchase(
      id: 'purchase_${DateTime.now().millisecondsSinceEpoch}',
      supplierId: supplierId,
      supplierName: supplierName,
      dateCreated: Timestamp.now(),
      status: PurchaseStatus.created,
      items: items,
      totalAmount: total,
      notes: notes,
      createdByUserId: createdByUserId,
      createdByUserName: createdByUserName,
    );
  }

  Purchase copyWith({
    String? id,
    String? supplierId,
    String? supplierName,
    Timestamp? dateCreated,
    PurchaseStatus? status,
    List<PurchaseItem>? items,
    double? totalAmount,
    String? notes,
    String? createdByUserId,
    String? createdByUserName,
    Timestamp? receivedAt,      // Дата оприходывания
    Timestamp? stockedAt,       // Дата принятия на склад
    Timestamp? onSaleAt,        // Дата выставки на продажу
    Timestamp? completedAt,     // Дата завершения
    Timestamp? archivedAt,      // Дата архивации
  }) {
    return Purchase(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      dateCreated: dateCreated ?? this.dateCreated,
      status: status ?? this.status,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      notes: notes ?? this.notes,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      createdByUserName: createdByUserName ?? this.createdByUserName,
      receivedAt: receivedAt ?? this.receivedAt,      // Дата оприходывания
      stockedAt: stockedAt ?? this.stockedAt,        // Дата принятия на склад
      onSaleAt: onSaleAt ?? this.onSaleAt,            // Дата выставки на продажу
      completedAt: completedAt ?? this.completedAt,    // Дата завершения
      archivedAt: archivedAt ?? this.archivedAt,      // Дата архивации
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'supplierId': supplierId,
    'supplierName': supplierName,
    'dateCreated': dateCreated,
    'status': status.index,
    'items': items.map((item) => item.toMap()).toList(),
    'totalAmount': totalAmount,
    'notes': notes,
    'createdByUserId': createdByUserId,
    'createdByUserName': createdByUserName,
    'receivedAt': receivedAt,      // Дата оприходывания
    'stockedAt': stockedAt,        // Дата принятия на склад
    'onSaleAt': onSaleAt,          // Дата выставки на продажу
    'completedAt': completedAt,    // Дата завершения
    'archivedAt': archivedAt,      // Дата архивации
  };

  factory Purchase.fromMap(Map<String, dynamic> map) => Purchase(
    id: map['id'] ?? '',
    supplierId: map['supplierId'] ?? '',
    supplierName: map['supplierName'] ?? '',
    dateCreated: map['dateCreated'] ?? Timestamp.now(),
    status: PurchaseStatus.values[map['status'] ?? 0],
    items: (map['items'] as List?)?.map((item) => PurchaseItem.fromMap(item)).toList() ?? [],
    totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
    notes: map['notes'],
    createdByUserId: map['createdByUserId'] ?? '',
    createdByUserName: map['createdByUserName'] ?? '',
    receivedAt: map['receivedAt'],      // Дата оприходывания
    stockedAt: map['stockedAt'],        // Дата принятия на склад
    onSaleAt: map['onSaleAt'],          // Дата выставки на продажу
    completedAt: map['completedAt'],    // Дата завершения
    archivedAt: map['archivedAt'],      // Дата архивации
  );

  // Вычисляемые свойства
  int get totalOrderedQuantity => items.fold<int>(0, (total, item) => total + item.orderedQty);
  int get totalReceivedQuantity => items.fold<int>(0, (total, item) => total + (item.receivedQty ?? 0));
  int get totalMissingQuantity => items.fold<int>(0, (total, item) => total + (item.missingQty ?? 0));
  
  bool get isFullyReceived => totalReceivedQuantity == totalOrderedQuantity;
  bool get hasShortages => totalMissingQuantity > 0;
  bool get isPartiallyReceived => totalReceivedQuantity > 0 && totalReceivedQuantity < totalOrderedQuantity;
  
  // Статус для отображения
  String get statusDisplayName {
    switch (status) {
      case PurchaseStatus.created:
        return 'Создан';
      case PurchaseStatus.receiving:
        return 'Оприходывание';
      case PurchaseStatus.stocked:
        return 'Принять на склад';
      case PurchaseStatus.inStock:
        return 'Выставка на продажу';
      case PurchaseStatus.onSale:
        return 'Архив заказов';
      case PurchaseStatus.completed:
        return 'Завершен';
      case PurchaseStatus.closedWithShortage:
        return 'Закрыт с недостачей';
      case PurchaseStatus.archived:
        return 'В архиве';
    }
  }

  // Цвет статуса для UI
  int get statusColor {
    switch (status) {
      case PurchaseStatus.created:
        return 0xFF2196F3; // Синий
      case PurchaseStatus.receiving:
        return 0xFFFF9800; // Оранжевый
      case PurchaseStatus.stocked:
        return 0xFF00BCD4; // Голубой
      case PurchaseStatus.inStock:
        return 0xFF4CAF50; // Зеленый
      case PurchaseStatus.onSale:
        return 0xFF9C27B0; // Фиолетовый
      case PurchaseStatus.completed:
        return 0xFF4CAF50; // Зеленый
      case PurchaseStatus.closedWithShortage:
        return 0xFFF44336; // Красный
      case PurchaseStatus.archived:
        return 0xFF9E9E9E; // Серый
    }
  }
}
