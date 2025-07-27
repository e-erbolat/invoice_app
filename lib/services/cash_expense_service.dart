import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cash_expense.dart';
import '../services/cash_register_service.dart';
import '../models/cash_register.dart';

class CashExpenseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'cash_expenses';
  final CashRegisterService _cashRegisterService = CashRegisterService();

  // Создать новый расход
  Future<void> createExpense(CashExpense expense) async {
    try {
      await _firestore.collection(_collection).doc(expense.id).set(expense.toMap());
    } catch (e) {
      throw Exception('Ошибка при создании расхода: $e');
    }
  }

  // Получить все расходы
  Future<List<CashExpense>> getAllExpenses() async {
    try {
      final querySnapshot = await _firestore.collection(_collection).orderBy('date', descending: true).get();
      return querySnapshot.docs.map((doc) => CashExpense.fromMap(doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Ошибка при получении расходов: $e');
    }
  }

  // Получить расходы по статусу
  Future<List<CashExpense>> getExpensesByStatus(CashExpenseStatus status) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('status', isEqualTo: status.value)
          .orderBy('date', descending: true)
          .get();
      return querySnapshot.docs.map((doc) => CashExpense.fromMap(doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Ошибка при получении расходов по статусу: $e');
    }
  }

  // Получить расходы, созданные пользователем
  Future<List<CashExpense>> getExpensesByUser(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('createdBy', isEqualTo: userId)
          .orderBy('date', descending: true)
          .get();
      return querySnapshot.docs.map((doc) => CashExpense.fromMap(doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Ошибка при получении расходов пользователя: $e');
    }
  }

  // Подтвердить расход (только суперадмин)
  Future<void> approveExpense(String expenseId, String approvedBy) async {
    try {
      // Получаем расход
      final doc = await _firestore.collection(_collection).doc(expenseId).get();
      if (!doc.exists) {
        throw Exception('Расход не найден');
      }

      final expense = CashExpense.fromMap(doc.data() as Map<String, dynamic>);
      if (expense.status != CashExpenseStatus.pending) {
        throw Exception('Расход уже обработан');
      }

      // Обновляем статус расхода
      await _firestore.collection(_collection).doc(expenseId).update({
        'status': CashExpenseStatus.approved.value,
        'approvedBy': approvedBy,
        'approvedAt': Timestamp.now(),
      });

      // Добавляем запись в кассу (отрицательная сумма)
      final cashRecord = CashRegister(
        id: _cashRegisterService.generateRecordId(),
        date: DateTime.now(),
        amount: -expense.amount, // Отрицательная сумма для расхода
        description: 'Расход: ${expense.description}',
      );
      await _cashRegisterService.addCashRecord(cashRecord);
    } catch (e) {
      throw Exception('Ошибка при подтверждении расхода: $e');
    }
  }

  // Отклонить расход (только суперадмин)
  Future<void> rejectExpense(String expenseId, String rejectedBy, String reason) async {
    try {
      // Получаем расход
      final doc = await _firestore.collection(_collection).doc(expenseId).get();
      if (!doc.exists) {
        throw Exception('Расход не найден');
      }

      final expense = CashExpense.fromMap(doc.data() as Map<String, dynamic>);
      if (expense.status != CashExpenseStatus.pending) {
        throw Exception('Расход уже обработан');
      }

      // Обновляем статус расхода
      await _firestore.collection(_collection).doc(expenseId).update({
        'status': CashExpenseStatus.rejected.value,
        'approvedBy': rejectedBy,
        'approvedAt': Timestamp.now(),
        'rejectReason': reason,
      });
    } catch (e) {
      throw Exception('Ошибка при отклонении расхода: $e');
    }
  }

  // Удалить расход (только если он в статусе pending)
  Future<void> deleteExpense(String expenseId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(expenseId).get();
      if (!doc.exists) {
        throw Exception('Расход не найден');
      }

      final expense = CashExpense.fromMap(doc.data() as Map<String, dynamic>);
      if (expense.status != CashExpenseStatus.pending) {
        throw Exception('Нельзя удалить обработанный расход');
      }

      await _firestore.collection(_collection).doc(expenseId).delete();
    } catch (e) {
      throw Exception('Ошибка при удалении расхода: $e');
    }
  }

  // Генерировать уникальный ID для расхода
  String generateExpenseId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
} 