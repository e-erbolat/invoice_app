import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';
import '../models/product.dart';
import '../models/outlet.dart';
import '../models/sales_rep.dart';
import '../services/invoice_service.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import '../models/app_user.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class InvoiceCreateScreen extends StatefulWidget {
  final Invoice? invoiceToEdit;
  const InvoiceCreateScreen({super.key, this.invoiceToEdit});

  @override
  _InvoiceCreateScreenState createState() => _InvoiceCreateScreenState();
}

class _InvoiceCreateScreenState extends State<InvoiceCreateScreen> {
  final InvoiceService _invoiceService = InvoiceService();
  final FirebaseService _firebaseService = FirebaseService();
  final AuthService _authService = AuthService();
  AppUser? _currentUser;
  List<Product> _products = [];
  List<Outlet> _outlets = [];
  List<SalesRep> _salesReps = [];
  List<InvoiceItem> _invoiceItems = [];
  Product? _selectedProduct;
  String _productSearch = '';
  Outlet? _selectedOutlet;
  SalesRep? _selectedSalesRep;
  DateTime _selectedDate = DateTime.now();
  int _quantity = 1;
  double _price = 0.0;
  bool _isBonus = false;
  final TextEditingController _quantityController = TextEditingController(text: '1');
  final TextEditingController _priceController = TextEditingController(text: '0.0');
  // Добавляю контроллер для Autocomplete
  TextEditingController? _autocompleteProductController;
  FocusNode? _autocompleteProductFocusNode;
  bool _isLoading = true;
  bool _isSubmitting = false;
  int? _selectedStatusCode;
  static const String _draftKey = 'invoice_draft';
  bool _restoredFromDraft = false;
  bool get isEditMode => widget.invoiceToEdit != null;

  @override
  void initState() {
    super.initState();
    _autocompleteProductController = TextEditingController();
    _autocompleteProductFocusNode = FocusNode();
    _loadData();
    if (!isEditMode) _loadDraftIfExists();
  }

  void _preFillFromInvoice(Invoice invoice) {
    if (_outlets.isNotEmpty) {
      _selectedOutlet = _outlets.firstWhere(
        (o) => o.id == invoice.outletId,
        orElse: () => _outlets.first,
      );
    }
    if (_salesReps.isNotEmpty) {
      _selectedSalesRep = _salesReps.firstWhere(
        (r) => r.id == invoice.salesRepId,
        orElse: () => _salesReps.first,
      );
    }
    _selectedDate = invoice.date.toDate();
    _invoiceItems = List<InvoiceItem>.from(invoice.items);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _autocompleteProductController?.dispose();
    _autocompleteProductFocusNode?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final user = await _authService.getCurrentUser();
      final products = await _firebaseService.getProducts();
      final outlets = await _firebaseService.getOutlets();
      final salesReps = await _firebaseService.getSalesReps();
      SalesRep? selectedRep;
      if (user != null && user.role == 'sales') {
        print('[InvoiceCreateScreen] Поиск SalesRep для uid: ${user.uid}');
        print('[InvoiceCreateScreen] Доступные SalesRep: ${salesReps.map((r) => '${r.id}:${r.name}').join(', ')}');
        
        selectedRep = salesReps.firstWhere(
          (rep) => rep.id == user.uid,
          orElse: () {
            print('[InvoiceCreateScreen] SalesRep не найден, создаем временный');
            return SalesRep(
              id: user.uid, // Используем uid пользователя
              name: user.email ?? 'Неизвестный',
              phone: '',
              email: user.email ?? '',
              region: '',
              commissionRate: 0,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
          },
        );
        print('[InvoiceCreateScreen] Выбранный SalesRep: ${selectedRep.id}:${selectedRep.name}');
      }
      if (mounted) {
        setState(() {
          _currentUser = user;
          _products = products;
          _outlets = outlets;
          _salesReps = salesReps;
          _selectedSalesRep = selectedRep;
          _isLoading = false;
        });
        if (isEditMode) {
          _preFillFromInvoice(widget.invoiceToEdit!);
          _selectedStatusCode = widget.invoiceToEdit!.status;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки данных: $e')),
        );
      }
    }
  }

