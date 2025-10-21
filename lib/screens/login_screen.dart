import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';
import '../services/notification_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isObscure = true;
  bool _isLoading = false;

  void _login() async {
    // Validasi input
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackBar(
        'Username dan password tidak boleh kosong',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    try {
      // Panggil login API
      final result = await AuthService.login(username, password);

      if (!mounted) return;

      if (result['success'] == true) {
        // ✅ Login berhasil
        _showSnackBar(
          result['message'] ?? 'Login berhasil!',
          isError: false,
        );

        // Register FCM token setelah login
        try {
          await NotificationService().registerTokenAfterLogin();
        } catch (e) {
          print('Failed to register FCM token: $e');
        }

        // Get user info untuk cek apakah sudah mengisi biodata
        final userInfo = await AuthService.getUserInfo();

        if (!mounted) return;

        if (userInfo != null && userInfo['member_info'] != null) {
          final info = userInfo['member_info'];
          
          // Cek apakah full_name sudah diisi
          if (info['full_name'] == null ||
              info['full_name'].toString().isEmpty) {
            // Redirect ke biodata jika belum lengkap
            Navigator.pushReplacementNamed(context, '/biodata');
          } else {
            // Redirect ke dashboard jika sudah lengkap
            final fullName = info['full_name'];
            Navigator.pushReplacementNamed(
              context,
              '/dashboard',
              arguments: fullName,
            );
          }
        } else {
          // Jika userInfo null, redirect ke biodata
          Navigator.pushReplacementNamed(context, '/biodata');
        }
      } else {
        // ❌ Login gagal dengan pesan dari backend
        _showSnackBar(
          result['message'] ?? 'Login gagal, cek username dan password',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Helper untuk menampilkan SnackBar dengan warna berbeda
  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 60),
            // Logo image
            Image.asset('assets/images/logo_opn.png', height: 120, width: 120),
            const SizedBox(height: 20),
            const Text(
              'Login',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Masuk menggunakan akun Anda untuk menggunakan aplikasi',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController,
              obscureText: _isObscure,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isObscure ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _isObscure = !_isObscure;
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) => _login(), // Enter untuk submit
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _login,
                  child: const Text(
                    'MASUK',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RegisterScreen(),
                  ),
                );
              },
              child: const Text.rich(
                TextSpan(
                  text: 'Belum punya akun? ',
                  children: [
                    TextSpan(
                      text: 'Daftar',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}