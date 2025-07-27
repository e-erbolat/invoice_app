import 'package:flutter/material.dart';
import '../models/cash_expense.dart';
import '../services/cash_expense_service.dart';
import '../services/auth_service.dart';
import '../models/app_user.dart';
import 'package:intl/intl.dart';

class CashExpenseCreateScreen extends StatefulWidget {
  const CashExpenseCreateScreen({Key? key}) : super(key: key);

  @override
  State<CashExpenseCreateScreen> createState() => _CashExpenseCreateScreenState();
}

class _CashExpenseCreateScreenState extends State<CashExpenseCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final CashExpenseService _expenseService = CashExpenseService();
  AppUser? _currentUser;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final user = await AuthService().getCurrentUser();
    setState(() {
      _currentUser = user;
    });
  }

  Future<void> _createExpense() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: пользователь не найден')),
      );
      return;
    }

    setState(() { _isLoading = true; });

    try {
      final amount = double.parse(_amountController.text.replaceAll(',', '.'));
      if (amount <= 0) {
        throw Exception('Сумма должна быть больше нуля');
      }

      final expense = CashExpense(
        id: _expenseService.generateExpenseId(),
        date: DateTime.now(),
        amount: amount,
        description: _descriptionController.text.trim(),
        status: CashExpenseStatus.pending,
        createdBy: _currentUser!.uid,
      );

      await _expenseService.createExpense(expense);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Расход создан и отправлен на подтверждение'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Возвращаем true для обновления списка
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при создании расхода: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Создать расход'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Информация о расходе',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Сумма (₸)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Введите сумму';
                          }
                          final amount = double.tryParse(value.replaceAll(',', '.'));
                          if (amount == null || amount <= 0) {
                            return 'Введите корректную сумму';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Описание расхода',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Введите описание';
                          }
                          if (value.trim().length < 5) {
                            return 'Описание должно содержать минимум 5 символов';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _createExpense,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('Создание...'),
                        ],
                      )
                    : Text('Создать расход'),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'Информация',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Расход будет отправлен на подтверждение суперадмину. После подтверждения сумма будет списана с кассы.',
                      style: TextStyle(color: Colors.orange.shade800),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 