import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shortage.dart';
import '../services/purchase_service.dart';

class ShortageManagementScreen extends StatefulWidget {
  final String purchaseId;

  const ShortageManagementScreen({Key? key, required this.purchaseId}) : super(key: key);

  @override
  State<ShortageManagementScreen> createState() => _ShortageManagementScreenState();
}

class _ShortageManagementScreenState extends State<ShortageManagementScreen> {
  final PurchaseService _purchaseService = PurchaseService();
  List<Shortage> _shortages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadShortages();
  }

  Future<void> _loadShortages() async {
    setState(() => _isLoading = true);
    try {
      final shortages = await _purchaseService.getShortages(purchaseId: widget.purchaseId);
      setState(() {
        _shortages = shortages;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки недостач: $e')),
        );
      }
    }
  }

  Future<void> _receiveShortage(Shortage shortage) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Подтвердить получение'),
        content: Text('Отметить недостачу "${shortage.productName}" как полученную?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Получено'),
          ),
        ],
      ),
    );

    if (result != true) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Пользователь не авторизован');

      await _purchaseService.receiveShortage(
        shortageId: shortage.id,
        userId: user.uid,
        userName: user.displayName ?? user.email ?? 'Unknown',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Недостача отмечена как полученная')),
        );
        _loadShortages();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  Future<void> _closeShortageAsNotReceived(Shortage shortage) async {
    final notesController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Закрыть недостачу'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Закрыть недостачу "${shortage.productName}" как не полученную?'),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Причина (необязательно)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );

    if (result != true) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Пользователь не авторизован');

      await _purchaseService.closeShortageAsNotReceived(
        shortageId: shortage.id,
        userId: user.uid,
        userName: user.displayName ?? user.email ?? 'Unknown',
        notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Недостача закрыта')),
        );
        _loadShortages();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      notesController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final openShortages = _shortages.where((s) => s.status == Shortage.statusWaiting).toList();
    final closedShortages = _shortages.where((s) => s.status != Shortage.statusWaiting).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Управление недостачами'),
        actions: [
          IconButton(
            onPressed: _loadShortages,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _shortages.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text(
                    'Нет недостач',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Открытые недостачи
                  if (openShortages.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: Colors.orange.shade50,
                      child: Text(
                        'Ожидается от поставщика (${openShortages.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                    ...openShortages.map((shortage) => _buildShortageCard(shortage, true)),
                  ],
                  
                  // Закрытые недостачи
                  if (closedShortages.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: Colors.grey.shade100,
                      child: Text(
                        'Закрытые недостачи (${closedShortages.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    ...closedShortages.map((shortage) => _buildShortageCard(shortage, false)),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildShortageCard(Shortage shortage, bool isOpen) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        title: Text(
          shortage.productName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Штрихкод: ${shortage.productBarcode}'),
            Text('Недостача: ${shortage.missingQty} шт'),
            Text('Сумма: ${shortage.totalMissingAmount.toStringAsFixed(2)} ₽'),
            Text('Создано: ${_formatDate(shortage.dateCreated)}'),
            if (shortage.dateClosed != null)
              Text('Закрыто: ${_formatDate(shortage.dateClosed!)}'),
            if (shortage.notes != null)
              Text('Примечания: ${shortage.notes}'),
          ],
        ),
        trailing: isOpen
            ? PopupMenuButton<String>(
                onSelected: (action) {
                  switch (action) {
                    case 'received':
                      _receiveShortage(shortage);
                      break;
                    case 'not_received':
                      _closeShortageAsNotReceived(shortage);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'received',
                    child: Row(
                      children: [
                        Icon(Icons.check, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Получено'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'not_received',
                    child: Row(
                      children: [
                        Icon(Icons.close, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Не получено'),
                      ],
                    ),
                  ),
                ],
              )
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getShortageStatusColor(shortage.status),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  shortage.statusDisplayName,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
      ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Color _getShortageStatusColor(String status) {
    switch (status) {
      case Shortage.statusWaiting:
        return Colors.orange;
      case Shortage.statusReceived:
        return Colors.green;
      case Shortage.statusNotReceived:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}