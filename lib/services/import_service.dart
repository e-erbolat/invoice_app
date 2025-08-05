import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import '../models/product.dart';

// Структура для импортируемых данных
class ImportData {
  final String exportDate;
  final String collection;
  final int count;
  final List<Map<String, dynamic>> data;

  ImportData({
    required this.exportDate,
    required this.collection,
    required this.count,
    required this.data,
  });

  factory ImportData.fromJson(Map<String, dynamic> json) {
    return ImportData(
      exportDate: json['exportDate'] ?? '',
      collection: json['collection'] ?? '',
      count: json['count'] ?? 0,
      data: List<Map<String, dynamic>>.from(json['data'] ?? []),
    );
  }
}

class ImportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Выбор файла JSON
  Future<Map<String, dynamic>?> pickJsonFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        // На веб-платформе используем bytes, на мобильных - path
        if (file.bytes != null) {
          // Веб-платформа
          final jsonString = utf8.decode(file.bytes!);
          final jsonData = json.decode(jsonString);
          return jsonData;
        } else if (file.path != null) {
          // Мобильная платформа
          final fileObj = File(file.path!);
          final jsonString = await fileObj.readAsString();
          final jsonData = json.decode(jsonString);
          return jsonData;
        }
      }
      return null;
    } catch (e) {
      print('Ошибка выбора файла: $e');
      return null;
    }
  }

  // Импорт продуктов с прогрессом
  Future<ImportResult> importProducts(Map<String, dynamic> jsonData, {Function(int current, int total)? onProgress, bool skipExisting = false}) async {
    try {
      print('🔍 Начинаем импорт продуктов...');
      
      // Парсим данные
      final importData = ImportData.fromJson(jsonData);
      
      print('📊 Найдено ${importData.count} продуктов для импорта');
      
      if (importData.collection != 'products') {
        throw Exception('Неверная коллекция. Ожидается "products", получено "${importData.collection}"');
      }

      int successCount = 0;
      int errorCount = 0;
      List<String> errors = [];
      final total = importData.data.length;

      // Импортируем каждый продукт
      for (int i = 0; i < importData.data.length; i++) {
        // Обновляем прогресс
        onProgress?.call(i + 1, total);
        try {
          final productData = importData.data[i];
          
          print('🔍 Обрабатываем продукт ${i + 1}: ${productData['name']}');
          
          // Проверяем обязательные поля
          if ((productData['id'] == null && productData['documentId'] == null) || productData['name'] == null) {
            final error = 'Продукт ${i + 1}: отсутствуют обязательные поля (id/documentId, name)';
            errors.add(error);
            errorCount++;
            print('❌ $error');
            continue;
          }

          // Создаем объект продукта
          final product = Product(
            id: productData['id'] ?? productData['documentId'] ?? '', // Используем documentId как fallback
            name: productData['name'],
            description: productData['description'] ?? '',
            price: (productData['price'] ?? 0).toDouble(), // Поддерживаем как int, так и double
            stockQuantity: (productData['stockQuantity'] ?? 0).toInt(),
            category: productData['category'] ?? '',
            barcode: productData['barcode'] ?? '',
            createdAt: _parseDateTime(productData['createdAt']),
            updatedAt: _parseDateTime(productData['updatedAt']),
          );

          // Проверяем, существует ли уже продукт
          if (skipExisting) {
            final existingDoc = await _firestore.collection('products').doc(product.id).get();
            if (existingDoc.exists) {
              print('⏭️ Пропускаем существующий продукт: ${product.name} (ID: ${product.id})');
              continue;
            }
          }
          
          // Сохраняем в Firestore
          await _firestore.collection('products').doc(product.id).set(product.toMap());
          
          successCount++;
          print('✅ Импортирован продукт: ${product.name} (ID: ${product.id})');
          
        } catch (e) {
          errorCount++;
          final error = 'Продукт ${i + 1}: $e';
          errors.add(error);
          print('❌ $error');
        }
      }

      return ImportResult(
        successCount: successCount,
        errorCount: errorCount,
        errors: errors,
        totalCount: importData.count,
      );

    } catch (e) {
      print('❌ Ошибка импорта: $e');
      return ImportResult(
        successCount: 0,
        errorCount: 1,
        errors: ['Общая ошибка импорта: $e'],
        totalCount: 0,
      );
    }
  }

  // Импорт других коллекций (расширяемый)
  Future<ImportResult> importCollection(Map<String, dynamic> jsonData, String collectionName, {Function(int current, int total)? onProgress, bool skipExisting = false}) async {
    switch (collectionName) {
      case 'products':
        return await importProducts(jsonData, onProgress: onProgress, skipExisting: skipExisting);
      case 'outlets':
        return await importOutlets(jsonData);
      case 'sales_reps':
        return await importSalesReps(jsonData);
      default:
        throw Exception('Неподдерживаемая коллекция: $collectionName');
    }
  }

  // Импорт торговых точек
  Future<ImportResult> importOutlets(Map<String, dynamic> jsonData) async {
    // TODO: Реализовать импорт торговых точек
    throw UnimplementedError('Импорт торговых точек пока не реализован');
  }

  // Импорт торговых представителей
  Future<ImportResult> importSalesReps(Map<String, dynamic> jsonData) async {
    // TODO: Реализовать импорт торговых представителей
    throw UnimplementedError('Импорт торговых представителей пока не реализован');
  }

  // Безопасный парсинг даты
  DateTime _parseDateTime(dynamic dateValue) {
    try {
      if (dateValue == null || dateValue.toString().isEmpty) {
        return DateTime.now();
      }
      return DateTime.parse(dateValue.toString());
    } catch (e) {
      print('⚠️ Ошибка парсинга даты: $dateValue, используем текущую дату');
      return DateTime.now();
    }
  }

  // Получение статистики коллекции
  Future<CollectionStats> getCollectionStats(String collectionName) async {
    try {
      final snapshot = await _firestore.collection(collectionName).get();
      return CollectionStats(
        collectionName: collectionName,
        documentCount: snapshot.docs.length,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      print('Ошибка получения статистики: $e');
      return CollectionStats(
        collectionName: collectionName,
        documentCount: 0,
        lastUpdated: DateTime.now(),
      );
    }
  }
}

// Результат импорта
class ImportResult {
  final int successCount;
  final int errorCount;
  final List<String> errors;
  final int totalCount;

  ImportResult({
    required this.successCount,
    required this.errorCount,
    required this.errors,
    required this.totalCount,
  });

  bool get isSuccess => errorCount == 0;
  double get successRate => totalCount > 0 ? (successCount / totalCount) * 100 : 0;
}

// Статистика коллекции
class CollectionStats {
  final String collectionName;
  final int documentCount;
  final DateTime lastUpdated;

  CollectionStats({
    required this.collectionName,
    required this.documentCount,
    required this.lastUpdated,
  });
} 