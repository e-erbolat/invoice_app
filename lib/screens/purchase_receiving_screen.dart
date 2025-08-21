import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/purchase_item.dart';
import '../services/purchase_service.dart';

class PurchaseReceivingScreen extends StatefulWidget {
  final String purchaseId;

  const PurchaseReceivingScreen({Key? key, required this.purchaseId}) : super(key: key);

  @override
  State<PurchaseReceivingScreen> createState() => _PurchaseReceivingScreenState();
}

class _PurchaseReceivingScreenState extends State<PurchaseReceivingScreen> {
  final PurchaseService _purchaseService = PurchaseService();
  List<PurchaseItem> _items = [];
  Map<String, TextEditingController> _controllers = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await _purchaseService.getPurchaseItems(widget.purchaseId);
      setState(() {
        _items = items;
        _controllers = {
          for (var item in items)
            item.id: TextEditingController(text: item.orderedQty.toString())
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки товаров: $e')),
        );
      }
    }
  }

  Future<void> _saveReceiving() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пользователь не авторизован')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final receivedItems = <Map<String, dynamic>>[];
      
      for (var item in _items) {
        final controller = _controllers[item.id];
        if (controller != null) {
          final receivedQty = int.tryParse(controller.text) ?? 0;
          if (receivedQty < 0 || receivedQty > item.orderedQty) {
            throw Exception('Некорректное количество для товара ${item.productName}');
          }
          
          receivedItems.add({
            'itemId': item.id,
            'receivedQty': receivedQty,
          });
        }
      }

      await _purchaseService.receivePurchaseItems(
        purchaseId: widget.purchaseId,
        receivedItems: receivedItems,
        userId: user.uid,
        userName: user.displayName ?? user.email ?? 'Unknown',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Приемка завершена')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка приемки: $e')),
        );
      }
    }
  }

  void _setReceivedQtyForAll(int qty) {
    for (var item in _items) {
      final controller = _controllers[item.id];
      if (controller != null) {
        controller.text = qty.toString();
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Приемка товаров'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveReceiving,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Сохранить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Быстрые действия
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Column(
              children: [
                const Text('Быстрые действия:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => _setReceivedQtyForAll(0),
                      child: const Text('Ничего не получено'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        for (var item in _items) {
                          _controllers[item.id]?.text = item.orderedQty.toString();
                        }
                        setState(() {});
                      },
                      child: const Text('Получено полностью'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Список товаров
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final controller = _controllers[item.id]!;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text('Штрихкод: ${item.productBarcode}'),
                        Text('Цена: ${item.unitPrice.toStringAsFixed(2)} ₽'),
                        Text('Заказано: ${item.orderedQty} шт'),
                        const SizedBox(height: 12),
                        
                        Row(
                          children: [
                            const Text('Получено: ', style: TextStyle(fontWeight: FontWeight.bold)),
                            Expanded(
                              child: TextField(
                                controller: controller,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  border: const OutlineInputBorder(),
                                  suffixText: 'шт',
                                  helperText: 'Максимум: ${item.orderedQty}',
                                ),
                                onChanged: (value) {
                                  final qty = int.tryParse(value) ?? 0;
                                  if (qty > item.orderedQty) {
                                    controller.text = item.orderedQty.toString();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              children: [
                                IconButton(
                                  onPressed: () {
                                    final current = int.tryParse(controller.text) ?? 0;
                                    if (current < item.orderedQty) {
                                      controller.text = (current + 1).toString();
                                    }
                                  },
                                  icon: const Icon(Icons.add),
                                ),
                                IconButton(
                                  onPressed: () {
                                    final current = int.tryParse(controller.text) ?? 0;
                                    if (current > 0) {
                                      controller.text = (current - 1).toString();
                                    }
                                  },
                                  icon: const Icon(Icons.remove),
                                ),
                              ],
                            ),
                          ],
                        ),
                        
                        // Показываем недостачу если есть
                        Builder(
                          builder: (context) {
                            final receivedQty = int.tryParse(controller.text) ?? 0;
                            final missingQty = item.orderedQty - receivedQty;
                            
                            if (missingQty > 0) {
                              return Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  border: Border.all(color: Colors.red.shade200),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning, color: Colors.red, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Недостача: $missingQty шт (${(missingQty * item.unitPrice).toStringAsFixed(2)} ₽)',
                                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}