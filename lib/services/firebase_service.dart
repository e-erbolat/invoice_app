import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import '../models/outlet.dart';
import '../models/sales_rep.dart';
import '../models/invoice.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Продукты
  Future<List<Product>> getProducts() async {
    try {
      final snapshot = await _firestore.collection('products').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Product.fromMap(data);
      }).toList();
    } catch (e) {
      print('Ошибка получения продуктов: $e');
      return [];
    }
  }

  Future<void> addProduct(Product product) async {
    try {
      print('Попытка добавления продукта: ${product.name}');
      final docRef = await _firestore.collection('products').add(product.toMap())
          .timeout(Duration(seconds: 60), onTimeout: () {
        throw TimeoutException('Операция добавления товара превысила время ожидания (60 секунд)');
      });
      print('Продукт успешно добавлен с ID: ${docRef.id}');
    } catch (e) {
      print('Ошибка добавления продукта: $e');
      print('Тип ошибки: ${e.runtimeType}');
      rethrow; // Пробрасываем ошибку дальше
    }
  }

  Future<void> updateProduct(Product product) async {
    try {
      await _firestore.collection('products').doc(product.id).update(product.toMap());
    } catch (e) {
      print('Ошибка обновления продукта: $e');
    }
  }

  Future<void> deleteProduct(String productId) async {
    try {
      await _firestore.collection('products').doc(productId).delete();
    } catch (e) {
      print('Ошибка удаления продукта: $e');
    }
  }

  Future<Product?> getProductById(String productId) async {
    try {
      final doc = await _firestore.collection('products').doc(productId).get();
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        return Product.fromMap(data);
      }
      return null;
    } catch (e) {
      print('Ошибка получения продукта по ID: $e');
      return null;
    }
  }

  // Торговые точки
  Future<List<Outlet>> getOutlets() async {
    try {
      final snapshot = await _firestore.collection('outlets').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Outlet.fromMap(data);
      }).toList();
    } catch (e) {
      print('Ошибка получения торговых точек: $e');
      return [];
    }
  }

  Future<void> addOutlet(Outlet outlet) async {
    try {
      await _firestore.collection('outlets').add(outlet.toMap());
    } catch (e) {
      print('Ошибка добавления торговой точки: $e');
    }
  }

  Future<void> updateOutlet(Outlet outlet) async {
    try {
      await _firestore.collection('outlets').doc(outlet.id).update(outlet.toMap());
    } catch (e) {
      print('Ошибка обновления торговой точки: $e');
    }
  }

  Future<void> deleteOutlet(String outletId) async {
    try {
      await _firestore.collection('outlets').doc(outletId).delete();
    } catch (e) {
      print('Ошибка удаления торговой точки: $e');
    }
  }

  // Торговые представители
  Future<List<SalesRep>> getSalesReps() async {
    try {
      final snapshot = await _firestore.collection('sales_reps').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return SalesRep.fromMap(data);
      }).toList();
    } catch (e) {
      print('Ошибка получения торговых представителей: $e');
      return [];
    }
  }

  Future<void> addSalesRep(SalesRep salesRep) async {
    try {
      await _firestore.collection('sales_reps').add(salesRep.toMap());
    } catch (e) {
      print('Ошибка добавления торгового представителя: $e');
    }
  }

  Future<void> updateSalesRep(SalesRep salesRep) async {
    try {
      await _firestore.collection('sales_reps').doc(salesRep.id).update(salesRep.toMap());
    } catch (e) {
      print('Ошибка обновления торгового представителя: $e');
    }
  }

  Future<void> deleteSalesRep(String salesRepId) async {
    try {
      await _firestore.collection('sales_reps').doc(salesRepId).delete();
    } catch (e) {
      print('Ошибка удаления торгового представителя: $e');
    }
  }

  // Накладные
  Future<List<Invoice>> getInvoices() async {
    try {
      final snapshot = await _firestore.collection('invoices').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Invoice.fromMap(data);
      }).toList();
    } catch (e) {
      print('Ошибка получения накладных: $e');
      return [];
    }
  }

  Future<void> addInvoice(Invoice invoice) async {
    try {
      await _firestore.collection('invoices').add(invoice.toMap());
    } catch (e) {
      print('Ошибка добавления накладной: $e');
    }
  }

  Future<void> updateInvoice(Invoice invoice) async {
    try {
      await _firestore.collection('invoices').doc(invoice.id).update(invoice.toMap());
    } catch (e) {
      print('Ошибка обновления накладной: $e');
    }
  }

  Future<void> deleteInvoice(String invoiceId) async {
    try {
      await _firestore.collection('invoices').doc(invoiceId).delete();
    } catch (e) {
      print('Ошибка удаления накладной: $e');
    }
  }
} 