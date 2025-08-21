import 'package:cloud_firestore/cloud_firestore.dart';

enum ShortageStatus {
  waiting,      // Ожидает поставки
  received,     // Получено
  notReceived   // Не получено
}

class Shortage {
  final String id;
  final String purchaseId;      // ID закупа
  final String itemId;          // ID позиции товара
  final String productId;       // ID товара
  final String productName;     // Название товара
  final int orderedQty;         // Заказанное количество
  final int missingQty;         // Количество недостачи
  final double purchasePrice;   // Цена закупки
  final ShortageStatus status;  // Статус недостачи
  final String? note;           // Примечание
  final Timestamp createdAt;    // Дата создания
  final Timestamp? receivedAt;  // Дата получения
  final Timestamp? closedAt;    // Дата закрытия

  const Shortage({
    required this.id,
    required this.purchaseId,
    required this.itemId,
    required this.productId,
    required this.productName,
    required this.orderedQty,
    required this.missingQty,
    required this.purchasePrice,
    required this.status,
    this.note,
    required this.createdAt,
    this.receivedAt,
    this.closedAt,
  });

  factory Shortage.create({
    required String purchaseId,
    required String itemId,
    required String productId,
    required String productName,
    required int orderedQty,
    required int missingQty,
    required double purchasePrice,
    String? note,
  }) {
    return Shortage(
      id: 'shortage_${purchaseId}_${itemId}_${DateTime.now().millisecondsSinceEpoch}',
      purchaseId: purchaseId,
      itemId: itemId,
      productId: productId,
      productName: productName,
      orderedQty: orderedQty,
      missingQty: missingQty,
      purchasePrice: purchasePrice,
      status: ShortageStatus.waiting,
      note: note,
      createdAt: Timestamp.now(),
    );
  }

  Shortage copyWith({
    String? id,
    String? purchaseId,
    String? itemId,
    String? productId,
    String? productName,
    int? orderedQty,
    int? missingQty,
    double? purchasePrice,
    ShortageStatus? status,
    String? note,
    Timestamp? createdAt,
    Timestamp? receivedAt,
    Timestamp? closedAt,
  }) {
    return Shortage(
      id: id ?? this.id,
      purchaseId: purchaseId ?? this.purchaseId,
      itemId: itemId ?? this.itemId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      orderedQty: orderedQty ?? this.orderedQty,
      missingQty: missingQty ?? this.missingQty,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      status: status ?? this.status,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      receivedAt: receivedAt ?? this.receivedAt,
      closedAt: closedAt ?? this.closedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'purchaseId': purchaseId,
    'itemId': itemId,
    'productId': productId,
    'productName': productName,
    'orderedQty': orderedQty,
    'missingQty': missingQty,
    'purchasePrice': purchasePrice,
    'status': status.index,
    'note': note,
    'createdAt': createdAt,
    'receivedAt': receivedAt,
    'closedAt': closedAt,
  };

  factory Shortage.fromMap(Map<String, dynamic> map) => Shortage(
    id: map['id'] ?? '',
    purchaseId: map['purchaseId'] ?? '',
    itemId: map['itemId'] ?? '',
    productId: map['productId'] ?? '',
    productName: map['productName'] ?? '',
    orderedQty: map['orderedQty'] ?? 0,
    missingQty: map['missingQty'] ?? 0,
    purchasePrice: (map['purchasePrice'] as num?)?.toDouble() ?? 0.0,
    status: ShortageStatus.values[map['status'] ?? 0],
    note: map['note'],
    createdAt: map['createdAt'] is Timestamp ? map['createdAt'] : Timestamp.fromDate(DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()),
    receivedAt: map['receivedAt'] is Timestamp ? map['receivedAt'] : (map['receivedAt'] != null ? Timestamp.fromDate(DateTime.tryParse(map['receivedAt'].toString()) ?? DateTime.now()) : null),
    closedAt: map['closedAt'] is Timestamp ? map['closedAt'] : (map['closedAt'] != null ? Timestamp.fromDate(DateTime.tryParse(map['closedAt'].toString()) ?? DateTime.now()) : null),
  );

  // Методы для изменения статуса
  Shortage markAsReceived({String? note}) {
    return copyWith(
      status: ShortageStatus.received,
      receivedAt: Timestamp.now(),
      note: note ?? this.note,
    );
  }

  Shortage markAsNotReceived({String? note}) {
    return copyWith(
      status: ShortageStatus.notReceived,
      closedAt: Timestamp.now(),
      note: note ?? this.note,
    );
  }

  // Проверки статуса
  bool get isWaiting => status == ShortageStatus.waiting;
  bool get isReceived => status == ShortageStatus.received;
  bool get isNotReceived => status == ShortageStatus.notReceived;
}
