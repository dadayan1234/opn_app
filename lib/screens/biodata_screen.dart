import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:http_parser/http_parser.dart';

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
  String? _divisi;
  File? _selectedImage;
  bool isSaving = false;

  Future<void> _pickAndCropImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      if (mounted) {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: image.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          maxWidth: 512,
          maxHeight: 512,
          compressFormat: ImageCompressFormat.jpg,
          compressQuality: 85,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop Foto Profil',
              toolbarColor: Colors.deepPurple,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true,
              statusBarColor: Colors.deepPurple,
              activeControlsWidgetColor: Colors.deepPurple,
              cropFrameColor: Colors.deepPurple,
              cropGridColor: Colors.deepPurple.withOpacity(0.5),
              backgroundColor: Colors.black,
              dimmedLayerColor: Colors.black.withOpacity(0.8),
              hideBottomControls: false,
              showCropGrid: true,
            ),
            IOSUiSettings(
              title: 'Crop Foto Profil',
              aspectRatioLockEnabled: true,
              minimumAspectRatio: 1.0,
              resetAspectRatioEnabled: false,
            ),
          ],
        );

        if (croppedFile != null && mounted) {
          setState(() {
            _selectedImage = File(croppedFile.path);
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memproses gambar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Map<String, dynamic>?> _getUserInfo(String token) async {
    final response = await http.get(
      Uri.parse('https://beopn.penaku.site/api/v1/members/me'),
      headers: {'accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      print('Gagal ambil info user: ${response.body}');
      return null;
    }
  }

  Future<void> _uploadImage(File imageFile, int userId, String token) async {
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('https://beopn.penaku.site/api/v1/uploads/users/$userId/photo'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['accept'] = 'application/json';

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      print('Upload gambar berhasil');
    } else {
      print('Upload gambar gagal: ${response.body}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload gambar gagal: ${response.statusCode}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitBiodata() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSaving = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (token == null) {
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Token tidak ditemukan.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final biodataResponse = await http.post(
      Uri.parse('https://beopn.penaku.site/api/v1/members/biodata/'),
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
        "photo_url": "/default.jpg", // dummy
      }),
    );

    if (biodataResponse.statusCode == 200 ||
        biodataResponse.statusCode == 201) {
      final userInfo = await _getUserInfo(token);
      final userId = userInfo?['id'];

      if (_selectedImage != null && userId != null) {
        await _uploadImage(_selectedImage!, userId, token);
      }

      final fullName =
          _namaController.text.isNotEmpty ? _namaController.text : 'Pengguna';
      Navigator.pushReplacementNamed(
        context,
        '/dashboard',
        arguments: fullName,
      );
    } else {
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal mengirim data biodata.'),
          backgroundColor: Colors.red,
        ),
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

  Widget _buildPhotoSection() {
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey.shade200,
              backgroundImage:
                  _selectedImage != null ? FileImage(_selectedImage!) : null,
              child:
                  _selectedImage == null
                      ? const Icon(Icons.person, size: 60, color: Colors.grey)
                      : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _pickAndCropImage,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.deepPurple,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
              const SizedBox(height: 8),
              Text(
                'Gunakan foto yang rapi dan formal',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                '• Wajah terlihat jelas\n• Pakaian rapi dan sopan\n• Latar belakang bersih\n• Format JPG/PNG',
                style: TextStyle(color: Colors.blue.shade600, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lengkapi Biodata'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildPhotoSection(),
              const SizedBox(height: 24),
              TextFormField(
                controller: _namaController,
                decoration: const InputDecoration(
                  labelText: 'Nama Lengkap',
                  border: OutlineInputBorder(),
                ),
                validator:
                    (value) =>
                        value == null || value.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Wajib diisi';
                  if (!RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                  ).hasMatch(value))
                    return 'Format email tidak valid';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _hpController,
                decoration: const InputDecoration(
                  labelText: 'No. HP',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator:
                    (value) =>
                        value == null || value.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tempatLahirController,
                decoration: const InputDecoration(
                  labelText: 'Tempat Lahir',
                  border: OutlineInputBorder(),
                ),
                validator:
                    (value) =>
                        value == null || value.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _selectDate,
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: _tglLahirController,
                    decoration: const InputDecoration(
                      labelText: 'Tanggal Lahir',
                      hintText: 'YYYY-MM-DD',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    validator:
                        (value) =>
                            value == null || value.isEmpty
                                ? 'Wajib diisi'
                                : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _alamatController,
                decoration: const InputDecoration(
                  labelText: 'Alamat',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator:
                    (value) =>
                        value == null || value.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _divisi,
                decoration: const InputDecoration(
                  labelText: 'Divisi',
                  border: OutlineInputBorder(),
                ),
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
                validator:
                    (value) =>
                        value == null || value.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isSaving ? null : _submitBiodata,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.deepPurple.withOpacity(0.5),
                  ),
                  child:
                      isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Simpan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
