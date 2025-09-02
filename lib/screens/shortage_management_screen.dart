import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/shortage.dart';
import '../services/shortage_service.dart';
import '../services/auth_service.dart';
import '../services/satushi_api_service.dart';
import '../models/app_user.dart';

class ShortageManagementScreen extends StatefulWidget {
  const ShortageManagementScreen({super.key});

  @override
  State<ShortageManagementScreen> createState() => _ShortageManagementScreenState();
}

class _ShortageManagementScreenState extends State<ShortageManagementScreen> {
  final ShortageService _shortageService = ShortageService();
  final AuthService _authService = AuthService();
  final SatushiApiService _satushiApiService = SatushiApiService();
  AppUser? _currentUser;
  List<Shortage> _shortages = [];
  bool _loading = false;
  String? _error;
  ShortageStatus _selectedStatus = ShortageStatus.waiting;
  final Map<String, bool> _stockingInProgress = {};

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadShortages();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _authService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }
  }

  Future<void> _loadShortages() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Получаем все недостачи
      final allShortages = await _shortageService.getAllShortages();
      
      // Группируем по purchaseId и очищаем дубликаты для каждого закупа
      final purchaseIds = allShortages.map((s) => s.purchaseId).toSet();
      for (final purchaseId in purchaseIds) {
        await _shortageService.removeDuplicateShortages(purchaseId);
      }
      
      // Загружаем недостачи заново после очистки
      final shortages = await _shortageService.getAllShortages();
      if (mounted) {
        setState(() {
          _shortages = shortages;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Ошибка загрузки недостач: $e';
          _loading = false;
        });
      }
    }
  }

  List<Shortage> get _filteredShortages {
    return _shortages.where((shortage) => shortage.status == _selectedStatus).toList();
  }

  Future<void> _markShortageAsReceived(Shortage shortage) async {
    try {
      await _shortageService.markShortageAsReceived(
        shortage.id,
        userId: _currentUser?.uid,
        userName: _currentUser?.name ?? _currentUser?.email,
      );
      _loadShortages();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Недостача отмечена как полученная')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _markShortageAsStocked(Shortage shortage) async {
    try {
      // Проверяем наличие токена Satushi
      if (_currentUser?.satushiToken == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка: отсутствует токен Satushi в профиле'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Устанавливаем индикатор загрузки для этой недостачи
      setState(() {
        _stockingInProgress[shortage.id] = true;
      });

      // Вызываем Satushi API для оприходывания только недостачи
      final success = await _satushiApiService.incomeShortageRequest(
        [shortage], // Передаем список с одной недостачей
        _currentUser!.satushiToken!
      );

      if (success) {
        // Если API вызов успешен, обновляем статус недостачи
        await _shortageService.markShortageAsStocked(
          shortage.id,
          userId: _currentUser?.uid,
          userName: _currentUser?.name ?? _currentUser?.email,
        );
        _loadShortages();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Недостача успешно оприходована через Satushi API!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Оприходывание недостачи через Satushi API не удалось');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка оприходывания недостачи: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      // Убираем индикатор загрузки
      setState(() {
        _stockingInProgress[shortage.id] = false;
      });
    }
  }

  Future<void> _markShortageAsInStock(Shortage shortage) async {
    try {
      await _shortageService.markShortageAsInStock(
        shortage.id,
        userId: _currentUser?.uid,
        userName: _currentUser?.name ?? _currentUser?.email,
      );
      _loadShortages();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Недостача принята на склад')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _markShortageAsOnSale(Shortage shortage) async {
    try {
      await _shortageService.markShortageAsOnSale(
        shortage.id,
        userId: _currentUser?.uid,
        userName: _currentUser?.name ?? _currentUser?.email,
      );
      _loadShortages();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Недостача выставлена на продажу')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _markShortageAsCompleted(Shortage shortage) async {
    try {
      await _shortageService.markShortageAsCompleted(
        shortage.id,
        userId: _currentUser?.uid,
        userName: _currentUser?.name ?? _currentUser?.email,
      );
      _loadShortages();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Недостача завершена')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _markShortageAsNotReceived(Shortage shortage) async {
    try {
      await _shortageService.markShortageAsNotReceived(
        shortage.id,
        userId: _currentUser?.uid,
        userName: _currentUser?.name ?? _currentUser?.email,
      );
      _loadShortages();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Недостача отмечена как не полученная')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }



  // Метод для построения списка недостач по статусу
  Widget _buildShortagesListByStatus(ShortageStatus status) {
    final filteredShortages = _shortages.where((s) => s.status == status).toList();
    
    if (filteredShortages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Нет недостач со статусом "${_getStatusDisplayName(status)}"',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredShortages.length,
      itemBuilder: (context, index) {
        final shortage = filteredShortages[index];
        return _buildShortageCard(shortage);
      },
    );
  }

  // Метод для получения отображаемого названия статуса
  String _getStatusDisplayName(ShortageStatus status) {
    switch (status) {
      case ShortageStatus.waiting:
        return 'Ожидается';
      case ShortageStatus.received:
        return 'Оприходывание';
      case ShortageStatus.stocked:
        return 'Принять на склад';
      case ShortageStatus.inStock:
        return 'Выставка на продажу';
      case ShortageStatus.onSale:
        return 'Архив заказов';
      case ShortageStatus.completed:
        return 'Завершено';
      case ShortageStatus.notReceived:
        return 'Не довезли';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6, // Количество табов
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Управление недостачами'),
          backgroundColor: Colors.white,
          elevation: 2,
          foregroundColor: Colors.black,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadShortages,
              tooltip: 'Обновить',
            ),
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
                        _shortages.where((s) => s.status == ShortageStatus.waiting).length.toString(),
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
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _shortages.where((s) => s.status == ShortageStatus.received).length.toString(),
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
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _shortages.where((s) => s.status == ShortageStatus.stocked).length.toString(),
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
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _shortages.where((s) => s.status == ShortageStatus.inStock).length.toString(),
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
                        color: Colors.purple,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _shortages.where((s) => s.status == ShortageStatus.onSale || s.status == ShortageStatus.completed).length.toString(),
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
                    const Text('Завершенные'),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _shortages.where((s) => s.status == ShortageStatus.completed).length.toString(),
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
        body: TabBarView(
          children: [
            // Таб "Ожидание"
            _buildShortagesListByStatus(ShortageStatus.waiting),
            // Таб "Оприходывание"
            _buildShortagesListByStatus(ShortageStatus.received),
            // Таб "Принять на склад"
            _buildShortagesListByStatus(ShortageStatus.stocked),
            // Таб "Выставка на продажу"
            _buildShortagesListByStatus(ShortageStatus.inStock),
            // Таб "Архив заказов"
            _buildShortagesListByStatus(ShortageStatus.onSale),
            // Таб "Завершенные"
            _buildShortagesListByStatus(ShortageStatus.completed),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortagesList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadShortages,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    final filteredShortages = _filteredShortages;

    if (filteredShortages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
                             'Нет недостач со статусом "${_getStatusDisplayName(_selectedStatus)}"',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Попробуйте выбрать другой статус',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadShortages,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredShortages.length,
        itemBuilder: (context, index) {
          final shortage = filteredShortages[index];
          return _buildShortageCard(shortage);
        },
      ),
    );
  }

  Widget _buildShortageCard(Shortage shortage) {
    final createdAt = shortage.createdAt.toDate();
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    shortage.productName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(shortage.statusColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    shortage.statusDisplayName,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.warning, color: Colors.red[600], size: 14),
                const SizedBox(width: 4),
                Text(
                  'Недостача: ${shortage.missingQty} шт.',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.grey[600], size: 14),
                const SizedBox(width: 4),
                Text(
                  'Создана: ${createdAt.day.toString().padLeft(2,'0')}.${createdAt.month.toString().padLeft(2,'0')}.${createdAt.year}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
            if (shortage.notes != null && shortage.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.note, color: Colors.grey[600], size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      shortage.notes!,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600], fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ],
            // Отображение дат переходов
            if (shortage.receivedAt != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[600], size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Получено: ${shortage.receivedAt!.toDate().day.toString().padLeft(2,'0')}.${shortage.receivedAt!.toDate().month.toString().padLeft(2,'0')}.${shortage.receivedAt!.toDate().year}',
                    style: TextStyle(fontSize: 14, color: Colors.green[600]),
                  ),
                ],
              ),
            ],
            if (shortage.stockedAt != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.inventory, color: Colors.blue[600], size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Оприходовано: ${shortage.stockedAt!.toDate().day.toString().padLeft(2,'0')}.${shortage.stockedAt!.toDate().month.toString().padLeft(2,'0')}.${shortage.stockedAt!.toDate().year}',
                    style: TextStyle(fontSize: 14, color: Colors.blue[600]),
                  ),
                ],
              ),
            ],
            if (shortage.inStockAt != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.warehouse, color: Colors.green[600], size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Принято на склад: ${shortage.inStockAt!.toDate().day.toString().padLeft(2,'0')}.${shortage.inStockAt!.toDate().month.toString().padLeft(2,'0')}.${shortage.inStockAt!.toDate().year}',
                    style: TextStyle(fontSize: 14, color: Colors.green[600]),
                  ),
                ],
              ),
            ],
            if (shortage.onSaleAt != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.shopping_cart, color: Colors.purple[600], size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Выставлено на продажу: ${shortage.onSaleAt!.toDate().day.toString().padLeft(2,'0')}.${shortage.onSaleAt!.toDate().month.toString().padLeft(2,'0')}.${shortage.onSaleAt!.toDate().year}',
                    style: TextStyle(fontSize: 14, color: Colors.purple[600]),
                  ),
                ],
              ),
            ],
            if (shortage.completedAt != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[600], size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Завершено: ${shortage.completedAt!.toDate().day.toString().padLeft(2,'0')}.${shortage.completedAt!.toDate().month.toString().padLeft(2,'0')}.${shortage.completedAt!.toDate().year}',
                    style: TextStyle(fontSize: 14, color: Colors.green[600]),
                  ),
                ],
              ),
            ],
            // Отображение информации о том, кто выполнил действия
            if (shortage.receivedByUserName != null) ...[
              const SizedBox(height: 4),
              Text(
                'Получил: ${shortage.receivedByUserName}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
              ),
            ],
            if (shortage.stockedByUserName != null) ...[
              const SizedBox(height: 4),
              Text(
                'Оприходовал: ${shortage.stockedByUserName}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
              ),
            ],
            if (shortage.inStockByUserName != null) ...[
              const SizedBox(height: 4),
              Text(
                'Принял на склад: ${shortage.inStockByUserName}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
              ),
            ],
            if (shortage.onSaleByUserName != null) ...[
              const SizedBox(height: 4),
              Text(
                'Выставил на продажу: ${shortage.onSaleByUserName}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
              ),
            ],
            if (shortage.completedByUserName != null) ...[
              const SizedBox(height: 4),
              Text(
                'Завершил: ${shortage.completedByUserName}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
              ),
            ],
            if (shortage.status == ShortageStatus.waiting) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _markShortageAsReceived(shortage),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Получено'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _markShortageAsNotReceived(shortage),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Не получено'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (shortage.status == ShortageStatus.received) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _stockingInProgress[shortage.id] == true 
                          ? null 
                          : () => _markShortageAsStocked(shortage),
                      icon: _stockingInProgress[shortage.id] == true
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.inventory, size: 16),
                      label: Text(
                        _stockingInProgress[shortage.id] == true 
                            ? 'Оприходование...' 
                            : 'Оприходовать',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (shortage.status == ShortageStatus.stocked) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _markShortageAsInStock(shortage),
                      icon: const Icon(Icons.warehouse, size: 16),
                      label: const Text('Принять на склад'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (shortage.status == ShortageStatus.inStock) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _markShortageAsOnSale(shortage),
                      icon: const Icon(Icons.shopping_cart, size: 16),
                      label: const Text('Выставить на продажу'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (shortage.status == ShortageStatus.onSale) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _markShortageAsCompleted(shortage),
                      icon: const Icon(Icons.check_circle, size: 16),
                      label: const Text('Завершить'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

}
