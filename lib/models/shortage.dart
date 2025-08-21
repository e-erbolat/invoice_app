import 'package:cloud_firestore/cloud_firestore.dart';

class Shortage {
  final String id;
  final String purchaseItemId;
  final String purchaseId;
  final String productId;
  final String productName;
  final String productBarcode;
  final int missingQty;
  final double unitPrice;
  final String status; // 'waiting', 'received', 'notReceived'
  final Timestamp dateCreated;
  final Timestamp? dateClosed;
  final String? closedByUserId;
  final String? notes;

  Shortage({
    required this.id,
    required this.purchaseItemId,
    required this.purchaseId,
    required this.productId,
    required this.productName,
    required this.productBarcode,
    required this.missingQty,
    required this.unitPrice,
    this.status = 'waiting',
    required this.dateCreated,
    this.dateClosed,
    this.closedByUserId,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purchaseItemId': purchaseItemId,
      'purchaseId': purchaseId,
      'productId': productId,
      'productName': productName,
      'productBarcode': productBarcode,
      'missingQty': missingQty,
      'unitPrice': unitPrice,
      'status': status,
      'dateCreated': dateCreated,
      'dateClosed': dateClosed,
      'closedByUserId': closedByUserId,
      'notes': notes,
    };
  }

  factory Shortage.fromMap(Map<String, dynamic> map) {
    return Shortage(
      id: map['id'] ?? '',
      purchaseItemId: map['purchaseItemId'] ?? '',
      purchaseId: map['purchaseId'] ?? '',
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      productBarcode: map['productBarcode'] ?? '',
      missingQty: map['missingQty'] ?? 0,
      unitPrice: (map['unitPrice'] ?? 0.0).toDouble(),
      status: map['status'] ?? 'waiting',
      dateCreated: map['dateCreated'] ?? Timestamp.now(),
      dateClosed: map['dateClosed'],
      closedByUserId: map['closedByUserId'],
      notes: map['notes'],
    );
  }

  Shortage copyWith({
    String? id,
    String? purchaseItemId,
    String? purchaseId,
    String? productId,
    String? productName,
    String? productBarcode,
    int? missingQty,
    double? unitPrice,
    String? status,
    Timestamp? dateCreated,
    Timestamp? dateClosed,
    String? closedByUserId,
    String? notes,
  }) {
    return Shortage(
      id: id ?? this.id,
      purchaseItemId: purchaseItemId ?? this.purchaseItemId,
      purchaseId: purchaseId ?? this.purchaseId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productBarcode: productBarcode ?? this.productBarcode,
      missingQty: missingQty ?? this.missingQty,
      unitPrice: unitPrice ?? this.unitPrice,
      status: status ?? this.status,
      dateCreated: dateCreated ?? this.dateCreated,
      dateClosed: dateClosed ?? this.dateClosed,
      closedByUserId: closedByUserId ?? this.closedByUserId,
      notes: notes ?? this.notes,
    );
  }

  // Статические методы для работы со статусами
  static const String statusWaiting = 'waiting';
  static const String statusReceived = 'received';
  static const String statusNotReceived = 'notReceived';

  static List<String> get allStatuses => [
    statusWaiting,
    statusReceived,
    statusNotReceived,
  ];

  String get statusDisplayName {
    switch (status) {
      case statusWaiting:
        return 'Ожидается';
      case statusReceived:
        return 'Получено';
      case statusNotReceived:
        return 'Не получено';
      default:
        return status;
    }
  }

  // Вычисляемые поля
  double get totalMissingAmount => missingQty * unitPrice;
  bool get isOpen => status == statusWaiting;
  bool get isClosed => status == statusReceived || status == statusNotReceived;
}