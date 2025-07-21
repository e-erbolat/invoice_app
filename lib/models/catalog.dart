import 'package:flutter/foundation.dart';

class Catalog {
  final String id;
  final String name;
  final List<CatalogItem> items;

  Catalog({required this.id, required this.name, required this.items});

  factory Catalog.fromMap(Map<String, dynamic> map, String id) {
    return Catalog(
      id: id,
      name: map['name'] ?? '',
      items: (map['items'] as List<dynamic>? ?? [])
          .map((e) => CatalogItem.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'items': items.map((e) => e.toMap()).toList(),
    };
  }
}

class CatalogItem {
  final String productId;
  final String productName;
  final double price;

  CatalogItem({required this.productId, required this.productName, required this.price});

  factory CatalogItem.fromMap(Map<String, dynamic> map) {
    return CatalogItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'price': price,
    };
  }
} 