import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseItem {
  final String id;
  final String purchaseId;
  final String productId;
  final String productName;
  final String productBarcode;
  final double unitPrice;
  final int orderedQty;
  final int receivedQty;
  final int missingQty;
  final String status; // 'ordered', 'received', 'in_stock', 'on_sale', 'shortage_waiting', 'shortage_received', 'shortage_notReceived'
  final Timestamp? receivedDate;
  final Timestamp? stockedDate;
  final Timestamp? onSaleDate;

  PurchaseItem({
    required this.id,
    required this.purchaseId,
    required this.productId,
    required this.productName,
    required this.productBarcode,
    required this.unitPrice,
    required this.orderedQty,
    this.receivedQty = 0,
    this.missingQty = 0,
    this.status = 'ordered',
    this.receivedDate,
    this.stockedDate,
    this.onSaleDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purchaseId': purchaseId,
      'productId': productId,
      'productName': productName,
      'productBarcode': productBarcode,
      'unitPrice': unitPrice,
      'orderedQty': orderedQty,
      'receivedQty': receivedQty,
      'missingQty': missingQty,
      'status': status,
      'receivedDate': receivedDate,
      'stockedDate': stockedDate,
      'onSaleDate': onSaleDate,
    };
  }

  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    return PurchaseItem(
      id: map['id'] ?? '',
      purchaseId: map['purchaseId'] ?? '',
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      productBarcode: map['productBarcode'] ?? '',
      unitPrice: (map['unitPrice'] ?? 0.0).toDouble(),
      orderedQty: map['orderedQty'] ?? 0,
      receivedQty: map['receivedQty'] ?? 0,
      missingQty: map['missingQty'] ?? 0,
      status: map['status'] ?? 'ordered',
      receivedDate: map['receivedDate'],
      stockedDate: map['stockedDate'],
      onSaleDate: map['onSaleDate'],
    );
  }

  PurchaseItem copyWith({
    String? id,
    String? purchaseId,
    String? productId,
    String? productName,
    String? productBarcode,
    double? unitPrice,
    int? orderedQty,
    int? receivedQty,
    int? missingQty,
    String? status,
    Timestamp? receivedDate,
    Timestamp? stockedDate,
    Timestamp? onSaleDate,
  }) {
    return PurchaseItem(
      id: id ?? this.id,
      purchaseId: purchaseId ?? this.purchaseId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productBarcode: productBarcode ?? this.productBarcode,
      unitPrice: unitPrice ?? this.unitPrice,
      orderedQty: orderedQty ?? this.orderedQty,
      receivedQty: receivedQty ?? this.receivedQty,
      missingQty: missingQty ?? this.missingQty,
      status: status ?? this.status,
      receivedDate: receivedDate ?? this.receivedDate,
      stockedDate: stockedDate ?? this.stockedDate,
      onSaleDate: onSaleDate ?? this.onSaleDate,
    );
  }

  // Статические методы для работы со статусами
  static const String statusOrdered = 'ordered';
  static const String statusReceived = 'received';
  static const String statusInStock = 'in_stock';
  static const String statusOnSale = 'on_sale';
  static const String statusShortageWaiting = 'shortage_waiting';
  static const String statusShortageReceived = 'shortage_received';
  static const String statusShortageNotReceived = 'shortage_notReceived';

  static List<String> get allStatuses => [
    statusOrdered,
    statusReceived,
    statusInStock,
    statusOnSale,
    statusShortageWaiting,
    statusShortageReceived,
    statusShortageNotReceived,
  ];

  String get statusDisplayName {
    switch (status) {
      case statusOrdered:
        return 'Заказано';
      case statusReceived:
        return 'Принято';
      case statusInStock:
        return 'На складе';
      case statusOnSale:
        return 'В продаже';
      case statusShortageWaiting:
        return 'Ожидается недостача';
      case statusShortageReceived:
        return 'Недостача получена';
      case statusShortageNotReceived:
        return 'Недостача не получена';
      default:
        return status;
    }
  }

  // Вычисляемые поля
  double get totalOrderedAmount => orderedQty * unitPrice;
  double get totalReceivedAmount => receivedQty * unitPrice;
  double get totalMissingAmount => missingQty * unitPrice;
  
  bool get hasShortage => missingQty > 0;
  bool get isFullyReceived => receivedQty == orderedQty;
}