  Future<void> _loadDraftIfExists() async {
    final prefs = await SharedPreferences.getInstance();
    final draft = prefs.getString(_draftKey);
    if (draft != null && !_restoredFromDraft) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final restore = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Восстановить черновик?'),
            content: const Text('У вас есть несохранённый черновик накладной. Хотите продолжить заполнение?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Нет, начать заново')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Восстановить')),
            ],
          ),
        );
        if (restore == true) {
          _restoreDraft(jsonDecode(draft));
          setState(() { _restoredFromDraft = true; });
        } else {
          await prefs.remove(_draftKey);
        }
      });
    }
  }

  void _restoreDraft(Map<String, dynamic> data) {
    setState(() {
      _selectedOutlet = data['outletId'] != null ? _outlets.firstWhere((o) => o.id == data['outletId'], orElse: () => _selectedOutlet ?? _outlets.first) : null;
      _selectedSalesRep = data['salesRepId'] != null ? _salesReps.firstWhere((r) => r.id == data['salesRepId'], orElse: () => _selectedSalesRep ?? _salesReps.first) : null;
      _selectedDate = data['date'] != null ? DateTime.tryParse(data['date']) ?? _selectedDate : _selectedDate;
      _invoiceItems = (data['items'] as List?)?.map((e) => InvoiceItem.fromMap(e)).toList() ?? [];
    });
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draft = {
      'outletId': _selectedOutlet?.id,
      'salesRepId': _selectedSalesRep?.id,
      'date': _selectedDate.toIso8601String(),
      'items': _invoiceItems.map((e) => e.toMap()).toList(),
    };
    await prefs.setString(_draftKey, jsonEncode(draft));
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  void _addProductItem() {
    if (_selectedProduct == null || _quantity <= 0 || (!_isBonus && _price <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля товара')),
      );
      return;
    }

    final item = InvoiceItem(
      productId: _selectedProduct!.id,
      productName: _selectedProduct!.name,
      quantity: _quantity,
      price: _price,
      totalPrice: _isBonus ? 0.0 : _quantity * _price,
      isBonus: _isBonus,
    );

    setState(() {
      _invoiceItems.add(item);
      _selectedProduct = null;
      _quantity = 1;
      _price = 0.0;
      _isBonus = false;
      _quantityController.text = '1';
      _priceController.text = '0.0';
      // Очищаем поле поиска товара через контроллер Autocomplete
      if (_autocompleteProductController != null) {
        _autocompleteProductController!.clear();
      }
    });
    _saveDraft();
  }

  void _removeProductItem(int index) {
    setState(() {
      _invoiceItems.removeAt(index);
    });
    _saveDraft();
  }

  void _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _saveDraft();
    }
  }

  double get _totalAmount {
    return _invoiceItems.fold(0.0, (total, item) => total + (item.isBonus ? 0.0 : item.totalPrice));
  }

  Future<void> _saveInvoice() async {
    if (_selectedOutlet == null || _selectedSalesRep == null || _invoiceItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все обязательные поля')),
      );
      return;
    }
    setState(() { _isSubmitting = true; });
    try {
      int status = InvoiceStatus.review;
      if (_currentUser != null && _currentUser!.role == 'admin') {
        status = _selectedStatusCode ?? InvoiceStatus.review;
      }
      final invoice = Invoice(
        id: isEditMode ? widget.invoiceToEdit!.id : DateTime.now().millisecondsSinceEpoch.toString(),
        outletId: _selectedOutlet!.id,
        outletName: _selectedOutlet!.name,
        outletAddress: _selectedOutlet!.address,
        salesRepId: _selectedSalesRep!.id,
        salesRepName: _selectedSalesRep!.name,
        date: Timestamp.fromDate(_selectedDate),
        status: status,
        isPaid: false,
        paymentType: 'наличка',
        isDebt: false,
        acceptedByAdmin: false,
        acceptedBySuperAdmin: false,
        items: _invoiceItems,
        totalAmount: _totalAmount,
      );
      if (isEditMode) {
        await _invoiceService.updateInvoice(invoice);
      } else {
        await _invoiceService.createInvoice(invoice);
        await _clearDraft();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEditMode ? 'Изменения сохранены!' : 'Накладная создана успешно!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isSubmitting = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Редактировать накладную' : 'Создать накладную'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Торговый представитель
            if (_currentUser != null && _currentUser!.role == 'sales')
              TextFormField(
                initialValue: _selectedSalesRep?.name ?? '',
                decoration: const InputDecoration(
                  labelText: 'Торговый представитель',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                enabled: false,
              )
            else
              DropdownButtonFormField<SalesRep>(
                value: _selectedSalesRep,
                decoration: const InputDecoration(
                  labelText: 'Торговый представитель *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                items: _salesReps.map((rep) {
                  return DropdownMenuItem<SalesRep>(
                    value: rep,
                    child: Text(rep.name),
                  );
                }).toList(),
                onChanged: (rep) {
                  setState(() {
                    _selectedSalesRep = rep;
                  });
                  _saveDraft();
                },
              ),
            
            const SizedBox(height: 16),
            
            // Торговая точка
            Autocomplete<Outlet>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text == '') {
                  return _outlets;
                }
                return _outlets.where((Outlet outlet) =>
                  outlet.name.toLowerCase().contains(textEditingValue.text.toLowerCase())
                );
              },
              displayStringForOption: (Outlet option) => option.name,
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                if (_selectedOutlet != null && controller.text.isEmpty) {
                  controller.text = _selectedOutlet!.name;
                }
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Торговая точка *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.store),
                  ),
                );
              },
              onSelected: (Outlet outlet) {
                setState(() {
                  _selectedOutlet = outlet;
                });
                _saveDraft();
              },
            ),
            
            const SizedBox(height: 16),
            
            // Дата
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Дата накладной',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  DateFormat('dd.MM.yyyy').format(_selectedDate),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Товары
            const Text(
              'Товары',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Форма добавления товара
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Добавить товар',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Выбор товара с автодополнением
                    Autocomplete<Product>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text == '') {
                          return _products;
                        }
                        return _products.where((Product product) =>
                          product.name.toLowerCase().contains(textEditingValue.text.toLowerCase())
                        );
                      },
                      displayStringForOption: (Product option) => option.name,
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Товар *',
                            border: OutlineInputBorder(),
                          ),
                        );
                      },
                      onSelected: (Product product) {
                        setState(() {
                          _selectedProduct = product;
                          _price = product.price;
                          _priceController.text = product.price.toStringAsFixed(2);
                        });
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Количество и цена
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Количество *',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            controller: _quantityController,
                            onChanged: (value) {
                              setState(() {
                                _quantity = int.tryParse(value) ?? 1;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Цена (₸) *',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            controller: _priceController,
                            onChanged: (value) {
                              setState(() {
                                _price = double.tryParse(value) ?? 0.0;
                              });
                            },
                            enabled: !_isBonus,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: _isBonus,
                      onChanged: (v) {
                        setState(() {
                          _isBonus = v ?? false;
                          if (_isBonus) {
                            _priceController.text = '0.0';
                            _price = 0.0;
                          } else if (_selectedProduct != null) {
                            _priceController.text = _selectedProduct!.price.toStringAsFixed(2);
                            _price = _selectedProduct!.price;
                          }
                        });
                      },
                      title: const Text('Бонус (выдать бесплатно)'),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Кнопка добавления
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _selectedProduct != null ? _addProductItem : null,
                        child: const Text('Добавить товар'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            if (_invoiceItems.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    'Товары не добавлены',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _invoiceItems.length,
                itemBuilder: (context, index) {
                  final item = _invoiceItems[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(item.productName),
                      subtitle: Text(
                        '${item.quantity} шт. × ${item.price.toStringAsFixed(2)} ₸ = ${item.totalPrice.toStringAsFixed(2)} ₸',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.deepPurple),
                            tooltip: 'Редактировать',
                            onPressed: () async {
                              final result = await showDialog<Map<String, dynamic>>(
                                context: context,
                                builder: (context) {
                                  final qtyController = TextEditingController(text: item.quantity.toString());
                                  final priceController = TextEditingController(text: item.price.toStringAsFixed(2));
                                  return AlertDialog(
                                    title: const Text('Редактировать товар'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextFormField(
                                          controller: qtyController,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(labelText: 'Количество'),
                                        ),
                                        const SizedBox(height: 12),
                                        TextFormField(
                                          controller: priceController,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          decoration: const InputDecoration(labelText: 'Цена (₸)'),
                                          enabled: !item.isBonus,
                                        ),
                                        CheckboxListTile(
                                          value: item.isBonus,
                                          onChanged: (v) {
                                            // Не реализовано редактирование бонуса в диалоге (можно добавить при необходимости)
                                          },
                                          title: const Text('Бонус (выдать бесплатно)'),
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Отмена'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          final qty = int.tryParse(qtyController.text) ?? item.quantity;
                                          final price = double.tryParse(priceController.text.replaceAll(',', '.')) ?? item.price;
                                          Navigator.pop(context, {'quantity': qty, 'price': price});
                                        },
                                        child: const Text('Сохранить'),
                                      ),
                                    ],
                                  );
                                },
                              );
                              if (result != null) {
                                setState(() {
                                  _invoiceItems[index] = InvoiceItem(
                                    productId: item.productId,
                                    productName: item.productName,
                                    quantity: result['quantity'],
                                    price: item.isBonus ? 0.0 : result['price'],
                                    totalPrice: item.isBonus ? 0.0 : result['quantity'] * result['price'],
                                    isBonus: item.isBonus,
                                  );
                                });
                                _saveDraft();
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeProductItem(index),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            
            const SizedBox(height: 24),
            
            // Итого
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Итого:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_totalAmount.toStringAsFixed(2)} ₸',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Удаляю/скрываю выбор статуса накладной
            if (_currentUser != null && _currentUser!.role != 'sales')
              DropdownButtonFormField<int>(
                value: _selectedStatusCode ?? InvoiceStatus.review,
                decoration: const InputDecoration(
                  labelText: 'Статус накладной',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.assignment),
                ),
                items: [
                  DropdownMenuItem(value: InvoiceStatus.review, child: Text(InvoiceStatus.getName(InvoiceStatus.review))),
                  DropdownMenuItem(value: InvoiceStatus.packing, child: Text(InvoiceStatus.getName(InvoiceStatus.packing))),
                  DropdownMenuItem(value: InvoiceStatus.delivery, child: Text(InvoiceStatus.getName(InvoiceStatus.delivery))),
                  DropdownMenuItem(value: InvoiceStatus.delivered, child: Text(InvoiceStatus.getName(InvoiceStatus.delivered))),
                  DropdownMenuItem(value: InvoiceStatus.cancelled, child: Text(InvoiceStatus.getName(InvoiceStatus.cancelled))),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedStatusCode = value;
                  });
                  _saveDraft();
                },
              ),
            
            const SizedBox(height: 24),
            
            // Кнопка сохранения
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _saveInvoice,
                child: Text(
                  _isSubmitting
                    ? (isEditMode ? 'Сохранение...' : 'Сохранение...')
                    : (isEditMode ? 'Сохранить изменения' : 'Создать накладную'),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 