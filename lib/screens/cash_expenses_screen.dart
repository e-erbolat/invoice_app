import 'package:flutter/material.dart';
import '../models/cash_expense.dart';
import '../services/cash_expense_service.dart';
import '../services/auth_service.dart';
import '../models/app_user.dart';
import 'package:intl/intl.dart';

class CashExpensesScreen extends StatefulWidget {
  const CashExpensesScreen({Key? key}) : super(key: key);

  @override
  State<CashExpensesScreen> createState() => _CashExpensesScreenState();
}

class _CashExpensesScreenState extends State<CashExpensesScreen> with SingleTickerProviderStateMixin {
  final CashExpenseService _expenseService = CashExpenseService();
  AppUser? _currentUser;
  List<CashExpense> _expenses = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; });
    try {
      final user = await AuthService().getCurrentUser();
      final expenses = await _expenseService.getAllExpenses();
      
      setState(() {
        _currentUser = user;
        _expenses = expenses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при загрузке данных: $e')),
      );
    }
  }

  List<CashExpense> _getExpensesByStatus(CashExpenseStatus status) {
    return _expenses.where((expense) => expense.status == status).toList();
  }

  Future<void> _approveExpense(CashExpense expense) async {
    if (_currentUser?.role != 'superadmin') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Только суперадмин может подтверждать расходы')),
      );
      return;
    }

    try {
      await _expenseService.approveExpense(expense.id, _currentUser!.uid);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Расход подтвержден'),
          backgroundColor: Colors.green,
        ),
      );
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при подтверждении: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectExpense(CashExpense expense) async {
    if (_currentUser?.role != 'superadmin') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Только суперадмин может отклонять расходы')),
      );
      return;
    }

    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Отклонить расход'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Введите причину отклонения:'),
            SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Причина отклонения...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Отклонить'),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonController.text.trim().isNotEmpty) {
      try {
        await _expenseService.rejectExpense(expense.id, _currentUser!.uid, reasonController.text.trim());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Расход отклонен'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при отклонении: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteExpense(CashExpense expense) async {
    if (expense.createdBy != _currentUser?.uid && _currentUser?.role != 'superadmin') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Вы можете удалить только свои расходы')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить расход'),
        content: Text('Вы уверены, что хотите удалить этот расход?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _expenseService.deleteExpense(expense.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Расход удален'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при удалении: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildExpenseCard(CashExpense expense) {
    final isPending = expense.status == CashExpenseStatus.pending;
    final isApproved = expense.status == CashExpenseStatus.approved;
    final isRejected = expense.status == CashExpenseStatus.rejected;
    final canManage = _currentUser?.role == 'superadmin';
    final canDelete = expense.createdBy == _currentUser?.uid || _currentUser?.role == 'superadmin';

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isPending 
              ? Colors.orange 
              : isApproved 
                  ? Colors.green 
                  : Colors.red,
          child: Icon(
            isPending ? Icons.schedule : isApproved ? Icons.check : Icons.close,
            color: Colors.white,
          ),
        ),
        title: Text(
          expense.description,
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('dd.MM.yyyy HH:mm').format(expense.date)),
            Text('Сумма: ${expense.amount.toStringAsFixed(2)} ₸'),
            Text('Статус: ${expense.status.name}'),
            if (expense.rejectReason != null)
              Text('Причина отклонения: ${expense.rejectReason}', 
                   style: TextStyle(color: Colors.red)),
          ],
        ),
        trailing: isPending && canManage
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.check, color: Colors.green),
                    onPressed: () => _approveExpense(expense),
                    tooltip: 'Подтвердить',
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.red),
                    onPressed: () => _rejectExpense(expense),
                    tooltip: 'Отклонить',
                  ),
                ],
              )
            : canDelete
                ? IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteExpense(expense),
                    tooltip: 'Удалить',
                  )
                : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Расходы кассы'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 2,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.deepPurple,
          tabs: [
            Tab(text: 'Ожидают (${_getExpensesByStatus(CashExpenseStatus.pending).length})'),
            Tab(text: 'Подтверждены (${_getExpensesByStatus(CashExpenseStatus.approved).length})'),
            Tab(text: 'Отклонены (${_getExpensesByStatus(CashExpenseStatus.rejected).length})'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildExpenseList(_getExpensesByStatus(CashExpenseStatus.pending)),
                _buildExpenseList(_getExpensesByStatus(CashExpenseStatus.approved)),
                _buildExpenseList(_getExpensesByStatus(CashExpenseStatus.rejected)),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.pushNamed(context, '/cash_expense_create');
          if (result == true) {
            _loadData();
          }
        },
        backgroundColor: Colors.deepPurple,
        child: Icon(Icons.add, color: Colors.white),
        tooltip: 'Создать расход',
      ),
    );
  }

  Widget _buildExpenseList(List<CashExpense> expenses) {
    if (expenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Нет расходов',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: expenses.length,
        itemBuilder: (context, index) => _buildExpenseCard(expenses[index]),
      ),
    );
  }
} 