import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

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

  File? _selectedImage;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    setState(() {
      _selectedImage = File(image.path);
    });

    await _uploadImage(_selectedImage!);
  }

  Future<void> _uploadImage(File imageFile) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    final userInfo = await _getUserInfo(token!);
    final userId = userInfo?['id'];

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://beopn.mysesa.site/api/v1/uploads/users/$userId/photo'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['accept'] = 'application/json';

    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _fotoController.text = data['url']; // asumsikan `url` ada di response
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Upload gambar gagal')));
    }
  }

  Future<Map<String, dynamic>?> _getUserInfo(String token) async {
    final response = await http.get(
      Uri.parse('https://beopn.mysesa.site/api/v1/members/me'),
      headers: {'accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data;
    }
    return null;
  }

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

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      _tglLahirController.text = picked.toIso8601String().split('T')[0];
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
              GestureDetector(
                onTap: _selectDate,
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: _tglLahirController,
                    decoration: const InputDecoration(
                      labelText: 'Tanggal Lahir (YYYY-MM-DD)',
                    ),
                  ),
                ),
              ),
              TextFormField(
                controller: _alamatController,
                decoration: const InputDecoration(labelText: 'Alamat'),
              ),
              DropdownButtonFormField<String>(
                value: _divisi,
                items: const [
                  DropdownMenuItem(value: 'agama', child: Text('Divisi Agama')),
                  DropdownMenuItem(
                    value: 'sosial',
                    child: Text('Divisi Sosial'),
                  ),
                  DropdownMenuItem(
                    value: 'lingkungan',
                    child: Text('Divisi Lingkungan'),
                  ),
                  DropdownMenuItem(
                    value: 'perlengkapan',
                    child: Text('Divisi Perlengkapan'),
                  ),
                  DropdownMenuItem(value: 'media', child: Text('Divisi Media')),
                ],
                onChanged: (val) => setState(() => _divisi = val),
                decoration: const InputDecoration(labelText: 'Divisi'),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _pickImage,
                child:
                    _selectedImage == null
                        ? Container(
                          height: 150,
                          width: double.infinity,
                          color: Colors.grey[300],
                          child: const Center(
                            child: Text("Klik untuk memilih gambar"),
                          ),
                        )
                        : Image.file(_selectedImage!, height: 150),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _fotoController,
                decoration: const InputDecoration(
                  labelText: 'Photo URL (otomatis setelah upload)',
                ),
                readOnly: true,
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
