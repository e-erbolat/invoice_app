import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cash_register.dart';

class CashRegisterService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'cash_register';

  // Добавить запись в кассу
  Future<void> addCashRecord(CashRegister record) async {
    try {
      await _firestore.collection(_collection).doc(record.id).set(record.toMap());
    } catch (e) {
      throw Exception('Ошибка при добавлении записи в кассу: $e');
    }
  }

  // Получить общую сумму в кассе
  Future<double> getTotalCashAmount() async {
    try {
      final querySnapshot = await _firestore.collection(_collection).get();
      double total = 0.0;
      
      for (var doc in querySnapshot.docs) {
        final record = CashRegister.fromMap(doc.data() as Map<String, dynamic>);
        total += record.amount;
      }
      
      return total;
    } catch (e) {
      throw Exception('Ошибка при получении общей суммы кассы: $e');
    }
  }

  // Получить историю операций кассы
  Future<List<CashRegister>> getCashHistory({
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
  }) async {
    try {
      Query query = _firestore.collection(_collection).orderBy('date', descending: true);
      
      if (fromDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(fromDate));
      }
      
      if (toDate != null) {
        query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(toDate));
      }
      
      if (limit != null) {
        query = query.limit(limit);
      }
      
      final querySnapshot = await query.get();
      return querySnapshot.docs.map((doc) => CashRegister.fromMap(doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Ошибка при получении истории кассы: $e');
    }
  }

  // Получить записи по конкретной накладной
  Future<List<CashRegister>> getCashRecordsByInvoice(String invoiceId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('invoiceId', isEqualTo: invoiceId)
          .get();
      
      return querySnapshot.docs.map((doc) => CashRegister.fromMap(doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Ошибка при получении записей кассы по накладной: $e');
    }
  }

  // Удалить запись из кассы
  Future<void> deleteCashRecord(String recordId) async {
    try {
      await _firestore.collection(_collection).doc(recordId).delete();
    } catch (e) {
      throw Exception('Ошибка при удалении записи из кассы: $e');
    }
  }

  // Генерировать уникальный ID для записи
  String generateRecordId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
} 