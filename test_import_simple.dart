import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  // Инициализируем Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print('🔍 Тестируем импорт...');

  try {
    // Читаем тестовый файл
    final file = File('test_products.json');
    if (!await file.exists()) {
      print('❌ Файл test_products.json не найден');
      return;
    }

    final jsonString = await file.readAsString();
    final jsonData = json.decode(jsonString);
    
    print('✅ JSON файл прочитан');
    print('📊 Коллекция: ${jsonData['collection']}');
    print('📊 Количество: ${jsonData['count']}');
    
    // Проверяем первый продукт
    final firstProduct = jsonData['data'][0];
    print('🔍 Первый продукт: ${firstProduct['name']}');
    print('🔍 ID: ${firstProduct['id']}');
    print('🔍 DocumentId: ${firstProduct['documentId']}');
    
    // Пробуем сохранить в Firestore
    final firestore = FirebaseFirestore.instance;
    final productId = firstProduct['id'] ?? firstProduct['documentId'] ?? 'test_${DateTime.now().millisecondsSinceEpoch}';
    
    await firestore.collection('products').doc(productId).set({
      'id': productId,
      'name': firstProduct['name'],
      'description': firstProduct['description'] ?? '',
      'price': (firstProduct['price'] ?? 0).toDouble(),
      'stockQuantity': (firstProduct['stockQuantity'] ?? 0).toInt(),
      'category': firstProduct['category'] ?? '',
      'barcode': firstProduct['barcode'] ?? '',
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
    
    print('✅ Продукт сохранен в Firestore с ID: $productId');
    
  } catch (e) {
    print('❌ Ошибка: $e');
  }
} 