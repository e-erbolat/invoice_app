import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/supplier.dart';
import '../models/product.dart';
import '../services/purchase_service.dart';
import '../services/firebase_service.dart';

class PurchaseCreateScreen extends StatefulWidget {
  const PurchaseCreateScreen({Key? key}) : super(key: key);

  @override
  State<PurchaseCreateScreen> createState() => _PurchaseCreateScreenState();
}

class _PurchaseCreateScreenState extends State<PurchaseCreateScreen> {
  final PurchaseService _purchaseService = PurchaseService();
  final FirebaseService _firebaseService = FirebaseService();
  final _notesController = TextEditingController();
  
  List<Supplier> _suppliers = [];
  List<Product> _products = [];
  Supplier? _selectedSupplier;
  List<PurchaseItemData> _purchaseItems = [];
  bool _isLoading = false;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingData = true);
    try {
      final suppliers = await _purchaseService.getSuppliers();
      final products = await _firebaseService.getProducts();
      
      setState(() {
        _suppliers = suppliers;
        _products = products;
        _isLoadingData = false;
      });
    } catch (e) {
      setState(() => _isLoadingData = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки данных: $e')),
        );
      }
    }
  }

  void _addProduct() {
    showDialog(
      context: context,
      builder: (context) => AddProductDialog(
        products: _products,
        onProductAdded: (productData) {
          setState(() {
            _purchaseItems.add(productData);
          });
        },
      ),
    );
  }

  void _removeProduct(int index) {
    setState(() {
      _purchaseItems.removeAt(index);
    });
  }

  double get _totalAmount {
    return _purchaseItems.fold(0.0, (sum, item) => sum + (item.unitPrice * item.orderedQty));
  }

  Future<void> _createPurchase() async {
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите поставщика')),
      );
      return;
    }

    if (_purchaseItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте товары в закуп')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Пользователь не авторизован');

      final items = _purchaseItems.map((item) => {
        'productId': item.productId,
        'productName': item.productName,
        'productBarcode': item.productBarcode,
        'unitPrice': item.unitPrice,
        'orderedQty': item.orderedQty,
      }).toList();

      await _purchaseService.createPurchase(
        supplierId: _selectedSupplier!.id,
        supplierName: _selectedSupplier!.name,
        userId: user.uid,
        userName: user.displayName ?? user.email ?? 'Unknown',
        items: items,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Закуп успешно создан')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка создания закупа: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Новый закуп'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createPurchase,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Создать', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Выбор поставщика
            const Text('Поставщик', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<Supplier>(
              value: _selectedSupplier,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Выберите поставщика',
              ),
              items: _suppliers.map((supplier) => DropdownMenuItem(
                value: supplier,
                child: Text(supplier.name),
              )).toList(),
              onChanged: (supplier) {
                setState(() => _selectedSupplier = supplier);
              },
            ),
            
            const SizedBox(height: 24),
            
            // Товары
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Товары', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: _addProduct,
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить'),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            if (_purchaseItems.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Товары не добавлены',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              )
            else
              ...List.generate(_purchaseItems.length, (index) {
                final item = _purchaseItems[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(item.productName),
                    subtitle: Text(
                      'Цена: ${item.unitPrice.toStringAsFixed(2)} ₽ × ${item.orderedQty} шт = ${(item.unitPrice * item.orderedQty).toStringAsFixed(2)} ₽'
                    ),
                    trailing: IconButton(
                      onPressed: () => _removeProduct(index),
                      icon: const Icon(Icons.delete, color: Colors.red),
                    ),
                  ),
                );
              }),
            
            if (_purchaseItems.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  'Общая сумма: ${_totalAmount.toStringAsFixed(2)} ₽',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Примечания
            const Text('Примечания', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Дополнительная информация о закупе',
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}

class PurchaseItemData {
  final String productId;
  final String productName;
  final String productBarcode;
  final double unitPrice;
  final int orderedQty;

  PurchaseItemData({
    required this.productId,
    required this.productName,
    required this.productBarcode,
    required this.unitPrice,
    required this.orderedQty,
  });
}

class AddProductDialog extends StatefulWidget {
  final List<Product> products;
  final Function(PurchaseItemData) onProductAdded;

  const AddProductDialog({
    Key? key,
    required this.products,
    required this.onProductAdded,
  }) : super(key: key);

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  Product? _selectedProduct;
  final _priceController = TextEditingController();
  final _qtyController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Добавить товар'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<Product>(
              value: _selectedProduct,
              decoration: const InputDecoration(
                labelText: 'Товар',
                border: OutlineInputBorder(),
              ),
              items: widget.products.map((product) => DropdownMenuItem(
                value: product,
                child: Text(product.name),
              )).toList(),
              onChanged: (product) {
                setState(() {
                  _selectedProduct = product;
                  if (product != null) {
                    _priceController.text = product.price.toString();
                  }
                });
              },
            ),
            
            const SizedBox(height: 16),
            
            TextField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Цена за единицу',
                border: OutlineInputBorder(),
                suffixText: '₽',
              ),
              keyboardType: TextInputType.number,
            ),
            
            const SizedBox(height: 16),
            
            TextField(
              controller: _qtyController,
              decoration: const InputDecoration(
                labelText: 'Количество',
                border: OutlineInputBorder(),
                suffixText: 'шт',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: _selectedProduct != null &&
                      _priceController.text.isNotEmpty &&
                      _qtyController.text.isNotEmpty
              ? () {
                  final price = double.tryParse(_priceController.text);
                  final qty = int.tryParse(_qtyController.text);
                  
                  if (price != null && qty != null && qty > 0) {
                    widget.onProductAdded(PurchaseItemData(
                      productId: _selectedProduct!.id,
                      productName: _selectedProduct!.name,
                      productBarcode: _selectedProduct!.barcode,
                      unitPrice: price,
                      orderedQty: qty,
                    ));
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Проверьте введенные данные')),
                    );
                  }
                }
              : null,
          child: const Text('Добавить'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    _qtyController.dispose();
    super.dispose();
  }
}