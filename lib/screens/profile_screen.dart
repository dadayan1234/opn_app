// screens/profile_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart'; // Tambahkan dependency ini
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http_parser/http_parser.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers untuk form
  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _hpController = TextEditingController();
  final _tempatLahirController = TextEditingController();
  final _tglLahirController = TextEditingController();
  final _alamatController = TextEditingController();

  String? _divisi;
  File? _selectedImage;
  String? _currentPhotoUrl;
  String? authToken;
  int? userId;
  bool isLoading = true;

  static const String apiPrefix = 'https://beopn.penaku.site/api/v1';
  static const String apiImagePrefix = 'https://beopn.penaku.site';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    // Load user data from API dan populate form
    final prefs = await SharedPreferences.getInstance();
    authToken = prefs.getString('token');
    userId = prefs.getInt('user_id');

    if (authToken == null || userId == null) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal memuat data user. Silakan login ulang.'),
        ),
      );
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$apiPrefix/members/biodata/'),
        headers: {
          'accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _namaController.text = data['full_name'] ?? '';
          _emailController.text = data['email'] ?? '';
          _hpController.text = data['phone_number'] ?? '';
          _tempatLahirController.text = data['birth_place'] ?? '';
          _tglLahirController.text = data['birth_date'] ?? '';
          _divisi = data['division'];
          _alamatController.text = data['address'] ?? '';
          _currentPhotoUrl = data['photo_url'];
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Gagal memuat data user')));
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Terjadi kesalahan: $e')));
    }
  }

  Future<void> _pickAndCropImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // 1:1 ratio
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: Colors.deepPurple,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Image',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          _selectedImage = File(croppedFile.path);
        });
      }
    }
  }

  Future<void> _uploadProfilePhoto() async {
    if (_selectedImage == null || userId == null || authToken == null) return;

    final request = http.MultipartRequest(
      'PUT', // Menggunakan PUT sesuai API
      Uri.parse('$apiPrefix/uploads/users/$userId/photo'),
    );

    request.headers['Authorization'] = 'Bearer $authToken';
    request.headers['accept'] = 'application/json';

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        _selectedImage!.path,
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      setState(() {
        _currentPhotoUrl = responseData['updated_photo_url'];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto profil berhasil diupdate')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal upload foto: ${response.statusCode}')),
      );
    }
  }

  Future<void> _updateBiodata() async {
    if (!_formKey.currentState!.validate() || authToken == null) return;

    final response = await http.put(
      Uri.parse('$apiPrefix/members/biodata/'),
      headers: {
        'accept': 'application/json',
        'Authorization': 'Bearer $authToken',
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
        "photo_url": _currentPhotoUrl ?? "",
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biodata berhasil diupdate')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gagal update biodata')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profil'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Photo section at the top
                      _buildPhotoSection(),
                      const SizedBox(height: 24),

                      // Form fields
                      _buildFormFields(),

                      const SizedBox(height: 24),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Simpan Perubahan'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundImage:
                  _selectedImage != null
                      ? FileImage(_selectedImage!)
                      : (_currentPhotoUrl != null && authToken != null)
                      ? CachedNetworkImageProvider(
                        "$apiImagePrefix/$_currentPhotoUrl",
                        headers: {
                          'accept': 'application/json',
                          'Authorization': 'Bearer $authToken',
                        },
                      )
                      : null,
              child:
                  (_selectedImage == null && _currentPhotoUrl == null)
                      ? const Icon(Icons.person, size: 60)
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
        const SizedBox(height: 16),
        if (_selectedImage != null)
          ElevatedButton(
            onPressed: _uploadProfilePhoto,
            child: const Text('Upload Foto'),
          ),
      ],
    );
  }

  Widget _buildFormFields() {
    // Implementation untuk form fields
    // Similar to biodata_screen.dart but with pre-filled data
    return Column(
      children: [
        TextFormField(
          controller: _namaController,
          decoration: const InputDecoration(labelText: 'Nama Lengkap'),
          validator:
              (value) =>
                  value == null || value.isEmpty
                      ? 'Nama tidak boleh kosong'
                      : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _emailController,
          decoration: const InputDecoration(labelText: 'Email'),
          keyboardType: TextInputType.emailAddress,
          validator:
              (value) =>
                  value == null || value.isEmpty
                      ? 'Email tidak boleh kosong'
                      : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _hpController,
          decoration: const InputDecoration(labelText: 'No. HP'),
          keyboardType: TextInputType.phone,
          validator:
              (value) =>
                  value == null || value.isEmpty
                      ? 'No. HP tidak boleh kosong'
                      : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _tempatLahirController,
          decoration: const InputDecoration(labelText: 'Tempat Lahir'),
          validator:
              (value) =>
                  value == null || value.isEmpty
                      ? 'Tempat lahir tidak boleh kosong'
                      : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _tglLahirController,
          decoration: const InputDecoration(
            labelText: 'Tanggal Lahir',
            hintText: 'YYYY-MM-DD',
          ),
          readOnly: true,
          onTap: () async {
            FocusScope.of(context).requestFocus(FocusNode());
            final picked = await showDatePicker(
              context: context,
              initialDate:
                  DateTime.tryParse(_tglLahirController.text) ??
                  DateTime(2000, 1, 1),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              _tglLahirController.text =
                  "${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
            }
          },
          validator:
              (value) =>
                  value == null || value.isEmpty
                      ? 'Tanggal lahir tidak boleh kosong'
                      : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _divisi,
          decoration: const InputDecoration(labelText: 'Divisi'),
          items: const [
            DropdownMenuItem(value: 'agama', child: Text('Divisi Agama')),
            DropdownMenuItem(value: 'sosial', child: Text('Divisi Sosial')),
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
          onChanged: (value) {
            setState(() {
              _divisi = value;
            });
          },
          validator:
              (value) =>
                  value == null || value.isEmpty
                      ? 'Divisi tidak boleh kosong'
                      : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _alamatController,
          decoration: const InputDecoration(labelText: 'Alamat'),
          maxLines: 2,
          validator:
              (value) =>
                  value == null || value.isEmpty
                      ? 'Alamat tidak boleh kosong'
                      : null,
        ),
      ],
    );
  }

  Future<void> _saveProfile() async {
    // Upload photo first if there's a new image
    if (_selectedImage != null) {
      await _uploadProfilePhoto();
    }

    // Then update biodata
    await _updateBiodata();
  }
}
