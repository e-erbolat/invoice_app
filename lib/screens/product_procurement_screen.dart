import 'package:flutter/material.dart';
import 'purchase_create_screen.dart';
import 'purchase_detail_screen.dart';
import 'purchase_archive_screen.dart';
import 'shortage_management_screen.dart';
import '../services/purchase_service.dart';
import '../models/purchase.dart';
import '../services/auth_service.dart';
import '../models/app_user.dart';
import 'goods_receiving_screen.dart';

class ProductProcurementScreen extends StatefulWidget {
  const ProductProcurementScreen({super.key});

  @override
  State<ProductProcurementScreen> createState() => _ProductProcurementScreenState();
}

class _ProductProcurementScreenState extends State<ProductProcurementScreen> {
  final PurchaseService _purchaseService = PurchaseService();
  final AuthService _authService = AuthService();
  bool _loading = true;
  List<Purchase> _purchases = [];
  List<Purchase> _arrivals = [];
  List<Purchase> _stocked = [];
  List<Purchase> _inStock = [];
  List<Purchase> _archived = [];
  List<Purchase> _filteredArchived = [];
  String? _error;
  AppUser? _currentUser;
  DateTime? _archiveDateFrom;
  DateTime? _archiveDateTo;

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
      // Получаем все закупы и фильтруем по статусам
      final allPurchases = await _purchaseService.getAllPurchases();
      if (!mounted) return;
      
      setState(() {
        _purchases = allPurchases.where((p) => p.status == PurchaseStatus.created).toList();
        _arrivals = allPurchases.where((p) => p.status == PurchaseStatus.receiving).toList();
        _stocked = allPurchases.where((p) => p.status == PurchaseStatus.stocked).toList();
        _inStock = allPurchases.where((p) => p.status == PurchaseStatus.inStock).toList();
        _archived = allPurchases.where((p) => p.status == PurchaseStatus.archived || p.status == PurchaseStatus.completed || p.status == PurchaseStatus.closedWithShortage).toList();
        _filteredArchived = List.from(_archived);
        _loading = false;
      });
      
      // Логируем количество закупов в каждом статусе для отладки
      debugPrint('[ProductProcurementScreen] Загружено закупов:');
      debugPrint('  - Созданные: ${_purchases.length}');
      debugPrint('  - На приемке: ${_arrivals.length}');
      debugPrint('  - Оприходовано: ${_stocked.length}');
      debugPrint('  - Принято на склад: ${_inStock.length}');
      debugPrint('  - В архиве: ${_archived.length}');
      
