import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/shortage.dart';
import '../models/purchase_item.dart';
import '../models/purchase.dart';

class ShortageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Создание недостачи
  Future<void> createShortage(Shortage shortage) async {
    await _firestore.collection('shortages').doc(shortage.id).set(shortage.toMap());
  }

  // Получение всех недостач с оптимизацией
  Future<List<Shortage>> getAllShortages() async {
    try {
      final snapshot = await _firestore
          .collection('shortages')
          .orderBy('createdAt', descending: true) // Сортируем по дате создания
          .limit(1000) // Ограничиваем количество для производительности
          .get();
      
      return snapshot.docs.map((doc) => Shortage.fromMap(doc.data())).toList();
    } catch (e) {
      print('[ShortageService] Ошибка получения всех недостач: $e');
      return [];
    }
  }

  // Получение недостач по ID закупа с оптимизацией
  Future<List<Shortage>> getShortagesByPurchaseId(String purchaseId) async {
    try {
      final snapshot = await _firestore
          .collection('shortages')
          .where('purchaseId', isEqualTo: purchaseId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => Shortage.fromMap(doc.data())).toList();
    } catch (e) {
      print('[ShortageService] Ошибка получения недостач по ID закупа: $e');
      return [];
    }
  }

  // Получение недостач по статусу с оптимизацией
  Future<List<Shortage>> getShortagesByStatus(ShortageStatus status) async {
    try {
      final snapshot = await _firestore
          .collection('shortages')
          .where('status', isEqualTo: status.index)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => Shortage.fromMap(doc.data())).toList();
    } catch (e) {
      print('[ShortageService] Ошибка получения недостач по статусу: $e');
      return [];
    }
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

  // Отметить недостачу как оприходованную
  Future<void> markShortageAsStocked(String shortageId, {String? userId, String? userName}) async {
    final doc = await _firestore.collection('shortages').doc(shortageId).get();
    if (doc.exists) {
      final shortage = Shortage.fromMap(doc.data()!);
      final updatedShortage = shortage.markAsStocked(
        stockedByUserId: userId ?? '',
        stockedByUserName: userName ?? '',
      );
      await updateShortage(updatedShortage);
    }
  }

  // Отметить недостачу как принятую на склад
  Future<void> markShortageAsInStock(String shortageId, {String? userId, String? userName}) async {
    final doc = await _firestore.collection('shortages').doc(shortageId).get();
    if (doc.exists) {
      final shortage = Shortage.fromMap(doc.data()!);
      final updatedShortage = shortage.markAsInStock(
        inStockByUserId: userId ?? '',
        inStockByUserName: userName ?? '',
      );
      await updateShortage(updatedShortage);
    }
  }

  // Отметить недостачу как выставленную на продажу
  Future<void> markShortageAsOnSale(String shortageId, {String? userId, String? userName}) async {
    final doc = await _firestore.collection('shortages').doc(shortageId).get();
    if (doc.exists) {
      final shortage = Shortage.fromMap(doc.data()!);
      final updatedShortage = shortage.markAsOnSale(
        onSaleByUserId: userId ?? '',
        onSaleByUserName: userName ?? '',
      );
      await updateShortage(updatedShortage);
    }
  }

  // Отметить недостачу как завершенную
  Future<void> markShortageAsCompleted(String shortageId, {String? userId, String? userName}) async {
    final doc = await _firestore.collection('shortages').doc(shortageId).get();
    if (doc.exists) {
      final shortage = Shortage.fromMap(doc.data()!);
      final updatedShortage = shortage.markAsCompleted(
        completedByUserId: userId ?? '',
        completedByUserName: userName ?? '',
      );
      await updateShortage(updatedShortage);
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

  // Удаление дублирующихся недостач для закупа (оптимизированная версия)
  Future<void> removeDuplicateShortages(String purchaseId) async {
    try {
      final shortages = await getShortagesByPurchaseId(purchaseId);
      
      if (shortages.length <= 1) return; // Нет дубликатов
      
      // Группируем недостачи по purchaseItemId
      final groupedShortages = <String, List<Shortage>>{};
      for (final shortage in shortages) {
        groupedShortages.putIfAbsent(shortage.purchaseItemId, () => []).add(shortage);
      }
      
      // Собираем ID для удаления
      final idsToDelete = <String>[];
      for (final entry in groupedShortages.entries) {
        final itemShortages = entry.value;
        if (itemShortages.length > 1) {
          // Оставляем первую недостачу, помечаем остальные для удаления
          for (int i = 1; i < itemShortages.length; i++) {
            idsToDelete.add(itemShortages[i].id);
          }
        }
      }
      
      // Удаляем дубликаты пакетно
      if (idsToDelete.isNotEmpty) {
        print('[ShortageService] Удаляем ${idsToDelete.length} дубликатов для закупа $purchaseId');
        for (final id in idsToDelete) {
          await deleteShortage(id);
        }
      }
    } catch (e) {
      print('[ShortageService] Ошибка удаления дубликатов: $e');
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
