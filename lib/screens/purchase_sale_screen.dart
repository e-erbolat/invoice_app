import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/purchase_item.dart';
import '../services/purchase_service.dart';

class PurchaseSaleScreen extends StatefulWidget {
  final String purchaseId;

  const PurchaseSaleScreen({Key? key, required this.purchaseId}) : super(key: key);

  @override
  State<PurchaseSaleScreen> createState() => _PurchaseSaleScreenState();
}

class _PurchaseSaleScreenState extends State<PurchaseSaleScreen> {
  final PurchaseService _purchaseService = PurchaseService();
  List<PurchaseItem> _items = [];
  Set<String> _selectedItems = {};
  bool _isLoading = true;
  bool _isSaving = false;
  bool _putAllOnSale = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await _purchaseService.getPurchaseItems(widget.purchaseId);
      // Показываем только товары, которые можно выставить на продажу
      final stockedItems = items.where((item) => 
        item.status == PurchaseItem.statusInStock
      ).toList();
      
      setState(() {
        _items = stockedItems;
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

  Future<void> _putItemsOnSale() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пользователь не авторизован')),
      );
      return;
    }

    if (!_putAllOnSale && _selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите товары для выставки на продажу')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _purchaseService.putPurchaseItemsOnSale(
        purchaseId: widget.purchaseId,
        itemIds: _selectedItems.toList(),
        userId: user.uid,
        userName: user.displayName ?? user.email ?? 'Unknown',
        putAllOnSale: _putAllOnSale,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Товары успешно выставлены на продажу')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка выставки на продажу: $e')),
        );
      }
    }
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedItems.length == _items.length) {
        _selectedItems.clear();
      } else {
        _selectedItems = _items.map((item) => item.id).toSet();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Выставка на продажу')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.store_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Нет товаров для выставки',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              SizedBox(height: 8),
              Text(
                'Сначала оприходуйте товары',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Выставка на продажу'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _putItemsOnSale,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Выставить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Панель управления
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Column(
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: _putAllOnSale,
                      onChanged: (value) {
                        setState(() {
                          _putAllOnSale = value ?? false;
                          if (_putAllOnSale) {
                            _selectedItems.clear();
                          }
                        });
                      },
                    ),
                    const Expanded(
                      child: Text('Выставить все товары на продажу сразу'),
                    ),
                  ],
                ),
                
                if (!_putAllOnSale) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Выбрано: ${_selectedItems.length} из ${_items.length}'),
                      TextButton(
                        onPressed: _toggleSelectAll,
                        child: Text(_selectedItems.length == _items.length ? 'Снять все' : 'Выбрать все'),
                      ),
                    ],
                  ),
                ],
                
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'После выставки товары станут доступны для продажи в маркетплейсе',
                          style: TextStyle(color: Colors.blue, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
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
                final isSelected = _selectedItems.contains(item.id);
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: _putAllOnSale 
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : Checkbox(
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedItems.add(item.id);
                                } else {
                                  _selectedItems.remove(item.id);
                                }
                              });
                            },
                          ),
                    title: Text(
                      item.productName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Штрихкод: ${item.productBarcode}'),
                        Text('Количество: ${item.receivedQty} шт'),
                        Text('Цена: ${item.unitPrice.toStringAsFixed(2)} ₽'),
                        Text('Сумма: ${item.totalReceivedAmount.toStringAsFixed(2)} ₽'),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.purple,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'На складе',
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                    tileColor: _putAllOnSale || isSelected ? Colors.green.shade50 : null,
                  ),
                );
              },
            ),
          ),
          
          // Итоговая информация
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              children: [
                if (_putAllOnSale) ...[
                  Text(
                    'Будет выставлено: ${_items.length} товаров',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Общая сумма: ${_items.fold(0.0, (sum, item) => sum + item.totalReceivedAmount).toStringAsFixed(2)} ₽',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ] else if (_selectedItems.isNotEmpty) ...[
                  Text(
                    'Будет выставлено: ${_selectedItems.length} товаров',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Builder(
                    builder: (context) {
                      final selectedItemsList = _items.where((item) => _selectedItems.contains(item.id));
                      final totalAmount = selectedItemsList.fold(0.0, (sum, item) => sum + item.totalReceivedAmount);
                      return Text(
                        'Общая сумма: ${totalAmount.toStringAsFixed(2)} ₽',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                      );
                    },
                  ),
                ] else
                  const Text(
                    'Выберите товары для выставки на продажу',
                    style: TextStyle(color: Colors.grey),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}