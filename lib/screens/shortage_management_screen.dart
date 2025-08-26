import 'package:flutter/material.dart';
import '../models/shortage.dart';
import '../services/shortage_service.dart';
import '../services/auth_service.dart';
import '../models/app_user.dart';

class ShortageManagementScreen extends StatefulWidget {
  const ShortageManagementScreen({super.key});

  @override
  State<ShortageManagementScreen> createState() => _ShortageManagementScreenState();
}

class _ShortageManagementScreenState extends State<ShortageManagementScreen> {
  final ShortageService _shortageService = ShortageService();
  final AuthService _authService = AuthService();
  AppUser? _currentUser;
  List<Shortage> _shortages = [];
  bool _loading = false;
  String? _error;
  ShortageStatus _selectedStatus = ShortageStatus.waiting;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      ),
      body: Column(
        children: [
          // Фильтр по статусу
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                const Text(
                  'Статус: ',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<ShortageStatus>(
                    value: _selectedStatus,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                                          items: ShortageStatus.values.map((status) {
                        return DropdownMenuItem(
                          value: status,
                          child: Text(_getStatusDisplayName(status)),
                        );
                      }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedStatus = value;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Статистика
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                _buildStatCard(
                  'Всего',
                  _shortages.length.toString(),
                  Colors.blue,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Ожидание',
                  _shortages.where((s) => s.status == ShortageStatus.waiting).length.toString(),
                  Colors.orange,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Получено',
                  _shortages.where((s) => s.status == ShortageStatus.received).length.toString(),
                  Colors.green,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Не получено',
                  _shortages.where((s) => s.status == ShortageStatus.notReceived).length.toString(),
                  Colors.red,
                ),
              ],
            ),
          ),
          
          // Список недостач
          Expanded(
            child: _buildShortagesList(),
          ),
        ],
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
          ],
        ),
      ),
    );
  }

  String _getStatusDisplayName(ShortageStatus status) {
    switch (status) {
      case ShortageStatus.waiting:
        return 'Ожидается';
      case ShortageStatus.received:
        return 'Довезли';
      case ShortageStatus.notReceived:
        return 'Не довезли';
    }
  }
}
