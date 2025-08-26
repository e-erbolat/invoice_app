import 'package:cloud_firestore/cloud_firestore.dart';

enum ShortageStatus {
  waiting,      // Ожидается от поставщика
  received,     // Довезли
  notReceived,  // Не довезли
}

class Shortage {
  final String id;
  final String purchaseItemId;
  final String purchaseId;
  final String productId;
  final String productName;
  final int missingQty;
  final ShortageStatus status;
  final String? notes;
  final Timestamp createdAt;
  final Timestamp? receivedAt;
  final Timestamp? closedAt;
  final String? receivedByUserId;
  final String? receivedByUserName;
  final String? closedByUserId;
  final String? closedByUserName;

  const Shortage({
    required this.id,
    required this.purchaseItemId,
    required this.purchaseId,
    required this.productId,
    required this.productName,
    required this.missingQty,
    required this.status,
    this.notes,
    required this.createdAt,
    this.receivedAt,
    this.closedAt,
    this.receivedByUserId,
    this.receivedByUserName,
    this.closedByUserId,
    this.closedByUserName,
  });

  factory Shortage.create({
    required String purchaseItemId,
    required String purchaseId,
    required String productId,
    required String productName,
    required int missingQty,
    String? notes,
  }) {
    return Shortage(
      id: 'shortage_${DateTime.now().millisecondsSinceEpoch}',
      purchaseItemId: purchaseItemId,
      purchaseId: purchaseId,
      productId: productId,
      productName: productName,
      missingQty: missingQty,
      status: ShortageStatus.waiting,
      notes: notes,
      createdAt: Timestamp.now(),
    );
  }

  Shortage copyWith({
    String? id,
    String? purchaseItemId,
    String? purchaseId,
    String? productId,
    String? productName,
    int? missingQty,
    ShortageStatus? status,
    String? notes,
    Timestamp? createdAt,
    Timestamp? receivedAt,
    Timestamp? closedAt,
    String? receivedByUserId,
    String? receivedByUserName,
    String? closedByUserId,
    String? closedByUserName,
  }) {
    return Shortage(
      id: id ?? this.id,
      purchaseItemId: purchaseItemId ?? this.purchaseItemId,
      purchaseId: purchaseId ?? this.purchaseId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      missingQty: missingQty ?? this.missingQty,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      receivedAt: receivedAt ?? this.receivedAt,
      closedAt: closedAt ?? this.closedAt,
      receivedByUserId: receivedByUserId ?? this.receivedByUserId,
      receivedByUserName: receivedByUserName ?? this.receivedByUserName,
      closedByUserId: closedByUserId ?? this.closedByUserId,
      closedByUserName: closedByUserName ?? this.closedByUserName,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'purchaseItemId': purchaseItemId,
    'purchaseId': purchaseId,
    'productId': productId,
    'productName': productName,
    'missingQty': missingQty,
    'status': status.index,
    'notes': notes,
    'createdAt': createdAt,
    'receivedAt': receivedAt,
    'closedAt': closedAt,
    'receivedByUserId': receivedByUserId,
    'receivedByUserName': receivedByUserName,
    'closedByUserId': closedByUserId,
    'closedByUserName': closedByUserName,
  };

  factory Shortage.fromMap(Map<String, dynamic> map) => Shortage(
    id: map['id'] ?? '',
    purchaseItemId: map['purchaseItemId'] ?? '',
    purchaseId: map['purchaseId'] ?? '',
    productId: map['productId'] ?? '',
    productName: map['productName'] ?? '',
    missingQty: map['missingQty'] ?? 0,
    status: ShortageStatus.values[map['status'] ?? 0],
    notes: map['notes'],
    createdAt: map['createdAt'] ?? Timestamp.now(),
    receivedAt: map['receivedAt'],
    closedAt: map['closedAt'],
    receivedByUserId: map['receivedByUserId'],
    receivedByUserName: map['receivedByUserName'],
    closedByUserId: map['closedByUserId'],
    closedByUserName: map['closedByUserName'],
  );

  // Вычисляемые свойства
  bool get isWaiting => status == ShortageStatus.waiting;
  bool get isReceived => status == ShortageStatus.received;
  bool get isNotReceived => status == ShortageStatus.notReceived;
  bool get isClosed => status == ShortageStatus.received || status == ShortageStatus.notReceived;

  // Статус для отображения
  String get statusDisplayName {
    switch (status) {
      case ShortageStatus.waiting:
        return 'Ожидается';
      case ShortageStatus.received:
        return 'Довезли';
      case ShortageStatus.notReceived:
        return 'Не довезли';
    }
  }

  // Цвет статуса для UI
  int get statusColor {
    switch (status) {
      case ShortageStatus.waiting:
        return 0xFFFF9800; // Оранжевый
      case ShortageStatus.received:
        return 0xFF4CAF50; // Зеленый
      case ShortageStatus.notReceived:
        return 0xFFF44336; // Красный
    }
  }

  // Методы для обновления статуса
  Shortage markAsReceived({
    required String receivedByUserId,
    required String receivedByUserName,
  }) {
    return copyWith(
      status: ShortageStatus.received,
      receivedAt: Timestamp.now(),
      receivedByUserId: receivedByUserId,
      receivedByUserName: receivedByUserName,
    );
  }

  Shortage markAsNotReceived({
    required String closedByUserId,
    required String closedByUserName,
  }) {
    return copyWith(
      status: ShortageStatus.notReceived,
      closedAt: Timestamp.now(),
      closedByUserId: closedByUserId,
      closedByUserName: closedByUserName,
    );
  }
}
