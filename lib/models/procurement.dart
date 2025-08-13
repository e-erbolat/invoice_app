import 'package:cloud_firestore/cloud_firestore.dart';
import 'procurement_item.dart';

class ProcurementStatus {
  static const int purchase = 1; // Закуп создан
  static const int arrival = 2;  // Отправлен на приход
  static const int shortage = 3; // Недостача
  static const int forSale = 4;  // Выставка на продажу
}

class Procurement {
  final String id;
  final String sourceId; // место закупа
  final String sourceName;
  final Timestamp date;
  final List<ProcurementItem> items;
  final double totalAmount;
  final int status;

  const Procurement({
    required this.id,
    required this.sourceId,
    required this.sourceName,
    required this.date,
    required this.items,
    required this.totalAmount,
    required this.status,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'sourceId': sourceId,
    'sourceName': sourceName,
    'date': date,
    'items': items.map((e) => e.toMap()).toList(),
    'totalAmount': totalAmount,
    'status': status,
  };

  factory Procurement.fromMap(Map<String, dynamic> map) => Procurement(
    id: map['id'] ?? '',
    sourceId: map['sourceId'] ?? '',
    sourceName: map['sourceName'] ?? '',
    date: map['date'] is Timestamp ? map['date'] : Timestamp.fromDate(DateTime.tryParse(map['date'].toString()) ?? DateTime.now()),
    items: (map['items'] as List<dynamic>? ?? []).map((e) => ProcurementItem.fromMap(e as Map<String, dynamic>)).toList(),
    totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
    status: map['status'] ?? ProcurementStatus.purchase,
  );
}


