// lib/services/api_service.dart
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'navigation_service.dart';
import 'auth_service.dart';

class ApiService {
  static const String _apiPrefix = 'https://beopn.penaku.site/api/v1';
  static bool _isRefreshing = false;

  // Fungsi internal untuk menangani logout dan redirect
  static Future<void> _handleUnauthorized() async {
    // Cek apakah sedang proses refresh token
    if (_isRefreshing) {
      print('Already refreshing token, skipping...');
      await Future.delayed(const Duration(seconds: 2));
      return;
    }

    _isRefreshing = true;
    print('Token expired, attempting auto-login...');

    try {
      // Coba auto-login dengan kredensial tersimpan
      final success = await AuthService.autoLogin();

      if (success) {
        print('Auto-login successful');
        _isRefreshing = false;
        return;
      }

      // Jika auto-login gagal, logout dan redirect ke login
      print('Auto-login failed, redirecting to login...');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      await prefs.remove('saved_username');
      await prefs.remove('saved_password');
      await prefs.remove('fcm_token_sent');

      _isRefreshing = false;

      // Gunakan navigation service untuk redirect
      NavigationService.pushReplacementNamed('/login');
    } catch (e) {
      print('Error during auto-login: $e');
      _isRefreshing = false;
      NavigationService.pushReplacementNamed('/login');
    }
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

    // Jika status 401 (Unauthorized), handle auto-login atau redirect
    if (response.statusCode == 401) {
      print('Received 401, handling unauthorized...');
      await _handleUnauthorized();

      // Retry request dengan token baru setelah auto-login
      final newToken = prefs.getString('access_token');
      if (newToken != null && newToken != token) {
        print('Retrying GET request with new token...');
        final retryHeaders = {
          'accept': 'application/json',
          'Authorization': 'Bearer $newToken',
        };
        return await http.get(
          Uri.parse('$_apiPrefix$endpoint'),
          headers: retryHeaders,
        );
      }

      throw Exception('Sesi telah berakhir. Silakan login kembali.');
    }

    return response;
  }

  // Wrapper untuk metode POST
  static Future<http.Response> post(
    String endpoint, {
    Object? body,
    Map<String, String>? additionalHeaders,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (token == null) {
      await _handleUnauthorized();
      throw Exception('Sesi telah berakhir. Silakan login kembali.');
    }

    final headers = {
      'accept': 'application/json',
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      ...?additionalHeaders,
    };

    final response = await http.post(
      Uri.parse('$_apiPrefix$endpoint'),
      headers: headers,
      body: body,
    );

    if (response.statusCode == 401) {
      print('Received 401 on POST, handling unauthorized...');
      await _handleUnauthorized();

      final newToken = prefs.getString('access_token');
      if (newToken != null && newToken != token) {
        print('Retrying POST request with new token...');
        final retryHeaders = {
          'accept': 'application/json',
          'Authorization': 'Bearer $newToken',
          'Content-Type': 'application/json',
          ...?additionalHeaders,
        };
        return await http.post(
          Uri.parse('$_apiPrefix$endpoint'),
          headers: retryHeaders,
          body: body,
        );
      }

      throw Exception('Sesi telah berakhir. Silakan login kembali.');
    }

    return response;
  }
}
