import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String baseUrl = 'https://beopn.pemudanambangan.site';

  // PERBAIKAN: Login dengan response handling yang lebih baik
  static Future<Map<String, dynamic>> login(
    String username,
    String password, {
    bool saveCredentials = true,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/auth/token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'accept': 'application/json',
        },
        body: {
          'grant_type': 'password',
          'username': username,
          'password': password,
          'scope': '',
          'client_id': 'string',
          'client_secret': 'string',
        },
      );

      // ✅ Success (200)
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final token = data['access_token'];
        final message = data['message'] ?? 'Login successful.';

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', token);

        // Simpan username dan password untuk auto-login
        if (saveCredentials) {
          await prefs.setString('saved_username', username);
          await prefs.setString('saved_password', password);
          print('Credentials saved for auto-login');
        }

        return {
          'success': true,
          'message': message,
          'token': token,
        };
      }
      // ❌ Bad Request (400) - Invalid credentials
      else if (response.statusCode == 400) {
        final data = json.decode(response.body);
        return {
          'success': false,
          'message': data['detail'] ?? 'Invalid username or password.',
        };
      }
      // ❌ Unauthorized (401)
      else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Username atau password salah.',
        };
      }
      // ❌ Other errors
      else {
        return {
          'success': false,
          'message': 'Login gagal. Silakan coba lagi.',
        };
      }
    } catch (e) {
      // ❌ Network error
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  // PERBAIKAN: Register dengan response handling yang lebih baik
  static Future<Map<String, dynamic>> register(
    String username,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/auth/register'),
        headers: {
          'Content-Type': 'application/json',
          'accept': 'application/json',
        },
        body: json.encode({
          'username': username,
          'password': password,
        }),
      );

      // ✅ Success (200)
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'User registered successfully.',
        };
      }
      // ❌ Bad Request (400) - Validation errors
      else if (response.statusCode == 400) {
        final data = json.decode(response.body);
        return {
          'success': false,
          'message': data['detail'] ?? 'Registration failed.',
        };
      }
      // ❌ Other errors
      else {
        return {
          'success': false,
          'message': 'Registration failed. Please try again.',
        };
      }
    } catch (e) {
      // ❌ Network error
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  // Auto-login menggunakan kredensial tersimpan
  static Future<bool> autoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('saved_username');
    final password = prefs.getString('saved_password');

    if (username == null || password == null) {
      print('No saved credentials found for auto-login');
      return false;
    }

    print('Attempting auto-login for user: $username');

    // Login tanpa save credentials lagi (untuk avoid infinite loop)
    final result = await login(username, password, saveCredentials: false);

    if (result['success'] == true) {
      print('Auto-login successful');
      return true;
    } else {
      print('Auto-login failed: ${result['message']}');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (token == null) return null;

    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/members/me'),
      headers: {'accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data;
    }

    return null;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    // Hapus semua data terkait autentikasi dan notifikasi
    await prefs.remove('access_token');
    await prefs.remove('saved_username');
    await prefs.remove('saved_password');
    await prefs.remove('fcm_token_sent');

    print('User logged out, all credentials and FCM token cleared');
  }
}