import 'package:flutter/material.dart';
import '../models/purchase.dart';
import '../models/purchase_item.dart';
import '../models/shortage.dart';
import '../services/purchase_service.dart';
import '../services/shortage_service.dart';
import 'dart:async';

class GoodsReceivingScreen extends StatefulWidget {
  final Purchase purchase;
  
  const GoodsReceivingScreen({
    super.key,
    required this.purchase,
  });

  @override
  State<GoodsReceivingScreen> createState() => _GoodsReceivingScreenState();
}

class _GoodsReceivingScreenState extends State<GoodsReceivingScreen> {
  final PurchaseService _purchaseService = PurchaseService();
  final ShortageService _shortageService = ShortageService();
  
  final Map<String, TextEditingController> _receivedQtyControllers = {};
  final Map<String, TextEditingController> _noteControllers = {};
  Timer? _autoSaveTimer;
  bool _isLoading = false;
  bool _hasChanges = false;
  
  List<Shortage> _shortages = [];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _startAutoSave();
    _loadShortages();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    for (final controller in _receivedQtyControllers.values) {
      controller.dispose();
    }
    for (final controller in _noteControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadShortages() async {
    final shortages = await _shortageService.getShortagesByPurchaseId(widget.purchase.id);
    if (mounted) {
      setState(() {
        _shortages = shortages;
      });
    }
  }

  void _initializeControllers() {
    for (final item in widget.purchase.items) {
      _receivedQtyControllers[item.productId] = TextEditingController(
        text: (item.receivedQty?.toString() ?? '0'),
      );
      _noteControllers[item.productId] = TextEditingController(
        text: item.notes ?? '',
      );
      
      // Слушаем изменения для отслеживания модификаций
      _receivedQtyControllers[item.productId]!.addListener(() {
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
      final updatedPurchase = widget.purchase.copyWith(
        items: updatedItems,
        totalAmount: updatedItems.fold<double>(0.0, (total, item) => total + item.totalPrice),
      );
      
      await _purchaseService.updatePurchase(updatedPurchase);
      
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

  List<PurchaseItem> _getUpdatedItems() {
    return widget.purchase.items.map((item) {
      final receivedQty = int.tryParse(
        _receivedQtyControllers[item.productId]?.text ?? '0'
      ) ?? 0;
      
      final note = _noteControllers[item.productId]?.text ?? '';
      
      return item.copyWith(
        receivedQty: receivedQty,
        missingQty: receivedQty < item.orderedQty ? item.orderedQty - receivedQty : 0,
        notes: note.isNotEmpty ? note : null,
      );
    }).toList();
  }

  Future<void> _finalizeReceiving() async {
    setState(() => _isLoading = true);
    
    try {
      final updatedItems = _getUpdatedItems();
      final shortages = <PurchaseItem>[];
      final fullyReceivedItems = <PurchaseItem>[];
      
      // Анализируем каждый товар
      for (final item in updatedItems) {
        if (item.isFullyReceived) {
          // Товар принят полностью
          fullyReceivedItems.add(item);
        } else if (item.hasShortage) {
          // Есть недостача
          shortages.add(item);
        }
      }
      
      // Создаем недостачи, если есть
      if (shortages.isNotEmpty) {
        await _shortageService.createShortagesFromItems(
          widget.purchase.id,
          shortages,
        );
        
        // Обновляем закуп - переводим в статус приемки
        final updatedPurchase = widget.purchase.copyWith(
          items: updatedItems,
          totalAmount: updatedItems.fold<double>(0.0, (total, item) => total + item.totalPrice),
        );
        
        await _purchaseService.updatePurchase(updatedPurchase);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Приемка завершена. Создано ${shortages.length} недостач.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        // Все товары приняты полностью
        final updatedPurchase = widget.purchase.copyWith(
          items: updatedItems,
          totalAmount: updatedItems.fold<double>(0.0, (total, item) => total + item.totalPrice),
        );
        
        await _purchaseService.updatePurchase(updatedPurchase);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Приемка завершена успешно! Все товары получены.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
      
      // Перезагружаем недостачи
      await _loadShortages();
      
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка завершения приемки: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Приемка товара: ${widget.purchase.supplierName}'),
        backgroundColor: Colors.white,
        elevation: 2,
        foregroundColor: Colors.black,
        actions: [
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
                  'Закуп: ${widget.purchase.supplierName}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Дата: ${widget.purchase.dateCreated.toDate().day.toString().padLeft(2,'0')}.${widget.purchase.dateCreated.toDate().month.toString().padLeft(2,'0')}.${widget.purchase.dateCreated.toDate().year}',
                ),
                Text(
                  'Заказанная сумма: ${widget.purchase.totalAmount.toStringAsFixed(2)} ₸',
                ),
                if (_shortages.isNotEmpty)
                  Text(
                    'Недостачи: ${_shortages.length} позиций',
                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
          
          // Список товаров для приемки
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
                              itemCount: widget.purchase.items.length,
              itemBuilder: (context, index) {
                                  final item = widget.purchase.items[index];
                final receivedController = _receivedQtyControllers[item.productId]!;
                final noteController = _noteControllers[item.productId]!;
                final receivedQty = int.tryParse(receivedController.text) ?? 0;
                final hasShortage = receivedQty < item.orderedQty;
                
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
                        
                        // Информация о количестве
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
                                    '${item.orderedQty} шт.',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                                    'Принято:',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  TextField(
                                    controller: receivedController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      border: const OutlineInputBorder(),
                                      suffixText: 'шт.',
                                      errorText: hasShortage ? 'Недостача: ${item.orderedQty - receivedQty} шт.' : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        // Индикатор статуса
                        if (receivedQty > 0)
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: hasShortage ? Colors.orange.shade100 : Colors.green.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  hasShortage ? Icons.warning : Icons.check_circle,
                                  color: hasShortage ? Colors.orange.shade800 : Colors.green.shade800,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  hasShortage 
                                    ? 'Недостача: ${item.orderedQty - receivedQty} шт.'
                                    : 'Полностью принят',
                                  style: TextStyle(
                                    color: hasShortage ? Colors.orange.shade800 : Colors.green.shade800,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
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
                onPressed: _isLoading ? null : _finalizeReceiving,
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
                    : const Text('Завершить приемку'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
