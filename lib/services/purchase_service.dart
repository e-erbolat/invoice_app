import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/purchase.dart';
import '../models/purchase_item.dart';
import '../models/shortage.dart';
import '../models/purchase_log.dart';
import '../models/supplier.dart';
import '../models/product.dart';

class PurchaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ========== ПОСТАВЩИКИ ==========
  
  Future<List<Supplier>> getSuppliers() async {
    try {
      final snapshot = await _firestore
          .collection('suppliers')
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Supplier.fromMap(data);
      }).toList();
    } catch (e) {
      print('Ошибка получения поставщиков: $e');
      return [];
    }
  }

  Future<void> addSupplier(Supplier supplier) async {
    try {
      await _firestore.collection('suppliers').add(supplier.toMap());
    } catch (e) {
      print('Ошибка добавления поставщика: $e');
      rethrow;
    }
  }

  // ========== ЗАКУПЫ ==========

  Future<List<Purchase>> getPurchases({String? status}) async {
    try {
      Query query = _firestore.collection('purchases').orderBy('dateCreated', descending: true);
      
      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      final snapshot = await query.get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Purchase.fromMap(data);
      }).toList();
    } catch (e) {
      print('Ошибка получения закупов: $e');
      return [];
    }
  }

  Future<Purchase?> getPurchaseById(String purchaseId) async {
    try {
      final doc = await _firestore.collection('purchases').doc(purchaseId).get();
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        return Purchase.fromMap(data);
      }
      return null;
    } catch (e) {
      print('Ошибка получения закупа: $e');
      return null;
    }
  }

  Future<String> createPurchase({
    required String supplierId,
    required String supplierName,
    required String userId,
    required String userName,
    required List<Map<String, dynamic>> items, // {productId, productName, productBarcode, unitPrice, orderedQty}
    String? notes,
  }) async {
    try {
      // Вычисляем общую сумму
      double totalAmount = 0.0;
      for (var item in items) {
        totalAmount += (item['unitPrice'] as double) * (item['orderedQty'] as int);
      }

      // Создаем закуп
      final purchase = Purchase(
        id: '',
        supplierId: supplierId,
        supplierName: supplierName,
        dateCreated: Timestamp.now(),
        status: Purchase.statusCreated,
        totalAmount: totalAmount,
        createdByUserId: userId,
        notes: notes,
      );

      final purchaseRef = await _firestore.collection('purchases').add(purchase.toMap());
      final purchaseId = purchaseRef.id;

      // Создаем товары закупа
      final batch = _firestore.batch();
      
      for (var itemData in items) {
        final purchaseItem = PurchaseItem(
          id: '',
          purchaseId: purchaseId,
          productId: itemData['productId'],
          productName: itemData['productName'],
          productBarcode: itemData['productBarcode'],
          unitPrice: itemData['unitPrice'],
          orderedQty: itemData['orderedQty'],
        );

        final itemRef = _firestore.collection('purchase_items').doc();
        batch.set(itemRef, purchaseItem.toMap());
      }

      // Создаем лог
      final log = PurchaseLog.createCreatedLog(
        purchaseId: purchaseId,
        userId: userId,
        userName: userName,
        notes: notes,
      );
      
      final logRef = _firestore.collection('purchase_logs').doc();
      batch.set(logRef, log.toMap());

      await batch.commit();

      return purchaseId;
    } catch (e) {
      print('Ошибка создания закупа: $e');
      rethrow;
    }
  }

  // ========== ТОВАРЫ ЗАКУПА ==========

  Future<List<PurchaseItem>> getPurchaseItems(String purchaseId) async {
    try {
      final snapshot = await _firestore
          .collection('purchase_items')
          .where('purchaseId', isEqualTo: purchaseId)
          .orderBy('productName')
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return PurchaseItem.fromMap(data);
      }).toList();
    } catch (e) {
      print('Ошибка получения товаров закупа: $e');
      return [];
    }
  }

  // ========== ПРИЕМКА ==========

  Future<void> receivePurchaseItems({
    required String purchaseId,
    required List<Map<String, dynamic>> receivedItems, // {itemId, receivedQty}
    required String userId,
    required String userName,
  }) async {
    try {
      final batch = _firestore.batch();
      
      bool hasShortages = false;
      Map<String, dynamic> receivingDetails = {
        'itemsReceived': [],
        'shortagesCreated': [],
      };

      for (var receivedItem in receivedItems) {
        final itemId = receivedItem['itemId'] as String;
        final receivedQty = receivedItem['receivedQty'] as int;

        // Получаем товар закупа
        final itemDoc = await _firestore.collection('purchase_items').doc(itemId).get();
        if (!itemDoc.exists) continue;

        final itemData = itemDoc.data()!;
        final purchaseItem = PurchaseItem.fromMap(itemData);
        
        final missingQty = purchaseItem.orderedQty - receivedQty;
        
        // Обновляем товар закупа
        final updatedItem = purchaseItem.copyWith(
          receivedQty: receivedQty,
          missingQty: missingQty,
          status: missingQty > 0 ? PurchaseItem.statusShortageWaiting : PurchaseItem.statusReceived,
          receivedDate: Timestamp.now(),
        );

        batch.update(_firestore.collection('purchase_items').doc(itemId), updatedItem.toMap());

        receivingDetails['itemsReceived'].add({
          'itemId': itemId,
          'productName': purchaseItem.productName,
          'orderedQty': purchaseItem.orderedQty,
          'receivedQty': receivedQty,
          'missingQty': missingQty,
        });

        // Создаем недостачу если нужно
        if (missingQty > 0) {
          hasShortages = true;
          
          final shortage = Shortage(
            id: '',
            purchaseItemId: itemId,
            purchaseId: purchaseId,
            productId: purchaseItem.productId,
            productName: purchaseItem.productName,
            productBarcode: purchaseItem.productBarcode,
            missingQty: missingQty,
            unitPrice: purchaseItem.unitPrice,
            dateCreated: Timestamp.now(),
          );

          final shortageRef = _firestore.collection('shortages').doc();
          batch.set(shortageRef, shortage.toMap());

          receivingDetails['shortagesCreated'].add({
            'productName': purchaseItem.productName,
            'missingQty': missingQty,
            'amount': missingQty * purchaseItem.unitPrice,
          });
        }
      }

      // Обновляем статус закупа
      final newPurchaseStatus = hasShortages ? Purchase.statusReceiving : Purchase.statusInStock;
      batch.update(
        _firestore.collection('purchases').doc(purchaseId),
        {'status': newPurchaseStatus}
      );

      // Создаем лог
      final log = PurchaseLog.createReceivedLog(
        purchaseId: purchaseId,
        userId: userId,
        userName: userName,
        receivingDetails: receivingDetails,
      );
      
      final logRef = _firestore.collection('purchase_logs').doc();
      batch.set(logRef, log.toMap());

      await batch.commit();
    } catch (e) {
      print('Ошибка приемки закупа: $e');
      rethrow;
    }
  }

  // ========== ОПРИХОДОВАНИЕ ==========

  Future<void> stockPurchaseItems({
    required String purchaseId,
    required List<String> itemIds, // Список ID товаров для оприходования
    required String userId,
    required String userName,
    bool stockAll = false, // Оприходовать все товары сразу
  }) async {
    try {
      final batch = _firestore.batch();
      
      List<String> targetItemIds = itemIds;
      
      // Если нужно оприходовать все товары
      if (stockAll) {
        final items = await getPurchaseItems(purchaseId);
        targetItemIds = items
            .where((item) => item.status == PurchaseItem.statusReceived)
            .map((item) => item.id)
            .toList();
      }

      Map<String, dynamic> stockingDetails = {
        'itemsStocked': [],
        'stockAll': stockAll,
      };

      for (String itemId in targetItemIds) {
        final itemDoc = await _firestore.collection('purchase_items').doc(itemId).get();
        if (!itemDoc.exists) continue;

        final itemData = itemDoc.data()!;
        final purchaseItem = PurchaseItem.fromMap(itemData);

        // Обновляем статус товара
        final updatedItem = purchaseItem.copyWith(
          status: PurchaseItem.statusInStock,
          stockedDate: Timestamp.now(),
        );

        batch.update(_firestore.collection('purchase_items').doc(itemId), updatedItem.toMap());

        stockingDetails['itemsStocked'].add({
          'itemId': itemId,
          'productName': purchaseItem.productName,
          'receivedQty': purchaseItem.receivedQty,
        });
      }

      // Проверяем, все ли товары оприходованы
      final allItems = await getPurchaseItems(purchaseId);
      final allStocked = allItems.every((item) => 
        item.status == PurchaseItem.statusInStock || 
        item.status == PurchaseItem.statusOnSale ||
        item.status == PurchaseItem.statusShortageWaiting
      );

      if (allStocked) {
        batch.update(
          _firestore.collection('purchases').doc(purchaseId),
          {'status': Purchase.statusInStock}
        );
      }

      // Создаем лог
      final log = PurchaseLog.createStockedLog(
        purchaseId: purchaseId,
        userId: userId,
        userName: userName,
        stockingDetails: stockingDetails,
      );
      
      final logRef = _firestore.collection('purchase_logs').doc();
      batch.set(logRef, log.toMap());

      await batch.commit();
    } catch (e) {
      print('Ошибка оприходования: $e');
      rethrow;
    }
  }

  // ========== ВЫСТАВКА НА ПРОДАЖУ ==========

  Future<void> putPurchaseItemsOnSale({
    required String purchaseId,
    required List<String> itemIds,
    required String userId,
    required String userName,
    bool putAllOnSale = false,
  }) async {
    try {
      final batch = _firestore.batch();
      
      List<String> targetItemIds = itemIds;
      
      // Если нужно выставить все товары
      if (putAllOnSale) {
        final items = await getPurchaseItems(purchaseId);
        targetItemIds = items
            .where((item) => item.status == PurchaseItem.statusInStock)
            .map((item) => item.id)
            .toList();
      }

      Map<String, dynamic> saleDetails = {
        'itemsPutOnSale': [],
        'putAllOnSale': putAllOnSale,
      };

      for (String itemId in targetItemIds) {
        final itemDoc = await _firestore.collection('purchase_items').doc(itemId).get();
        if (!itemDoc.exists) continue;

        final itemData = itemDoc.data()!;
        final purchaseItem = PurchaseItem.fromMap(itemData);

        // Обновляем статус товара
        final updatedItem = purchaseItem.copyWith(
          status: PurchaseItem.statusOnSale,
          onSaleDate: Timestamp.now(),
        );

        batch.update(_firestore.collection('purchase_items').doc(itemId), updatedItem.toMap());

        saleDetails['itemsPutOnSale'].add({
          'itemId': itemId,
          'productName': purchaseItem.productName,
          'receivedQty': purchaseItem.receivedQty,
        });
      }

      // Проверяем, все ли товары выставлены на продажу
      final allItems = await getPurchaseItems(purchaseId);
      final allOnSale = allItems.every((item) => 
        item.status == PurchaseItem.statusOnSale ||
        item.status == PurchaseItem.statusShortageWaiting
      );

      if (allOnSale) {
        batch.update(
          _firestore.collection('purchases').doc(purchaseId),
          {'status': Purchase.statusOnSale}
        );
      }

      // Создаем лог
      final log = PurchaseLog.createOnSaleLog(
        purchaseId: purchaseId,
        userId: userId,
        userName: userName,
        saleDetails: saleDetails,
      );
      
      final logRef = _firestore.collection('purchase_logs').doc();
      batch.set(logRef, log.toMap());

      await batch.commit();
    } catch (e) {
      print('Ошибка выставки на продажу: $e');
      rethrow;
    }
  }

  // ========== НЕДОСТАЧИ ==========

  Future<List<Shortage>> getShortages({String? purchaseId, String? status}) async {
    try {
      Query query = _firestore.collection('shortages').orderBy('dateCreated', descending: true);
      
      if (purchaseId != null) {
        query = query.where('purchaseId', isEqualTo: purchaseId);
      }
      
      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      final snapshot = await query.get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Shortage.fromMap(data);
      }).toList();
    } catch (e) {
      print('Ошибка получения недостач: $e');
      return [];
    }
  }

  Future<void> receiveShortage({
    required String shortageId,
    required String userId,
    required String userName,
    String? notes,
  }) async {
    try {
      final batch = _firestore.batch();

      // Получаем недостачу
      final shortageDoc = await _firestore.collection('shortages').doc(shortageId).get();
      if (!shortageDoc.exists) throw Exception('Недостача не найдена');

      final shortageData = shortageDoc.data()!;
      final shortage = Shortage.fromMap(shortageData);

      // Обновляем недостачу
      final updatedShortage = shortage.copyWith(
        status: Shortage.statusReceived,
        dateClosed: Timestamp.now(),
        closedByUserId: userId,
        notes: notes,
      );

      batch.update(_firestore.collection('shortages').doc(shortageId), updatedShortage.toMap());

      // Обновляем товар закупа
      final itemDoc = await _firestore.collection('purchase_items').doc(shortage.purchaseItemId).get();
      if (itemDoc.exists) {
        final itemData = itemDoc.data()!;
        final purchaseItem = PurchaseItem.fromMap(itemData);

        final updatedItem = purchaseItem.copyWith(
          receivedQty: purchaseItem.receivedQty + shortage.missingQty,
          missingQty: 0,
          status: PurchaseItem.statusReceived,
        );

        batch.update(_firestore.collection('purchase_items').doc(shortage.purchaseItemId), updatedItem.toMap());
      }

      // Создаем лог
      final log = PurchaseLog(
        id: '',
        purchaseId: shortage.purchaseId,
        action: PurchaseLog.actionShortageReceived,
        date: Timestamp.now(),
        userId: userId,
        userName: userName,
        details: {
          'shortageId': shortageId,
          'productName': shortage.productName,
          'missingQty': shortage.missingQty,
          'amount': shortage.totalMissingAmount,
        },
        notes: notes,
      );
      
      final logRef = _firestore.collection('purchase_logs').doc();
      batch.set(logRef, log.toMap());

      await batch.commit();
    } catch (e) {
      print('Ошибка получения недостачи: $e');
      rethrow;
    }
  }

  Future<void> closeShortageAsNotReceived({
    required String shortageId,
    required String userId,
    required String userName,
    String? notes,
  }) async {
    try {
      final batch = _firestore.batch();

      // Получаем недостачу
      final shortageDoc = await _firestore.collection('shortages').doc(shortageId).get();
      if (!shortageDoc.exists) throw Exception('Недостача не найдена');

      final shortageData = shortageDoc.data()!;
      final shortage = Shortage.fromMap(shortageData);

      // Обновляем недостачу
      final updatedShortage = shortage.copyWith(
        status: Shortage.statusNotReceived,
        dateClosed: Timestamp.now(),
        closedByUserId: userId,
        notes: notes,
      );

      batch.update(_firestore.collection('shortages').doc(shortageId), updatedShortage.toMap());

      // Обновляем товар закупа
      final itemDoc = await _firestore.collection('purchase_items').doc(shortage.purchaseItemId).get();
      if (itemDoc.exists) {
        final itemData = itemDoc.data()!;
        final purchaseItem = PurchaseItem.fromMap(itemData);

        final updatedItem = purchaseItem.copyWith(
          status: PurchaseItem.statusShortageNotReceived,
        );

        batch.update(_firestore.collection('purchase_items').doc(shortage.purchaseItemId), updatedItem.toMap());
      }

      // Создаем лог
      final log = PurchaseLog(
        id: '',
        purchaseId: shortage.purchaseId,
        action: PurchaseLog.actionShortageNotReceived,
        date: Timestamp.now(),
        userId: userId,
        userName: userName,
        details: {
          'shortageId': shortageId,
          'productName': shortage.productName,
          'missingQty': shortage.missingQty,
          'amount': shortage.totalMissingAmount,
        },
        notes: notes,
      );
      
      final logRef = _firestore.collection('purchase_logs').doc();
      batch.set(logRef, log.toMap());

      await batch.commit();
    } catch (e) {
      print('Ошибка закрытия недостачи: $e');
      rethrow;
    }
  }

  // ========== ЛОГИ ==========

  Future<List<PurchaseLog>> getPurchaseLogs(String purchaseId) async {
    try {
      final snapshot = await _firestore
          .collection('purchase_logs')
          .where('purchaseId', isEqualTo: purchaseId)
          .orderBy('date', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return PurchaseLog.fromMap(data);
      }).toList();
    } catch (e) {
      print('Ошибка получения логов: $e');
      return [];
    }
  }

  // ========== АРХИВАЦИЯ ==========

  Future<void> archivePurchase({
    required String purchaseId,
    required String userId,
    required String userName,
  }) async {
    try {
      final batch = _firestore.batch();

      // Обновляем статус закупа
      batch.update(
        _firestore.collection('purchases').doc(purchaseId),
        {'status': Purchase.statusArchived}
      );

      // Создаем лог
      final log = PurchaseLog(
        id: '',
        purchaseId: purchaseId,
        action: PurchaseLog.actionArchived,
        date: Timestamp.now(),
        userId: userId,
        userName: userName,
      );
      
      final logRef = _firestore.collection('purchase_logs').doc();
      batch.set(logRef, log.toMap());

      await batch.commit();
    } catch (e) {
      print('Ошибка архивации закупа: $e');
      rethrow;
    }
  }

  // ========== СТАТИСТИКА ==========

  Future<Map<String, dynamic>> getPurchaseStatistics(String purchaseId) async {
    try {
      final items = await getPurchaseItems(purchaseId);
      final shortages = await getShortages(purchaseId: purchaseId);

      int totalItemsOrdered = items.fold(0, (sum, item) => sum + item.orderedQty);
      int totalItemsReceived = items.fold(0, (sum, item) => sum + item.receivedQty);
      int totalItemsMissing = items.fold(0, (sum, item) => sum + item.missingQty);

      double totalAmountOrdered = items.fold(0.0, (sum, item) => sum + item.totalOrderedAmount);
      double totalAmountReceived = items.fold(0.0, (sum, item) => sum + item.totalReceivedAmount);
      double totalAmountMissing = items.fold(0.0, (sum, item) => sum + item.totalMissingAmount);

      int openShortages = shortages.where((s) => s.status == Shortage.statusWaiting).length;
      int closedShortages = shortages.where((s) => s.status != Shortage.statusWaiting).length;

      return {
        'totalItemsOrdered': totalItemsOrdered,
        'totalItemsReceived': totalItemsReceived,
        'totalItemsMissing': totalItemsMissing,
        'totalAmountOrdered': totalAmountOrdered,
        'totalAmountReceived': totalAmountReceived,
        'totalAmountMissing': totalAmountMissing,
        'openShortages': openShortages,
        'closedShortages': closedShortages,
        'completionPercentage': totalItemsOrdered > 0 ? (totalItemsReceived / totalItemsOrdered * 100) : 0,
      };
    } catch (e) {
      print('Ошибка получения статистики: $e');
      return {};
    }
  }
}