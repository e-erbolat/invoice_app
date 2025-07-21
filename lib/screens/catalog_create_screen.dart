import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/catalog.dart';
import '../models/product.dart';

class CatalogCreateScreen extends StatefulWidget {
  const CatalogCreateScreen({Key? key}) : super(key: key);

  @override
  State<CatalogCreateScreen> createState() => _CatalogCreateScreenState();
}

class _CatalogCreateScreenState extends State<CatalogCreateScreen> {
  final _nameController = TextEditingController();
  final Map<String, double> _selectedProducts = {}; // productId -> price
  List<Product> _products = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() { _loading = true; });
    final snap = await FirebaseFirestore.instance.collection('products').get();
    setState(() {
      _products = snap.docs.map((d) {
        final map = d.data();
        map['id'] = d.id;
        return Product.fromMap(map);
      }).toList();
      _loading = false;
    });
  }

  void _toggleProduct(Product product, bool selected) {
    setState(() {
      if (selected) {
        _selectedProducts[product.id] = product.price;
      } else {
        _selectedProducts.remove(product.id);
      }
    });
  }

  void _setProductPrice(String productId, double price) {
    setState(() {
      _selectedProducts[productId] = price;
    });
  }

  Future<void> _saveCatalog() async {
    if (_nameController.text.trim().isEmpty || _selectedProducts.isEmpty) return;
    setState(() { _saving = true; });
    final items = _selectedProducts.entries.map((e) {
      final product = _products.firstWhere((p) => p.id == e.key);
      return CatalogItem(productId: product.id, productName: product.name, price: e.value);
    }).toList();
    final catalog = Catalog(id: '', name: _nameController.text.trim(), items: items);
    await FirebaseFirestore.instance.collection('catalogs').add(catalog.toMap());
    setState(() { _saving = false; });
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Создать каталог')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Имя каталога',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Выберите товары и укажите цены:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _products.length,
                      itemBuilder: (context, i) {
                        final product = _products[i];
                        final selected = _selectedProducts.containsKey(product.id);
                        return Card(
                          child: ListTile(
                            leading: Checkbox(
                              value: selected,
                              onChanged: (v) => _toggleProduct(product, v ?? false),
                            ),
                            title: Text(product.name),
                            subtitle: selected
                                ? Row(
                                    children: [
                                      const Text('Цена: '),
                                      SizedBox(
                                        width: 80,
                                        child: TextFormField(
                                          initialValue: _selectedProducts[product.id]?.toStringAsFixed(2) ?? product.price.toStringAsFixed(2),
                                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                                          onChanged: (v) {
                                            final price = double.tryParse(v.replaceAll(',', '.')) ?? product.price;
                                            _setProductPrice(product.id, price);
                                          },
                                        ),
                                      ),
                                    ],
                                  )
                                : Text('Цена по складу: ${product.price.toStringAsFixed(2)}'),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _saveCatalog,
                      child: _saving ? const CircularProgressIndicator() : const Text('Сохранить каталог'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
} 