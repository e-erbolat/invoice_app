import 'package:flutter/material.dart';
import '../models/catalog.dart';
import 'product_catalog_screen.dart';
import 'catalog_create_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'catalog_detail_screen.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({Key? key}) : super(key: key);

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  List<Catalog> catalogs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCatalogs();
  }

  Future<void> _loadCatalogs() async {
    setState(() { _loading = true; });
    final snap = await FirebaseFirestore.instance.collection('catalogs').get();
    setState(() {
      catalogs = snap.docs.map((d) => Catalog.fromMap(d.data(), d.id)).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Удалён appBar: AppBar(...)
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 1 + (catalogs.isNotEmpty ? catalogs.length : 1),
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          if (i == 0) {
            // Первый пункт — общий склад
            return Card(
              color: Colors.deepPurple.shade50,
              child: ListTile(
                leading: const Icon(Icons.warehouse, color: Colors.deepPurple),
                title: const Text('Склад', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Все товары компании'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProductCatalogScreen()),
                  );
                },
              ),
            );
          }
          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (catalogs.isEmpty) {
            return const Center(child: Text('Каталоги отсутствуют'));
          }
          final catalog = catalogs[i - 1];
          return Card(
            child: ListTile(
              title: Text(catalog.name),
              subtitle: Text('Товаров: ${catalog.items.length}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CatalogDetailScreen(catalog: catalog),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CatalogCreateScreen()),
          );
          if (created == true) {
            _loadCatalogs();
          }
        },
        child: const Icon(Icons.add),
        tooltip: 'Добавить каталог',
      ),
    );
  }
} 