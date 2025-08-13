import 'dart:typed_data';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import '../models/invoice.dart';
import '../models/analytics/outlet_sales_data.dart';
import '../models/analytics/product_sales_data.dart';
import 'dart:html' as html;

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
            case 2: cell.value = item.originalPrice; break; // Цена по прайсу
            case 3: cell.value = item.price; break; // Цена со скидкой
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
            case 2: cell.value = item.originalPrice; break; // Цена по прайсу
            case 3: cell.value = item.price; break; // Цена со скидкой
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

  /// Экспорт аналитики продаж по торговым точкам в Excel
  static Future<void> exportOutletAnalyticsToExcel({
    required List<OutletSalesData> outletSalesData,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (_isExporting) return;
    _isExporting = true;

    try {
      if (outletSalesData.isEmpty) return;

      final excel = Excel.createExcel();
      final defaultSheetName = excel.sheets.keys.first;
      excel.delete(defaultSheetName);
      final sheet = excel['Аналитика по торговым точкам'];

      final cellStyle = CellStyle(
        fontFamily: 'Times New Roman',
        fontSize: 12,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        bold: true,
      );

      final dataStyle = CellStyle(
        fontFamily: 'Times New Roman',
        fontSize: 11,
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
      );

      int currentRow = 0;

      // Заголовок отчета
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = 
          'Аналитика продаж по торговым точкам';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = cellStyle;
      currentRow++;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = 
          'Период: ${DateFormat('dd.MM.yyyy').format(startDate)} - ${DateFormat('dd.MM.yyyy').format(endDate)}';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = dataStyle;
      currentRow++;
      currentRow++;

      // Заголовки таблицы
      final headers = [
        '№',
        'Торговая точка',
        'Адрес',
        'Общая сумма продаж',
        'Количество накладных',
        'Средний чек',
      ];

      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow));
        cell.value = headers[i];
        cell.cellStyle = cellStyle;
      }
      currentRow++;

      // Данные по торговым точкам
      for (int i = 0; i < outletSalesData.length; i++) {
        final outlet = outletSalesData[i];
        final averageCheck = outlet.invoiceCount > 0 
            ? outlet.totalSales / outlet.invoiceCount 
            : 0.0;

        final cells = [
          i + 1,
          outlet.outletName,
          outlet.outletAddress,
          outlet.totalSales,
          outlet.invoiceCount,
          averageCheck,
        ];

        for (int j = 0; j < cells.length; j++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: currentRow));
          cell.value = cells[j];
          cell.cellStyle = dataStyle;
        }
        currentRow++;
      }

      // Итоги
      currentRow++;
      final totalSales = outletSalesData.fold<double>(0.0, (sum, outlet) => sum + outlet.totalSales);
      final totalInvoices = outletSalesData.fold<int>(0, (sum, outlet) => sum + outlet.invoiceCount);
      final averageCheck = totalInvoices > 0 ? totalSales / totalInvoices : 0.0;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = 'ИТОГО';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = cellStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow)).value = totalSales;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow)).cellStyle = cellStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow)).value = totalInvoices;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow)).cellStyle = cellStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow)).value = averageCheck;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow)).cellStyle = cellStyle;

      // Сохраняем файл
      final bytes = excel.save();
      if (bytes != null) {
        final fileName = 'outlet_analytics_${DateFormat('yyyyMMdd').format(startDate)}_${DateFormat('yyyyMMdd').format(endDate)}';
        
        if (kIsWeb) {
          final blob = html.Blob([bytes]);
          final url = html.Url.createObjectUrlFromBlob(blob);
          html.AnchorElement(href: url)
            ..setAttribute('download', '$fileName.xlsx')
            ..click();
          html.Url.revokeObjectUrl(url);
        } else {
          await Share.shareXFiles(
            [XFile.fromData(
              Uint8List.fromList(bytes),
              name: '$fileName.xlsx',
              mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            )],
            text: 'Экспорт аналитики по торговым точкам',
          );
        }
      }
    } finally {
      _isExporting = false;
    }
  }

  /// Экспорт аналитики продаж по товарам в Excel
  static Future<void> exportProductAnalyticsToExcel({
    required List<ProductAnalyticsData> productAnalyticsData,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (_isExporting) return;
    _isExporting = true;

    try {
      if (productAnalyticsData.isEmpty) return;

      final excel = Excel.createExcel();
      final defaultSheetName = excel.sheets.keys.first;
      excel.delete(defaultSheetName);
      final sheet = excel['Аналитика по товарам'];

      final cellStyle = CellStyle(
        fontFamily: 'Times New Roman',
        fontSize: 12,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        bold: true,
      );

      final dataStyle = CellStyle(
        fontFamily: 'Times New Roman',
        fontSize: 11,
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
      );

      int currentRow = 0;

      // Заголовок отчета
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = 
          'Аналитика продаж по товарам';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = cellStyle;
      currentRow++;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = 
          'Период: ${DateFormat('dd.MM.yyyy').format(startDate)} - ${DateFormat('dd.MM.yyyy').format(endDate)}';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = dataStyle;
      currentRow++;
      currentRow++;

      // Заголовки таблицы
      final headers = [
        '№',
        'Товар',
        'Цена',
        'Общая сумма продаж',
        'Общее количество',
        'Обычные продажи',
        'Обычные продажи (сумма)',
        'Бонусные продажи',
        'Бонусные продажи (сумма)',
      ];

      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow));
        cell.value = headers[i];
        cell.cellStyle = cellStyle;
      }
      currentRow++;

      // Данные по товарам
      for (int i = 0; i < productAnalyticsData.length; i++) {
        final product = productAnalyticsData[i];

        final cells = [
          i + 1,
          product.productName,
          product.price,
          product.totalSales,
          product.totalQuantity,
          product.regularQuantity,
          product.regularAmount,
          product.bonusQuantity,
          product.bonusAmount,
        ];

        for (int j = 0; j < cells.length; j++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: currentRow));
          cell.value = cells[j];
          cell.cellStyle = dataStyle;
        }
        currentRow++;
      }

      // Итоги
      currentRow++;
      final totalSales = productAnalyticsData.fold<double>(0.0, (sum, product) => sum + product.totalSales);
      final totalQuantity = productAnalyticsData.fold<int>(0, (sum, product) => sum + product.totalQuantity);
      final totalRegularQuantity = productAnalyticsData.fold<int>(0, (sum, product) => sum + product.regularQuantity);
      final totalRegularAmount = productAnalyticsData.fold<double>(0.0, (sum, product) => sum + product.regularAmount);
      final totalBonusQuantity = productAnalyticsData.fold<int>(0, (sum, product) => sum + product.bonusQuantity);
      final totalBonusAmount = productAnalyticsData.fold<double>(0.0, (sum, product) => sum + product.bonusAmount);

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = 'ИТОГО';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = cellStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow)).value = totalSales;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow)).cellStyle = cellStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow)).value = totalQuantity;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow)).cellStyle = cellStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow)).value = totalRegularQuantity;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow)).cellStyle = cellStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: currentRow)).value = totalRegularAmount;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: currentRow)).cellStyle = cellStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: currentRow)).value = totalBonusQuantity;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: currentRow)).cellStyle = cellStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: currentRow)).value = totalBonusAmount;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: currentRow)).cellStyle = cellStyle;

      // Сохраняем файл
      final bytes = excel.save();
      if (bytes != null) {
        final fileName = 'product_analytics_${DateFormat('yyyyMMdd').format(startDate)}_${DateFormat('yyyyMMdd').format(endDate)}';
        
        if (kIsWeb) {
          final blob = html.Blob([bytes]);
          final url = html.Url.createObjectUrlFromBlob(blob);
          html.AnchorElement(href: url)
            ..setAttribute('download', '$fileName.xlsx')
            ..click();
          html.Url.revokeObjectUrl(url);
        } else {
          await Share.shareXFiles(
            [XFile.fromData(
              Uint8List.fromList(bytes),
              name: '$fileName.xlsx',
              mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            )],
            text: 'Экспорт аналитики по товарам',
          );
        }
      }
    } finally {
      _isExporting = false;
    }
  }
} 