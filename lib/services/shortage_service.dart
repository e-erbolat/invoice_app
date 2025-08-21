import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shortage.dart';
import '../models/procurement_item.dart';

class ShortageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Создание недостачи
  Future<void> createShortage(Shortage shortage) async {
    await _firestore.collection('shortages').doc(shortage.id).set(shortage.toMap());
  }

  // Получение всех недостач
  Future<List<Shortage>> getAllShortages() async {
    final snapshot = await _firestore.collection('shortages').get();
    return snapshot.docs.map((doc) => Shortage.fromMap(doc.data())).toList();
  }

  // Получение недостач по ID закупа
  Future<List<Shortage>> getShortagesByPurchaseId(String purchaseId) async {
    final snapshot = await _firestore
        .collection('shortages')
        .where('purchaseId', isEqualTo: purchaseId)
        .get();
    return snapshot.docs.map((doc) => Shortage.fromMap(doc.data())).toList();
  }

  // Получение недостач по статусу
  Future<List<Shortage>> getShortagesByStatus(ShortageStatus status) async {
    final snapshot = await _firestore
        .collection('shortages')
        .where('status', isEqualTo: status.index)
        .get();
    return snapshot.docs.map((doc) => Shortage.fromMap(doc.data())).toList();
  }

  // Получение ожидаемых недостач (waiting)
  Future<List<Shortage>> getWaitingShortages() async {
    return getShortagesByStatus(ShortageStatus.waiting);
  }

  // Обновление недостачи
  Future<void> updateShortage(Shortage shortage) async {
    await _firestore.collection('shortages').doc(shortage.id).update(shortage.toMap());
  }

  // Отметить недостачу как полученную
  Future<void> markShortageAsReceived(String shortageId, {String? note}) async {
    final doc = await _firestore.collection('shortages').doc(shortageId).get();
    if (doc.exists) {
      final shortage = Shortage.fromMap(doc.data()!);
      final updatedShortage = shortage.markAsReceived(note: note);
      await updateShortage(updatedShortage);
    }
  }

  // Отметить недостачу как не полученную
  Future<void> markShortageAsNotReceived(String shortageId, {String? note}) async {
    final doc = await _firestore.collection('shortages').doc(shortageId).get();
    if (doc.exists) {
      final shortage = Shortage.fromMap(doc.data()!);
      final updatedShortage = shortage.markAsNotReceived(note: note);
      await updateShortage(updatedShortage);
    }
  }

  // Удаление недостачи
  Future<void> deleteShortage(String shortageId) async {
    await _firestore.collection('shortages').doc(shortageId).delete();
  }

  // Создание недостач из позиций закупа
  Future<List<Shortage>> createShortagesFromItems(
    String purchaseId,
    List<ProcurementItem> items,
  ) async {
    final shortages = <Shortage>[];
    
    for (final item in items) {
      if (item.hasShortage) {
        final shortage = Shortage.create(
          purchaseId: purchaseId,
          itemId: item.productId,
          productId: item.productId,
          productName: item.productName,
          orderedQty: item.quantity,
          missingQty: item.calculatedMissingQty,
          purchasePrice: item.purchasePrice,
          note: item.note,
        );
        shortages.add(shortage);
        await createShortage(shortage);
      }
    }
    
    return shortages;
  }

  // Получение статистики по недостачам
  Future<Map<String, dynamic>> getShortageStatistics() async {
    final allShortages = await getAllShortages();
    
    final waiting = allShortages.where((s) => s.isWaiting).length;
    final received = allShortages.where((s) => s.isReceived).length;
    final notReceived = allShortages.where((s) => s.isNotReceived).length;
    
    final totalMissingQty = allShortages
        .where((s) => s.isWaiting)
        .fold(0, (sum, s) => sum + s.missingQty);
    
    return {
      'waiting': waiting,
      'received': received,
      'notReceived': notReceived,
      'totalMissingQty': totalMissingQty,
    };
  }
}
