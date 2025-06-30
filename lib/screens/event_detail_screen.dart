import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'dart:typed_data';
// --- PERUBAHAN: Import package baru ---
import 'package:flutter_html/flutter_html.dart';

class EventDetailScreen extends StatefulWidget {
  final dynamic event;

  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen>
    with TickerProviderStateMixin {
  String? authToken;
  List<dynamic> meetingMinutes = [];
  bool isLoadingMinutes = true;
  bool hasSentFeedback = false;
  bool isSubmittingFeedback = false;
  final TextEditingController _feedbackController = TextEditingController();

  static const String apiPrefix = 'https://beopn.penaku.site/api/v1';
  static const String apiImagePrefix = 'https://beopn.penaku.site';

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _getToken().then((_) => _fetchMeetingMinutes());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      authToken = prefs.getString('access_token');
    });
  }

  Future<void> _fetchMeetingMinutes() async {
    if (authToken == null) return;

    final eventId = widget.event['id'];
    final headers = {
      'accept': 'application/json',
      'Authorization': 'Bearer $authToken',
    };

    try {
      final response = await http.get(
        Uri.parse('$apiPrefix/meeting-minutes/event/$eventId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          meetingMinutes = data is List ? data : [];
          isLoadingMinutes = false;
        });
      } else {
        setState(() {
          meetingMinutes = [];
          isLoadingMinutes = false;
        });
      }
    } catch (e) {
      print('Error fetching meeting minutes: $e');
      setState(() {
        meetingMinutes = [];
        isLoadingMinutes = false;
      });
    }
  }

  Future<void> _submitFeedback() async {
    if (_feedbackController.text.trim().isEmpty || authToken == null) return;

    setState(() {
      isSubmittingFeedback = true;
    });

    final eventId = widget.event['id'];
    final headers = {
      'accept': 'application/json',
      'Authorization': 'Bearer $authToken',
      'Content-Type': 'application/json',
    };

    final body = json.encode({'content': _feedbackController.text.trim()});

    try {
      final response = await http.post(
        Uri.parse('$apiPrefix/feedback/event/$eventId/feedback'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          hasSentFeedback = true;
          _feedbackController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Feedback berhasil dikirim'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mengirim feedback'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error submitting feedback: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terjadi kesalahan saat mengirim feedback'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() {
      isSubmittingFeedback = false;
    });
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tidak dapat membuka link: $url'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error launching URL: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terjadi kesalahan saat membuka link'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- PERUBAHAN: Fungsi baru untuk mengunduh gambar ---
  Future<void> _downloadImage(String imageUrl) async {
    if (!mounted) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Mempersiapkan file...'),
        backgroundColor: Colors.blue,
      ),
    );

    try {
      // 1. Download data gambar sebagai byte
      final dio = Dio();
      final response = await dio.get(
        imageUrl,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Authorization': 'Bearer $authToken'},
        ),
      );
      final Uint8List imageBytes = response.data;

      // 2. Dapatkan direktori sementara di aplikasi
      final tempDir = await getTemporaryDirectory();

      // 3. Buat file di direktori sementara tersebut
      final String fileName =
          "event_doc_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final File tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(imageBytes);

      if (!mounted) return;

      // 4. Bagikan file yang sudah dibuat menggunakan share_plus
      final xfile = XFile(tempFile.path);
      await Share.shareXFiles([xfile], text: 'Dokumen Event');
    } catch (e) {
      print("ERROR saat proses download atau share: $e");
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- PERUBAHAN: Fungsi _formatHtmlContent dihapus karena tidak digunakan lagi ---

  @override
  Widget build(BuildContext context) {
    final event = widget.event;

    String imagePath = '';
    if (event['photos'] != null && event['photos'].isNotEmpty) {
      imagePath = event['photos'][0]['photo_url'] ?? '';
    }

    if (imagePath.isEmpty) {
      imagePath = '/uploads/events/2025-05-13/2025-05/1747106713609_0.jpg';
    }

    final imageUrl = "$apiImagePrefix/$imagePath";
    final date =
        event['date'] != null
            ? DateFormat(
              'EEEE, dd MMMM yyyy',
              'id_ID',
            ).format(DateTime.parse(event['date']))
            : '-';
    final time =
        event['time'] != null
            ? DateFormat(
              'HH:mm',
            ).format(DateFormat('HH:mm:ss').parse(event['time']))
            : '-';

    Color statusColor;
    switch (event['status']?.toLowerCase()) {
      case 'akan datang':
        statusColor = Colors.blue;
        break;
      case 'sedang berlangsung':
        statusColor = Colors.green;
        break;
      case 'selesai':
        statusColor = Colors.grey;
        break;
      default:
        statusColor = Colors.blue;
    }

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              backgroundColor: Colors.deepPurple,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    authToken != null
                        ? Image(
                          image: CachedNetworkImageProvider(
                            imageUrl,
                            headers: {
                              'accept': 'application/json',
                              'Authorization': 'Bearer $authToken',
                            },
                          ),
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.grey[300],
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          },
                          errorBuilder:
                              (context, error, stackTrace) => Container(
                                color: Colors.grey[300],
                                child: const Icon(
                                  Icons.image_not_supported,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                              ),
                        )
                        : Container(
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.image_not_supported,
                            size: 50,
                            color: Colors.grey,
                          ),
                        ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.3),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 20,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          event['status'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.deepPurple,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.deepPurple,
                  tabs: const [
                    Tab(text: 'Detail'),
                    Tab(text: 'Notulensi'),
                    Tab(text: 'Dokumentasi'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: SingleChildScrollView(
          // <--- TAMBAHKAN WIDGET INI
          child: Column(
            children: [
              // ConstrainedBox diperlukan agar TabBarView tidak error di dalam SingleChildScrollView
              ConstrainedBox(
                constraints: BoxConstraints(
                  // Mengambil tinggi layar dikurangi beberapa elemen UI lain
                  // Sesuaikan nilai 180 jika perlu
                  maxHeight: MediaQuery.of(context).size.height - 180,
                ),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDetailTab(event, date, time),
                    _buildMeetingMinutesTab(),
                    _buildDocumentationTab(),
                  ],
                ),
              ),
              _buildFeedbackSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailTab(dynamic event, String date, String time) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event['title'] ?? '',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _buildInfoCard(
            icon: Icons.calendar_today,
            title: 'Tanggal & Waktu',
            content: '$date\n$time WIB',
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            icon: Icons.location_on,
            title: 'Lokasi',
            content: event['location'] ?? 'Lokasi belum ditentukan',
          ),
          const SizedBox(height: 20),
          if (event['description'] != null &&
              event['description'].isNotEmpty) ...[
            const Text(
              'Deskripsi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                event['description'],
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ),
            const SizedBox(height: 20),
          ],
          const Text(
            'Detail Event',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildDetailRow('ID Event', event['id']?.toString() ?? '-'),
          // --- PERUBAHAN: Logika untuk menampilkan 'Admin' ---
          _buildDetailRow(
            'Dibuat oleh',
            (event['created_by']?.toString() == '1')
                ? 'Admin'
                : 'User ID: ${event['created_by']?.toString() ?? '-'}',
          ),
          _buildDetailRow(
            'Dibuat pada',
            event['created_at'] != null
                ? DateFormat(
                  'dd MMMM yyyy, HH:mm',
                  'id_ID',
                ).format(DateTime.parse(event['created_at']))
                : '-',
          ),
          _buildDetailRow(
            'Terakhir diupdate',
            event['updated_at'] != null
                ? DateFormat(
                  'dd MMMM yyyy, HH:mm',
                  'id_ID',
                ).format(DateTime.parse(event['updated_at']))
                : '-',
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingMinutesTab() {
    if (isLoadingMinutes) {
      return const Center(child: CircularProgressIndicator());
    }

    if (meetingMinutes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Belum ada notulensi tersedia',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: meetingMinutes.length,
      itemBuilder: (context, index) {
        final minute = meetingMinutes[index];
        final date =
            minute['date'] != null
                ? DateFormat(
                  'dd MMMM yyyy',
                  'id_ID',
                ).format(DateTime.parse(minute['date']))
                : '-';

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        minute['title'] ?? 'Tanpa Judul',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      date,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (minute['description'] != null &&
                    minute['description'].isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    // --- PERUBAHAN: Merender HTML ---
                    child: Html(
                      data: minute['description'],
                      style: {
                        "body": Style(
                          fontSize: FontSize(14.0),
                          lineHeight: LineHeight.number(1.4),
                        ),
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                if (minute['document_url'] != null &&
                    minute['document_url'].isNotEmpty)
                  ElevatedButton.icon(
                    // --- PERUBAHAN: Memperbaiki URL ---
                    onPressed: () {
                      final fullUrl = "${minute['document_url']}";
                      _launchUrl(fullUrl);
                    },
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Buka Dokumen'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDocumentationTab() {
    final event = widget.event;
    final photos = event['photos'] as List?;

    if (photos == null || photos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Belum ada dokumentasi tersedia',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        final photoUrl = '$apiImagePrefix/${photo['photo_url'] ?? ''}';

        return GestureDetector(
          onTap: () => _showPhotoDialog(photoUrl),
          // --- PERUBAHAN: Menambahkan Stack untuk tombol download ---
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child:
                      authToken != null
                          ? CachedNetworkImage(
                            imageUrl: photoUrl,
                            httpHeaders: {
                              'accept': 'application/json',
                              'Authorization': 'Bearer $authToken',
                            },
                            fit: BoxFit.cover,
                            placeholder:
                                (context, url) => Container(
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                            errorWidget:
                                (context, url, error) => Container(
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.broken_image,
                                    size: 40,
                                    color: Colors.grey,
                                  ),
                                ),
                          )
                          : Container(
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.broken_image,
                              size: 40,
                              color: Colors.grey,
                            ),
                          ),
                ),
              ),
              // --- PERUBAHAN: Tombol Download ---
              Positioned(
                bottom: 8,
                right: 8,
                child: Material(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: () => _downloadImage(photoUrl),
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(6.0),
                      child: Icon(
                        Icons.download,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Sisa kode (showPhotoDialog, _buildFeedbackSection, _buildInfoCard, _buildDetailRow, _SliverTabBarDelegate) tetap sama
  // ... (salin sisa kode dari file asli Anda ke sini)
  void _showPhotoDialog(String imageUrl) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                ),
                child:
                    authToken != null
                        ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          httpHeaders: {
                            'accept': 'application/json',
                            'Authorization': 'Bearer $authToken',
                          },
                          fit: BoxFit.contain,
                          placeholder:
                              (context, url) => Container(
                                color: Colors.black.withOpacity(0.5),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          errorWidget:
                              (context, url, error) => Container(
                                color: Colors.black.withOpacity(0.5),
                                child: const Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    size: 60,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                        )
                        : Container(
                          color: Colors.black.withOpacity(0.5),
                          child: const Center(
                            child: Icon(
                              Icons.broken_image,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                        ),
              ),
            ),
          ),
    );
  }

  Widget _buildFeedbackSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Berikan Feedback',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (!hasSentFeedback) ...[
            TextField(
              controller: _feedbackController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Tulis feedback Anda tentang event ini...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.deepPurple),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSubmittingFeedback ? null : _submitFeedback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child:
                    isSubmittingFeedback
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                        : const Text('Kirim Feedback'),
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700]),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Terima kasih! Feedback Anda telah dikirim.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.deepPurple, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          const Text(': '),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverTabBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: Colors.white, child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
