import 'dart:convert';
import 'package:http/http.dart' as http;

class SatushiApiService {
  static const String _baseUrl = 'https://api.satushi.me/api/v1/order/custom';

  Future<http.Response> createCustomOrder({required String bearerToken, required Map<String, dynamic> body}) {
    final uri = Uri.parse(_baseUrl);
    return http
        .post(
          uri,
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


