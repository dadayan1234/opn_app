// lib/screens/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    print('Splash screen: Starting app initialization...');

    // Berikan delay singkat untuk memastikan semua service sudah ready
    await Future.delayed(const Duration(milliseconds: 500));

    // Periksa status login pengguna
    if (mounted) {
      _checkAuthAndNavigate();
    }
  }

  Future<void> _checkAuthAndNavigate() async {
    print('Splash screen: Checking auth status...');

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (!mounted) return;

    if (token == null) {
      // Coba auto-login jika ada kredensial tersimpan
      print('Splash screen: No token found, checking for saved credentials');
      final autoLoginSuccess = await AuthService.autoLogin();

      if (autoLoginSuccess) {
        print('Splash screen: Auto-login successful');
        // Lanjutkan validasi dengan token baru
        await _validateAndNavigate();
      } else {
        print('Splash screen: No saved credentials, navigating to login');
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    // Validasi token yang ada
    await _validateAndNavigate();
  }

  Future<void> _validateAndNavigate() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (token == null) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    try {
      print('Splash screen: Validating token with server...');
      final response = await http
          .get(
            Uri.parse('https://beopn.penaku.site/api/v1/members/me'),
            headers: {
              'accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final user = json.decode(response.body);
        final info = user['member_info'];
        final fullName = info?['full_name'];

        print('Splash screen: Token valid, user: $fullName');

        if (fullName != null && fullName.toString().isNotEmpty) {
          Navigator.pushReplacementNamed(
            context,
            '/dashboard',
            arguments: fullName,
          );
        } else {
          Navigator.pushReplacementNamed(context, '/biodata');
        }
      } else if (response.statusCode == 401) {
        print('Splash screen: Token expired, attempting auto-login...');
        // Token expired, coba auto-login
        final autoLoginSuccess = await AuthService.autoLogin();

        if (autoLoginSuccess) {
          print('Splash screen: Auto-login successful, validating again...');
          // Rekursif validasi dengan token baru
          await _validateAndNavigate();
        } else {
          print('Splash screen: Auto-login failed, navigating to login');
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        print('Splash screen: Token invalid, status: ${response.statusCode}');
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      print("Splash screen: Error checking auth: $e");
      if (mounted) {
        // Coba auto-login jika ada error
        final autoLoginSuccess = await AuthService.autoLogin();

        if (autoLoginSuccess) {
          await _validateAndNavigate();
        } else {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo_opn.png', width: 120, height: 120),
            const SizedBox(height: 20),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
            ),
            const SizedBox(height: 20),
            const Text(
              'Memuat aplikasi...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
