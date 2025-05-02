// biodata_form_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class BiodataFormScreen extends StatefulWidget {
  const BiodataFormScreen({super.key});

  @override
  State<BiodataFormScreen> createState() => _BiodataFormScreenState();
}

class _BiodataFormScreenState extends State<BiodataFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _hpController = TextEditingController();
  final _tempatLahirController = TextEditingController();
  final _tglLahirController = TextEditingController();
  final _alamatController = TextEditingController();
  final _fotoController = TextEditingController();
  String? _divisi;

  Future<void> _submitBiodata() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    final url = Uri.parse('https://beopn.mysesa.site/api/v1/members/biodata/');

    final response = await http.post(
      url,
      headers: {
        'accept': 'application/json',
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "full_name": _namaController.text,
        "email": _emailController.text,
        "phone_number": _hpController.text,
        "birth_place": _tempatLahirController.text,
        "birth_date": _tglLahirController.text,
        "division": _divisi,
        "address": _alamatController.text,
        "photo_url": _fotoController.text,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengirim data biodata.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lengkapi Biodata')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _namaController,
                decoration: const InputDecoration(labelText: 'Nama Lengkap'),
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextFormField(
                controller: _hpController,
                decoration: const InputDecoration(labelText: 'No. HP'),
              ),
              TextFormField(
                controller: _tempatLahirController,
                decoration: const InputDecoration(labelText: 'Tempat Lahir'),
              ),
              TextFormField(
                controller: _tglLahirController,
                decoration: const InputDecoration(
                  labelText: 'Tanggal Lahir (YYYY-MM-DD)',
                ),
              ),
              TextFormField(
                controller: _alamatController,
                decoration: const InputDecoration(labelText: 'Alamat'),
              ),
              DropdownButtonFormField<String>(
                value: _divisi,
                items: const [
                  DropdownMenuItem(
                    value: 'divisi agama',
                    child: Text('Divisi Agama'),
                  ),
                  DropdownMenuItem(
                    value: 'divisi sosial',
                    child: Text('Divisi Sosial'),
                  ),
                  DropdownMenuItem(
                    value: 'divisi lingkungan',
                    child: Text('Divisi Lingkungan'),
                  ),
                  DropdownMenuItem(
                    value: 'divisi perlengkapan',
                    child: Text('Divisi Perlengkapan'),
                  ),
                  DropdownMenuItem(
                    value: 'divisi media',
                    child: Text('Divisi Media'),
                  ),
                ],
                onChanged: (val) => setState(() => _divisi = val),
                decoration: const InputDecoration(labelText: 'Divisi'),
              ),
              TextFormField(
                controller: _fotoController,
                decoration: const InputDecoration(labelText: 'Photo URL'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitBiodata,
                child: const Text('Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
