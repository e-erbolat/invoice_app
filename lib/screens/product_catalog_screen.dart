import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/firebase_service.dart';
import 'package:intl/intl.dart';

class ProductCatalogScreen extends StatefulWidget {
  @override
  _ProductCatalogScreenState createState() => _ProductCatalogScreenState();
}

class _ProductCatalogScreenState extends State<ProductCatalogScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  List<Product> _products = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });
    
    final products = await _firebaseService.getProducts();
    setState(() {
      _products = products;
      _isLoading = false;
    });
  }

  List<Product> get _filteredProducts {
    if (_searchQuery.isEmpty) {
      return _products;
    }
    return _products.where((product) =>
        product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        product.category.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  void _showAddEditDialog([Product? product]) {
    final nameController = TextEditingController(text: product?.name ?? '');
    final descriptionController = TextEditingController(text: product?.description ?? '');
    final priceController = TextEditingController(text: product?.price.toString() ?? '');
    final categoryController = TextEditingController(text: product?.category ?? '');
    final stockController = TextEditingController(text: product?.stockQuantity.toString() ?? '');
    final barcodeController = TextEditingController(text: product?.barcode ?? '');
    
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(product == null ? 'Добавить товар' : 'Редактировать товар'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Название товара *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.inventory),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Введите название товара';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Описание',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 3,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: priceController,
                    decoration: InputDecoration(
                      labelText: 'Цена (₸) *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Введите цену';
                      }
                      final price = double.tryParse(value);
                      if (price == null || price <= 0) {
                        return 'Введите корректную цену';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: categoryController,
                    decoration: InputDecoration(
                      labelText: 'Категория *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Введите категорию';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: stockController,
                    decoration: InputDecoration(
                      labelText: 'Количество на складе *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.inventory_2),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Введите количество';
                      }
                      final stock = int.tryParse(value);
                      if (stock == null || stock < 0) {
                        return 'Введите корректное количество';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: barcodeController,
                    decoration: InputDecoration(labelText: 'Штрихкод'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(context),
              child: Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: isSubmitting ? null : () async {
                if (formKey.currentState!.validate()) {
                  setState(() {
                    isSubmitting = true;
                  });
                  
                  try {
                    print('Создание объекта Product...');
                    final newProduct = Product(
                      id: product?.id ?? '',
                      name: nameController.text.trim(),
                      description: descriptionController.text.trim(),
                      price: double.parse(priceController.text),
                      category: categoryController.text.trim(),
                      stockQuantity: int.parse(stockController.text),
                      createdAt: product?.createdAt ?? DateTime.now(),
                      updatedAt: DateTime.now(),
                      barcode: barcodeController.text.trim(),
                    );
                    print('Объект Product создан: ${newProduct.name}');

                    if (product == null) {
                      print('Вызов addProduct...');
                      await _firebaseService.addProduct(newProduct);
                      print('addProduct завершен успешно');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Товар "${newProduct.name}" успешно добавлен!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      print('Вызов updateProduct...');
                      await _firebaseService.updateProduct(newProduct);
                      print('updateProduct завершен успешно');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Товар "${newProduct.name}" успешно обновлен!'),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    }

                    print('Закрытие диалога...');
                    Navigator.pop(context);
                    print('Обновление списка товаров...');
                    _loadProducts();
                    print('Операция завершена успешно');
                  } catch (e) {
                    print('Ошибка в диалоге: $e');
                    print('Тип ошибки: ${e.runtimeType}');
                    setState(() {
                      isSubmitting = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Ошибка: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: isSubmitting 
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(product == null ? 'Добавить' : 'Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(Product product) {
    bool isDeleting = false;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('Удалить товар'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Вы уверены, что хотите удалить товар:'),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Категория: ${product.category}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    Text(
                      'Цена: ${NumberFormat.currency(locale: 'ru_RU', symbol: '₸').format(product.price)}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Это действие нельзя отменить!',
                style: TextStyle(
                  color: Colors.red[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.pop(context),
              child: Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: isDeleting ? null : () async {
                setState(() {
                  isDeleting = true;
                });
                
                try {
                  await _firebaseService.deleteProduct(product.id);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Товар "${product.name}" успешно удален!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadProducts();
                } catch (e) {
                  setState(() {
                    isDeleting = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Ошибка при удалении: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: isDeleting 
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text('Удалить'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Каталог товаров'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadProducts,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Поиск товаров',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _filteredProducts.isEmpty
                    ? Center(child: Text('Товары не найдены'))
                    : ListView.builder(
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = _filteredProducts[index];
                          return Card(
                            margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                            elevation: 2,
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product.name,
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              product.category,
                                              style: TextStyle(
                                                color: Colors.blue[600],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuButton(
                                        itemBuilder: (context) => [
                                          PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit, color: Colors.blue),
                                                SizedBox(width: 8),
                                                Text('Редактировать'),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(Icons.delete, color: Colors.red),
                                                SizedBox(width: 8),
                                                Text('Удалить'),
                                              ],
                                            ),
                                          ),
                                        ],
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _showAddEditDialog(product);
                                          } else if (value == 'delete') {
                                            _showDeleteDialog(product);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                  if (product.description.isNotEmpty) ...[
                                    SizedBox(height: 8),
                                    Text(
                                      product.description,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                  SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Цена',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            NumberFormat.currency(locale: 'ru_RU', symbol: '₸').format(product.price),
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'На складе',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: product.stockQuantity > 0 ? Colors.green[100] : Colors.red[100],
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '${product.stockQuantity} шт.',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: product.stockQuantity > 0 ? Colors.green[700] : Colors.red[700],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        child: Icon(Icons.add),
        tooltip: 'Добавить товар',
      ),
    );
  }
} 