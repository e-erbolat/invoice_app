import 'dart:convert';
import 'package:http/http.dart' as http;

class LatLng {
  final double latitude;
  final double longitude;
  const LatLng({required this.latitude, required this.longitude});
}

class GeocodingService {
  // Используем бесплатный Nominatim (OpenStreetMap). Для продакшена лучше свой сервер/ключ провайдера.
  static const String _endpoint = 'https://nominatim.openstreetmap.org/search';

  Future<LatLng?> geocodeAddress(String address) async {
    if (address.trim().isEmpty) return null;
    final uri = Uri.parse('$_endpoint?q=${Uri.encodeComponent(address)}&format=json&limit=1');
    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        // Nominatim требует указания User-Agent
        'User-Agent': 'invoice_app (contact: example@example.com)',
      },
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body);
    if (data is List && data.isNotEmpty) {
      final first = data.first as Map<String, dynamic>;
      final lat = double.tryParse(first['lat']?.toString() ?? '');
      final lon = double.tryParse(first['lon']?.toString() ?? '');
      if (lat != null && lon != null) {
        return LatLng(latitude: lat, longitude: lon);
      }
    }
    return null;
  }
}


