import 'package:flutter/material.dart';
import '../models/catalog.dart';

class CatalogDetailScreen extends StatelessWidget {
  final Catalog catalog;
  const CatalogDetailScreen({Key? key, required this.catalog}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(catalog.name)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: catalog.items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final item = catalog.items[i];
          return Card(
            child: ListTile(
              title: Text(item.productName),
              subtitle: Text('Цена: ${item.price.toStringAsFixed(2)}'),
            ),
          );
        }, 
      ),
    );
  }
} 