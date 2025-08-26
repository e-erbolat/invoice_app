import 'package:cloud_firestore/cloud_firestore.dart';

enum PurchaseAction {
  created,              // Закуп создан
  received,             // Товары получены
  shortageRecorded,     // Зафиксирована недостача
  stocked,              // Товары оприходованы
  onSale,               // Товары выставлены на продажу
  shortageReceived,     // Недостача получена
  shortageNotReceived,  // Недостача не получена
  archived,             // Закуп архивирован
}

class PurchaseLog {
  final String id;
  final String purchaseId;
  final PurchaseAction action;
  final Timestamp date;
  final String userId;
  final String userName;
  final String? details;      // Дополнительные детали действия
  final Map<String, dynamic>? metadata; // Дополнительные данные

  const PurchaseLog({
    required this.id,
    required this.purchaseId,
    required this.action,
    required this.date,
    required this.userId,
    required this.userName,
    this.details,
    this.metadata,
  });

  factory PurchaseLog.create({
    required String purchaseId,
    required PurchaseAction action,
    required String userId,
    required String userName,
    String? details,
    Map<String, dynamic>? metadata,
  }) {
    return PurchaseLog(
      id: 'log_${DateTime.now().millisecondsSinceEpoch}',
      purchaseId: purchaseId,
      action: action,
      date: Timestamp.now(),
      userId: userId,
      userName: userName,
      details: details,
      metadata: metadata,
    );
  }

  PurchaseLog copyWith({
    String? id,
    String? purchaseId,
    PurchaseAction? action,
    Timestamp? date,
    String? userId,
    String? userName,
    String? details,
    Map<String, dynamic>? metadata,
  }) {
    return PurchaseLog(
      id: id ?? this.id,
      purchaseId: purchaseId ?? this.purchaseId,
      action: action ?? this.action,
      date: date ?? this.date,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      details: details ?? this.details,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'purchaseId': purchaseId,
    'action': action.index,
    'date': date,
    'userId': userId,
    'userName': userName,
    'details': details,
    'metadata': metadata,
  };

  factory PurchaseLog.fromMap(Map<String, dynamic> map) => PurchaseLog(
    id: map['id'] ?? '',
    purchaseId: map['purchaseId'] ?? '',
    action: PurchaseAction.values[map['action'] ?? 0],
    date: map['date'] ?? Timestamp.now(),
    userId: map['userId'] ?? '',
    userName: map['userName'] ?? '',
    details: map['details'],
    metadata: map['metadata'] != null ? Map<String, dynamic>.from(map['metadata']) : null,
  );

  // Описание действия для отображения
  String get actionDisplayName {
    switch (action) {
      case PurchaseAction.created:
        return 'Закуп создан';
      case PurchaseAction.received:
        return 'Товары получены';
      case PurchaseAction.shortageRecorded:
        return 'Зафиксирована недостача';
      case PurchaseAction.stocked:
        return 'Товары оприходованы';
      case PurchaseAction.onSale:
        return 'Товары выставлены на продажу';
      case PurchaseAction.shortageReceived:
        return 'Недостача получена';
      case PurchaseAction.shortageNotReceived:
        return 'Недостача не получена';
      case PurchaseAction.archived:
        return 'Закуп архивирован';
    }
  }

  // Иконка для действия
  String get actionIcon {
    switch (action) {
      case PurchaseAction.created:
        return '📝';
      case PurchaseAction.received:
        return '📦';
      case PurchaseAction.shortageRecorded:
        return '⚠️';
      case PurchaseAction.stocked:
        return '🏪';
      case PurchaseAction.onSale:
        return '🛒';
      case PurchaseAction.shortageReceived:
        return '✅';
      case PurchaseAction.shortageNotReceived:
        return '❌';
      case PurchaseAction.archived:
        return '📁';
    }
  }

  // Цвет для действия
  int get actionColor {
    switch (action) {
      case PurchaseAction.created:
        return 0xFF2196F3; // Синий
      case PurchaseAction.received:
        return 0xFF4CAF50; // Зеленый
      case PurchaseAction.shortageRecorded:
        return 0xFFFF9800; // Оранжевый
      case PurchaseAction.stocked:
        return 0xFF4CAF50; // Зеленый
      case PurchaseAction.onSale:
        return 0xFF9C27B0; // Фиолетовый
      case PurchaseAction.shortageReceived:
        return 0xFF4CAF50; // Зеленый
      case PurchaseAction.shortageNotReceived:
        return 0xFFF44336; // Красный
      case PurchaseAction.archived:
        return 0xFF9E9E9E; // Серый
    }
  }

  // Форматированная дата
  String get formattedDate {
    final dateTime = date.toDate();
    return '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
