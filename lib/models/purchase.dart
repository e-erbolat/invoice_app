import 'package:cloud_firestore/cloud_firestore.dart';

class Purchase {
  final String id;
  final String supplierId;
  final String supplierName;
  final Timestamp dateCreated;
  final String status; // 'created', 'receiving', 'in_stock', 'on_sale', 'completed', 'closed_with_shortage', 'archived'
  final double totalAmount;
  final String createdByUserId;
  final String? notes;

  Purchase({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.dateCreated,
    required this.status,
    required this.totalAmount,
    required this.createdByUserId,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'dateCreated': dateCreated,
      'status': status,
      'totalAmount': totalAmount,
      'createdByUserId': createdByUserId,
      'notes': notes,
    };
  }

  factory Purchase.fromMap(Map<String, dynamic> map) {
    return Purchase(
      id: map['id'] ?? '',
      supplierId: map['supplierId'] ?? '',
      supplierName: map['supplierName'] ?? '',
      dateCreated: map['dateCreated'] ?? Timestamp.now(),
      status: map['status'] ?? 'created',
      totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
      createdByUserId: map['createdByUserId'] ?? '',
      notes: map['notes'],
    );
  }

  Purchase copyWith({
    String? id,
    String? supplierId,
    String? supplierName,
    Timestamp? dateCreated,
    String? status,
    double? totalAmount,
    String? createdByUserId,
    String? notes,
  }) {
    return Purchase(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      dateCreated: dateCreated ?? this.dateCreated,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      notes: notes ?? this.notes,
    );
  }

  // Статические методы для работы со статусами
  static const String statusCreated = 'created';
  static const String statusReceiving = 'receiving';
  static const String statusInStock = 'in_stock';
  static const String statusOnSale = 'on_sale';
  static const String statusCompleted = 'completed';
  static const String statusClosedWithShortage = 'closed_with_shortage';
  static const String statusArchived = 'archived';

  static List<String> get allStatuses => [
    statusCreated,
    statusReceiving,
    statusInStock,
    statusOnSale,
    statusCompleted,
    statusClosedWithShortage,
    statusArchived,
  ];

  String get statusDisplayName {
    switch (status) {
      case statusCreated:
        return 'Создан';
      case statusReceiving:
        return 'Приемка';
      case statusInStock:
        return 'На складе';
      case statusOnSale:
        return 'В продаже';
      case statusCompleted:
        return 'Завершен';
      case statusClosedWithShortage:
        return 'Закрыт с недостачей';
      case statusArchived:
        return 'В архиве';
      default:
        return status;
    }
  }
}