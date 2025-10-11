// screens/profile_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
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
  bool isSaving = false; // State untuk proses penyimpanan

  static const String apiPrefix = 'https://beopn.pemudanambangan.site/api/v1';
  static const String apiImagePrefix = 'https://beopn.pemudanambangan.site';

  final List<String> _validDivisions = [
    'agama',
    'sosial',
    'lingkungan',
    'perlengkapan',
    'media',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _emailController.dispose();
    _hpController.dispose();
    _tempatLahirController.dispose();
    _tglLahirController.dispose();
    _alamatController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      authToken = prefs.getString('access_token');

      if (authToken == null) {
        setState(() => isLoading = false);
        _showError('Token tidak ditemukan. Silakan login ulang.');
        return;
      }

      final response = await http.get(
        Uri.parse('$apiPrefix/members/me'),
        headers: {
          'accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final memberInfo = data['member_info'];

        setState(() {
          userId = data['id'];
          _namaController.text = memberInfo['full_name'] ?? '';
          _emailController.text = memberInfo['email'] ?? '';
          _hpController.text = memberInfo['phone_number'] ?? '';
          _tempatLahirController.text = memberInfo['birth_place'] ?? '';
          _tglLahirController.text = memberInfo['birth_date'] ?? '';

          String? apiDivision =
              memberInfo['division']?.toString().trim().toLowerCase();
          if (apiDivision != null && _validDivisions.contains(apiDivision)) {
            _divisi = apiDivision;
          } else {
            _divisi = null;
            if (apiDivision != null && apiDivision.isNotEmpty) {
              _showError(
                'Divisi "$apiDivision" dari API tidak valid. Mohon pilih divisi yang benar.',
              );
            }
          }

          _alamatController.text = memberInfo['address'] ?? '';
          _currentPhotoUrl = memberInfo['photo_url'];
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        _showError('Gagal memuat data user: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showError('Terjadi kesalahan: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    }
  }

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
              toolbarTitle: 'Crop Image',
              toolbarColor: Colors.deepPurple,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true,
              // PERBAIKAN: Tambahkan konfigurasi untuk status bar
              statusBarColor: Colors.deepPurple,
              activeControlsWidgetColor: Colors.deepPurple,
              // Tambahkan padding untuk mengakomodasi status bar (DIPINDAHKAN: toolbarHeight dihapus karena tidak didukung)
              cropFrameColor: Colors.deepPurple,
              cropGridColor: Colors.deepPurple.withOpacity(0.5),
              backgroundColor: Colors.black,
              dimmedLayerColor: Colors.black.withOpacity(0.8),
              // Atur layout agar tidak tertutup status bar
              hideBottomControls: false,
              showCropGrid: true,
            ),
            IOSUiSettings(
              title: 'Crop Image',
              aspectRatioLockEnabled: true,
              // Untuk iOS juga tambahkan konfigurasi yang diperlukan
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
      _showError('Gagal memproses gambar: $e');
    }
  }

  // --- PERBAIKAN 1: UBAH FUNGSI UNTUK MENGEMBALIKAN URL ---
  Future<String?> _uploadProfilePhoto() async {
    if (_selectedImage == null || userId == null || authToken == null) {
      _showError('Data tidak lengkap untuk upload foto');
      return null;
    }

    try {
      final request = http.MultipartRequest(
        'PUT',
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
        final newPhotoUrl = responseData['updated_photo_url'];
        _showSuccess('Foto profil berhasil diupdate');
        return newPhotoUrl; // Kembalikan URL baru jika sukses
      } else {
        _showError('Gagal upload foto: ${response.statusCode}');
        return null; // Kembalikan null jika gagal
      }
    } catch (e) {
      _showError('Gagal upload foto: $e');
      return null; // Kembalikan null jika terjadi exception
    }
  }

  // --- PERBAIKAN 2: UBAH FUNGSI UNTUK MENERIMA URL FINAL ---
  Future<void> _updateBiodata({required String finalPhotoUrl}) async {
    if (authToken == null) return;

    try {
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
          "photo_url": finalPhotoUrl, // Gunakan URL final dari parameter
        }),
      );

      if (response.statusCode == 200) {
        _showSuccess('Biodata berhasil diupdate');
        if (mounted) Navigator.pop(context);
      } else {
        _showError('Gagal update biodata: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Gagal update biodata: $e');
    }
  }

  // --- PERBAIKAN 3: LOGIKA PENYIMPANAN YANG DIATUR ULANG ---
  Future<void> _saveProfile() async {
    // Validasi form terlebih dahulu
    if (!_formKey.currentState!.validate()) {
      _showError('Harap lengkapi semua data yang diperlukan.');
      return;
    }

    setState(() => isSaving = true);

    String? photoUrlToSave = _currentPhotoUrl;

    // Jika ada gambar baru yang dipilih, proses upload dulu
    if (_selectedImage != null) {
      final newUrl = await _uploadProfilePhoto();

      // Jika upload gagal, hentikan seluruh proses penyimpanan
      if (newUrl == null) {
        _showError("Penyimpanan dibatalkan karena foto gagal diupload.");
        setState(() => isSaving = false);
        return;
      }
      photoUrlToSave = newUrl;
    }

    // Lanjutkan dengan update biodata, menggunakan URL foto yang benar
    await _updateBiodata(finalPhotoUrl: photoUrlToSave ?? "");

    setState(() => isSaving = false);
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
                      _buildPhotoSection(),
                      const SizedBox(height: 24),
                      _buildFormFields(),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isSaving ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.deepPurple
                                .withOpacity(0.5),
                          ),
                          child:
                              isSaving
                                  ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                  : const Text('Simpan Perubahan'),
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
              backgroundColor: Colors.grey.shade200,
              backgroundImage:
                  _selectedImage != null
                      ? FileImage(_selectedImage!)
                      : (_currentPhotoUrl != null &&
                          _currentPhotoUrl!.isNotEmpty &&
                          authToken != null)
                      ? CachedNetworkImageProvider(
                        "$apiImagePrefix$_currentPhotoUrl",
                        headers: {'Authorization': 'Bearer $authToken'},
                      )
                      : null,
              child:
                  (_selectedImage == null &&
                          (_currentPhotoUrl == null ||
                              _currentPhotoUrl!.isEmpty))
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
        // Tombol upload foto tidak lagi diperlukan di sini karena sudah dihandle oleh "Simpan Perubahan"
      ],
    );
  }

  Widget _buildFormFields() {
    // ... (Isi dari _buildFormFields tidak berubah, tetap sama seperti kode asli Anda)
    return Column(
      children: [
        TextFormField(
          controller: _namaController,
          decoration: const InputDecoration(
            labelText: 'Nama Lengkap',
            border: OutlineInputBorder(),
          ),
          validator:
              (value) =>
                  value == null || value.isEmpty
                      ? 'Nama tidak boleh kosong'
                      : null,
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
            if (value == null || value.isEmpty)
              return 'Email tidak boleh kosong';
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value))
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
                  value == null || value.isEmpty
                      ? 'No. HP tidak boleh kosong'
                      : null,
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
                  value == null || value.isEmpty
                      ? 'Tempat lahir tidak boleh kosong'
                      : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _tglLahirController,
          decoration: const InputDecoration(
            labelText: 'Tanggal Lahir',
            hintText: 'YYYY-MM-DD',
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.calendar_today),
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
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _divisi,
          decoration: const InputDecoration(
            labelText: 'Divisi',
            border: OutlineInputBorder(),
          ),
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
          onChanged: (value) => setState(() => _divisi = value),
          validator:
              (value) =>
                  value == null || value.isEmpty
                      ? 'Divisi tidak boleh kosong'
                      : null,
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
                  value == null || value.isEmpty
                      ? 'Alamat tidak boleh kosong'
                      : null,
        ),
      ],
    );
  }
}
