import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/procurement.dart';
import '../models/procurement_item.dart';
import '../models/product.dart';
import '../models/purchase_source.dart';
import '../services/firebase_service.dart';
import '../services/procurement_service.dart';
import '../services/auth_service.dart';
import '../models/app_user.dart';

class PurchaseCreateScreen extends StatefulWidget {
  final Procurement? procurementToEdit;
  const PurchaseCreateScreen({Key? key, this.procurementToEdit}) : super(key: key);

  @override
  State<PurchaseCreateScreen> createState() => _PurchaseCreateScreenState();
}

class _PurchaseCreateScreenState extends State<PurchaseCreateScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final ProcurementService _procurementService = ProcurementService();
  final AuthService _authService = AuthService();

  List<Product> _products = [];
  List<PurchaseSource> _sources = [];
  PurchaseSource? _selectedSource;
  Product? _selectedProduct;
  final TextEditingController _productPriceController = TextEditingController(text: '0.0');
  final TextEditingController _productQtyController = TextEditingController(text: '1');
  final TextEditingController _autocompleteProductController = TextEditingController();
  final TextEditingController _sourceController = TextEditingController();
  final FocusNode _productFocus = FocusNode();
  DateTime _selectedDate = DateTime.now();
  bool _loading = true;
  bool _submitting = false;
  final List<ProcurementItem> _items = [];
  bool get isEditMode => widget.procurementToEdit != null;
  AppUser? _currentUser;

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
    final products = await _firebaseService.getProducts();
    final sources = await _procurementService.getSources();
    
    if (isEditMode && widget.procurementToEdit != null) {
      final procurement = widget.procurementToEdit!;
      _selectedSource = sources.firstWhere(
        (s) => s.id == procurement.sourceId,
        orElse: () => sources.first,
      );
      _selectedDate = procurement.date.toDate();
      _items.addAll(procurement.items);
    }
    
    setState(() {
      _products = products;
      _sources = sources;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _productPriceController.dispose();
    _productQtyController.dispose();
    _autocompleteProductController.dispose();
    _sourceController.dispose();
    _productFocus.dispose();
    super.dispose();
  }

  void _addItem() {
    final qty = int.tryParse(_productQtyController.text) ?? 1;
    final price = double.tryParse(_productPriceController.text.replaceAll(',', '.')) ?? 0.0;
    if (_selectedProduct == null || qty <= 0 || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заполните товар, цену и количество')));
      return;
    }
    setState(() {
      _items.add(ProcurementItem.create(
        productId: _selectedProduct!.id,
        productName: _selectedProduct!.name,
        quantity: qty,
        purchasePrice: price,
      ));
      _selectedProduct = null;
      _productQtyController.text = '1';
      _productPriceController.text = '0.0';
      _autocompleteProductController.clear();
    });
  }

  double get _totalAmount => _items.fold(0.0, (s, i) => s + i.totalPrice);

  Future<void> _save() async {
    if (_selectedSource == null || _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Выберите источник и добавьте товары')));
      return;
    }
    setState(() { _submitting = true; });
    try {
      if (isEditMode && widget.procurementToEdit != null) {
        // Обновляем существующий закуп
        final updatedProcurement = widget.procurementToEdit!.copyWith(
          sourceId: _selectedSource!.id,
          sourceName: _selectedSource!.name,
          date: Timestamp.fromDate(_selectedDate),
          items: _items,
          totalAmount: _totalAmount,
        );
        await _procurementService.updateProcurement(updatedProcurement);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Закуп обновлён')));
          Navigator.pop(context);
        }
      } else {
        // Создаём новый закуп
        final procurement = Procurement(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sourceId: _selectedSource!.id,
          sourceName: _selectedSource!.name,
          date: Timestamp.fromDate(_selectedDate),
          items: _items,
          totalAmount: _totalAmount,
          status: ProcurementStatus.purchase.index,
        );
        await _procurementService.createProcurement(procurement);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Закуп сохранён')));
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() { _submitting = false; });
    }
  }

  Future<void> _addSourceDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Добавить место закупа'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Название *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите название' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Описание'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          ElevatedButton(onPressed: () {
            if (formKey.currentState!.validate()) Navigator.pop(context, true);
          }, child: const Text('Сохранить')),
        ],
      ),
    );
    if (ok == true) {
      final src = PurchaseSource(id: '', name: nameController.text.trim(), description: descController.text.trim().isEmpty ? null : descController.text.trim());
      await _procurementService.addSource(src);
      final updated = await _procurementService.getSources();
      setState(() { _sources = updated; });
    }
  }

  Future<void> _rejectProcurement() async {
    if (!isEditMode) return; // Только для редактирования
    
    // Показываем диалог подтверждения
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отклонить закуп'),
        content: Text('Вы уверены, что хотите вернуть закуп "${widget.procurementToEdit!.sourceName}" на предыдущий этап?'),
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
        
        switch (widget.procurementToEdit!.status) {
          case ProcurementStatus.arrival:
            previousStatus = ProcurementStatus.purchase.index;
            statusMessage = 'Закуп возвращен в статус "Закуп товара"';
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
          widget.procurementToEdit!.id, 
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
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Редактировать закуп' : 'Создать закуп'),
        actions: [
          // Кнопка отклонения для суперадмина в режиме редактирования
          if (isEditMode && _currentUser?.role == 'superadmin')
            IconButton(
              icon: const Icon(Icons.undo, color: Colors.orange),
              tooltip: 'Отклонить закуп',
              onPressed: _rejectProcurement,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Источник закупа
                  DropdownButtonFormField<PurchaseSource>(
                    value: _selectedSource,
                    decoration: InputDecoration(
                      labelText: 'Откуда закуп *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.store_mall_directory),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: 'Добавить место закупа',
                        onPressed: _addSourceDialog,
                      ),
                    ),
                    items: _sources.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                    onChanged: (v) => setState(() => _selectedSource = v),
                  ),

                  const SizedBox(height: 16),

                  // Дата
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 3650)),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (picked != null) setState(() => _selectedDate = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Дата закупа',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text('${_selectedDate.day.toString().padLeft(2,'0')}.${_selectedDate.month.toString().padLeft(2,'0')}.${_selectedDate.year}'),
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text('Добавить товар', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  // Поиск товара
                  Autocomplete<Product>(
                    optionsBuilder: (TextEditingValue tev) {
                      if (tev.text.isEmpty) return _products;
                      return _products.where((p) => p.name.toLowerCase().contains(tev.text.toLowerCase()));
                    },
                    displayStringForOption: (p) => p.name,
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      _autocompleteProductController.text = controller.text;
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Товар *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.inventory),
                        ),
                      );
                    },
                    onSelected: (p) => setState(() => _selectedProduct = p),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _productQtyController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Количество *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _productPriceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Закупочная цена (₸) *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _addItem,
                      child: const Text('Добавить в закуп'),
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (_items.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(child: Text('Товары не добавлены', style: TextStyle(color: Colors.grey))),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _items.length,
                      itemBuilder: (context, i) {
                        final it = _items[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(it.productName),
                            subtitle: Text('${it.quantity} × ${it.purchasePrice.toStringAsFixed(2)} = ${it.totalPrice.toStringAsFixed(2)} ₸'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => setState(() => _items.removeAt(i)),
                            ),
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 16),
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
                        const Text('Итого:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('${_totalAmount.toStringAsFixed(2)} ₸', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _save,
                      child: Text(_submitting ? 'Сохранение...' : (isEditMode ? 'Обновить закуп' : 'Сохранить закуп')),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}


