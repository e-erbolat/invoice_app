import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';
import '../utils/validation_utils.dart';

class InvoiceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Создать новую накладную
  Future<void> createInvoice(Invoice invoice) async {
    try {
      // Валидация данных
      _validateInvoice(invoice);
      
      
      await _firestore.collection('invoices').doc(invoice.id).set({
        'id': invoice.id,
        'outletId': invoice.outletId,
        'outletName': invoice.outletName,
        'outletAddress': invoice.outletAddress,
        'salesRepId': invoice.salesRepId,
        'salesRepName': invoice.salesRepName,
        'date': invoice.date,
        'status': invoice.status,
        'isPaid': invoice.isPaid,
        'paymentType': invoice.paymentType,
        'isDebt': invoice.isDebt,
        'acceptedByAdmin': invoice.acceptedByAdmin,
        'acceptedBySuperAdmin': invoice.acceptedBySuperAdmin,
        'acceptedAt': invoice.acceptedAt,
        'items': invoice.items.map((item) => {
          'productId': item.productId,
          'productName': item.productName,
          'quantity': item.quantity,
          'price': item.price,
          'originalPrice': item.originalPrice,
          'totalPrice': item.totalPrice,
          'isBonus': item.isBonus,
        }).toList(),
        'totalAmount': invoice.totalAmount,
      });
      
      print('[InvoiceService] Накладная успешно сохранена в Firestore');
    } catch (e) {
      print('[InvoiceService] Ошибка сохранения накладной: $e');
      throw Exception('Ошибка создания накладной: $e');
    }
  }

  /// Валидация накладной
  void _validateInvoice(Invoice invoice) {
    if (invoice.items.isEmpty) {
      throw ArgumentError('Накладная должна содержать хотя бы один товар');
    }
    
    for (int i = 0; i < invoice.items.length; i++) {
      final item = invoice.items[i];
      final error = ValidationUtils.getValidationError(
        price: item.price,
        originalPrice: item.originalPrice,
        quantity: item.quantity,
        productId: item.productId,
        productName: item.productName,
      );
      
      if (error != null) {
        throw ArgumentError('Ошибка валидации товара $i (${item.productName}): $error');
      }
    }
  }

  // Получить все накладные
  Future<List<Invoice>> getAllInvoices() async {
    try {
      final querySnapshot = await _firestore
          .collection('invoices')
          .orderBy('date', descending: true)
          .get();
        
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return Invoice(
          id: data['id'],
          outletId: data['outletId'],
          outletName: data['outletName'],
          outletAddress: data['outletAddress'] ?? '',
          salesRepId: data['salesRepId'],
          salesRepName: data['salesRepName'],
          date: data['date'],
          status: data['status'] ?? 'передан',
          isPaid: data['isPaid'] ?? false,
          paymentType: data['paymentType'] ?? 'наличка',
          isDebt: data['isDebt'] ?? false,
          acceptedByAdmin: data['acceptedByAdmin'] ?? false,
          acceptedBySuperAdmin: data['acceptedBySuperAdmin'] ?? false,
          acceptedAt: data['acceptedAt'],
          items: (data['items'] as List).map((item) => InvoiceItem(
            productId: item['productId'],
            productName: item['productName'],
            quantity: item['quantity'],
            price: (item['price'] as num).toDouble(),
            originalPrice: (item['originalPrice'] as num?)?.toDouble() ?? (item['price'] as num).toDouble(),
            totalPrice: (item['totalPrice'] as num).toDouble(),
            isBonus: item['isBonus'] ?? false,
          )).toList(),
          totalAmount: (data['totalAmount'] as num).toDouble(),
        );
      }).toList();
    } catch (e) {
      throw Exception('Ошибка загрузки накладных: $e');
    }
  }

  // Получить накладные по торговому представителю
  Future<List<Invoice>> getInvoicesBySalesRep(String salesRepId) async {
    try {
      final querySnapshot = await _firestore
          .collection('invoices')
          .where('salesRepId', isEqualTo: salesRepId)
          .orderBy('date', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return Invoice(
          id: data['id'],
          outletId: data['outletId'],
          outletName: data['outletName'],
          outletAddress: data['outletAddress'] ?? '',
          salesRepId: data['salesRepId'],
          salesRepName: data['salesRepName'],
          date: data['date'],
          status: data['status'] ?? 'передан',
          isPaid: data['isPaid'] ?? false,
          paymentType: data['paymentType'] ?? 'наличка',
          isDebt: data['isDebt'] ?? false,
          acceptedByAdmin: data['acceptedByAdmin'] ?? false,
          acceptedBySuperAdmin: data['acceptedBySuperAdmin'] ?? false,
          acceptedAt: data['acceptedAt'],
          items: (data['items'] as List).map((item) => InvoiceItem(
            productId: item['productId'],
            productName: item['productName'],
            quantity: item['quantity'],
            price: (item['price'] as num).toDouble(),
            originalPrice: (item['originalPrice'] as num?)?.toDouble() ?? (item['price'] as num).toDouble(),
            totalPrice: (item['totalPrice'] as num).toDouble(),
            isBonus: item['isBonus'] ?? false,
          )).toList(),
          totalAmount: (data['totalAmount'] as num).toDouble(),
        );
      }).toList();
    } catch (e) {
      throw Exception('Ошибка загрузки накладных торгового: $e');
    }
  }

  // Получить накладную по ID
  Future<Invoice?> getInvoiceById(String invoiceId) async {
    try {
      final doc = await _firestore.collection('invoices').doc(invoiceId).get();
      
      if (!doc.exists) return null;

      final data = doc.data()!;
      return Invoice(
        id: data['id'],
        outletId: data['outletId'],
        outletName: data['outletName'],
        outletAddress: data['outletAddress'] ?? '',
        salesRepId: data['salesRepId'],
        salesRepName: data['salesRepName'],
        date: data['date'],
        status: data['status'] ?? 'передан',
        isPaid: data['isPaid'] ?? false,
        paymentType: data['paymentType'] ?? 'наличка',
        isDebt: data['isDebt'] ?? false,
        acceptedByAdmin: data['acceptedByAdmin'] ?? false,
        acceptedBySuperAdmin: data['acceptedBySuperAdmin'] ?? false,
        items: (data['items'] as List).map((item) => InvoiceItem(
          productId: item['productId'],
          productName: item['productName'],
          quantity: item['quantity'],
          price: (item['price'] as num).toDouble(),
          originalPrice: (item['originalPrice'] as num?)?.toDouble() ?? (item['price'] as num).toDouble(),
          totalPrice: (item['totalPrice'] as num).toDouble(),
          isBonus: item['isBonus'] ?? false,
        )).toList(),
        totalAmount: (data['totalAmount'] as num).toDouble(),
      );
    } catch (e) {
      throw Exception('Ошибка загрузки накладной: $e');
    }
  }

  // Получить накладные по статусу
  Future<List<Invoice>> getInvoicesByStatus(int status) async {
    try {
      final querySnapshot = await _firestore
          .collection('invoices')
          .where('status', isEqualTo: status)
          .orderBy('date', descending: true)
          .get();
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return Invoice.fromMap(data);
      }).toList();
    } catch (e) {
      throw Exception('Ошибка загрузки накладных по статусу: $e');
    }
  }

  // Получить накладные по статусу и торговому представителю
  Future<List<Invoice>> getInvoicesByStatusAndSalesRep(String status, String salesRepId) async {
    try {
      final querySnapshot = await _firestore
          .collection('invoices')
          .where('status', isEqualTo: status)
          .where('salesRepId', isEqualTo: salesRepId)
          .orderBy('date', descending: true)
          .get();
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return Invoice(
          id: data['id'],
          outletId: data['outletId'],
          outletName: data['outletName'],
          outletAddress: data['outletAddress'] ?? '',
          salesRepId: data['salesRepId'],
          salesRepName: data['salesRepName'],
          date: data['date'],
          status: data['status'] ?? 'передан',
          isPaid: data['isPaid'] ?? false,
          paymentType: data['paymentType'] ?? 'наличка',
          isDebt: data['isDebt'] ?? false,
          acceptedByAdmin: data['acceptedByAdmin'] ?? false,
          acceptedBySuperAdmin: data['acceptedBySuperAdmin'] ?? false,
          items: (data['items'] as List).map((item) => InvoiceItem(
            productId: item['productId'],
            productName: item['productName'],
            quantity: item['quantity'],
            price: (item['price'] as num).toDouble(),
            originalPrice: (item['originalPrice'] as num?)?.toDouble() ?? (item['price'] as num).toDouble(),
            totalPrice: (item['totalPrice'] as num).toDouble(),
            isBonus: item['isBonus'] ?? false,
          )).toList(),
          totalAmount: (data['totalAmount'] as num).toDouble(),
        );
      }).toList();
    } catch (e) {
      throw Exception('Ошибка загрузки накладных по статусу и торговому: $e');
    }
  }

  // Получить накладные по статусу и торговому представителю (без составного индекса)
  Future<List<Invoice>> getInvoicesByStatusAndSalesRepSimple(int status, String salesRepId) async {
    try {
      print('[InvoiceService] getInvoicesByStatusAndSalesRepSimple: статус=$status, salesRepId=$salesRepId');
      final querySnapshot = await _firestore
          .collection('invoices')
          .where('status', isEqualTo: status)
          .orderBy('date', descending: true)
          .get();
      print('[InvoiceService] Получено накладных по статусу $status: ${querySnapshot.docs.length}');
      final filteredDocs = querySnapshot.docs.where((doc) => doc.data()['salesRepId'] == salesRepId);
      print('[InvoiceService] После фильтрации по salesRepId $salesRepId: ${filteredDocs.length}');
      return filteredDocs.map((doc) {
        final data = doc.data();
        return Invoice.fromMap(data);
      }).toList();
    } catch (e) {
      print('[InvoiceService] Ошибка в getInvoicesByStatusAndSalesRepSimple: $e');
      throw Exception('Ошибка загрузки накладных по статусу и торговому: $e');
    }
  }

  // Обновить накладную полностью
  Future<void> updateInvoice(Invoice invoice) async {
    try {
      await _firestore.collection('invoices').doc(invoice.id).update({
        'outletId': invoice.outletId,
        'outletName': invoice.outletName,
        'outletAddress': invoice.outletAddress,
        'salesRepId': invoice.salesRepId,
        'salesRepName': invoice.salesRepName,
        'date': invoice.date,
        'status': invoice.status,
        'isPaid': invoice.isPaid,
        'paymentType': invoice.paymentType,
        'isDebt': invoice.isDebt,
        'acceptedByAdmin': invoice.acceptedByAdmin,
        'acceptedBySuperAdmin': invoice.acceptedBySuperAdmin,
        'acceptedAt': invoice.acceptedAt,
        'items': invoice.items.map((item) => {
          'productId': item.productId,
          'productName': item.productName,
          'quantity': item.quantity,
          'price': item.price,
          'originalPrice': item.originalPrice,
          'totalPrice': item.totalPrice,
          'isBonus': item.isBonus,
        }).toList(),
        'totalAmount': invoice.totalAmount,
      });
    } catch (e) {
      throw Exception('Ошибка обновления накладной: $e');
    }
  }

  // Обновить только статус накладной по id
  Future<void> updateInvoiceStatus(String invoiceId, int status) async {
    try {
      final updateData = <String, dynamic>{'status': status};
      
      // Если статус меняется на архив, сохраняем дату принятия
      if (status == InvoiceStatus.archive) {
        updateData['acceptedAt'] = Timestamp.now();
      }
      
      await _firestore.collection('invoices').doc(invoiceId).update(updateData);
    } catch (e) {
      throw Exception('Ошибка обновления статуса накладной: $e');
    }
  }

  // Обновить оплату, тип оплаты и комментарий по id накладной
  Future<void> updateInvoicePayment(String invoiceId, bool isPaid, String? paymentType, String? comment, {double? bankAmount, double? cashAmount}) async {
    try {
      await _firestore.collection('invoices').doc(invoiceId).update({
        'isPaid': isPaid,
        'paymentType': paymentType,
        'paymentComment': comment,
        if (bankAmount != null) 'bankAmount': bankAmount,
        if (cashAmount != null) 'cashAmount': cashAmount,
      });
    } catch (e) {
      throw Exception('Ошибка обновления оплаты накладной: $e');
    }
  }

  // Обновить статус принятия админом
  Future<void> updateInvoiceAcceptedByAdmin(String invoiceId, bool acceptedByAdmin) async {
    try {
      await _firestore.collection('invoices').doc(invoiceId).update({
        'acceptedByAdmin': acceptedByAdmin,
      });
    } catch (e) {
      throw Exception('Ошибка обновления статуса принятия админом: $e');
    }
  }

  // Удалить накладную
  Future<void> deleteInvoice(String invoiceId) async {
    try {
      await _firestore.collection('invoices').doc(invoiceId).delete();
    } catch (e) {
      throw Exception('Ошибка удаления накладной: $e');
    }
  }
} 