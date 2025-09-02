import 'package:cloud_firestore/cloud_firestore.dart';

enum ShortageStatus {
  waiting,      // 1. Ожидается от поставщика
  received,     // 2. Довезли (начало оприходывания)
  stocked,      // 3. Оприходовано (принять на склад)
  inStock,      // 4. Принято на склад (выставка на продажу)
  onSale,       // 5. Выставлено на продажу (архив)
  completed,    // Завершено
  notReceived,  // Не довезли (закрыто)
}

class Shortage {
  final String id;
  final String purchaseItemId;
  final String purchaseId;
  final String productId;
  final String productName;
  final int missingQty;
  final ShortageStatus status;
  final String? notes;
  final Timestamp createdAt;
  final Timestamp? receivedAt;      // Дата получения (начало оприходывания)
  final Timestamp? stockedAt;       // Дата оприходывания (принять на склад)
  final Timestamp? inStockAt;       // Дата принятия на склад (выставка на продажу)
  final Timestamp? onSaleAt;        // Дата выставки на продажу (архив)
  final Timestamp? completedAt;     // Дата завершения
  final Timestamp? closedAt;        // Дата закрытия (для notReceived)
  final String? receivedByUserId;
  final String? receivedByUserName;
  final String? stockedByUserId;    // Кто оприходовал
  final String? stockedByUserName;  // Кто оприходовал
  final String? inStockByUserId;    // Кто принял на склад
  final String? inStockByUserName;  // Кто принял на склад
  final String? onSaleByUserId;     // Кто выставил на продажу
  final String? onSaleByUserName;   // Кто выставил на продажу
  final String? completedByUserId;  // Кто завершил
  final String? completedByUserName; // Кто завершил
  final String? closedByUserId;
  final String? closedByUserName;

  const Shortage({
    required this.id,
    required this.purchaseItemId,
    required this.purchaseId,
    required this.productId,
    required this.productName,
    required this.missingQty,
    required this.status,
    this.notes,
    required this.createdAt,
    this.receivedAt,
    this.stockedAt,
    this.inStockAt,
    this.onSaleAt,
    this.completedAt,
    this.closedAt,
    this.receivedByUserId,
    this.receivedByUserName,
    this.stockedByUserId,
    this.stockedByUserName,
    this.inStockByUserId,
    this.inStockByUserName,
    this.onSaleByUserId,
    this.onSaleByUserName,
    this.completedByUserId,
    this.completedByUserName,
    this.closedByUserId,
    this.closedByUserName,
  });

  factory Shortage.create({
    required String purchaseItemId,
    required String purchaseId,
    required String productId,
    required String productName,
    required int missingQty,
    String? notes,
  }) {
    return Shortage(
      id: 'shortage_${DateTime.now().millisecondsSinceEpoch}',
      purchaseItemId: purchaseItemId,
      purchaseId: purchaseId,
      productId: productId,
      productName: productName,
      missingQty: missingQty,
      status: ShortageStatus.waiting,
      notes: notes,
      createdAt: Timestamp.now(),
    );
  }

