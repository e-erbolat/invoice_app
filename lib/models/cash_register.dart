import 'package:cloud_firestore/cloud_firestore.dart';

class CashRegister {
  final String id;
  final DateTime date;
  final double amount;
  final String? description;
  final String? invoiceId; // ID накладной, если это поступление от накладной

  CashRegister({
    required this.id,
    required this.date,
    required this.amount,
    this.description,
    this.invoiceId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': Timestamp.fromDate(date),
      'amount': amount,
      'description': description,
      'invoiceId': invoiceId,
    };
  }

  factory CashRegister.fromMap(Map<String, dynamic> map) {
    return CashRegister(
      id: map['id'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      amount: (map['amount'] ?? 0.0).toDouble(),
      description: map['description'],
      invoiceId: map['invoiceId'],
    );
  }

  CashRegister copyWith({
    String? id,
    DateTime? date,
    double? amount,
    String? description,
    String? invoiceId,
  }) {
    return CashRegister(
      id: id ?? this.id,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      invoiceId: invoiceId ?? this.invoiceId,
    );
  }
} 