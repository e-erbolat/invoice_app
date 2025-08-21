import 'package:flutter/material.dart';
import '../models/shortage.dart';
import '../services/shortage_service.dart';
import '../services/auth_service.dart';
import '../models/app_user.dart';

class ShortageManagementScreen extends StatefulWidget {
  const ShortageManagementScreen({Key? key}) : super(key: key);

  @override
  State<ShortageManagementScreen> createState() => _ShortageManagementScreenState();
}

class _ShortageManagementScreenState extends State<ShortageManagementScreen>
    with SingleTickerProviderStateMixin {
  final ShortageService _shortageService = ShortageService();
  final AuthService _authService = AuthService();
  
  late TabController _tabController;
  List<Shortage> _waitingShortages = [];
  List<Shortage> _receivedShortages = [];
  List<Shortage> _notReceivedShortages = [];
  bool _isLoading = false;
  AppUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCurrentUser();
    _loadShortages();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    setState(() => _isLoading = true);
    
    try {
      final allShortages = await _shortageService.getAllShortages();
      
      if (mounted) {
        setState(() {
          _waitingShortages = allShortages.where((s) => s.isWaiting).toList();
          _receivedShortages = allShortages.where((s) => s.isReceived).toList();
          _notReceivedShortages = allShortages.where((s) => s.isNotReceived).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки недостач: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markAsReceived(Shortage shortage) async {
    try {
      await _shortageService.markShortageAsReceived(shortage.id);
      await _loadShortages();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Недостача отмечена как полученная'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markAsNotReceived(Shortage shortage) async {
    final noteController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Закрыть недостачу'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Товар "${shortage.productName}" не будет получен от поставщика.'),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Причина (необязательно)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _shortageService.markShortageAsNotReceived(
          shortage.id,
          note: noteController.text.isNotEmpty ? noteController.text : null,
        );
        await _loadShortages();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Недостача закрыта'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(
              text: 'Ожидаемые',
              icon: Icon(Icons.schedule),
            ),
            Tab(
              text: 'Полученные',
              icon: Icon(Icons.check_circle),
            ),
            Tab(
              text: 'Не полученные',
              icon: Icon(Icons.cancel),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildShortagesList(_waitingShortages, isWaiting: true),
                _buildShortagesList(_receivedShortages, isWaiting: false),
                _buildShortagesList(_notReceivedShortages, isWaiting: false),
              ],
            ),
    );
  }

  Widget _buildShortagesList(List<Shortage> shortages, {required bool isWaiting}) {
    if (shortages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isWaiting ? Icons.schedule : (shortages == _receivedShortages ? Icons.check_circle : Icons.cancel),
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              isWaiting 
                ? 'Нет ожидаемых недостач'
                : (shortages == _receivedShortages ? 'Нет полученных недостач' : 'Нет закрытых недостач'),
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: shortages.length,
      itemBuilder: (context, index) {
        final shortage = shortages[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        shortage.productName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${shortage.purchasePrice.toStringAsFixed(2)} ₸',
                        style: TextStyle(
                          color: Colors.blue.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Заказано:',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            '${shortage.orderedQty} шт.',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Недостача:',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            '${shortage.missingQty} шт.',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                Text(
                  'Закуп: ${shortage.purchaseId}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                
                if (shortage.note != null && shortage.note!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Примечание: ${shortage.note}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
                
                if (shortage.isWaiting) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _markAsReceived(shortage),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Отметить как полученное'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _markAsNotReceived(shortage),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Закрыть'),
                        ),
                      ),
                    ],
                  ),
                ],
                
                if (shortage.isReceived) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade800, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Получено ${shortage.receivedAt?.toDate().day.toString().padLeft(2,'0')}.${shortage.receivedAt?.toDate().month.toString().padLeft(2,'0')}.${shortage.receivedAt?.toDate().year}',
                          style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
                
                if (shortage.isNotReceived) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cancel, color: Colors.orange.shade800, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Закрыто ${shortage.closedAt?.toDate().day.toString().padLeft(2,'0')}.${shortage.closedAt?.toDate().month.toString().padLeft(2,'0')}.${shortage.closedAt?.toDate().year}',
                          style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