  Shortage copyWith({
    String? id,
    String? purchaseItemId,
    String? purchaseId,
    String? productId,
    String? productName,
    int? missingQty,
    ShortageStatus? status,
    String? notes,
    Timestamp? createdAt,
    Timestamp? receivedAt,
    Timestamp? stockedAt,
    Timestamp? inStockAt,
    Timestamp? onSaleAt,
    Timestamp? completedAt,
    Timestamp? closedAt,
    String? receivedByUserId,
    String? receivedByUserName,
    String? stockedByUserId,
    String? stockedByUserName,
    String? inStockByUserId,
    String? inStockByUserName,
    String? onSaleByUserId,
    String? onSaleByUserName,
    String? completedByUserId,
    String? completedByUserName,
    String? closedByUserId,
    String? closedByUserName,
  }) {
    return Shortage(
      id: id ?? this.id,
      purchaseItemId: purchaseItemId ?? this.purchaseItemId,
      purchaseId: purchaseId ?? this.purchaseId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      missingQty: missingQty ?? this.missingQty,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      receivedAt: receivedAt ?? this.receivedAt,
      stockedAt: stockedAt ?? this.stockedAt,
      inStockAt: inStockAt ?? this.inStockAt,
      onSaleAt: onSaleAt ?? this.onSaleAt,
      completedAt: completedAt ?? this.completedAt,
      closedAt: closedAt ?? this.closedAt,
      receivedByUserId: receivedByUserId ?? this.receivedByUserId,
      receivedByUserName: receivedByUserName ?? this.receivedByUserName,
      stockedByUserId: stockedByUserId ?? this.stockedByUserId,
      stockedByUserName: stockedByUserName ?? this.stockedByUserName,
      inStockByUserId: inStockByUserId ?? this.inStockByUserId,
      inStockByUserName: inStockByUserName ?? this.inStockByUserName,
      onSaleByUserId: onSaleByUserId ?? this.onSaleByUserId,
      onSaleByUserName: onSaleByUserName ?? this.onSaleByUserName,
      completedByUserId: completedByUserId ?? this.completedByUserId,
      completedByUserName: completedByUserName ?? this.completedByUserName,
      closedByUserId: closedByUserId ?? this.closedByUserId,
      closedByUserName: closedByUserName ?? this.closedByUserName,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'purchaseItemId': purchaseItemId,
    'purchaseId': purchaseId,
    'productId': productId,
    'productName': productName,
    'missingQty': missingQty,
    'status': status.index,
    'notes': notes,
    'createdAt': createdAt,
    'receivedAt': receivedAt,
    'stockedAt': stockedAt,
    'inStockAt': inStockAt,
    'onSaleAt': onSaleAt,
    'completedAt': completedAt,
    'closedAt': closedAt,
    'receivedByUserId': receivedByUserId,
    'receivedByUserName': receivedByUserName,
    'stockedByUserId': stockedByUserId,
    'stockedByUserName': stockedByUserName,
    'inStockByUserId': inStockByUserId,
    'inStockByUserName': inStockByUserName,
    'onSaleByUserId': onSaleByUserId,
    'onSaleByUserName': onSaleByUserName,
    'completedByUserId': completedByUserId,
    'completedByUserName': completedByUserName,
    'closedByUserId': closedByUserId,
    'closedByUserName': closedByUserName,
  };

  factory Shortage.fromMap(Map<String, dynamic> map) => Shortage(
    id: map['id'] ?? '',
    purchaseItemId: map['purchaseItemId'] ?? '',
    purchaseId: map['purchaseId'] ?? '',
    productId: map['productId'] ?? '',
    productName: map['productName'] ?? '',
    missingQty: map['missingQty'] ?? 0,
    status: ShortageStatus.values[map['status'] ?? 0],
    notes: map['notes'],
    createdAt: map['createdAt'] ?? Timestamp.now(),
    receivedAt: map['receivedAt'],
    stockedAt: map['stockedAt'],
    inStockAt: map['inStockAt'],
    onSaleAt: map['onSaleAt'],
    completedAt: map['completedAt'],
    closedAt: map['closedAt'],
    receivedByUserId: map['receivedByUserId'],
    receivedByUserName: map['receivedByUserName'],
    stockedByUserId: map['stockedByUserId'],
    stockedByUserName: map['stockedByUserName'],
    inStockByUserId: map['inStockByUserId'],
    inStockByUserName: map['inStockByUserName'],
    onSaleByUserId: map['onSaleByUserId'],
    onSaleByUserName: map['onSaleByUserName'],
    completedByUserId: map['completedByUserId'],
    completedByUserName: map['completedByUserName'],
    closedByUserId: map['closedByUserId'],
    closedByUserName: map['closedByUserName'],
  );

  // Вычисляемые свойства
  bool get isWaiting => status == ShortageStatus.waiting;
  bool get isReceived => status == ShortageStatus.received;
  bool get isStocked => status == ShortageStatus.stocked;
  bool get isInStock => status == ShortageStatus.inStock;
  bool get isOnSale => status == ShortageStatus.onSale;
  bool get isCompleted => status == ShortageStatus.completed;
  bool get isNotReceived => status == ShortageStatus.notReceived;
  bool get isClosed => status == ShortageStatus.completed || status == ShortageStatus.notReceived;
  bool get isInProgress => status == ShortageStatus.received || status == ShortageStatus.stocked || status == ShortageStatus.inStock || status == ShortageStatus.onSale;

  // Статус для отображения
  String get statusDisplayName {
    switch (status) {
      case ShortageStatus.waiting:
        return 'Ожидается';
      case ShortageStatus.received:
        return 'Оприходывание';
      case ShortageStatus.stocked:
        return 'Принять на склад';
      case ShortageStatus.inStock:
        return 'Выставка на продажу';
      case ShortageStatus.onSale:
        return 'Архив заказов';
      case ShortageStatus.completed:
        return 'Завершено';
      case ShortageStatus.notReceived:
        return 'Не довезли';
    }
  }

  // Цвет статуса для UI
  int get statusColor {
    switch (status) {
      case ShortageStatus.waiting:
        return 0xFFFF9800; // Оранжевый
      case ShortageStatus.received:
        return 0xFFFF9800; // Оранжевый (оприходывание)
      case ShortageStatus.stocked:
        return 0xFF00BCD4; // Голубой (принять на склад)
      case ShortageStatus.inStock:
        return 0xFF4CAF50; // Зеленый (выставка на продажу)
      case ShortageStatus.onSale:
        return 0xFF9C27B0; // Фиолетовый (архив)
      case ShortageStatus.completed:
        return 0xFF4CAF50; // Зеленый
      case ShortageStatus.notReceived:
        return 0xFFF44336; // Красный
    }
  }

  // Методы для обновления статуса
  Shortage markAsReceived({
    required String receivedByUserId,
    required String receivedByUserName,
  }) {
    return copyWith(
      status: ShortageStatus.received,
      receivedAt: Timestamp.now(),
      receivedByUserId: receivedByUserId,
      receivedByUserName: receivedByUserName,
    );
  }

  Shortage markAsStocked({
    required String stockedByUserId,
    required String stockedByUserName,
  }) {
    return copyWith(
      status: ShortageStatus.stocked,
      stockedAt: Timestamp.now(),
      stockedByUserId: stockedByUserId,
      stockedByUserName: stockedByUserName,
    );
  }

  Shortage markAsInStock({
    required String inStockByUserId,
    required String inStockByUserName,
  }) {
    return copyWith(
      status: ShortageStatus.inStock,
      inStockAt: Timestamp.now(),
      inStockByUserId: inStockByUserId,
      inStockByUserName: inStockByUserName,
    );
  }

  Shortage markAsOnSale({
    required String onSaleByUserId,
    required String onSaleByUserName,
  }) {
    return copyWith(
      status: ShortageStatus.onSale,
      onSaleAt: Timestamp.now(),
      onSaleByUserId: onSaleByUserId,
      onSaleByUserName: onSaleByUserName,
    );
  }

  Shortage markAsCompleted({
    required String completedByUserId,
    required String completedByUserName,
  }) {
    return copyWith(
      status: ShortageStatus.completed,
      completedAt: Timestamp.now(),
      completedByUserId: completedByUserId,
      completedByUserName: completedByUserName,
    );
  }

  Shortage markAsNotReceived({
    required String closedByUserId,
    required String closedByUserName,
  }) {
    return copyWith(
      status: ShortageStatus.notReceived,
      closedAt: Timestamp.now(),
      closedByUserId: closedByUserId,
      closedByUserName: closedByUserName,
    );
  }
}
