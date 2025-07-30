import 'package:cloud_firestore/cloud_firestore.dart';
import 'invoice_item.dart';

class InvoiceStatus {
  static const int cancelled = 0;
  static const int review = 1;        // На рассмотрении
  static const int packing = 2;       // На сборке
  static const int delivery = 3;      // На доставке
  static const int delivered = 4;     // Доставлен
       // Отменен
  static const int paymentChecked = 5; // Проверка оплат
  static const int archive = 6;        // Архив накладных

  static String getName(int status) {
    switch (status) {
      case review: return 'на рассмотрении';
      case packing: return 'на сборке';
      case delivery: return 'на доставке';
      case delivered: return 'доставлен';
      case cancelled: return 'отменен';
      case paymentChecked: return 'проверка оплат';
      case archive: return 'архив';
      default: return 'неизвестно';
    }
  }
}

class Invoice {
  final String id;
  final String salesRepId;
  final String salesRepName;
  final String outletId;
  final String outletName;
  final String outletAddress;
  final Timestamp date;
  final List<InvoiceItem> items;
  final double totalAmount;
  final int status; // InvoiceStatus.review, ...
  final bool isPaid;
  final String? paymentType; // 'bank', 'cash', null
  final bool isDebt;
  final bool acceptedByAdmin;
  final bool acceptedBySuperAdmin;
  final Timestamp? acceptedAt; // Дата принятия оплаты (перехода в архив)
  final double bankAmount;
  final double cashAmount;

  Invoice({
    required this.id,
    required this.salesRepId,
    required this.salesRepName,
    required this.outletId,
    required this.outletName,
    required this.outletAddress,
    required this.date,
    required this.items,
    required this.totalAmount,
    this.status = InvoiceStatus.review,
    this.isPaid = false,
    this.paymentType,
    this.isDebt = false,
    this.acceptedByAdmin = false,
    this.acceptedBySuperAdmin = false,
    this.acceptedAt,
    this.bankAmount = 0.0,
    this.cashAmount = 0.0,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'salesRepId': salesRepId,
    'salesRepName': salesRepName,
    'outletId': outletId,
    'outletName': outletName,
    'outletAddress': outletAddress,
    'date': date,
    'items': items.map((e) => e.toMap()).toList(),
    'totalAmount': totalAmount,
    'status': status,
    'isPaid': isPaid,
    'paymentType': paymentType,
    'isDebt': isDebt,
    'acceptedByAdmin': acceptedByAdmin,
    'acceptedBySuperAdmin': acceptedBySuperAdmin,
    'acceptedAt': acceptedAt,
    'bankAmount': bankAmount,
    'cashAmount': cashAmount,
  };

  factory Invoice.fromMap(Map<String, dynamic> map) => Invoice(
    id: map['id'],
    salesRepId: map['salesRepId'],
    salesRepName: map['salesRepName'],
    outletId: map['outletId'],
    outletName: map['outletName'],
    outletAddress: map['outletAddress'] ?? '',
    date: map['date'],
    items: (map['items'] as List).map((e) => InvoiceItem.fromMap(e)).toList(),
    totalAmount: (map['totalAmount'] as num).toDouble(),
    status: map['status'] is int ? map['status'] : InvoiceStatus.review,
    isPaid: map['isPaid'] ?? false,
    paymentType: map['paymentType'],
    isDebt: map['isDebt'] ?? false,
    acceptedByAdmin: map['acceptedByAdmin'] ?? false,
    acceptedBySuperAdmin: map['acceptedBySuperAdmin'] ?? false,
    acceptedAt: map['acceptedAt'],
    bankAmount: (map['bankAmount'] ?? 0.0) is num ? (map['bankAmount'] ?? 0.0).toDouble() : 0.0,
    cashAmount: (map['cashAmount'] ?? 0.0) is num ? (map['cashAmount'] ?? 0.0).toDouble() : 0.0,
  );

  Invoice copyWith({
    String? id,
    String? salesRepId,
    String? salesRepName,
    String? outletId,
    String? outletName,
    String? outletAddress,
    Timestamp? date,
    List<InvoiceItem>? items,
    double? totalAmount,
    int? status,
    bool? isPaid,
    String? paymentType,
    bool? isDebt,
    bool? acceptedByAdmin,
    bool? acceptedBySuperAdmin,
    Timestamp? acceptedAt,
    double? bankAmount,
    double? cashAmount,
  }) => Invoice(
    id: id ?? this.id,
    salesRepId: salesRepId ?? this.salesRepId,
    salesRepName: salesRepName ?? this.salesRepName,
    outletId: outletId ?? this.outletId,
    outletName: outletName ?? this.outletName,
    outletAddress: outletAddress ?? this.outletAddress,
    date: date ?? this.date,
    items: items ?? this.items,
    totalAmount: totalAmount ?? this.totalAmount,
    status: status ?? this.status,
    isPaid: isPaid ?? this.isPaid,
    paymentType: paymentType ?? this.paymentType,
    isDebt: isDebt ?? this.isDebt,
    acceptedByAdmin: acceptedByAdmin ?? this.acceptedByAdmin,
    acceptedBySuperAdmin: acceptedBySuperAdmin ?? this.acceptedBySuperAdmin,
    acceptedAt: acceptedAt ?? this.acceptedAt,
    bankAmount: bankAmount ?? this.bankAmount,
    cashAmount: cashAmount ?? this.cashAmount,
  );
}

 