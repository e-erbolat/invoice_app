import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/invoice_item.dart';

/// Сервис для миграции данных с лучшими практиками
class DataMigrationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Миграция накладных для добавления originalPrice
  static Future<void> migrateInvoicesToOriginalPrice() async {
    try {
      print('[DataMigrationService] Начинаем миграцию накладных...');
      
      final querySnapshot = await _firestore.collection('invoices').get();
      int migratedCount = 0;
      int errorCount = 0;
      
      for (final doc in querySnapshot.docs) {
        try {
          final data = doc.data();
          final items = data['items'] as List?;
          
          if (items == null) continue;
          
          bool needsMigration = false;
          final migratedItems = <Map<String, dynamic>>[];
          
          for (final item in items) {
            final itemMap = item as Map<String, dynamic>;
            
            // Проверяем, есть ли уже originalPrice
            if (!itemMap.containsKey('originalPrice') || itemMap['originalPrice'] == null) {
              needsMigration = true;
              
              // Создаем новый товар с originalPrice
              final migratedItem = Map<String, dynamic>.from(itemMap);
              migratedItem['originalPrice'] = itemMap['price']; // Используем старую цену как оригинальную
              
              migratedItems.add(migratedItem);
            } else {
              migratedItems.add(itemMap);
            }
          }
          
          if (needsMigration) {
            await _firestore.collection('invoices').doc(doc.id).update({
              'items': migratedItems,
              'migratedAt': FieldValue.serverTimestamp(),
            });
            
            migratedCount++;
            print('[DataMigrationService] Мигрирована накладная: ${doc.id}');
          }
        } catch (e) {
          errorCount++;
          print('[DataMigrationService] Ошибка миграции накладной ${doc.id}: $e');
        }
      }
      
      print('[DataMigrationService] Миграция завершена!');
      print('[DataMigrationService] Успешно мигрировано: $migratedCount');
      print('[DataMigrationService] Ошибок: $errorCount');
      
    } catch (e) {
      print('[DataMigrationService] Критическая ошибка миграции: $e');
      rethrow;
    }
  }
  
  /// Проверка статуса миграции
  static Future<Map<String, dynamic>> getMigrationStatus() async {
    try {
      final querySnapshot = await _firestore.collection('invoices').get();
      int totalInvoices = querySnapshot.docs.length;
      int migratedInvoices = 0;
      int itemsWithOriginalPrice = 0;
      int totalItems = 0;
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final items = data['items'] as List?;
        
        if (items != null) {
          totalItems += items.length;
          
          bool hasOriginalPrice = true;
          for (final item in items) {
            final itemMap = item as Map<String, dynamic>;
            if (!itemMap.containsKey('originalPrice') || itemMap['originalPrice'] == null) {
              hasOriginalPrice = false;
            } else {
              itemsWithOriginalPrice++;
            }
          }
          
          if (hasOriginalPrice) {
            migratedInvoices++;
          }
        }
      }
      
      return {
        'totalInvoices': totalInvoices,
        'migratedInvoices': migratedInvoices,
        'totalItems': totalItems,
        'itemsWithOriginalPrice': itemsWithOriginalPrice,
        'migrationProgress': totalInvoices > 0 ? (migratedInvoices / totalInvoices * 100) : 0,
        'itemsProgress': totalItems > 0 ? (itemsWithOriginalPrice / totalItems * 100) : 0,
      };
    } catch (e) {
      print('[DataMigrationService] Ошибка получения статуса миграции: $e');
      rethrow;
    }
  }
} 