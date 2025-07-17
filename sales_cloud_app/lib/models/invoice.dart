import 'invoice_item.dart';

class Invoice {
  final String id;
  final String outletId;
  final String outletName;
  final String salesRepId;
  final DateTime date;
  final List<InvoiceItem> items;
  final double totalAmount;

  Invoice({
    required this.id,
    required this.outletId,
    required this.outletName,
    required this.salesRepId,
    required this.date,
    required this.items,
    required this.totalAmount,
  });

  factory Invoice.fromMap(Map<String, dynamic> map, String id) {
    return Invoice(
      id: id,
      outletId: map['outletId'] ?? '',
      outletName: map['outletName'] ?? '',
      salesRepId: map['salesRepId'] ?? '',
      date: DateTime.parse(map['date']),
      items: (map['items'] as List<dynamic>?)?.map((item) => InvoiceItem.fromMap(item)).toList() ?? [],
      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'outletId': outletId,
      'outletName': outletName,
      'salesRepId': salesRepId,
      'date': date.toIso8601String(),
      'items': items.map((item) => item.toMap()).toList(),
      'totalAmount': totalAmount,
    };
  }
} 