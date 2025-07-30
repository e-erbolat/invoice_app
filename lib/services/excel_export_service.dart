import 'dart:typed_data';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import '../models/invoice.dart';

class ExcelExportService {
  static bool _isExporting = false;
  
  static Future<void> exportInvoicesToExcel({
    required List<Invoice> invoices,
    required String sheetName,
    required String fileName,
  }) async {
    // Защита от двойного вызова
    if (_isExporting) return;
    _isExporting = true;
    
    try {
    if (invoices.isEmpty) return;
    
    // Создаем Excel файл
    final excel = Excel.createExcel();
    
    // Удаляем лист по умолчанию
     String firstSheetName = excel.tables.keys.first;
    // Получаем старый лист
    var firstSheet = excel.tables[firstSheetName];
    if (firstSheet != null) {
      excel.delete(firstSheetName);
    }
    
    
    // Создаем новый лист с нужным именем
    final sheet = excel[sheetName];
    final cellStyle = CellStyle(
      fontFamily: 'Times New Roman',
      fontSize: 25,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    
    int currentRow = 0;
    
    for (int invoiceIndex = 0; invoiceIndex < invoices.length; invoiceIndex++) {
      final invoice = invoices[invoiceIndex];
      
      // Заголовок накладной (строка 1)
      var cell1 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow));
      cell1.value = 'MELLO AQTOBE';
      cell1.cellStyle = cellStyle;
      var cell2 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow));
      cell2.value = DateFormat('dd.MM.yyyy').format(invoice.date.toDate());
      cell2.cellStyle = cellStyle;
      currentRow++;
      
      // Заголовки таблицы (строка 2)
      for (int col = 0; col <= 5; col++) {
        var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: currentRow));
        switch (col) {
          case 0: cell.value = '№'; break;
          case 1: cell.value = 'Наименование товара'; break;
          case 2: cell.value = 'Цена по прайсу'; break;
          case 3: cell.value = 'Цена со скидкой'; break;
          case 4: cell.value = 'Количество'; break;
          case 5: cell.value = 'Итого'; break;
        }
        cell.cellStyle = cellStyle;
      }
      currentRow++;
      
      // Товары: сначала обычные, потом бонусные
      final nonBonusItems = invoice.items.where((item) => !item.isBonus).toList();
      final bonusItems = invoice.items.where((item) => item.isBonus).toList();
      
      for (int itemIndex = 0; itemIndex < nonBonusItems.length; itemIndex++) {
        final item = nonBonusItems[itemIndex];
        for (int col = 0; col <= 5; col++) {
          var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: currentRow));
          switch (col) {
            case 0: cell.value = itemIndex + 1; break;
            case 1: cell.value = item.productName; break;
            case 2: cell.value = item.price; break;
            case 3: cell.value = item.price; break;
            case 4: cell.value = item.quantity; break;
            case 5: cell.value = item.totalPrice; break;
          }
          cell.cellStyle = cellStyle;
        }
        currentRow++;
      }
      
      for (int itemIndex = 0; itemIndex < bonusItems.length; itemIndex++) {
        final item = bonusItems[itemIndex];
        for (int col = 0; col <= 5; col++) {
          var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: currentRow));
          switch (col) {
            case 0: cell.value = nonBonusItems.length + itemIndex + 1; break;
            case 1: cell.value = 'Бонус ${item.productName}'; break;
            case 2: cell.value = item.price; break;
            case 3: cell.value = item.price; break;
            case 4: cell.value = item.quantity; break;
            case 5: cell.value = item.totalPrice; break;
          }
          cell.cellStyle = cellStyle;
        }
        currentRow++;
      }
      
      // Итоги
      final totalQuantity = invoice.items.fold<int>(0, (sum, item) => sum + item.quantity);
      var cellItogo = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow));
      cellItogo.value = 'Итого';
      cellItogo.cellStyle = cellStyle;
      var cellQty = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow));
      cellQty.value = totalQuantity;
      cellQty.cellStyle = cellStyle;
      var cellSum = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow));
      cellSum.value = invoice.totalAmount;
      cellSum.cellStyle = cellStyle;
      currentRow++;
      
      // Адрес доставки
      var cellAddr = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow));
      cellAddr.value = 'адрес доставки: ${invoice.outletName}, ${invoice.outletAddress}';
      cellAddr.cellStyle = cellStyle;
      var cellDebt = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow));
      cellDebt.value = 'долг';
      cellDebt.cellStyle = cellStyle;
      var cellDebtSum = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow));
      cellDebtSum.value = invoice.totalAmount;
      cellDebtSum.cellStyle = cellStyle;
      currentRow++;
      
      // Контактная информация
      var cellContact = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)); 
      cellContact.cellStyle = cellStyle;
      currentRow++;
      currentRow++;
      
     
      // Пустая строка между накладными
      if (invoiceIndex < invoices.length - 1) {
        currentRow++;
      }
    }
    
    // Сохраняем файл
    final bytes = excel.save();
    if (bytes != null) {
      // Используем Share для всех платформ, чтобы избежать двойного скачивания
      await Share.shareXFiles(
        [XFile.fromData(
          Uint8List.fromList(bytes),
          name: '$fileName.xlsx',
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        )],
        text: 'Экспорт накладных в Excel',
      );
    }
    } finally {
      _isExporting = false;
    }
  }
} 