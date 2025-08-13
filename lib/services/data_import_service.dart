import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Сервис для импорта данных в Firestore
class DataImportService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Импорт продуктов из JSON
  static Future<Map<String, dynamic>> importProductsFromJson(String jsonData) async {
    try {
      print('[DataImportService] Начинаем импорт продуктов...');
      
      final data = jsonDecode(jsonData);
      final products = data['data'] as List;
      
      int successCount = 0;
      int errorCount = 0;
      final errors = <String>[];
      
      for (int i = 0; i < products.length; i++) {
        try {
          final product = products[i] as Map<String, dynamic>;
          final documentId = product['documentId'] as String?;
          
          // Удаляем documentId из данных продукта
          product.remove('documentId');
          
          // Конвертируем timestamp поля
          _convertTimestamps(product);
          
          if (documentId != null) {
            // Используем оригинальный ID документа
            await _firestore.collection('products').doc(documentId).set(product);
          } else {
            // Создаем новый документ
            await _firestore.collection('products').add(product);
          }
          
          successCount++;
          print('[DataImportService] Импортирован продукт $i: ${product['name']}');
        } catch (e) {
          errorCount++;
          final error = 'Ошибка импорта продукта $i: $e';
          errors.add(error);
          print('[DataImportService] $error');
        }
      }
      
      final result = {
        'successCount': successCount,
        'errorCount': errorCount,
        'errors': errors,
        'totalCount': products.length,
      };
      
      print('[DataImportService] Импорт завершен! Успешно: $successCount, Ошибок: $errorCount');
      return result;
      
    } catch (e) {
      print('[DataImportService] Ошибка импорта: $e');
      rethrow;
    }
  }

  /// Импорт всех коллекций из JSON
  static Future<Map<String, dynamic>> importAllCollectionsFromJson(String jsonData) async {
    try {
      print('[DataImportService] Начинаем импорт всех коллекций...');
      
      final data = jsonDecode(jsonData);
      final collections = data['collections'] as Map<String, dynamic>;
      
      final results = <String, Map<String, dynamic>>{};
      
      for (final entry in collections.entries) {
        final collectionName = entry.key;
        final collectionData = entry.value as Map<String, dynamic>;
        
        if (collectionData.containsKey('error')) {
          results[collectionName] = {
            'successCount': 0,
            'errorCount': 0,
            'errors': ['Ошибка в исходных данных: ${collectionData['error']}'],
            'totalCount': 0,
          };
          continue;
        }
        
        final documents = collectionData['data'] as List;
        int successCount = 0;
        int errorCount = 0;
        final errors = <String>[];
        
        for (int i = 0; i < documents.length; i++) {
          try {
            final document = documents[i] as Map<String, dynamic>;
            final documentId = document['documentId'] as String?;
            
            // Удаляем documentId из данных документа
            document.remove('documentId');
            
            // Конвертируем timestamp поля
            _convertTimestamps(document);
            
            if (documentId != null) {
              // Используем оригинальный ID документа
              await _firestore.collection(collectionName).doc(documentId).set(document);
            } else {
              // Создаем новый документ
              await _firestore.collection(collectionName).add(document);
            }
            
            successCount++;
            print('[DataImportService] Импортирован документ $i в коллекцию $collectionName');
          } catch (e) {
            errorCount++;
            final error = 'Ошибка импорта документа $i в коллекции $collectionName: $e';
            errors.add(error);
            print('[DataImportService] $error');
          }
        }
        
        results[collectionName] = {
          'successCount': successCount,
          'errorCount': errorCount,
          'errors': errors,
          'totalCount': documents.length,
        };
      }
      
      print('[DataImportService] Импорт всех коллекций завершен!');
      return results;
      
    } catch (e) {
      print('[DataImportService] Ошибка импорта всех коллекций: $e');
      rethrow;
    }
  }

  /// Конвертация timestamp полей из ISO строки в Firestore Timestamp
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
            print('[DataImportService] Ошибка конвертации timestamp для поля $field: $e');
          }
        }
      }
    }
  }

  /// Проверка структуры JSON файла
  static Map<String, dynamic> validateJsonStructure(String jsonData) {
    try {
      final data = jsonDecode(jsonData);
      final validation = <String, dynamic>{
        'isValid': true,
        'type': 'unknown',
        'collections': <String>[],
        'errors': <String>[],
      };
      
      if (data.containsKey('collection') && data['collection'] == 'products') {
        validation['type'] = 'products';
        if (data.containsKey('data') && data['data'] is List) {
          validation['productCount'] = (data['data'] as List).length;
        } else {
          validation['isValid'] = false;
          validation['errors'].add('Отсутствует поле "data" или оно не является списком');
        }
      } else if (data.containsKey('collections')) {
        validation['type'] = 'all_collections';
        final collections = data['collections'] as Map<String, dynamic>;
        validation['collections'] = collections.keys.toList();
        
        for (final entry in collections.entries) {
          final collectionData = entry.value as Map<String, dynamic>;
          if (!collectionData.containsKey('data') || collectionData['data'] is! List) {
            validation['isValid'] = false;
            validation['errors'].add('Коллекция ${entry.key}: отсутствует поле "data" или оно не является списком');
          }
        }
      } else {
        validation['isValid'] = false;
        validation['errors'].add('Неизвестная структура JSON файла');
      }
      
      return validation;
    } catch (e) {
      return {
        'isValid': false,
        'type': 'invalid_json',
        'errors': ['Ошибка парсинга JSON: $e'],
      };
    }
  }

  /// Очистка коллекции (удаление всех документов)
  static Future<void> clearCollection(String collectionName) async {
    try {
      print('[DataImportService] Очистка коллекции $collectionName...');
      
      final querySnapshot = await _firestore.collection(collectionName).get();
      final batch = _firestore.batch();
      
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      print('[DataImportService] Коллекция $collectionName очищена. Удалено ${querySnapshot.docs.length} документов');
      
    } catch (e) {
      print('[DataImportService] Ошибка очистки коллекции $collectionName: $e');
      rethrow;
    }
  }

  /// Получить статистику импорта
  static Map<String, dynamic> getImportStats(Map<String, dynamic> results) {
    int totalSuccess = 0;
    int totalErrors = 0;
    int totalDocuments = 0;
    final allErrors = <String>[];
    
    for (final result in results.values) {
      totalSuccess += result['successCount'] as int;
      totalErrors += result['errorCount'] as int;
      totalDocuments += result['totalCount'] as int;
      allErrors.addAll((result['errors'] as List).cast<String>());
    }
    
    return {
      'totalSuccess': totalSuccess,
      'totalErrors': totalErrors,
      'totalDocuments': totalDocuments,
      'successRate': totalDocuments > 0 ? (totalSuccess / totalDocuments * 100) : 0,
      'allErrors': allErrors,
    };
  }
} 