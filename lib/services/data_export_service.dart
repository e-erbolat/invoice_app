import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' as excel;
import 'package:flutter/foundation.dart';
import 'dart:html' as html;

/// Сервис для экспорта данных из Firestore
class DataExportService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Экспорт всех продуктов в JSON
  static Future<void> exportProductsToJson() async {
    try {
      print('[DataExportService] Начинаем экспорт продуктов...');
      
      final querySnapshot = await _firestore.collection('products').get();
      final products = <Map<String, dynamic>>[];
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        // Добавляем ID документа в данные
        data['documentId'] = doc.id;
        products.add(data);
      }
      
      final jsonData = jsonEncode({
        'exportDate': DateTime.now().toIso8601String(),
        'collection': 'products',
        'count': products.length,
        'data': products,
      });
      
      // Создаем файл для экспорта
      final fileName = 'products_export_${DateTime.now().millisecondsSinceEpoch}.json';
      
      // Для веб используем простой download, для мобильных - Share
      if (kIsWeb) {
        // Создаем blob и скачиваем файл
        final bytes = utf8.encode(jsonData);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        // Для мобильных используем Share
        await Share.shareXFiles(
          [XFile.fromData(Uint8List.fromList(utf8.encode(jsonData)), name: fileName)],
          text: 'Экспорт продуктов в JSON',
        );
      }
      
      print('[DataExportService] Экспорт завершен! Экспортировано ${products.length} продуктов');
      
    } catch (e) {
      print('[DataExportService] Ошибка экспорта: $e');
      rethrow;
    }
  }

  /// Экспорт всех продуктов в Excel
  static Future<void> exportProductsToExcel() async {
    try {
      print('[DataExportService] Начинаем экспорт продуктов в Excel...');
      
      final querySnapshot = await _firestore.collection('products').get();
      
      // Создаем Excel документ
      final excelDoc = excel.Excel.createExcel();
      final defaultSheetName = excelDoc.sheets.keys.first;
      excelDoc.delete(defaultSheetName);
      final sheet = excelDoc['Products'];
      
      // Заголовки
      final headers = [
        'ID документа',
        'ID продукта',
        'Название',
        'Цена',
        'Описание',
        'Категория',
        'Дата создания',
        'Дата обновления',
      ];
      
      // Записываем заголовки
      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = headers[i];
        
        // Форматирование заголовков
        cell.cellStyle = excel.CellStyle(
          bold: true,
          horizontalAlign: excel.HorizontalAlign.Center,
        );
      }
      
      // Записываем данные
      int rowIndex = 1;
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        
        final cells = [
          doc.id, // ID документа
          data['id'] ?? '',
          data['name'] ?? '',
          data['price']?.toString() ?? '',
          data['description'] ?? '',
          data['category'] ?? '',
          _formatTimestamp(data['createdAt']),
          _formatTimestamp(data['updatedAt']),
        ];
        
        for (int i = 0; i < cells.length; i++) {
          final cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex));
          cell.value = cells[i];
          
                  // Форматирование ячеек
        cell.cellStyle = excel.CellStyle(
          horizontalAlign: excel.HorizontalAlign.Center,
        );
        }
        
        rowIndex++;
      }
      
      // Автоматическая ширина столбцов
      // Примечание: setColumnWidth не поддерживается в текущей версии excel пакета
      
      // Сохраняем файл
      final fileName = 'products_export_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final bytes = excelDoc.encode();
      
      // Для веб используем простой download, для мобильных - Share
      if (kIsWeb) {
        // Создаем blob и скачиваем файл
        final blob = html.Blob([bytes ?? []]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        // Для мобильных используем Share
        await Share.shareXFiles(
          [XFile.fromData(Uint8List.fromList(bytes ?? []), name: fileName)],
          text: 'Экспорт продуктов в Excel',
        );
      }
      
      print('[DataExportService] Экспорт в Excel завершен! Экспортировано ${querySnapshot.docs.length} продуктов');
      
    } catch (e) {
      print('[DataExportService] Ошибка экспорта в Excel: $e');
      rethrow;
    }
  }



  /// Форматирование Timestamp для Excel
  static String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    
    if (timestamp is Timestamp) {
      return timestamp.toDate().toIso8601String();
    } else if (timestamp is Map && timestamp['_seconds'] != null) {
      final seconds = timestamp['_seconds'] as int;
      final nanoseconds = timestamp['_nanoseconds'] as int? ?? 0;
      final date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000 + (nanoseconds / 1000000).round());
      return date.toIso8601String();
    }
    
    return timestamp.toString();
  }


} 