      // Логируем детали каждого закупа для отладки
      for (final purchase in allPurchases) {
        debugPrint('[ProductProcurementScreen] Закуп ID=${purchase.id}, Поставщик=${purchase.supplierName}, Статус=${purchase.status} (${purchase.statusDisplayName})');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _acceptToArrival(Purchase p) async {
    // Проверяем, была ли приемка
    if (p.totalReceivedQuantity == 0) {
      // Если приемки не было, перекидываем на страницу приемки
      await _openGoodsReceiving(p);
      return;
    }
    // Если приемка была, переводим на следующий этап
    await _purchaseService.updatePurchaseStatus(p.id, PurchaseStatus.receiving);
    _load();
  }



  Future<void> _moveToInStock(Purchase p) async {
    await _purchaseService.updatePurchaseStatus(p.id, PurchaseStatus.inStock);
    _load();
  }

  Future<void> _moveToForSale(Purchase p) async {
    await _purchaseService.updatePurchaseStatus(p.id, PurchaseStatus.onSale);
    _load();
  }



  Future<void> _rejectProcurement(Purchase p) async {
    // Переводим на предыдущий этап в зависимости от текущего статуса
    PurchaseStatus newStatus;
    switch (p.status) {
      case PurchaseStatus.receiving:
        newStatus = PurchaseStatus.created;
        break;
      case PurchaseStatus.stocked:
        newStatus = PurchaseStatus.receiving;
        break;
      case PurchaseStatus.inStock:
        newStatus = PurchaseStatus.stocked;
        break;
      case PurchaseStatus.onSale:
        newStatus = PurchaseStatus.inStock;
        break;
      default:
        newStatus = PurchaseStatus.created;
    }
    
    await _purchaseService.updatePurchaseStatus(p.id, newStatus);
    _load();
  }

  /// Фильтрация архива заказов по дате
  void _filterArchive() {
    List<Purchase> filtered = _archived;
    
    if (_archiveDateFrom != null) {
      filtered = filtered.where((p) => 
        p.dateCreated.toDate().isAfter(_archiveDateFrom!) || 
        p.dateCreated.toDate().isAtSameMomentAs(_archiveDateFrom!)
      ).toList();
    }
    
    if (_archiveDateTo != null) {
      filtered = filtered.where((p) => 
        p.dateCreated.toDate().isBefore(_archiveDateTo!.add(const Duration(days: 1)))
      ).toList();
    }
    
    setState(() {
      _filteredArchived = filtered;
    });
  }

  /// Выбор даты для фильтра архива
  Future<void> _selectArchiveDate(BuildContext context, bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (_archiveDateFrom ?? DateTime.now()) : (_archiveDateTo ?? DateTime.now()),
      firstDate: DateTime(2022),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _archiveDateFrom = picked;
        } else {
          _archiveDateTo = picked;
        }
      });
      _filterArchive();
    }
  }

  Future<void> _editProcurement(Purchase p) async {
    // Навигация на экран редактирования
    debugPrint('Открытие редактирования закупа: ID=${p.id}, Поставщик=${p.supplierName}');
    debugPrint('Firestore ID: ${p.id}');
    
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PurchaseCreateScreen(purchaseToEdit: p),
      ),
    );
    _load(); // Перезагружаем данные после редактирования
  }





  Future<void> _openGoodsReceiving(Purchase p) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GoodsReceivingScreen(purchase: p),
      ),
    );
    _load();
  }



  Future<void> _openPurchaseDetails(Purchase p) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PurchaseDetailScreen(purchase: p),
      ),
    );
    
    // Если закуп был оприходован, перезагружаем данные
    if (result == 'stocked') {
      _load();
    }
  }

  void _openArchive() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PurchaseArchiveScreen(),
      ),
    );
  }

  void _openShortageManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ShortageManagementScreen(),
      ),
    );
  }

  Widget _buildCard(Purchase p, {List<Widget> trailingActions = const []}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.shopping_bag, color: Colors.blue),
        title: Text(p.supplierName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Дата: ${p.dateCreated.toDate().day.toString().padLeft(2,'0')}.${p.dateCreated.toDate().month.toString().padLeft(2,'0')}.${p.dateCreated.toDate().year}  •  Итого: ${p.totalAmount.toStringAsFixed(2)} ₸',
            ),
            if (p.status == PurchaseStatus.inStock && p.items.isNotEmpty)
              Text(
                'Статус: ${p.statusDisplayName}',
                style: const TextStyle(
                  color: Colors.blue,
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
        onTap: () => _openPurchaseDetails(p),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
            return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Закуп товара'),
          actions: [
            IconButton(
              onPressed: _openShortageManagement,
              icon: const Icon(Icons.warning),
              tooltip: 'Управление недостачами',
            ),
            IconButton(
              onPressed: _openArchive,
              icon: const Icon(Icons.archive),
              tooltip: 'Архив закупов',
            ),
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Ожидание'),
              Tab(text: 'Оприходывание'),
              Tab(text: 'Принять на склад'),
              Tab(text: 'Выставка на продажу'),
              Tab(text: 'Архив заказов'),
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
          tooltip: 'Создать закуп',
          child: const Icon(Icons.add),
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
                        ElevatedButton(
                          onPressed: _load,
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  )
                : TabBarView(
                children: [
                  // Закупы в ожидании
                  _purchases.isEmpty
                      ? const Center(child: Text('Закупы в ожидании отсутствуют'))
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
                                  icon: const Icon(Icons.cancel, color: Colors.red),
                                  tooltip: 'Отклонить',
                                  onPressed: () => _rejectProcurement(p),
                                ),
                              if (_currentUser?.role == 'superadmin')
                                const SizedBox(width: 8),
                              ElevatedButton(
                                child: const Text('Принять'),
                                onPressed: () => _acceptToArrival(p),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Приемка'),
                                onPressed: () => _openGoodsReceiving(p),
                              ),
                            ]);
                          },
                        ),
                  // Закупы на оприходывании
                  _arrivals.isEmpty
                      ? const Center(child: Text('Закупы на оприходывании отсутствуют'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _arrivals.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final p = _arrivals[i];
                            return _buildCard(p, trailingActions: [
                              // Кнопка отклонения только для суперадмина
                              if (_currentUser?.role == 'superadmin')
                                IconButton(
                                  icon: const Icon(Icons.cancel, color: Colors.red),
                                  tooltip: 'Отклонить',
                                  onPressed: () => _rejectProcurement(p),
                                ),
                              if (_currentUser?.role == 'superadmin')
                                const SizedBox(width: 8),
                              // Кнопка просмотра деталей (для всех)
                              IconButton(
                                icon: const Icon(Icons.visibility, color: Colors.blue),
                                tooltip: 'Просмотреть детали',
                                onPressed: () => _openPurchaseDetails(p),
                              ),
                            ]);
                          },
                        ),
                  // Закупы на этапе "Принять на склад"
                  _stocked.isEmpty
                      ? const Center(child: Text('Закупы для принятия на склад отсутствуют'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _stocked.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final p = _stocked[i];
                            return _buildCard(p, trailingActions: [
                              // Кнопка отклонения для суперадмина
                              if (_currentUser?.role == 'superadmin')
                                IconButton(
                                  icon: const Icon(Icons.cancel, color: Colors.red),
                                  tooltip: 'Отклонить',
                                  onPressed: () => _rejectProcurement(p),
                                ),
                              if (_currentUser?.role == 'superadmin')
                                const SizedBox(width: 8),
                              // Кнопка принятия на склад
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Принять на склад'),
                                onPressed: () => _moveToInStock(p),
                              ),
                            ]);
                          },
                        ),
                  // Закупы на выставке на продажу
                  _inStock.isEmpty
                      ? const Center(child: Text('Закупы для выставки на продажу отсутствуют'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _inStock.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final p = _inStock[i];
                            return _buildCard(p, trailingActions: [
                              // Кнопка отклонения для суперадмина
                              if (_currentUser?.role == 'superadmin')
                                IconButton(
                                  icon: const Icon(Icons.cancel, color: Colors.red),
                                  tooltip: 'Отклонить',
                                  onPressed: () => _rejectProcurement(p),
                                ),
                              if (_currentUser?.role == 'superadmin')
                                const SizedBox(width: 8),
                              // Кнопка выставки на продажу
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Выставить на продажу'),
                                onPressed: () => _moveToForSale(p),
                              ),
                            ]);
                          },
                        ),
                  // Архив заказов
                  Column(
                    children: [
                      // Фильтры по дате
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                readOnly: true,
                                decoration: InputDecoration(
                                  labelText: 'Дата с',
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.calendar_today),
                                    onPressed: () => _selectArchiveDate(context, true),
                                  ),
                                ),
                                controller: TextEditingController(
                                  text: _archiveDateFrom != null 
                                    ? '${_archiveDateFrom!.day.toString().padLeft(2,'0')}.${_archiveDateFrom!.month.toString().padLeft(2,'0')}.${_archiveDateFrom!.year}'
                                    : '',
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                readOnly: true,
                                decoration: InputDecoration(
                                  labelText: 'Дата по',
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.calendar_today),
                                    onPressed: () => _selectArchiveDate(context, false),
                                  ),
                                ),
                                controller: TextEditingController(
                                  text: _archiveDateTo != null 
                                    ? '${_archiveDateTo!.day.toString().padLeft(2,'0')}.${_archiveDateTo!.month.toString().padLeft(2,'0')}.${_archiveDateTo!.year}'
                                    : '',
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _archiveDateFrom = null;
                                  _archiveDateTo = null;
                                });
                                _filterArchive();
                              },
                              child: const Text('Сбросить'),
                            ),
                          ],
                        ),
                      ),
                      // Список заказов
                      Expanded(
                        child: _filteredArchived.isEmpty
                            ? const Center(child: Text('Архив заказов пуст'))
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: _filteredArchived.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, i) {
                                  final p = _filteredArchived[i];
                                  return _buildCard(p, trailingActions: [
                                    // Кнопка просмотра деталей
                                    IconButton(
                                      icon: const Icon(Icons.visibility, color: Colors.blue),
                                      tooltip: 'Просмотреть детали',
                                      onPressed: () => _openPurchaseDetails(p),
                                    ),
                                  ]);
                                },
                              ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}




