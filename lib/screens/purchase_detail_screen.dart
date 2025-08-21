import 'package:flutter/material.dart';
import '../models/procurement.dart';
import '../services/procurement_service.dart';
import '../services/auth_service.dart';
import '../models/app_user.dart';

class PurchaseDetailScreen extends StatefulWidget {
  final Procurement procurement;
  const PurchaseDetailScreen({Key? key, required this.procurement}) : super(key: key);

  @override
  State<PurchaseDetailScreen> createState() => _PurchaseDetailScreenState();
}

class _PurchaseDetailScreenState extends State<PurchaseDetailScreen> {
  final ProcurementService _procurementService = ProcurementService();
  final AuthService _authService = AuthService();
  AppUser? _currentUser;

  @override
  void initState() {
    super.initState();
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

  Future<void> _rejectProcurement() async {
    // Показываем диалог подтверждения
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отклонить закуп'),
        content: Text('Вы уверены, что хотите вернуть закуп "${widget.procurement.sourceName}" на предыдущий этап?'),
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
        
        switch (widget.procurement.status) {
          case ProcurementStatus.arrival:
            previousStatus = ProcurementStatus.arrival.index;
            statusMessage = 'Закуп возвращен в статус "Приход товара"';
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
        await _procurementService.updateProcurementStatus(
          widget.procurement.id, 
          previousStatus
        );
        
        // Показываем уведомление об успехе
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(statusMessage),
              backgroundColor: Colors.green,
            ),
          );
          
          // Возвращаемся на предыдущий экран
          Navigator.pop(context, true);
        }
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

  @override
  Widget build(BuildContext context) {
    final date = widget.procurement.date.toDate();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали закупа'),
        actions: [
          // Кнопка отклонения для суперадмина
          if (_currentUser?.role == 'superadmin')
            IconButton(
              icon: const Icon(Icons.undo, color: Colors.orange),
              tooltip: 'Отклонить закуп',
              onPressed: _rejectProcurement,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Источник: ${widget.procurement.sourceName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Дата: ${date.day.toString().padLeft(2,'0')}.${date.month.toString().padLeft(2,'0')}.${date.year}'),
            const SizedBox(height: 8),
            Text('Итого: ${widget.procurement.totalAmount.toStringAsFixed(2)} ₸', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            const Text('Позиции', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: widget.procurement.items.length,
                itemBuilder: (context, i) {
                  final it = widget.procurement.items[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(it.productName),
                      subtitle: Text('${it.quantity} × ${it.purchasePrice.toStringAsFixed(2)} = ${it.totalPrice.toStringAsFixed(2)} ₸'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


