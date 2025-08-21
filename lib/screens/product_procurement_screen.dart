import 'package:flutter/material.dart';
import 'purchase_create_screen.dart';
import '../services/procurement_service.dart';
import '../models/procurement.dart';
import 'purchase_detail_screen.dart';
import '../services/auth_service.dart';
import '../models/app_user.dart';
import 'arrival_verification_screen.dart';
import 'goods_receiving_screen.dart'; // Новый импорт

class ProductProcurementScreen extends StatefulWidget {
  const ProductProcurementScreen({Key? key}) : super(key: key);

  @override
  State<ProductProcurementScreen> createState() => _ProductProcurementScreenState();
}

class _ProductProcurementScreenState extends State<ProductProcurementScreen> {
  final ProcurementService _procurementService = ProcurementService();
  final AuthService _authService = AuthService();
  bool _loading = true;
  List<Procurement> _purchases = [];
  List<Procurement> _arrivals = [];
  List<Procurement> _shortages = [];
  List<Procurement> _forSales = [];
  String? _error;
  AppUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _load();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _authService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait<List<Procurement>>([
        _procurementService.getProcurementsByStatus(ProcurementStatus.purchase.index),
        _procurementService.getProcurementsByStatus(ProcurementStatus.arrival.index),
        _procurementService.getProcurementsByStatus(ProcurementStatus.shortage.index),
        _procurementService.getProcurementsByStatus(ProcurementStatus.forSale.index),
      ]);
      if (!mounted) return;
      setState(() {
        _purchases = results[0];
        _arrivals = results[1];
        _shortages = results[2];
        _forSales = results[3];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _acceptToArrival(Procurement p) async {
    await _procurementService.updateProcurementStatus(p.id, ProcurementStatus.arrival.index);
    _load();
  }

  Future<void> _moveToShortage(Procurement p) async {
    await _procurementService.updateProcurementStatus(p.id, ProcurementStatus.shortage.index);
    _load();
  }

  Future<void> _moveToForSale(Procurement p) async {
    await _procurementService.updateProcurementStatus(p.id, ProcurementStatus.forSale.index);
    _load();
  }

  Future<void> _editProcurement(Procurement p) async {
    // Навигация на экран редактирования
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PurchaseCreateScreen(procurementToEdit: p),
      ),
    );
    _load(); // Перезагружаем данные после редактирования
  }

