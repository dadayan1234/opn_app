import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _register() async {
    final username = _usernameController.text;
    final password = _passwordController.text;

    final success = await AuthService.register(username, password);
    if (success) {
      // Navigasi ke halaman utama atau dashboard
    } else {
      // Tampilkan pesan error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Daftar')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(labelText: 'Nama Pengguna'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Kata Sandi'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(onPressed: _register, child: Text('Daftar')),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Sudah punya akun? Masuk'),
            ),
          ],
        ),
      ),
    );
  }
}
