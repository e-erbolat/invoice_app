import 'package:cloud_firestore/cloud_firestore.dart';
import 'purchase_item.dart';

enum PurchaseStatus {
  created,           // Создан, ожидает приемки
  receiving,         // Идет приемка, есть принятые и/или недостающие товары
  stocked,           // Товары оприходованы (новый этап)
  inStock,          // Товары приняты на склад
  onSale,           // Товары выставлены на продажу
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
  final Timestamp? receivedAt;      // Дата приемки
  final Timestamp? stockedAt;       // Дата оприходования
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
    this.receivedAt,
    this.stockedAt,
    this.onSaleAt,
    this.completedAt,
    this.archivedAt,
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
    Timestamp? receivedAt,
    Timestamp? stockedAt,
    Timestamp? onSaleAt,
    Timestamp? completedAt,
    Timestamp? archivedAt,
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
      receivedAt: receivedAt ?? this.receivedAt,
      stockedAt: stockedAt ?? this.stockedAt,
      onSaleAt: onSaleAt ?? this.onSaleAt,
      completedAt: completedAt ?? this.completedAt,
      archivedAt: archivedAt ?? this.archivedAt,
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
    'receivedAt': receivedAt,
    'stockedAt': stockedAt,
    'onSaleAt': onSaleAt,
    'completedAt': completedAt,
    'archivedAt': archivedAt,
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
    receivedAt: map['receivedAt'],
    stockedAt: map['stockedAt'],
    onSaleAt: map['onSaleAt'],
    completedAt: map['completedAt'],
    archivedAt: map['archivedAt'],
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
        return 'Приемка';
      case PurchaseStatus.stocked:
        return 'Оприходовано';
      case PurchaseStatus.inStock:
        return 'Принято на склад';
      case PurchaseStatus.onSale:
        return 'На продаже';
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