  Future<void> _openArrivalVerification(Procurement p) async {
    // Навигация на экран сверки прихода
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArrivalVerificationScreen(procurement: p),
      ),
    );
    
    // Если сверка была завершена, перезагружаем данные
    if (result == true) {
      _load();
    }
  }

  Future<void> _rejectProcurement(Procurement p) async {
    // Показываем диалог подтверждения
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отклонить закуп'),
        content: Text('Вы уверены, что хотите вернуть закуп "${p.sourceName}" на предыдущий этап?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Отклонить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Определяем предыдущий статус в зависимости от текущего
        int previousStatus;
        String statusMessage;
        
        switch (p.status) {
          case ProcurementStatus.arrival:
            previousStatus = ProcurementStatus.purchase.index;
            statusMessage = 'Закуп возвращен в статус "Закуп товара"';
            break;
          case ProcurementStatus.shortage:
            previousStatus = ProcurementStatus.arrival.index;
            statusMessage = 'Закуп возвращен в статус "Приход товара"';
            break;
          case ProcurementStatus.forSale:
            previousStatus = ProcurementStatus.arrival.index;
            statusMessage = 'Закуп возвращен в статус "Приход товара"';
            break;
          default:
            // Для закупа в статусе "purchase" нельзя отклонить
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Закуп в статусе "Закуп товара" нельзя отклонить'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
        }

        // Обновляем статус закупа
        await _procurementService.updateProcurementStatus(p.id, previousStatus);
        
        // Показываем уведомление об успехе
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(statusMessage),
              backgroundColor: Colors.green,
            ),
          );
        }
        
        // Перезагружаем данные
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка при отклонении закупа: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _openGoodsReceiving(Procurement p) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GoodsReceivingScreen(procurement: p),
      ),
    );
    _load();
  }

  Widget _buildCard(Procurement p, {List<Widget> trailingActions = const []}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.shopping_bag, color: Colors.blue),
        title: Text(p.sourceName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Дата: ${p.date.toDate().day.toString().padLeft(2,'0')}.${p.date.toDate().month.toString().padLeft(2,'0')}.${p.date.toDate().year}  •  Итого: ${p.totalAmount.toStringAsFixed(2)} ₸',
            ),
            if (p.status == ProcurementStatus.shortage && p.items.isNotEmpty && p.items.first.procurementId != null)
              Text(
                'Из закупа: ${p.items.first.procurementId}',
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        trailing: trailingActions.isEmpty
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: trailingActions,
              ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PurchaseDetailScreen(procurement: p)),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Закуп товара'),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Закуп товара'),
              Tab(text: 'Приход товара'),
              Tab(text: 'Недостача'),
              Tab(text: 'Выставка на продажу'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PurchaseCreateScreen()),
            );
            _load();
          },
          child: const Icon(Icons.add),
          tooltip: 'Создать закуп',
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(height: 8),
                        Text('Ошибка загрузки: \n\n$_error', textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _load, child: const Text('Повторить')),
                      ],
                    ),
                  )
                : TabBarView(
                children: [
                  // Закуп товара
                  _purchases.isEmpty
                      ? const Center(child: Text('Закупы отсутствуют'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _purchases.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final p = _purchases[i];
                            return _buildCard(p, trailingActions: [
                              // Кнопка редактирования для суперадмина
                              if (_currentUser?.role == 'superadmin')
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  tooltip: 'Редактировать',
                                  onPressed: () => _editProcurement(p),
                                ),
                              if (_currentUser?.role == 'superadmin')
                                const SizedBox(width: 8),
                              // Кнопка отклонения для суперадмина
                              if (_currentUser?.role == 'superadmin')
                                IconButton(
                                  icon: const Icon(Icons.undo, color: Colors.orange),
                                  tooltip: 'Отклонить',
                                  onPressed: () => _rejectProcurement(p),
                                ),
                              if (_currentUser?.role == 'superadmin')
                                const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => _acceptToArrival(p),
                                child: const Text('Принять'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => _openGoodsReceiving(p),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Приемка'),
                              ),
                            ]);
                          },
                        ),
                  // Приход товара
                  _arrivals.isEmpty
                      ? const Center(child: Text('Приходы отсутствуют'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _arrivals.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final p = _arrivals[i];
                            return _buildCard(p, trailingActions: [
                              // Кнопка редактирования для суперадмина
                              if (_currentUser?.role == 'superadmin')
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  tooltip: 'Редактировать',
                                  onPressed: () => _editProcurement(p),
                                ),
                              if (_currentUser?.role == 'superadmin')
                                const SizedBox(width: 8),
                              // Кнопка отклонения для суперадмина
                              if (_currentUser?.role == 'superadmin')
                                IconButton(
                                  icon: const Icon(Icons.undo, color: Colors.orange),
                                  tooltip: 'Отклонить',
                                  onPressed: () => _rejectProcurement(p),
                                ),
                              if (_currentUser?.role == 'superadmin')
                                const SizedBox(width: 8),
                              OutlinedButton(onPressed: () => _moveToShortage(p), child: const Text('Недостача')),
                              const SizedBox(width: 8),
                              ElevatedButton(onPressed: () => _moveToForSale(p), child: const Text('Выставка')),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.receipt_long, color: Colors.green),
                                tooltip: 'Сверка',
                                onPressed: () => _openArrivalVerification(p),
                              ),
                            ]);
                          },
                        ),
                  // Недостача
                  _shortages.isEmpty
                      ? const Center(child: Text('Недостачи отсутствуют'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _shortages.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final p = _shortages[i];
                            return _buildCard(p, trailingActions: [
                              // Кнопка редактирования для суперадмина
                              if (_currentUser?.role == 'superadmin')
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  tooltip: 'Редактировать',
                                  onPressed: () => _editProcurement(p),
                                ),
                              if (_currentUser?.role == 'superadmin')
                                const SizedBox(width: 8),
                              // Кнопка отклонения для суперадмина
                              if (_currentUser?.role == 'superadmin')
                                IconButton(
                                  icon: const Icon(Icons.undo, color: Colors.orange),
                                  tooltip: 'Отклонить',
                                  onPressed: () => _rejectProcurement(p),
                                ),
                              if (_currentUser?.role == 'superadmin')
                                const SizedBox(width: 8),
                              ElevatedButton(onPressed: () => _moveToForSale(p), child: const Text('Выставка')),
                            ]);
                          },
                        ),
                  // Выставка на продажу
                  _forSales.isEmpty
                      ? const Center(child: Text('Пусто'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _forSales.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final p = _forSales[i];
                            return _buildCard(p, trailingActions: [
                              // Кнопка редактирования для суперадмина
                              if (_currentUser?.role == 'superadmin')
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  tooltip: 'Редактировать',
                                  onPressed: () => _editProcurement(p),
                                ),
                              if (_currentUser?.role == 'superadmin')
                                const SizedBox(width: 8),
                              // Кнопка отклонения для суперадмина
                              if (_currentUser?.role == 'superadmin')
                                IconButton(
                                  icon: const Icon(Icons.undo, color: Colors.orange),
                                  tooltip: 'Отклонить',
                                  onPressed: () => _rejectProcurement(p),
                                ),
                            ]);
                          },
                        ),
                ],
              ),
      ),
    );
  }
}

class _ProcItem {
  final IconData icon;
  final String title;
  final String subtitle;
  const _ProcItem({required this.icon, required this.title, required this.subtitle});
}


