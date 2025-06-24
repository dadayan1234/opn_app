// lib/services/api_service.dart
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'navigation_service.dart';

class ApiService {
  static const String _apiPrefix = 'https://beopn.penaku.site/api/v1';

  // Fungsi internal untuk menangani logout dan redirect
  static Future<void> _handleUnauthorized() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    // Gunakan navigation service untuk redirect
    NavigationService.pushReplacementNamed('/login');
  }

  // Wrapper untuk metode GET
  static Future<http.Response> get(String endpoint) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    // Jika token tidak ada sama sekali, langsung redirect
    if (token == null) {
      await _handleUnauthorized();
      throw Exception('Sesi telah berakhir. Silakan login kembali.');
    }

    final headers = {
      'accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final response = await http.get(
      Uri.parse('$_apiPrefix$endpoint'),
      headers: headers,
    );

    // Jika status 401 (Unauthorized), handle redirect
    if (response.statusCode == 401) {
      await _handleUnauthorized();
      throw Exception('Sesi telah berakhir. Silakan login kembali.');
    }

    return response;
  }

  // Anda bisa menambahkan metode lain seperti POST, PUT, DELETE di sini dengan logika yang sama
  // static Future<http.Response> post(String endpoint, {Object? body}) async { ... }
}
