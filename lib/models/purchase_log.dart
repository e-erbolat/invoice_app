import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseLog {
  final String id;
  final String purchaseId;
  final String action; // 'created', 'received', 'shortage_recorded', 'stocked', 'on_sale', 'shortage_received', 'shortage_notReceived', 'archived'
  final Timestamp date;
  final String userId;
  final String userName;
  final Map<String, dynamic>? details; // Дополнительные данные о действии
  final String? notes;

  PurchaseLog({
    required this.id,
    required this.purchaseId,
    required this.action,
    required this.date,
    required this.userId,
    required this.userName,
    this.details,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purchaseId': purchaseId,
      'action': action,
      'date': date,
      'userId': userId,
      'userName': userName,
      'details': details,
      'notes': notes,
    };
  }

  factory PurchaseLog.fromMap(Map<String, dynamic> map) {
    return PurchaseLog(
      id: map['id'] ?? '',
      purchaseId: map['purchaseId'] ?? '',
      action: map['action'] ?? '',
      date: map['date'] ?? Timestamp.now(),
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      details: map['details'],
      notes: map['notes'],
    );
  }

  PurchaseLog copyWith({
    String? id,
    String? purchaseId,
    String? action,
    Timestamp? date,
    String? userId,
    String? userName,
    Map<String, dynamic>? details,
    String? notes,
  }) {
    return PurchaseLog(
      id: id ?? this.id,
      purchaseId: purchaseId ?? this.purchaseId,
      action: action ?? this.action,
      date: date ?? this.date,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      details: details ?? this.details,
      notes: notes ?? this.notes,
    );
  }

  // Статические методы для работы с действиями
  static const String actionCreated = 'created';
  static const String actionReceived = 'received';
  static const String actionShortageRecorded = 'shortage_recorded';
  static const String actionStocked = 'stocked';
  static const String actionOnSale = 'on_sale';
  static const String actionShortageReceived = 'shortage_received';
  static const String actionShortageNotReceived = 'shortage_notReceived';
  static const String actionArchived = 'archived';

  static List<String> get allActions => [
    actionCreated,
    actionReceived,
    actionShortageRecorded,
    actionStocked,
    actionOnSale,
    actionShortageReceived,
    actionShortageNotReceived,
    actionArchived,
  ];

  String get actionDisplayName {
    switch (action) {
      case actionCreated:
        return 'Создан';
      case actionReceived:
        return 'Принят';
      case actionShortageRecorded:
        return 'Зафиксирована недостача';
      case actionStocked:
        return 'Оприходован';
      case actionOnSale:
        return 'Выставлен на продажу';
      case actionShortageReceived:
        return 'Недостача получена';
      case actionShortageNotReceived:
        return 'Недостача не получена';
      case actionArchived:
        return 'Архивирован';
      default:
        return action;
    }
  }

  // Фабричные методы для создания логов различных действий
  static PurchaseLog createCreatedLog({
    required String purchaseId,
    required String userId,
    required String userName,
    String? notes,
  }) {
    return PurchaseLog(
      id: '', // Будет установлен при сохранении
      purchaseId: purchaseId,
      action: actionCreated,
      date: Timestamp.now(),
      userId: userId,
      userName: userName,
      notes: notes,
    );
  }

  static PurchaseLog createReceivedLog({
    required String purchaseId,
    required String userId,
    required String userName,
    required Map<String, dynamic> receivingDetails,
    String? notes,
  }) {
    return PurchaseLog(
      id: '',
      purchaseId: purchaseId,
      action: actionReceived,
      date: Timestamp.now(),
      userId: userId,
      userName: userName,
      details: receivingDetails,
      notes: notes,
    );
  }

  static PurchaseLog createStockedLog({
    required String purchaseId,
    required String userId,
    required String userName,
    required Map<String, dynamic> stockingDetails,
    String? notes,
  }) {
    return PurchaseLog(
      id: '',
      purchaseId: purchaseId,
      action: actionStocked,
      date: Timestamp.now(),
      userId: userId,
      userName: userName,
      details: stockingDetails,
      notes: notes,
    );
  }

  static PurchaseLog createOnSaleLog({
    required String purchaseId,
    required String userId,
    required String userName,
    required Map<String, dynamic> saleDetails,
    String? notes,
  }) {
    return PurchaseLog(
      id: '',
      purchaseId: purchaseId,
      action: actionOnSale,
      date: Timestamp.now(),
      userId: userId,
      userName: userName,
      details: saleDetails,
      notes: notes,
    );
  }
}