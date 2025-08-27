import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shortage.dart';
import '../models/purchase_item.dart';
import '../models/purchase.dart';

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
  Future<void> markShortageAsReceived(String shortageId, {String? userId, String? userName}) async {
    final doc = await _firestore.collection('shortages').doc(shortageId).get();
    if (doc.exists) {
      final shortage = Shortage.fromMap(doc.data()!);
      final updatedShortage = shortage.markAsReceived(
        receivedByUserId: userId ?? '',
        receivedByUserName: userName ?? '',
      );
      await updateShortage(updatedShortage);
      
      // Обновляем соответствующий товар в закупе
      await _updatePurchaseItemForShortage(shortage.purchaseId, shortage.purchaseItemId, updatedShortage);
    }
  }

  // Отметить недостачу как не полученную
  Future<void> markShortageAsNotReceived(String shortageId, {String? userId, String? userName}) async {
    final doc = await _firestore.collection('shortages').doc(shortageId).get();
    if (doc.exists) {
      final shortage = Shortage.fromMap(doc.data()!);
      final updatedShortage = shortage.markAsNotReceived(
        closedByUserId: userId ?? '',
        closedByUserName: userName ?? '',
      );
      await updateShortage(updatedShortage);
      
      // Обновляем соответствующий товар в закупе
      await _updatePurchaseItemForShortageNotReceived(shortage.purchaseId, shortage.purchaseItemId, updatedShortage);
    }
  }

  // Удаление недостачи
  Future<void> deleteShortage(String shortageId) async {
    await _firestore.collection('shortages').doc(shortageId).delete();
  }

  // Создание недостач из позиций закупа
  Future<List<Shortage>> createShortagesFromItems(
    String purchaseId,
    List<PurchaseItem> items,
  ) async {
    final shortages = <Shortage>[];
    
    // Сначала удаляем все существующие недостачи для этого закупа
    await removeAllShortagesForPurchase(purchaseId);
    
    // Создаем новые недостачи на основе актуальных данных
    for (final item in items) {
      if (item.hasShortage) {
        final missingQty = item.missingQty ?? 0;
        
        // Создаем новую недостачу
        final shortage = Shortage.create(
          purchaseItemId: item.id,
          purchaseId: purchaseId,
          productId: item.productId,
          productName: item.productName,
          missingQty: missingQty,
          notes: item.notes,
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
        .fold(0, (total, s) => total + s.missingQty);
    
    return {
      'waiting': waiting,
      'received': received,
      'notReceived': notReceived,
      'totalMissingQty': totalMissingQty,
    };
  }

  // Удаление дублирующихся недостач для закупа
  Future<void> removeDuplicateShortages(String purchaseId) async {
    final shortages = await getShortagesByPurchaseId(purchaseId);
    
    // Группируем недостачи по purchaseItemId
    final groupedShortages = <String, List<Shortage>>{};
    for (final shortage in shortages) {
      groupedShortages.putIfAbsent(shortage.purchaseItemId, () => []).add(shortage);
    }
    
    // Удаляем дубликаты, оставляя только первую недостачу для каждой позиции
    for (final entry in groupedShortages.entries) {
      final itemShortages = entry.value;
      if (itemShortages.length > 1) {
        // Оставляем первую недостачу, удаляем остальные
        for (int i = 1; i < itemShortages.length; i++) {
          await deleteShortage(itemShortages[i].id);
        }
      }
    }
  }

  // Удаление всех недостач для закупа
  Future<void> removeAllShortagesForPurchase(String purchaseId) async {
    final shortages = await getShortagesByPurchaseId(purchaseId);
    for (final shortage in shortages) {
      await deleteShortage(shortage.id);
    }
  }

  // Приватный метод для обновления товара в закупе при получении недостачи
  Future<void> _updatePurchaseItemForShortage(String purchaseId, String itemId, Shortage shortage) async {
    try {
      // Получаем закуп
      final purchaseDoc = await _firestore.collection('purchases').doc(purchaseId).get();
      if (!purchaseDoc.exists) return;

      final purchase = Purchase.fromMap(purchaseDoc.data()!);
      
      // Обновляем товар
      final updatedItems = purchase.items.map((item) {
        if (item.id == itemId) {
          return item.markShortageAsReceived();
        }
        return item;
      }).toList();

      final updatedPurchase = purchase.copyWith(items: updatedItems);
      
      // Сохраняем обновленный закуп
      await _firestore.collection('purchases').doc(purchaseId).update(updatedPurchase.toMap());
    } catch (e) {
      print('Ошибка обновления товара закупа: $e');
    }
  }

  // Приватный метод для обновления товара в закупе при отказе от недостачи
  Future<void> _updatePurchaseItemForShortageNotReceived(String purchaseId, String itemId, Shortage shortage) async {
    try {
      // Получаем закуп
      final purchaseDoc = await _firestore.collection('purchases').doc(purchaseId).get();
      if (!purchaseDoc.exists) return;

      final purchase = Purchase.fromMap(purchaseDoc.data()!);
      
      // Обновляем товар
      final updatedItems = purchase.items.map((item) {
        if (item.id == itemId) {
          return item.markShortageAsNotReceived();
        }
        return item;
      }).toList();

      final updatedPurchase = purchase.copyWith(items: updatedItems);
      
      // Сохраняем обновленный закуп
      await _firestore.collection('purchases').doc(purchaseId).update(updatedPurchase.toMap());
    } catch (e) {
      print('Ошибка обновления товара закупа: $e');
    }
  }
}
