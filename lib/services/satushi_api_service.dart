import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/purchase.dart';
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

      // Формируем запрос для каждого товара
      final request = <Map<String, dynamic>>[];

      for (final item in purchase.items) {
        // Получаем satushiCode из продукта
        final product = await _getProductById(item.productId);
        if (product?.satushiCode != null && product!.satushiCode!.isNotEmpty) {
          request.add({
            'code': product.satushiCode!,
            'amount': item.receivedQty ?? item.orderedQty,
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

      print('[SatushiApiService] Отправляем запрос: ${jsonEncode(body)}');

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


