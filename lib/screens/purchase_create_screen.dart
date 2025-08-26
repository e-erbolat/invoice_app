import 'package:flutter/material.dart';

import '../models/purchase.dart';
import '../models/purchase_item.dart';
import '../models/product.dart';
import '../models/purchase_source.dart';
import '../services/firebase_service.dart';
import '../services/procurement_service.dart';
import '../services/auth_service.dart';
import '../services/purchase_service.dart';
import '../models/app_user.dart';

class PurchaseCreateScreen extends StatefulWidget {
  final Purchase? purchaseToEdit; // если null → создаём новый закуп

  const PurchaseCreateScreen({ super.key, this.purchaseToEdit});

  @override
  State<PurchaseCreateScreen> createState() => _PurchaseCreateScreenState();
}

class _PurchaseCreateScreenState extends State<PurchaseCreateScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final ProcurementService _procurementService = ProcurementService();
  final AuthService _authService = AuthService();
  final PurchaseService _purchaseService = PurchaseService();

  List<Product> _products = [];
  List<PurchaseSource> _sources = [];
  PurchaseSource? _selectedSource;
  Product? _selectedProduct;
  final TextEditingController _productPriceController = TextEditingController(text: '0.0');
  final TextEditingController _productQtyController = TextEditingController(text: '1');
  final TextEditingController _autocompleteProductController = TextEditingController();
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final FocusNode _productFocus = FocusNode();
  bool _loading = true;
  bool _submitting = false;
  final List<PurchaseItem> _items = [];
  AppUser? _currentUser;
  bool get isEditMode => widget.purchaseToEdit != null;

  @override
  void initState() {
    super.initState();
    _init();
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

  Future<void> _init() async {
    setState(() { _loading = true; });
    try {
      final products = await _firebaseService.getProducts();
      final sources = await _procurementService.getSources();
      
      // Если редактируем существующий закуп, загружаем его данные
      if (isEditMode && widget.purchaseToEdit != null) {
        final purchase = widget.purchaseToEdit!;
        
        debugPrint('Редактирование закупа: ID=${purchase.id}, Поставщик=${purchase.supplierName}');
        debugPrint('Firestore ID: ${purchase.id}');
        debugPrint('Поставщик ID: ${purchase.supplierId}');
        
        // Находим поставщика
        _selectedSource = sources.firstWhere(
          (s) => s.id == purchase.supplierId,
          orElse: () => sources.first,
        );
        
        // Загружаем товары
        _items.addAll(purchase.items);
        
        // Загружаем примечания
        if (purchase.notes != null) {
          _notesController.text = purchase.notes!;
        }
        
        // Обновляем контроллеры поставщика
        if (_selectedSource != null) {
          _sourceController.text = _selectedSource!.name;
        }
      }
      
      setState(() {
        _products = products;
        _sources = sources;
        _loading = false;
      });
    } catch (e) {
      setState(() { _loading = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки данных: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _productPriceController.dispose();
    _productQtyController.dispose();
    _autocompleteProductController.dispose();
    _sourceController.dispose();
    _notesController.dispose();
    _productFocus.dispose();
    super.dispose();
  }

  void _addItem() {
    final qty = int.tryParse(_productQtyController.text) ?? 1;
    final price = double.tryParse(_productPriceController.text.replaceAll(',', '.')) ?? 0.0;
    
    if (_selectedProduct == null || qty <= 0 || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните товар, цену и количество')),
      );
      return;
    }

    // Проверяем, не добавлен ли уже этот товар
    if (_items.any((item) => item.productId == _selectedProduct!.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Этот товар уже добавлен в закуп')),
      );
      return;
    }

    setState(() {
      if (isEditMode) {
        // При редактировании используем существующий ID товара, если он есть
        final existingItem = _items.firstWhere(
          (item) => item.productId == _selectedProduct!.id,
          orElse: () => PurchaseItem.create(
            purchaseId: widget.purchaseToEdit?.id ?? '',
            productId: _selectedProduct!.id,
            productName: _selectedProduct!.name,
            orderedQty: qty,
            purchasePrice: price,
            notes: null,
          ),
        );
        
        if (existingItem.id.startsWith('item_')) {
          // Это новый товар, добавляем его
          _items.add(existingItem);
        } else {
          // Обновляем существующий товар
          final index = _items.indexWhere((item) => item.productId == _selectedProduct!.id);
          if (index != -1) {
            _items[index] = existingItem.copyWith(
              orderedQty: qty,
              purchasePrice: price,
              totalPrice: qty * price,
            );
          }
        }
      } else {
        // При создании нового закупа
        _items.add(PurchaseItem.create(
          purchaseId: '', // Будет установлено при создании закупа
          productId: _selectedProduct!.id,
          productName: _selectedProduct!.name,
          orderedQty: qty,
          purchasePrice: price,
          notes: null,
        ));
      }
      
      // Очищаем поля
      _selectedProduct = null;
      _autocompleteProductController.clear();
      _productPriceController.text = '0.0';
      _productQtyController.text = '1';
    });

    _productFocus.requestFocus();
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _updateItemQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      _removeItem(index);
      return;
    }

    setState(() {
      final item = _items[index];
      final updatedItem = item.copyWith(
        orderedQty: newQuantity,
        totalPrice: newQuantity * item.purchasePrice,
      );
      _items[index] = updatedItem;
    });
  }

  void _updateItemPrice(int index, double newPrice) {
    if (newPrice <= 0) return;

    setState(() {
      final item = _items[index];
      final updatedItem = item.copyWith(
        purchasePrice: newPrice,
        totalPrice: item.orderedQty * newPrice,
      );
      _items[index] = updatedItem;
    });
  }

  Future<void> _submitPurchase() async {
    if (_selectedSource == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите поставщика')),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте хотя бы один товар')),
      );
      return;
    }

    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пользователь не авторизован')),
      );
      return;
    }

    setState(() { _submitting = true; });

    try {
      if (isEditMode && widget.purchaseToEdit != null) {
        // 🟡 Редактирование существующего закупа
        if (widget.purchaseToEdit!.id.isEmpty) {
          throw Exception('ID закупа для редактирования не найден');
        }
        
        debugPrint('Редактирование закупа с ID: ${widget.purchaseToEdit!.id}');
        debugPrint('Firestore ID для обновления: ${widget.purchaseToEdit!.id}');
        debugPrint('Текущий поставщик: ${_selectedSource?.name}');
        debugPrint('Количество товаров: ${_items.length}');
        
        final updatedPurchase = widget.purchaseToEdit!.copyWith(
          supplierId: _selectedSource!.id,
          supplierName: _selectedSource!.name,
          items: _items,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );

        await _purchaseService.updatePurchase(updatedPurchase);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Закуп успешно обновлен'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Возвращаемся назад
          Navigator.of(context).pop(true);
        }
      } else {
        // 🟢 Создание нового закупа
        final purchase = Purchase.create(
          supplierId: _selectedSource!.id,
          supplierName: _selectedSource!.name,
          items: _items,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          createdByUserId: _currentUser!.uid,
          createdByUserName: (_currentUser!.name?.isNotEmpty == true) ? _currentUser!.name! : _currentUser!.email,
        );

        final purchaseId = await _purchaseService.createPurchase(purchase);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Закуп успешно создан'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Возвращаемся назад
          Navigator.of(context).pop(purchaseId);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка ${isEditMode ? 'обновления' : 'создания'} закупа: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() { _submitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Редактирование закупа' : 'Создание закупа'),
        actions: [
          if (_items.isNotEmpty)
            TextButton(
              onPressed: _submitting ? null : _submitPurchase,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      isEditMode ? 'СОХРАНИТЬ' : 'СОЗДАТЬ',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Выбор поставщика
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Поставщик',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Autocomplete<PurchaseSource>(
                            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                              return TextField(
                                controller: controller,
                                focusNode: focusNode,
                                decoration: const InputDecoration(
                                  labelText: 'Поиск поставщика',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.business),
                                ),
                                onChanged: (value) {
                                  _sourceController.text = value;
                                },
                              );
                            },
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              if (textEditingValue.text.isEmpty) {
                                return _sources;
                              }
                              return _sources.where((source) =>
                                  source.name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                            },
                            displayStringForOption: (option) => option.name,
                            onSelected: (option) {
                              setState(() {
                                _selectedSource = option;
                                _sourceController.text = option.name;
                              });
                            },
                            optionsViewBuilder: (context, onSelected, options) {
                              return Material(
                                elevation: 4.0,
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  itemCount: options.length,
                                  shrinkWrap: true,
                                  itemBuilder: (BuildContext context, int index) {
                                    final option = options.elementAt(index);
                                    return ListTile(
                                      title: Text(option.name),
                                      subtitle: Text(option.description ?? ''),
                                      onTap: () => onSelected(option),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                          if (_selectedSource != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedSource!.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        if (_selectedSource!.description != null)
                                          Text(
                                            _selectedSource!.description!,
                                            style: TextStyle(color: Colors.grey.shade600),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Добавление товаров
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Добавление товаров',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Поля для добавления товара
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Autocomplete<Product>(
                                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                    return TextField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      decoration: const InputDecoration(
                                        labelText: 'Товар',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.inventory),
                                      ),
                                      onChanged: (value) {
                                        _autocompleteProductController.text = value;
                                      },
                                    );
                                  },
                                  optionsBuilder: (TextEditingValue textEditingValue) {
                                    if (textEditingValue.text.isEmpty) {
                                      return _products;
                                    }
                                    return _products.where((product) =>
                                        product.name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                                  },
                                  displayStringForOption: (option) => option.name,
                                  onSelected: (option) {
                                    setState(() {
                                      _selectedProduct = option;
                                      _autocompleteProductController.text = option.name;
                                    });
                                  },
                                  optionsViewBuilder: (context, onSelected, options) {
                                    return Material(
                                      elevation: 4.0,
                                      child: ListView.builder(
                                        padding: EdgeInsets.zero,
                                        itemCount: options.length,
                                        shrinkWrap: true,
                                        itemBuilder: (BuildContext context, int index) {
                                          final option = options.elementAt(index);
                                          return ListTile(
                                            title: Text(option.name),
                                            subtitle: Text(option.category),
                                            onTap: () => onSelected(option),
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: TextField(
                                  controller: _productQtyController,
                                  decoration: const InputDecoration(
                                    labelText: 'Кол-во',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: TextField(
                                  controller: _productPriceController,
                                  decoration: const InputDecoration(
                                    labelText: 'Цена',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: _addItem,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: const Icon(Icons.add),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Список добавленных товаров
                          if (_items.isNotEmpty) ...[
                            const Text(
                              'Добавленные товары:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _items.length,
                              itemBuilder: (context, index) {
                                final item = _items[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    title: Text(item.productName),
                                    subtitle: Text(
                                      'Количество: ${item.orderedQty} × ${item.purchasePrice.toStringAsFixed(2)} ₸ = ${item.totalPrice.toStringAsFixed(2)} ₸',
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () => _showEditItemDialog(index, item),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () => _removeItem(index),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                  
                            const SizedBox(height: 16),
                  
                            // Итоговая сумма
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Общая сумма:',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                                                         '${_items.fold<double>(0.0, (total, item) => total + item.totalPrice).toStringAsFixed(2)} ₸',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Примечания
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Примечания',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _notesController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Дополнительная информация',
                              border: OutlineInputBorder(),
                              hintText: 'Введите примечания к закупу...',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _showEditItemDialog(int index, PurchaseItem item) {
    final qtyController = TextEditingController(text: item.orderedQty.toString());
    final priceController = TextEditingController(text: item.purchasePrice.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Редактировать ${item.productName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyController,
              decoration: const InputDecoration(
                labelText: 'Количество',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(
                labelText: 'Цена',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final newQty = int.tryParse(qtyController.text) ?? item.orderedQty;
              final newPrice = double.tryParse(priceController.text.replaceAll(',', '.')) ?? item.purchasePrice;
              
              if (newQty > 0 && newPrice > 0) {
                _updateItemQuantity(index, newQty);
                _updateItemPrice(index, newPrice);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}


