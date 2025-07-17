import 'package:cloud_firestore/cloud_firestore.dart';
import 'invoice_item.dart';

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
  final String status; // 'transferred', 'delivered', 'cancelled'
  final bool isPaid;
  final String? paymentType; // 'bank', 'cash', null
  final bool isDebt;
  final bool acceptedByAdmin;
  final bool acceptedBySuperAdmin;

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
    this.status = 'transferred',
    this.isPaid = false,
    this.paymentType,
    this.isDebt = false,
    this.acceptedByAdmin = false,
    this.acceptedBySuperAdmin = false,
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
    status: map['status'] ?? 'transferred',
    isPaid: map['isPaid'] ?? false,
    paymentType: map['paymentType'],
    isDebt: map['isDebt'] ?? false,
    acceptedByAdmin: map['acceptedByAdmin'] ?? false,
    acceptedBySuperAdmin: map['acceptedBySuperAdmin'] ?? false,
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
    String? status,
    bool? isPaid,
    String? paymentType,
    bool? isDebt,
    bool? acceptedByAdmin,
    bool? acceptedBySuperAdmin,
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
  );
}

 