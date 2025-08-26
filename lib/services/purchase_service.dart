import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/purchase.dart';
import '../models/purchase_item.dart';
import '../models/shortage.dart';
import '../models/purchase_log.dart';

import 'auth_service.dart';

class PurchaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // Получить все закупы
  Future<List<Purchase>> getAllPurchases() async {
    try {
      final snapshot = await _firestore
          .collection('purchases')
          .orderBy('dateCreated', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Используем ID документа Firestore
        return Purchase.fromMap(data);
      }).toList();
    } catch (e) {
      throw Exception('Ошибка получения закупов: $e');
    }
  }

  // Получить закупы по статусу
  Future<List<Purchase>> getPurchasesByStatus(PurchaseStatus status) async {
    try {
      final snapshot = await _firestore
          .collection('purchases')
          .where('status', isEqualTo: status.index)
          .orderBy('dateCreated', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Используем ID документа Firestore
        return Purchase.fromMap(data);
      }).toList();
    } catch (e) {
      throw Exception('Ошибка получения закупов по статусу: $e');
    }
  }

  // Получить закуп по ID
  Future<Purchase?> getPurchaseById(String purchaseId) async {
    try {
      final doc = await _firestore.collection('purchases').doc(purchaseId).get();
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id; // Используем ID документа Firestore
        return Purchase.fromMap(data);
      }
      return null;
    } catch (e) {
      throw Exception('Ошибка получения закупа: $e');
    }
  }

  // Создать новый закуп
  Future<String> createPurchase(Purchase purchase) async {
    try {
      final docRef = await _firestore.collection('purchases').add(purchase.toMap());
      
      // Создаем лог
      await _createPurchaseLog(
        purchaseId: docRef.id,
        action: PurchaseAction.created,
        details: 'Закуп создан',
      );
      
      return docRef.id;
    } catch (e) {
      throw Exception('Ошибка создания закупа: $e');
    }
  }

  // Обновить закуп
  Future<void> updatePurchase(Purchase purchase) async {
    try {
      debugPrint('Попытка обновления закупа с ID: ${purchase.id}');
      
      // Проверяем, существует ли документ
      final doc = await _firestore.collection('purchases').doc(purchase.id).get();
      if (!doc.exists) {
        throw Exception('Закуп с ID ${purchase.id} не найден в базе данных');
      }
      
      debugPrint('Документ найден, обновляем...');
      await _firestore.collection('purchases').doc(purchase.id).update(purchase.toMap());
      debugPrint('Закуп успешно обновлен');
    } catch (e) {
      debugPrint('Ошибка при обновлении закупа: $e');
      throw Exception('Ошибка обновления закупа: $e');
    }
  }

  // Обновить статус закупа
  Future<void> updatePurchaseStatus(String purchaseId, PurchaseStatus newStatus) async {
    try {
      final updateData = <String, dynamic>{
        'status': newStatus.index,
      };

      // Добавляем соответствующие даты
      switch (newStatus) {
        case PurchaseStatus.receiving:
          updateData['receivedAt'] = Timestamp.now();
          break;
        case PurchaseStatus.inStock:
          updateData['stockedAt'] = Timestamp.now();
          break;
        case PurchaseStatus.onSale:
          updateData['onSaleAt'] = Timestamp.now();
          break;
        case PurchaseStatus.completed:
          updateData['completedAt'] = Timestamp.now();
          break;
        case PurchaseStatus.archived:
          updateData['archivedAt'] = Timestamp.now();
          break;
        default:
          break;
      }

      await _firestore.collection('purchases').doc(purchaseId).update(updateData);
      
      // Создаем лог
      await _createPurchaseLog(
        purchaseId: purchaseId,
        action: _getActionForStatus(newStatus),
        details: 'Статус изменен на: ${newStatus.name}',
      );
    } catch (e) {
      throw Exception('Ошибка обновления статуса закупа: $e');
    }
  }

  // Приемка товаров
  Future<void> receiveItems(String purchaseId, List<PurchaseItem> receivedItems) async {
    try {
      final purchase = await getPurchaseById(purchaseId);
      if (purchase == null) throw Exception('Закуп не найден');

      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) throw Exception('Пользователь не авторизован');

      // Обновляем товары
      final updatedItems = <PurchaseItem>[];
      bool hasShortages = false;
      
      for (final item in purchase.items) {
        final receivedItem = receivedItems.firstWhere(
          (ri) => ri.productId == item.productId,
          orElse: () => item,
        );
        
        if (receivedItem.receivedQty != null) {
          final updatedItem = item.markAsReceived(
            receivedQty: receivedItem.receivedQty!,
            receivedByUserId: currentUser.uid,
            receivedByUserName: currentUser.name ?? currentUser.email,
          );
          updatedItems.add(updatedItem);
          
          if (updatedItem.hasShortage) {
            hasShortages = true;
            // Создаем запись о недостаче
            await _createShortage(updatedItem);
          }
        } else {
          updatedItems.add(item);
        }
      }

      // Обновляем закуп
      final updatedPurchase = purchase.copyWith(
        items: updatedItems,
        status: hasShortages ? PurchaseStatus.receiving : PurchaseStatus.receiving,
      );

      await updatePurchase(updatedPurchase);
      
      // Создаем лог
      await _createPurchaseLog(
        purchaseId: purchaseId,
        action: PurchaseAction.received,
        details: 'Товары приняты',
      );
      
      if (hasShortages) {
        await _createPurchaseLog(
          purchaseId: purchaseId,
          action: PurchaseAction.shortageRecorded,
          details: 'Зафиксирована недостача',
        );
      }
    } catch (e) {
      throw Exception('Ошибка приемки товаров: $e');
    }
  }

  // Оприходование товаров
  Future<void> stockItems(String purchaseId, List<String> itemIds, {bool stockAll = false}) async {
    try {
      final purchase = await getPurchaseById(purchaseId);
      if (purchase == null) throw Exception('Закуп не найден');

      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) throw Exception('Пользователь не авторизован');

      final updatedItems = <PurchaseItem>[];
      
      for (final item in purchase.items) {
        if (stockAll || itemIds.contains(item.id)) {
          if (item.isReceived && !item.isStocked) {
            updatedItems.add(item.markAsStocked());
          } else {
            updatedItems.add(item);
          }
        } else {
          updatedItems.add(item);
        }
      }

      // Проверяем, все ли полученные товары оприходованы
      final allReceivedStocked = updatedItems
          .where((item) => item.isReceived)
          .every((item) => item.isStocked);

      final newStatus = allReceivedStocked ? PurchaseStatus.inStock : PurchaseStatus.receiving;

      final updatedPurchase = purchase.copyWith(
        items: updatedItems,
        status: newStatus,
      );

      await updatePurchase(updatedPurchase);
      
      // Создаем лог
      await _createPurchaseLog(
        purchaseId: purchaseId,
        action: PurchaseAction.stocked,
        details: stockAll ? 'Все товары оприходованы' : 'Часть товаров оприходована',
      );
    } catch (e) {
      throw Exception('Ошибка оприходования товаров: $e');
    }
  }

  // Выставка товаров на продажу
  Future<void> putItemsOnSale(String purchaseId, List<String> itemIds, {bool putAllOnSale = false}) async {
    try {
      final purchase = await getPurchaseById(purchaseId);
      if (purchase == null) throw Exception('Закуп не найден');

      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) throw Exception('Пользователь не авторизован');

      final updatedItems = <PurchaseItem>[];
      
      for (final item in purchase.items) {
        if (putAllOnSale || itemIds.contains(item.id)) {
          if (item.isStocked && !item.isOnSale) {
            updatedItems.add(item.markAsOnSale());
          } else {
            updatedItems.add(item);
          }
        } else {
          updatedItems.add(item);
        }
      }

      // Проверяем, все ли оприходованные товары выставлены на продажу
      final allStockedOnSale = updatedItems
          .where((item) => item.isStocked)
          .every((item) => item.isOnSale);

      final newStatus = allStockedOnSale ? PurchaseStatus.onSale : PurchaseStatus.inStock;

      final updatedPurchase = purchase.copyWith(
        items: updatedItems,
        status: newStatus,
      );

      await updatePurchase(updatedPurchase);
      
      // Создаем лог
      await _createPurchaseLog(
        purchaseId: purchaseId,
        action: PurchaseAction.onSale,
        details: putAllOnSale ? 'Все товары выставлены на продажу' : 'Часть товаров выставлена на продажу',
      );
    } catch (e) {
      throw Exception('Ошибка выставки товаров на продажу: $e');
    }
  }

  // Работа с недостачами
  Future<void> markShortageAsReceived(String shortageId) async {
    try {
      final shortage = await _getShortageById(shortageId);
      if (shortage == null) throw Exception('Недостача не найдена');

      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) throw Exception('Пользователь не авторизован');

      final updatedShortage = shortage.markAsReceived(
        receivedByUserId: currentUser.uid,
        receivedByUserName: currentUser.name ?? currentUser.email,
      );

      await _updateShortage(updatedShortage);
      
      // Обновляем соответствующий товар в закупе
      await _updatePurchaseItemForShortage(shortage.purchaseId, shortage.purchaseItemId, updatedShortage);
      
      // Создаем лог
      await _createPurchaseLog(
        purchaseId: shortage.purchaseId,
        action: PurchaseAction.shortageReceived,
        details: 'Недостача получена: ${shortage.productName}',
      );
    } catch (e) {
      throw Exception('Ошибка отметки недостачи как полученной: $e');
    }
  }

  Future<void> markShortageAsNotReceived(String shortageId) async {
    try {
      final shortage = await _getShortageById(shortageId);
      if (shortage == null) throw Exception('Недостача не найдена');

      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) throw Exception('Пользователь не авторизован');

      final updatedShortage = shortage.markAsNotReceived(
        closedByUserId: currentUser.uid,
        closedByUserName: currentUser.name ?? currentUser.email,
      );

      await _updateShortage(updatedShortage);
      
      // Создаем лог
      await _createPurchaseLog(
        purchaseId: shortage.purchaseId,
        action: PurchaseAction.shortageNotReceived,
        details: 'Недостача не получена: ${shortage.productName}',
      );
    } catch (e) {
      throw Exception('Ошибка отметки недостачи как не полученной: $e');
    }
  }

  // Архивация закупа
  Future<void> archivePurchase(String purchaseId) async {
    try {
      final purchase = await getPurchaseById(purchaseId);
      if (purchase == null) throw Exception('Закуп не найден');

      // Проверяем, можно ли архивировать
      if (!_canArchivePurchase(purchase)) {
        throw Exception('Закуп нельзя архивировать в текущем состоянии');
      }

      await updatePurchaseStatus(purchaseId, PurchaseStatus.archived);
      
      // Создаем лог
      await _createPurchaseLog(
        purchaseId: purchaseId,
        action: PurchaseAction.archived,
        details: 'Закуп архивирован',
      );
    } catch (e) {
      throw Exception('Ошибка архивации закупа: $e');
    }
  }

  // Получить историю закупа
  Future<List<PurchaseLog>> getPurchaseHistory(String purchaseId) async {
    try {
      final snapshot = await _firestore
          .collection('purchase_logs')
          .where('purchaseId', isEqualTo: purchaseId)
          .orderBy('date', descending: true)
          .get();
      
      return snapshot.docs.map((doc) => PurchaseLog.fromMap(doc.data())).toList();
    } catch (e) {
      throw Exception('Ошибка получения истории закупа: $e');
    }
  }

  // Получить все недостачи
  Future<List<Shortage>> getAllShortages() async {
    try {
      final snapshot = await _firestore
          .collection('shortages')
          .where('status', isEqualTo: ShortageStatus.waiting.index)
          .orderBy('createdAt', descending: true)
          .get();
      
      return snapshot.docs.map((doc) => Shortage.fromMap(doc.data())).toList();
    } catch (e) {
      throw Exception('Ошибка получения недостач: $e');
    }
  }

  // Приватные методы
  Future<void> _createPurchaseLog({
    required String purchaseId,
    required PurchaseAction action,
    String? details,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) return;

      final log = PurchaseLog.create(
        purchaseId: purchaseId,
        action: action,
        userId: currentUser.uid,
        userName: currentUser.name ?? currentUser.email,
        details: details,
        metadata: metadata,
      );

      await _firestore.collection('purchase_logs').add(log.toMap());
    } catch (e) {
      // Логируем ошибку, но не прерываем основной процесс
      debugPrint('Ошибка создания лога: $e');
    }
  }

  PurchaseAction _getActionForStatus(PurchaseStatus status) {
    switch (status) {
      case PurchaseStatus.receiving:
        return PurchaseAction.received;
      case PurchaseStatus.inStock:
        return PurchaseAction.stocked;
      case PurchaseStatus.onSale:
        return PurchaseAction.onSale;
      case PurchaseStatus.completed:
        return PurchaseAction.stocked;
      case PurchaseStatus.archived:
        return PurchaseAction.archived;
      default:
        return PurchaseAction.created;
    }
  }

  Future<void> _createShortage(PurchaseItem item) async {
    try {
      if (item.missingQty == null || item.missingQty! <= 0) return;

      final shortage = Shortage.create(
        purchaseItemId: item.id,
        purchaseId: item.purchaseId,
        productId: item.productId,
        productName: item.productName,
        missingQty: item.missingQty!,
        notes: 'Автоматически создано при приемке',
      );

      await _firestore.collection('shortages').add(shortage.toMap());
    } catch (e) {
      debugPrint('Ошибка создания недостачи: $e');
    }
  }

  Future<Shortage?> _getShortageById(String shortageId) async {
    try {
      final doc = await _firestore.collection('shortages').doc(shortageId).get();
      if (doc.exists) {
        return Shortage.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Ошибка получения недостачи: $e');
    }
  }

  Future<void> _updateShortage(Shortage shortage) async {
    try {
      await _firestore.collection('shortages').doc(shortage.id).update(shortage.toMap());
    } catch (e) {
      throw Exception('Ошибка обновления недостачи: $e');
    }
  }

  Future<void> _updatePurchaseItemForShortage(String purchaseId, String itemId, Shortage shortage) async {
    try {
      final purchase = await getPurchaseById(purchaseId);
      if (purchase == null) return;

      final updatedItems = purchase.items.map((item) {
        if (item.id == itemId) {
          return item.markShortageAsReceived();
        }
        return item;
      }).toList();

      final updatedPurchase = purchase.copyWith(items: updatedItems);
      await updatePurchase(updatedPurchase);
    } catch (e) {
      debugPrint('Ошибка обновления товара закупа: $e');
    }
  }

  bool _canArchivePurchase(Purchase purchase) {
    // Закуп можно архивировать, если:
    // 1. Все товары либо получены и оприходованы, либо недостача закрыта
    // 2. Закуп не в статусе "создан"
    
    if (purchase.status == PurchaseStatus.created) return false;
    
    final allItemsProcessed = purchase.items.every((item) {
      if (item.isReceived) {
        return item.isStocked; // Полученные товары должны быть оприходованы
      } else {
        // Неполученные товары должны быть в статусе "не получены"
        return item.status == PurchaseItemStatus.shortageNotReceived;
      }
    });
    
    return allItemsProcessed;
  }
}
