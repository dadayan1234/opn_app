import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static const String baseUrl = 'https://beopn.mysesa.site';

  static Future<bool> login(String username, String password) async {
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

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final token = data['access_token'];
      // Simpan token untuk digunakan di permintaan berikutnya
      return true;
    } else {
      return false;
    }
  }

  static Future<bool> register(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/auth/register'),
      headers: {
        'Content-Type': 'application/json',
        'accept': 'application/json',
      },
      body: json.encode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      // Setelah registrasi berhasil, langsung login
      return await login(username, password);
    } else {
      return false;
    }
  }
}
