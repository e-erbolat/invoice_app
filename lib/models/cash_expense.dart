import 'package:cloud_firestore/cloud_firestore.dart';

enum CashExpenseStatus {
  pending(0, 'Ожидает подтверждения'),
  approved(1, 'Подтверждено'),
  rejected(2, 'Отклонено');

  const CashExpenseStatus(this.value, this.name);
  final int value;
  final String name;

  static CashExpenseStatus fromValue(int value) {
    return CashExpenseStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => CashExpenseStatus.pending,
    );
  }
}

class CashExpense {
  final String id;
  final DateTime date;
  final double amount;
  final String description;
  final CashExpenseStatus status;
  final String createdBy; // ID пользователя, создавшего расход
  final String? approvedBy; // ID суперадмина, подтвердившего расход
  final DateTime? approvedAt; // Дата подтверждения
  final String? rejectReason; // Причина отклонения

  CashExpense({
    required this.id,
    required this.date,
    required this.amount,
    required this.description,
    required this.status,
    required this.createdBy,
    this.approvedBy,
    this.approvedAt,
    this.rejectReason,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': Timestamp.fromDate(date),
      'amount': amount,
      'description': description,
      'status': status.value,
      'createdBy': createdBy,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'rejectReason': rejectReason,
    };
  }

  factory CashExpense.fromMap(Map<String, dynamic> map) {
    return CashExpense(
      id: map['id'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      amount: (map['amount'] ?? 0.0).toDouble(),
      description: map['description'] ?? '',
      status: CashExpenseStatus.fromValue(map['status'] ?? 0),
      createdBy: map['createdBy'] ?? '',
      approvedBy: map['approvedBy'],
      approvedAt: map['approvedAt'] != null ? (map['approvedAt'] as Timestamp).toDate() : null,
      rejectReason: map['rejectReason'],
    );
  }

  CashExpense copyWith({
    String? id,
    DateTime? date,
    double? amount,
    String? description,
    CashExpenseStatus? status,
    String? createdBy,
    String? approvedBy,
    DateTime? approvedAt,
    String? rejectReason,
  }) {
    return CashExpense(
      id: id ?? this.id,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectReason: rejectReason ?? this.rejectReason,
    );
  }
} 