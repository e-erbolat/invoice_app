import 'package:flutter/material.dart';
import 'purchase_create_screen.dart';
import 'purchase_detail_screen.dart';
import 'purchase_archive_screen.dart';
import 'shortage_management_screen.dart';
import '../services/purchase_service.dart';
import '../models/purchase.dart';
import '../services/auth_service.dart';
import '../models/app_user.dart';
import '../services/satushi_api_service.dart';
import 'goods_receiving_screen.dart';

class ProductProcurementScreen extends StatefulWidget {
  const ProductProcurementScreen({super.key});

  @override
  State<ProductProcurementScreen> createState() => _ProductProcurementScreenState();
}

class _ProductProcurementScreenState extends State<ProductProcurementScreen> {
  final PurchaseService _purchaseService = PurchaseService();
  final AuthService _authService = AuthService();
  final SatushiApiService _satushiApiService = SatushiApiService();
  bool _loading = true;
  List<Purchase> _purchases = [];
  List<Purchase> _arrivals = [];
  List<Purchase> _shortages = [];
  List<Purchase> _forSales = [];
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
      // Получаем все закупы и фильтруем по статусам
      final allPurchases = await _purchaseService.getAllPurchases();
      if (!mounted) return;
      
      setState(() {
        _purchases = allPurchases.where((p) => p.status == PurchaseStatus.created).toList();
        _arrivals = allPurchases.where((p) => p.status == PurchaseStatus.receiving).toList();
        _shortages = allPurchases.where((p) => p.status == PurchaseStatus.inStock).toList();
        _forSales = allPurchases.where((p) => p.status == PurchaseStatus.onSale).toList();
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

  Future<void> _acceptToArrival(Purchase p) async {
    await _purchaseService.updatePurchaseStatus(p.id, PurchaseStatus.receiving);
    _load();
  }

  Future<void> _moveToShortage(Purchase p) async {
    await _purchaseService.updatePurchaseStatus(p.id, PurchaseStatus.inStock);
    _load();
  }

  Future<void> _moveToForSale(Purchase p) async {
    await _purchaseService.updatePurchaseStatus(p.id, PurchaseStatus.onSale);
    _load();
  }

  /// Оприходовать товары закупа через API Satushi
  Future<void> _stockItems(Purchase p) async {
    if (_currentUser?.satushiToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка: отсутствует токен Satushi в профиле'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      setState(() { _loading = true; });
      
      // Вызываем API для оприходования
      final success = await _satushiApiService.incomeRequest(
        p, 
        _currentUser!.satushiToken!
      );
      
      if (success) {
        // Если оприходование успешно, переводим на следующий этап
        await _purchaseService.updatePurchaseStatus(p.id, PurchaseStatus.inStock);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Товары успешно оприходованы!'),
            backgroundColor: Colors.green,
          ),
        );
        
        _load(); // Перезагружаем данные
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка оприходования: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _rejectProcurement(Purchase p) async {
    // Логика отклонения закупа
    await _purchaseService.updatePurchaseStatus(p.id, PurchaseStatus.closedWithShortage);
    _load();
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

  Future<void> _openArrivalVerification(Purchase p) async {
    // Навигация на экран сверки прихода
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const Scaffold(body: Center(child: Text('Экран сверки прихода'))),
      ),
    );
    if (result == true) {
      _load();
    }
  }

  void _openPurchaseDetails(Purchase p) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PurchaseDetailScreen(purchase: p),
      ),
    );
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
      length: 4,
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
              Tab(text: 'Выставка на продажу'),
              Tab(text: 'На продаже'),
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
                              // Кнопка отклонения для суперадмина (заменили иконку на более видимую)
                              if (_currentUser?.role == 'superadmin')
                                IconButton(
                                  icon: const Icon(Icons.cancel, color: Colors.red),
                                  tooltip: 'Отклонить',
                                  onPressed: () => _rejectProcurement(p),
                                ),
                              if (_currentUser?.role == 'superadmin')
                                const SizedBox(width: 8),
                              // Кнопка оприходования
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Оприходовать'),
                                onPressed: () => _stockItems(p),
                              ),
                              const SizedBox(width: 8),
                              // Кнопка "Готово" (переводит на следующий этап)
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Готово'),
                                onPressed: () => _moveToShortage(p),
                              ),
                            ]);
                          },
                        ),
                  // Закупы на выставке на продажу
                  _shortages.isEmpty
                      ? const Center(child: Text('Закупы на выставке на продажу отсутствуют'))
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
                                  icon: const Icon(Icons.cancel, color: Colors.red),
                                  tooltip: 'Отклонить',
                                  onPressed: () => _rejectProcurement(p),
                                ),
                              if (_currentUser?.role == 'superadmin')
                                const SizedBox(width: 8),
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
                  // Закупы на продаже
                  _forSales.isEmpty
                      ? const Center(child: Text('Закупы на продаже отсутствуют'))
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
                                  icon: const Icon(Icons.cancel, color: Colors.red),
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




