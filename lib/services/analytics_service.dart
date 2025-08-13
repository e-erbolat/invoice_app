import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/invoice.dart';
import '../models/outlet.dart';
import '../models/product.dart';
import '../models/analytics/outlet_sales_data.dart';
import '../models/analytics/product_sales_data.dart';

/// Сервис для аналитики продаж
class AnalyticsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Получение аналитики продаж по торговым точкам
  static Future<List<OutletSalesData>> getOutletSalesAnalytics({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      print('[AnalyticsService] Загружаем аналитику по торговым точкам...');
      
      // Получаем все накладные за период
      final invoicesQuery = await _firestore
          .collection('invoices')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      final invoices = invoicesQuery.docs
          .map((doc) => Invoice.fromMap(doc.data()))
          .toList();

      print('[AnalyticsService] Найдено ${invoices.length} накладных');

      // Группируем накладные по торговым точкам
      final Map<String, List<Invoice>> outletInvoices = {};
      for (final invoice in invoices) {
        final outletId = invoice.outletId;
        outletInvoices.putIfAbsent(outletId, () => []).add(invoice);
      }

      // Создаем агрегированные данные для каждой точки
      final List<OutletSalesData> outletSalesData = [];
      
      for (final entry in outletInvoices.entries) {
        final outletId = entry.key;
        final outletInvoices = entry.value;
        
        // Получаем информацию о торговой точке
        final outletDoc = await _firestore.collection('outlets').doc(outletId).get();
        final outlet = outletDoc.exists 
            ? Outlet.fromMap(outletDoc.data()!)
            : Outlet(id: outletId, name: 'Неизвестная точка', address: '', contactPerson: '', phone: '', region: '', createdAt: DateTime.now(), updatedAt: DateTime.now());

        // Агрегируем данные по товарам
        final Map<String, ProductSalesData> productSales = {};
        final List<InvoiceSummary> invoiceSummaries = [];

        for (final invoice in outletInvoices) {
          // Добавляем сводку по накладной
          invoiceSummaries.add(InvoiceSummary(
            invoiceId: invoice.id,
            date: invoice.date.toDate(),
            salesRepName: invoice.salesRepName,
            totalAmount: invoice.totalAmount,
            status: invoice.status,
          ));

          // Агрегируем товары
          for (final item in invoice.items) {
            final productKey = '${item.productId}_${item.isBonus}';
            
            if (productSales.containsKey(productKey)) {
              final existing = productSales[productKey]!;
              productSales[productKey] = ProductSalesData(
                productId: item.productId,
                productName: item.productName,
                price: item.price,
                quantity: existing.quantity + item.quantity,
                totalAmount: existing.totalAmount + item.totalPrice,
                isBonus: item.isBonus,
              );
            } else {
              productSales[productKey] = ProductSalesData(
                productId: item.productId,
                productName: item.productName,
                price: item.price,
                quantity: item.quantity,
                totalAmount: item.totalPrice,
                isBonus: item.isBonus,
              );
            }
          }
        }

        // Вычисляем общую сумму продаж
        final totalSales = outletInvoices.fold<double>(
          0.0, (sum, invoice) => sum + invoice.totalAmount);

        // Создаем объект данных по торговой точке
        final outletData = OutletSalesData(
          outletId: outletId,
          outletName: outlet.name,
          outletAddress: outlet.address,
          totalSales: totalSales,
          invoiceCount: outletInvoices.length,
          products: productSales.values.toList(),
          invoices: invoiceSummaries,
          periodStart: startDate,
          periodEnd: endDate,
        );

        outletSalesData.add(outletData);
      }

      // Сортируем по убыванию общей суммы продаж
      outletSalesData.sort((a, b) => b.totalSales.compareTo(a.totalSales));

      print('[AnalyticsService] Аналитика по торговым точкам загружена');
      return outletSalesData;

    } catch (e) {
      print('[AnalyticsService] Ошибка загрузки аналитики по торговым точкам: $e');
      rethrow;
    }
  }

  /// Получение аналитики продаж по товарам
  static Future<List<ProductAnalyticsData>> getProductSalesAnalytics({
    required DateTime startDate,
    required DateTime endDate,
    String? searchQuery,
  }) async {
    try {
      print('[AnalyticsService] Загружаем аналитику по товарам...');
      
      // Получаем все накладные за период
      final invoicesQuery = await _firestore
          .collection('invoices')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      final invoices = invoicesQuery.docs
          .map((doc) => Invoice.fromMap(doc.data()))
          .toList();

      print('[AnalyticsService] Найдено ${invoices.length} накладных');

      // Группируем товары по накладным
      final Map<String, Map<String, dynamic>> productData = {};
      final Map<String, Map<String, OutletSalesInfo>> productOutletSales = {};
      final Map<String, List<InvoiceSummary>> productInvoices = {};

      for (final invoice in invoices) {
        // Получаем информацию о торговой точке
        final outletDoc = await _firestore.collection('outlets').doc(invoice.outletId).get();
        final outlet = outletDoc.exists 
            ? Outlet.fromMap(outletDoc.data()!)
            : Outlet(id: invoice.outletId, name: 'Неизвестная точка', address: '', contactPerson: '', phone: '', region: '', createdAt: DateTime.now(), updatedAt: DateTime.now());

        for (final item in invoice.items) {
          final productId = item.productId;
          
          // Инициализируем данные товара
          if (!productData.containsKey(productId)) {
            productData[productId] = {
              'productId': productId,
              'productName': item.productName,
              'price': item.originalPrice,
              'totalSales': 0.0,
              'totalQuantity': 0,
              'bonusQuantity': 0,
              'bonusAmount': 0.0,
              'regularQuantity': 0,
              'regularAmount': 0.0,
            };
            productOutletSales[productId] = {};
            productInvoices[productId] = [];
          }

          // Обновляем данные товара
          final data = productData[productId]!;
          data['totalSales'] = (data['totalSales'] as double) + item.totalPrice;
          data['totalQuantity'] = (data['totalQuantity'] as int) + item.quantity;

          if (item.isBonus) {
            data['bonusQuantity'] = (data['bonusQuantity'] as int) + item.quantity;
            data['bonusAmount'] = (data['bonusAmount'] as double) + item.totalPrice;
          } else {
            data['regularQuantity'] = (data['regularQuantity'] as int) + item.quantity;
            data['regularAmount'] = (data['regularAmount'] as double) + item.totalPrice;
          }

          // Обновляем данные по торговым точкам
          final outletKey = invoice.outletId;
          if (!productOutletSales[productId]!.containsKey(outletKey)) {
            productOutletSales[productId]![outletKey] = OutletSalesInfo(
              outletId: outlet.id,
              outletName: outlet.name,
              outletAddress: outlet.address,
              regularQuantity: 0,
              regularAmount: 0.0,
              bonusQuantity: 0,
              bonusAmount: 0.0,
              totalAmount: 0.0,
            );
          }

          final outletSales = productOutletSales[productId]![outletKey]!;
          if (item.isBonus) {
            productOutletSales[productId]![outletKey] = OutletSalesInfo(
              outletId: outlet.id,
              outletName: outlet.name,
              outletAddress: outlet.address,
              regularQuantity: outletSales.regularQuantity,
              regularAmount: outletSales.regularAmount,
              bonusQuantity: outletSales.bonusQuantity + item.quantity,
              bonusAmount: outletSales.bonusAmount + item.totalPrice,
              totalAmount: outletSales.totalAmount + item.totalPrice,
            );
          } else {
            productOutletSales[productId]![outletKey] = OutletSalesInfo(
              outletId: outlet.id,
              outletName: outlet.name,
              outletAddress: outlet.address,
              regularQuantity: outletSales.regularQuantity + item.quantity,
              regularAmount: outletSales.regularAmount + item.totalPrice,
              bonusQuantity: outletSales.bonusQuantity,
              bonusAmount: outletSales.bonusAmount,
              totalAmount: outletSales.totalAmount + item.totalPrice,
            );
          }

          // Добавляем накладную (если еще не добавлена)
          if (!productInvoices[productId]!.any((inv) => inv.invoiceId == (invoice.id ?? ''))) {
            productInvoices[productId]!.add(InvoiceSummary(
              invoiceId: invoice.id ?? '',
              date: invoice.date.toDate(),
              salesRepName: invoice.salesRepName,
              totalAmount: invoice.totalAmount,
              status: invoice.status,
            ));
          }
        }
      }

      // Создаем объекты аналитики
      final List<ProductAnalyticsData> productAnalytics = [];
      
      for (final entry in productData.entries) {
        final productId = entry.key;
        final data = entry.value;
        
        // Фильтрация по поисковому запросу
        if (searchQuery != null && searchQuery.isNotEmpty) {
          final productName = data['productName'] as String;
          if (!productName.toLowerCase().contains(searchQuery.toLowerCase())) {
            continue;
          }
        }

        final analyticsData = ProductAnalyticsData(
          productId: productId,
          productName: data['productName'] as String,
          price: (data['price'] as num).toDouble(),
          totalSales: (data['totalSales'] as num).toDouble(),
          totalQuantity: data['totalQuantity'] as int,
          bonusQuantity: data['bonusQuantity'] as int,
          bonusAmount: (data['bonusAmount'] as num).toDouble(),
          regularQuantity: data['regularQuantity'] as int,
          regularAmount: (data['regularAmount'] as num).toDouble(),
          outletSales: productOutletSales[productId]!.values.toList(),
          invoices: productInvoices[productId]!,
          periodStart: startDate,
          periodEnd: endDate,
        );

        productAnalytics.add(analyticsData);
      }

      // Сортируем по убыванию общей суммы продаж
      productAnalytics.sort((a, b) => b.totalSales.compareTo(a.totalSales));

      print('[AnalyticsService] Аналитика по товарам загружена');
      return productAnalytics;

    } catch (e) {
      print('[AnalyticsService] Ошибка загрузки аналитики по товарам: $e');
      rethrow;
    }
  }
}
