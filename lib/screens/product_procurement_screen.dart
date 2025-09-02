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
  List<Purchase> _created = [];
  List<Purchase> _receiving = [];
  List<Purchase> _inStock = [];
  List<Purchase> _forSale = [];
  List<Purchase> _onSale = [];
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
        _created = allPurchases.where((p) => p.status == PurchaseStatus.created).toList();
        _receiving = allPurchases.where((p) => p.status == PurchaseStatus.receiving).toList();
        _inStock = allPurchases.where((p) => p.status == PurchaseStatus.stocked).toList();
        _forSale = allPurchases.where((p) => p.status == PurchaseStatus.inStock).toList();
        _onSale = allPurchases.where((p) => p.status == PurchaseStatus.onSale || p.status == PurchaseStatus.completed || p.status == PurchaseStatus.closedWithShortage).toList();
        _filteredArchived = List.from(_onSale);
        _loading = false;
      });
      
      // Логируем количество закупов в каждом статусе для отладки
      debugPrint('[ProductProcurementScreen] Загружено закупов:');
      debugPrint('  - Созданные: ${_created.length}');
      debugPrint('  - Оприходывание: ${_receiving.length}');
      debugPrint('  - Принять на склад: ${_inStock.length}');
      debugPrint('  - Выставка на продажу: ${_forSale.length}');
      debugPrint('  - В архиве: ${_onSale.length}');
      
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

  Future<void> _moveToReceiving(Purchase p) async {
    // Проверяем, была ли приемка
    if (p.totalReceivedQuantity == 0) {
      // Если приемки не было, перекидываем на страницу приемки
      await _openGoodsReceiving(p);
      return;
    }
    // Если приемка была, переводим на следующий этап (created -> receiving)
    await _purchaseService.updatePurchaseStatus(p.id, PurchaseStatus.receiving);
    _load();
  }



  Future<void> _moveToInStock(Purchase p) async {
    // Переводим закуп из статуса stocked в inStock (Принять на склад)
    await _purchaseService.updatePurchaseStatus(p.id, PurchaseStatus.inStock);
    _load();
  }

  Future<void> _moveToForSale(Purchase p) async {
    // Переводим закуп из статуса inStock в onSale (Выставка на продажу)
    await _purchaseService.updatePurchaseStatus(p.id, PurchaseStatus.onSale);
    _load();
  }



  Future<void> _rejectProcurement(Purchase p) async {
    // Переводим на предыдущий этап в зависимости от текущего статуса
    PurchaseStatus newStatus;
    switch (p.status) {
      case PurchaseStatus.receiving:
        newStatus = PurchaseStatus.created;        // receiving -> created
        break;
      case PurchaseStatus.stocked:
        newStatus = PurchaseStatus.receiving;      // stocked -> receiving
        break;
      case PurchaseStatus.inStock:
        newStatus = PurchaseStatus.stocked;        // inStock -> stocked
        break;
      case PurchaseStatus.onSale:
        newStatus = PurchaseStatus.inStock;        // onSale -> inStock
        break;
      default:
        newStatus = PurchaseStatus.created;
    }
    
    await _purchaseService.updatePurchaseStatus(p.id, newStatus);
    _load();
  }

  /// Фильтрация архива заказов по дате (статус onSale, completed, closedWithShortage)
  void _filterArchive() {
    List<Purchase> filtered = _onSale;
    
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

  /// Выбор даты для фильтра архива (статус onSale, completed, closedWithShortage)
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
    // Навигация на экран редактирования закупа
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
    // Открываем экран приемки товаров для закупа
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GoodsReceivingScreen(purchase: p),
      ),
    );
    _load();
  }



  Future<void> _openPurchaseDetails(Purchase p) async {
    // Открываем экран деталей закупа
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
    // Открываем экран архива закупов
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PurchaseArchiveScreen(),
      ),
    );
  }

  void _openShortageManagement() {
    // Открываем экран управления недостачами
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ShortageManagementScreen(),
      ),
    );
  }

  Widget _buildCard(Purchase p, {List<Widget> trailingActions = const []}) {
    // Строим карточку закупа с действиями
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
    // Строим основной интерфейс экрана закупов
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
          bottom: TabBar(
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Ожидание'),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _created.length.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Оприходывание'),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _receiving.length.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Принять на склад'),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _inStock.length.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Выставка на продажу'),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.purple,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _forSale.length.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Архив заказов'),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _onSale.length.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.purple,
          ),
        ),
        floatingActionButton: FloatingActionButton(
          // Кнопка создания нового закупа
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
                  // Содержимое вкладок по статусам закупов
                  children: [
                  // Закупы в ожидании (статус created -> receiving)
                  _created.isEmpty
                      ? const Center(child: Text('Закупы в ожидании отсутствуют'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _created.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final p = _created[i];
                            return _buildCard(p, trailingActions: [
                              // Кнопка редактирования для суперадмина
                              if (_currentUser?.role == 'superadmin')
                                                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                tooltip: 'Редактировать',  // Редактировать закуп
                                onPressed: () => _editProcurement(p),
                              ),
                              if (_currentUser?.role == 'superadmin')
                                const SizedBox(width: 8),
                              // Кнопка отклонения для суперадмина
                              if (_currentUser?.role == 'superadmin')
                                IconButton(
                                  icon: const Icon(Icons.cancel, color: Colors.red),
                                  tooltip: 'Отклонить',  // Вернуть на предыдущий этап
                                  onPressed: () => _rejectProcurement(p),
                                ),
                              if (_currentUser?.role == 'superadmin')
                                const SizedBox(width: 8),
                              ElevatedButton(
                                child: const Text('Принять'),  // Перевести в статус receiving
                                onPressed: () => _moveToReceiving(p),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Приемка'),  // Открыть экран приемки товаров
                                onPressed: () => _openGoodsReceiving(p),
                              ),
                            ]);
                          },
                        ),
                  // Закупы на оприходывании (статус receiving -> stocked)
                                      _receiving.isEmpty
                        ? const Center(child: Text('Закупы на оприходывании отсутствуют'))
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _receiving.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, i) {
                              final p = _receiving[i];
                            return _buildCard(p, trailingActions: [
                              // Кнопка отклонения только для суперадмина
                              if (_currentUser?.role == 'superadmin')
                                IconButton(
                                  icon: const Icon(Icons.cancel, color: Colors.red),
                                  tooltip: 'Отклонить',  // Вернуть на предыдущий этап
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
                  // Закупы на этапе "Принять на склад" (статус stocked -> inStock)
                  _inStock.isEmpty
                      ? const Center(child: Text('Закупы для принятия на склад отсутствуют'))
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
                                  tooltip: 'Отклонить',  // Вернуть на предыдущий этап
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
                                child: const Text('Принять на склад'),  // Перевести в статус inStock
                                onPressed: () => _moveToInStock(p),
                              ),
                            ]);
                          },
                        ),
                  // Закупы на выставке на продажу (статус inStock -> onSale)
                  _forSale.isEmpty
                      ? const Center(child: Text('Закупы для выставки на продажу отсутствуют'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _forSale.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final p = _forSale[i];
                            return _buildCard(p, trailingActions: [
                              // Кнопка отклонения для суперадмина
                              if (_currentUser?.role == 'superadmin')
                                IconButton(
                                  icon: const Icon(Icons.cancel, color: Colors.red),
                                  tooltip: 'Отклонить',  // Вернуть на предыдущий этап
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
                                child: const Text('Выставить на продажу'),  // Перевести в статус onSale
                                onPressed: () => _moveToForSale(p),
                              ),
                            ]);
                          },
                        ),
                  // Архив заказов (статус onSale, completed, closedWithShortage)
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




