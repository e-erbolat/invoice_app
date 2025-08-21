import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/procurement.dart';
import '../models/procurement_item.dart';
import '../services/procurement_service.dart';
import '../services/auth_service.dart';
import '../models/app_user.dart';
import 'dart:async';

class ArrivalVerificationScreen extends StatefulWidget {
  final Procurement procurement;
  
  const ArrivalVerificationScreen({
    Key? key,
    required this.procurement,
  }) : super(key: key);

  @override
  State<ArrivalVerificationScreen> createState() => _ArrivalVerificationScreenState();
}

class _ArrivalVerificationScreenState extends State<ArrivalVerificationScreen> {
  final ProcurementService _procurementService = ProcurementService();
  final AuthService _authService = AuthService();
  final Map<String, TextEditingController> _quantityControllers = {};
  final Map<String, TextEditingController> _noteControllers = {};
  Timer? _autoSaveTimer;
  bool _isLoading = false;
  bool _hasChanges = false;
  AppUser? _currentUser;
  
  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _startAutoSave();
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

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    for (final controller in _quantityControllers.values) {
      controller.dispose();
    }
    for (final controller in _noteControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeControllers() {
    for (final item in widget.procurement.items) {
      _quantityControllers[item.productId] = TextEditingController(
        text: item.quantity.toString(),
      );
      _noteControllers[item.productId] = TextEditingController();
      
      // Слушаем изменения для отслеживания модификаций
      _quantityControllers[item.productId]!.addListener(() {
        if (!_hasChanges) {
          setState(() => _hasChanges = true);
        }
      });
    }
  }

  void _startAutoSave() {
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_hasChanges) {
        _autoSave();
      }
    });
  }

  Future<void> _autoSave() async {
    if (!_hasChanges) return;
    
    try {
      final updatedItems = _getUpdatedItems();
      final updatedProcurement = widget.procurement.copyWith(
        items: updatedItems,
        totalAmount: updatedItems.fold<double>(0.0, (sum, item) => sum + ((item.quantity ?? 0) * (item.purchasePrice ?? 0.0))),
      );
      
      await _procurementService.updateProcurement(updatedProcurement);
      
      if (mounted) {
        setState(() => _hasChanges = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Автосохранение выполнено'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка автосохранения: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<ProcurementItem> _getUpdatedItems() {
    return widget.procurement.items.map((item) {
      final actualQuantity = int.tryParse(
        _quantityControllers[item.productId]?.text ?? item.quantity.toString()
      ) ?? item.quantity;
      
      final note = _noteControllers[item.productId]?.text ?? '';
      
      return item.copyWith(
        quantity: actualQuantity,
        note: note.isNotEmpty ? note : null,
      );
    }).toList();
  }

  Future<void> _finalizeArrival() async {
    setState(() => _isLoading = true);
    
    try {
      final updatedItems = _getUpdatedItems();
      final shortages = <ProcurementItem>[];
      final forSaleItems = <ProcurementItem>[];
      
      // Анализируем каждый товар
      for (final item in updatedItems) {
        final originalItem = widget.procurement.items.firstWhere(
          (i) => i.productId == item.productId,
        );
        
        if (item.quantity < originalItem.quantity) {
          // Есть недостача - создаем запись о недостаче
          final shortageItem = ProcurementItem.create(
            productId: item.productId,
            productName: item.productName,
            quantity: originalItem.quantity - item.quantity,
            purchasePrice: item.purchasePrice,
            note: 'Недостача из закупа ${widget.procurement.id}',
            procurementId: widget.procurement.id,
          );
          shortages.add(shortageItem);
        }
        
        // Все товары (включая недостачи) идут на выставку
        forSaleItems.add(item);
      }
      
      // Создаем запись о недостаче, если есть
      if (shortages.isNotEmpty) {
        final shortageProcurement = Procurement(
          id: 'shortage_${widget.procurement.id}_${DateTime.now().millisecondsSinceEpoch}',
          sourceId: widget.procurement.sourceId,
          sourceName: '${widget.procurement.sourceName} (недостача)',
          date: Timestamp.now(),
          items: shortages,
          totalAmount: shortages.fold<double>(0.0, (sum, item) => sum + ((item.quantity ?? 0) * (item.purchasePrice ?? 0.0))),
          status: ProcurementStatus.shortage.index,
        );
        
        await _procurementService.createProcurement(shortageProcurement);
      }
      
      // Переводим основной закуп в статус "выставка на продажу"
      final forSaleProcurement = widget.procurement.copyWith(
        items: forSaleItems,
        totalAmount: forSaleItems.fold<double>(0.0, (sum, item) => sum + ((item.quantity ?? 0) * (item.purchasePrice ?? 0.0))),
        status: ProcurementStatus.forSale.index,
      );
      
      await _procurementService.updateProcurement(forSaleProcurement);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              shortages.isNotEmpty 
                ? 'Приход завершен. Создана запись о недостаче.'
                : 'Приход завершен успешно!'
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Возвращаем true для обновления списка
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка завершения прихода: $e'),
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
        // Возвращаем закуп в статус "Закуп товара"
        await _procurementService.updateProcurementStatus(
          widget.procurement.id, 
          ProcurementStatus.purchase.index
        );
        
        // Показываем уведомление об успехе
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Закуп возвращен в статус "Закуп товара"'),
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Сверка прихода: ${widget.procurement.sourceName}'),
        backgroundColor: Colors.white,
        elevation: 2,
        foregroundColor: Colors.black,
        actions: [
          // Кнопка отклонения для суперадмина
          if (_currentUser?.role == 'superadmin')
            IconButton(
              icon: const Icon(Icons.undo, color: Colors.orange),
              tooltip: 'Отклонить закуп',
              onPressed: _rejectProcurement,
            ),
          if (_currentUser?.role == 'superadmin')
            const SizedBox(width: 8),
          if (_hasChanges)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Есть изменения',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Информация о закупе
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Закуп: ${widget.procurement.sourceName}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Дата: ${widget.procurement.date.toDate().day.toString().padLeft(2,'0')}.${widget.procurement.date.toDate().month.toString().padLeft(2,'0')}.${widget.procurement.date.toDate().year}',
                ),
                Text(
                  'Ожидаемая сумма: ${widget.procurement.totalAmount.toStringAsFixed(2)} ₸',
                ),
              ],
            ),
          ),
          
          // Список товаров для сверки
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.procurement.items.length,
              itemBuilder: (context, index) {
                final item = widget.procurement.items[index];
                final quantityController = _quantityControllers[item.productId]!;
                final noteController = _noteControllers[item.productId]!;
                
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
                                item.productName,
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
                                '${item.purchasePrice.toStringAsFixed(2)} ₸',
                                style: TextStyle(
                                  color: Colors.blue.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Ожидаемое количество:',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  Text(
                                    '${item.quantity} шт.',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Фактическое количество:',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  TextField(
                                    controller: quantityController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      suffixText: 'шт.',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        TextField(
                          controller: noteController,
                          decoration: const InputDecoration(
                            labelText: 'Примечание (необязательно)',
                            border: OutlineInputBorder(),
                            hintText: 'Укажите причину недостачи или другие замечания',
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Кнопка завершения
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _finalizeArrival,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('Завершение...'),
                        ],
                      )
                    : const Text('Завершить приход'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
