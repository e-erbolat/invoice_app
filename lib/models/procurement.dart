import 'package:cloud_firestore/cloud_firestore.dart';
import 'procurement_item.dart';

enum ProcurementStatus {
  created,           // Создан, ожидает приемки
  receiving,         // Идет приемка, есть принятые и/или недостающие товары
  waiting_shortages, // Закуп закрыт частично, есть недостача в ожидании
  completed,         // Все товары получены
  closed_with_shortage, // Закуп закрыт, но часть товаров так и не поступила
  archived,          // Закуп перенесен в архив
  // Старые статусы для совместимости
  purchase,          // Закуп товара
  arrival,           // Приход товара
  shortage,          // Недостача
  forSale,           // Выставка на продажу
}

class Procurement {
  final String id;
  final String sourceId;
  final String sourceName;
  final Timestamp date;
  final List<ProcurementItem> items;
  final double totalAmount;
  final int status;
  final List<String>? eventHistory; // История событий приемки
  final Timestamp? completedAt;     // Дата завершения приемки
  final Timestamp? archivedAt;      // Дата архивации

  const Procurement({
    required this.id,
    required this.sourceId,
    required this.sourceName,
    required this.date,
    required this.items,
    required this.totalAmount,
    required this.status,
    this.eventHistory,
    this.completedAt,
    this.archivedAt,
  });

  factory Procurement.create({
    required String sourceId,
    required String sourceName,
    required List<ProcurementItem> items,
  }) {
    final total = items.fold(0.0, (sum, item) => sum + item.totalPrice);
    return Procurement(
      id: 'proc_${DateTime.now().millisecondsSinceEpoch}',
      sourceId: sourceId,
      sourceName: sourceName,
      date: Timestamp.now(),
      items: items,
      totalAmount: total,
      status: ProcurementStatus.created.index,
      eventHistory: ['Закуп создан'],
    );
  }

  Procurement copyWith({
    String? id,
    String? sourceId,
    String? sourceName,
    Timestamp? date,
    List<ProcurementItem>? items,
    double? totalAmount,
    int? status,
    List<String>? eventHistory,
    Timestamp? completedAt,
    Timestamp? archivedAt,
  }) {
    return Procurement(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      sourceName: sourceName ?? this.sourceName,
      date: date ?? this.date,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      eventHistory: eventHistory ?? this.eventHistory,
      completedAt: completedAt ?? this.completedAt,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'sourceId': sourceId,
    'sourceName': sourceName,
    'date': date,
    'items': items.map((item) => item.toMap()).toList(),
    'totalAmount': totalAmount,
    'status': status,
    'eventHistory': eventHistory,
    'completedAt': completedAt,
    'archivedAt': archivedAt,
  };

  factory Procurement.fromMap(Map<String, dynamic> map) => Procurement(
    id: map['id'] ?? '',
    sourceId: map['sourceId'] ?? '',
    sourceName: map['sourceName'] ?? '',
    date: map['date'] is Timestamp ? map['date'] : Timestamp.fromDate(DateTime.tryParse(map['date'].toString()) ?? DateTime.now()),
    items: (map['items'] as List<dynamic>? ?? []).map((e) => ProcurementItem.fromMap(e as Map<String, dynamic>)).toList(),
    totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
    status: map['status'] ?? ProcurementStatus.created.index,
    eventHistory: (map['eventHistory'] as List<dynamic>?)?.cast<String>(),
    completedAt: map['completedAt'] is Timestamp ? map['completedAt'] : (map['completedAt'] != null ? Timestamp.fromDate(DateTime.tryParse(map['completedAt'].toString()) ?? DateTime.now()) : null),
    archivedAt: map['archivedAt'] is Timestamp ? map['archivedAt'] : (map['archivedAt'] != null ? Timestamp.fromDate(DateTime.tryParse(map['archivedAt'].toString()) ?? DateTime.now()) : null),
  );

  // Методы для работы со статусами
  bool get isCreated => status == ProcurementStatus.created.index;
  bool get isReceiving => status == ProcurementStatus.receiving.index;
  bool get isWaitingShortages => status == ProcurementStatus.waiting_shortages.index;
  bool get isCompleted => status == ProcurementStatus.completed.index;
  bool get isClosedWithShortage => status == ProcurementStatus.closed_with_shortage.index;
  bool get isArchived => status == ProcurementStatus.archived.index;

  // Старые статусы для совместимости
  bool get isPurchase => status == ProcurementStatus.purchase.index;
  bool get isArrival => status == ProcurementStatus.arrival.index;
  bool get isShortage => status == ProcurementStatus.shortage.index;
  bool get isForSale => status == ProcurementStatus.forSale.index;

  // Методы для изменения статуса
  Procurement markAsReceiving() {
    final newHistory = <String>[...(eventHistory ?? []), 'Начата приемка товара'];
    return copyWith(
      status: ProcurementStatus.receiving.index,
      eventHistory: newHistory,
    );
  }

  Procurement markAsWaitingShortages() {
    final newHistory = <String>[...(eventHistory ?? []), 'Закуп закрыт частично, ожидается недостача'];
    return copyWith(
      status: ProcurementStatus.waiting_shortages.index,
      eventHistory: newHistory,
    );
  }

  Procurement markAsCompleted() {
    final newHistory = <String>[...(eventHistory ?? []), 'Все товары получены, закуп завершен'];
    return copyWith(
      status: ProcurementStatus.completed.index,
      completedAt: Timestamp.now(),
      eventHistory: newHistory,
    );
  }

  Procurement markAsClosedWithShortage() {
    final newHistory = <String>[...(eventHistory ?? []), 'Закуп закрыт с недостачей'];
    return copyWith(
      status: ProcurementStatus.closed_with_shortage.index,
      completedAt: Timestamp.now(),
      eventHistory: newHistory,
    );
  }

  Procurement markAsArchived() {
    final newHistory = <String>[...(eventHistory ?? []), 'Закуп перенесен в архив'];
    return copyWith(
      status: ProcurementStatus.archived.index,
      archivedAt: Timestamp.now(),
      eventHistory: newHistory,
    );
  }

  // Добавление события в историю
  Procurement addEvent(String event) {
    final newHistory = <String>[...(eventHistory ?? []), event];
    return copyWith(eventHistory: newHistory);
  }

  // Получение статуса как строки
  String get statusString {
    switch (status) {
      case 0: return 'Создан';
      case 1: return 'Приемка';
      case 2: return 'Ожидание недостачи';
      case 3: return 'Завершен';
      case 4: return 'Закрыт с недостачей';
      case 5: return 'В архиве';
      case 6: return 'Закуп товара';
      case 7: return 'Приход товара';
      case 8: return 'Недостача';
      case 9: return 'Выставка на продажу';
      default: return 'Неизвестно';
    }
  }
}


