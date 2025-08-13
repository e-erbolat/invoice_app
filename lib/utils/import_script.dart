import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Скрипт для импорта данных в Firestore
/// Использование: dart import_script.dart path/to/export.json
class ImportScript {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> main(List<String> args) async {
    if (args.isEmpty) {
      print('Использование: dart import_script.dart <path_to_json_file>');
      return;
    }

    final filePath = args[0];
    final file = File(filePath);

    if (!await file.exists()) {
      print('Файл не найден: $filePath');
      return;
    }

    try {
      print('Читаем файл: $filePath');
      final jsonString = await file.readAsString();
      
      print('Парсим JSON...');
      final data = jsonDecode(jsonString);
      
      if (data.containsKey('collection') && data['collection'] == 'products') {
        await _importProducts(data);
      } else if (data.containsKey('collections')) {
        await _importAllCollections(data);
      } else {
        print('Неизвестная структура JSON файла');
      }
      
    } catch (e) {
      print('Ошибка импорта: $e');
    }
  }

  static Future<void> _importProducts(Map<String, dynamic> data) async {
    final products = data['data'] as List;
    print('Найдено ${products.length} продуктов для импорта');
    
    int successCount = 0;
    int errorCount = 0;
    
    for (int i = 0; i < products.length; i++) {
      try {
        final product = products[i] as Map<String, dynamic>;
        final documentId = product['documentId'] as String?;
        
        // Удаляем documentId из данных продукта
        product.remove('documentId');
        
        // Конвертируем timestamp поля
        _convertTimestamps(product);
        
        if (documentId != null) {
          await _firestore.collection('products').doc(documentId).set(product);
        } else {
          await _firestore.collection('products').add(product);
        }
        
        successCount++;
        print('✓ Импортирован продукт ${i + 1}: ${product['name']}');
      } catch (e) {
        errorCount++;
        print('✗ Ошибка импорта продукта ${i + 1}: $e');
      }
    }
    
    print('\nИмпорт завершен!');
    print('Успешно: $successCount');
    print('Ошибок: $errorCount');
  }

  static Future<void> _importAllCollections(Map<String, dynamic> data) async {
    final collections = data['collections'] as Map<String, dynamic>;
    print('Найдено ${collections.length} коллекций для импорта');
    
    for (final entry in collections.entries) {
      final collectionName = entry.key;
      final collectionData = entry.value as Map<String, dynamic>;
      
      if (collectionData.containsKey('error')) {
        print('⚠ Пропускаем коллекцию $collectionName: ${collectionData['error']}');
        continue;
      }
      
      final documents = collectionData['data'] as List;
      print('\nИмпортируем коллекцию $collectionName (${documents.length} документов)...');
      
      int successCount = 0;
      int errorCount = 0;
      
      for (int i = 0; i < documents.length; i++) {
        try {
          final document = documents[i] as Map<String, dynamic>;
          final documentId = document['documentId'] as String?;
          
          // Удаляем documentId из данных документа
          document.remove('documentId');
          
          // Конвертируем timestamp поля
          _convertTimestamps(document);
          
          if (documentId != null) {
            await _firestore.collection(collectionName).doc(documentId).set(document);
          } else {
            await _firestore.collection(collectionName).add(document);
          }
          
          successCount++;
          print('✓ Импортирован документ ${i + 1} в коллекцию $collectionName');
        } catch (e) {
          errorCount++;
          print('✗ Ошибка импорта документа ${i + 1} в коллекции $collectionName: $e');
        }
      }
      
      print('Коллекция $collectionName: Успешно $successCount, Ошибок $errorCount');
    }
    
    print('\nИмпорт всех коллекций завершен!');
  }

  static void _convertTimestamps(Map<String, dynamic> data) {
    final timestampFields = ['createdAt', 'updatedAt', 'date', 'approvedAt'];
    
    for (final field in timestampFields) {
      if (data.containsKey(field) && data[field] != null) {
        final value = data[field];
        if (value is String) {
          try {
            final date = DateTime.parse(value);
            data[field] = Timestamp.fromDate(date);
          } catch (e) {
            print('Ошибка конвертации timestamp для поля $field: $e');
          }
        }
      }
    }
  }
} 