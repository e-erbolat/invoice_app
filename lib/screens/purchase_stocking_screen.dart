import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/purchase_item.dart';
import '../services/purchase_service.dart';

class PurchaseStockingScreen extends StatefulWidget {
  final String purchaseId;

  const PurchaseStockingScreen({Key? key, required this.purchaseId}) : super(key: key);

  @override
  State<PurchaseStockingScreen> createState() => _PurchaseStockingScreenState();
}

class _PurchaseStockingScreenState extends State<PurchaseStockingScreen> {
  final PurchaseService _purchaseService = PurchaseService();
  List<PurchaseItem> _items = [];
  Set<String> _selectedItems = {};
  bool _isLoading = true;
  bool _isSaving = false;
  bool _stockAll = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await _purchaseService.getPurchaseItems(widget.purchaseId);
      // Показываем только товары, которые можно оприходовать
      final receivedItems = items.where((item) => 
        item.status == PurchaseItem.statusReceived
      ).toList();
      
      setState(() {
        _items = receivedItems;
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

  Future<void> _stockItems() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пользователь не авторизован')),
      );
      return;
    }

    if (!_stockAll && _selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите товары для оприходования')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _purchaseService.stockPurchaseItems(
        purchaseId: widget.purchaseId,
        itemIds: _selectedItems.toList(),
        userId: user.uid,
        userName: user.displayName ?? user.email ?? 'Unknown',
        stockAll: _stockAll,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Товары успешно оприходованы')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка оприходования: $e')),
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
        appBar: AppBar(title: const Text('Оприходование')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Нет товаров для оприходования',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              SizedBox(height: 8),
              Text(
                'Сначала выполните приемку товаров',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Оприходование'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _stockItems,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Оприходовать', style: TextStyle(color: Colors.white)),
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
                      value: _stockAll,
                      onChanged: (value) {
                        setState(() {
                          _stockAll = value ?? false;
                          if (_stockAll) {
                            _selectedItems.clear();
                          }
                        });
                      },
                    ),
                    const Text('Оприходовать все товары сразу'),
                  ],
                ),
                
                if (!_stockAll) ...[
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
                    leading: _stockAll 
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
                        Text('Получено: ${item.receivedQty} шт'),
                        Text('Цена: ${item.unitPrice.toStringAsFixed(2)} ₽'),
                        Text('Сумма: ${item.totalReceivedAmount.toStringAsFixed(2)} ₽'),
                      ],
                    ),
                    tileColor: _stockAll || isSelected ? Colors.blue.shade50 : null,
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
              color: Colors.blue.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              children: [
                if (_stockAll) ...[
                  Text(
                    'Будет оприходовано: ${_items.length} товаров',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Общая сумма: ${_items.fold(0.0, (sum, item) => sum + item.totalReceivedAmount).toStringAsFixed(2)} ₽',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ] else if (_selectedItems.isNotEmpty) ...[
                  Text(
                    'Будет оприходовано: ${_selectedItems.length} товаров',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Builder(
                    builder: (context) {
                      final selectedItemsList = _items.where((item) => _selectedItems.contains(item.id));
                      final totalAmount = selectedItemsList.fold(0.0, (sum, item) => sum + item.totalReceivedAmount);
                      return Text(
                        'Общая сумма: ${totalAmount.toStringAsFixed(2)} ₽',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                      );
                    },
                  ),
                ] else
                  const Text(
                    'Выберите товары для оприходования',
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