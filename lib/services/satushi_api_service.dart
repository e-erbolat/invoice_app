import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/purchase.dart';
import '../models/purchase_item.dart';
import '../models/product.dart';
import 'firebase_service.dart';

class SatushiApiService {
  static const String _baseUrl = 'https://api.satushi.me/api/v1';
  static const String _warehouseId = '173'; // Константа warehouseId

  final FirebaseService _firebaseService = FirebaseService();


  /// Оприходовать товары закупа через API Satushi
  Future<bool> incomeRequest(Purchase purchase, String satushiToken) async {
    try {
      final url = Uri.parse('$_baseUrl/warehouse/income-request');

      print('[SatushiApiService] Начинаем оприходование закупа: ${purchase.id}');
      print('[SatushiApiService] Поставщик: ${purchase.supplierName}');
      print('[SatushiApiService] Количество товаров: ${purchase.items.length}');

      // Формируем запрос для каждого товара
      final request = <Map<String, dynamic>>[];

      for (final item in purchase.items) {
        // Получаем satushiCode из продукта
        final product = await _getProductById(item.productId);
        if (product?.satushiCode != null && product!.satushiCode!.isNotEmpty) {
          // Правильно рассчитываем количество для оприходования
          // Учитываем принятые недостачи
          int amountForStocking;
          
          print('[SatushiApiService] Товар: ${item.productName}');
          print('[SatushiApiService] Статус: ${item.status} (${item.statusDisplayName})');
          print('[SatushiApiService] Заказано: ${item.orderedQty}');
          print('[SatushiApiService] Принято: ${item.receivedQty}');
          print('[SatushiApiService] Недостача: ${item.missingQty}');
          
          if (item.status == PurchaseItemStatus.shortageReceived) {
            // Если недостача была принята, используем полное количество
            amountForStocking = item.orderedQty;
            print('[SatushiApiService] Используем полное количество (shortageReceived): $amountForStocking');
          } else if (item.receivedQty != null) {
            // Если есть принятое количество, используем его
            amountForStocking = item.receivedQty!;
            print('[SatushiApiService] Используем принятое количество: $amountForStocking');
          } else {
            // Иначе используем заказанное количество
            amountForStocking = item.orderedQty;
            print('[SatushiApiService] Используем заказанное количество: $amountForStocking');
          }
          
          
          request.add({
            'code': product.satushiCode!,
            'amount': amountForStocking,
            'purchasePrice': item.purchasePrice,
          });
        }
      }

      if (request.isEmpty) {
        throw Exception('Нет товаров с satushiCode для оприходования');
      }

      final body = {
        'warehouseId': _warehouseId,
        'request': request,
      };

      print('[SatushiApiService] === ФИНАЛЬНЫЙ ЗАПРОС ===');
      print('[SatushiApiService] Отправляем запрос: ${jsonEncode(body)}');
      print('[SatushiApiService] ========================');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $satushiToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'invoice_app/1.0 (+satushi integration)'
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        print('[SatushiApiService] Успешное оприходование:');
        return true;
      } else {
        print(
            '[SatushiApiService] Ошибка API: ${response.statusCode} - ${response
                .body}');
        throw Exception(
            'Ошибка API: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('[SatushiApiService] Ошибка оприходования: $e');
      rethrow;
    }
  }

  /// Получить продукт по ID через FirebaseService
  Future<Product?> _getProductById(String productId) async {
    try {
      final products = await _firebaseService.getProducts();
      return products.firstWhere((p) => p.id == productId);
    } catch (e) {
      print('[SatushiApiService] Ошибка получения продукта: $e');
      return null;
    }
  }

  Future<http.Response> createCustomOrder(
      {required String bearerToken, required Map<String, dynamic> body}) {
    final url = Uri.parse('$_baseUrl/order/custom');


    return http
        .post(
      url,
      headers: {
        'Authorization': 'Bearer $bearerToken',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'invoice_app/1.0 (+satushi integration)'
      },
      body: jsonEncode(body),
    )
        .timeout(const Duration(seconds: 30));
  }
}


