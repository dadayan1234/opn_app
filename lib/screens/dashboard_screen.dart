import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_html/flutter_html.dart';

// TODO: Sesuaikan path import ini dengan struktur proyek Anda
import 'event_detail_screen.dart';
import 'news_detail_screen.dart';
import 'package:opn_app/services/api_service.dart';

import 'package:opn_app/services/notification_service.dart';

class DashboardScreen extends StatefulWidget {
  final String fullName;
  const DashboardScreen({super.key, required this.fullName});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? userInfo;
  List<dynamic> events = [];
  List<dynamic> news = [];
  String? authToken;
  bool isNotificationEnabled = false;
  bool isLoading = true;

  static const String apiPrefix = 'https://beopn.penaku.site/api/v1';
  static const String apiImagePrefix = 'https://beopn.penaku.site';

  late AnimationController _skeletonController;
  late Animation<double> _skeletonAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _getToken().then((_) => _fetchAll());
    _checkNotificationStatus();
  }

  @override
  void dispose() {
    _skeletonController.dispose();
    _closeDropdown();
    super.dispose();
  }

  void _initializeAnimations() {
    _skeletonController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _skeletonAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _skeletonController, curve: Curves.easeInOut),
    );
  }

  Future<void> _checkNotificationStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        isNotificationEnabled = prefs.getBool('fcm_token_sent') ?? false;
      });
    }
  }

  Future<void> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        authToken = prefs.getString('access_token');
      });
    }
  }

  Future<void> _fetchAll() async {
    if (authToken == null) {
      // Jika token belum siap, tunggu sebentar dan coba lagi
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        _fetchAll();
      }
      return;
    }

    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    final headers = {
      'accept': 'application/json',
      'Authorization': 'Bearer $authToken',
    };

    try {
      final userRes = await ApiService.get('/members/me');
      final eventsRes = await ApiService.get('/events/?page=1&limit=3');
      final newsRes = await ApiService.get(
        '/news/?skip=0&limit=10&is_published=true',
      );

      if (userRes.statusCode == 200 &&
          eventsRes.statusCode == 200 &&
          newsRes.statusCode == 200) {
        final dynamic decodedUserBody = json.decode(userRes.body);
        Map<String, dynamic>? userMap;
        if (decodedUserBody is List && decodedUserBody.isNotEmpty) {
          userMap = decodedUserBody[0] as Map<String, dynamic>;
        } else if (decodedUserBody is Map<String, dynamic>) {
          userMap = decodedUserBody;
        }

        if (mounted) {
          setState(() {
            userInfo = userMap;
            events = json.decode(eventsRes.body)['data'];
            news = json.decode(newsRes.body);
          });
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error fetching data: $e');
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    await _fetchAll();
  }

  Future<void> _requestNotificationPermission() async {
    // Gunakan NotificationService yang baru
    final notificationService = NotificationService();

    bool permissionGranted = await notificationService.requestPermission();

    if (permissionGranted) {
      final token = await notificationService.getToken();
      if (token != null) {
        final success = await notificationService.sendTokenToServer(token);
        if (mounted) {
          if (success) {
            setState(() {
              isNotificationEnabled = true;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notifikasi telah diaktifkan'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Gagal mengaktifkan notifikasi'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Izin notifikasi ditolak'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  // State dan GlobalKey untuk dropdown menu
  bool _isDropdownOpen = false;
  OverlayEntry? _overlayEntry;
  final GlobalKey _avatarKey = GlobalKey();

  // Method untuk membuat overlay dropdown
  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox =
        _avatarKey.currentContext!.findRenderObject() as RenderBox;
    var size = renderBox.size;
    var offset = renderBox.localToGlobal(Offset.zero);

    return OverlayEntry(
      builder:
          (context) => Positioned(
            left: offset.dx - 120, // Sesuaikan posisi
            top: offset.dy + size.height + 5,
            width: 150,
            child: Material(
              elevation: 8.0,
              borderRadius: BorderRadius.circular(8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.person, size: 20),
                      title: const Text(
                        'Profil',
                        style: TextStyle(fontSize: 14),
                      ),
                      onTap: () {
                        _closeDropdown();
                        Navigator.of(context).pushNamed('/profile');
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.notifications, size: 20),
                      title: const Text(
                        'Notifikasi',
                        style: TextStyle(fontSize: 14),
                      ),
                      onTap: () {
                        _closeDropdown();
                        if (!isNotificationEnabled) {
                          _requestNotificationPermission();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Notifikasi sudah aktif'),
                            ),
                          );
                        }
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.logout,
                        size: 20,
                        color: Colors.red,
                      ),
                      title: const Text(
                        'Logout',
                        style: TextStyle(fontSize: 14, color: Colors.red),
                      ),
                      onTap: () {
                        _closeDropdown();
                        _logout();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  void _openDropdown() {
    if (_overlayEntry == null) {
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
      setState(() {
        _isDropdownOpen = true;
      });
    }
  }

  void _closeDropdown() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
      setState(() {
        _isDropdownOpen = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var fullName = widget.fullName;
    if (fullName.isEmpty) {
      fullName = userInfo?['member_info']?['full_name'] ?? 'Nama Pengguna';
    }
    final division =
        userInfo?['member_info']?['division'] ?? 'Belum ada divisi';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color.fromARGB(255, 155, 118, 224),
              const Color.fromARGB(255, 255, 236, 252),
            ],
            stops: const [0.0, 0.4],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildCustomHeader(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _onRefresh,
                  color: Colors.deepPurple,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isLoading)
                          _buildSkeletonLoading()
                        else ...[
                          _buildUserCard(fullName, division),
                          const SizedBox(height: 10),
                          if (!isNotificationEnabled) _buildNotificationCard(),
                          const SizedBox(height: 20),
                          const Text(
                            'Event Terbaru:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 150,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: events.length,
                              itemBuilder: (context, index) {
                                final event = events[index];
                                return _buildEventCard(event);
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildNavIcons(),
                          const SizedBox(height: 20),
                          const Text(
                            'Berita Terbaru:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Column(
                            children:
                                news
                                    .map((item) => _buildNewsCard(item))
                                    .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.transparent,
      child: Row(
        children: [
          Container(
            height: 30,
            width: 30,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Image.asset(
                'assets/images/logo_opn.png',
                height: 30,
                width: 30,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            "OPN Mobile",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          GestureDetector(
            key: _avatarKey,
            onTap: () {
              if (_isDropdownOpen) {
                _closeDropdown();
              } else {
                _openDropdown();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.person_outline,
                  size: 18,
                  color: Colors.deepPurple[700],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(String fullName, String division) {
    final photoUrl = userInfo?['member_info']?['photo_url'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.deepPurple.shade100,
            backgroundImage:
                (photoUrl != null && authToken != null)
                    ? CachedNetworkImageProvider(
                      "$apiImagePrefix$photoUrl", // Tanda / di awal photoUrl sudah ditangani oleh backend
                      headers: {
                        'accept': 'application/json',
                        'Authorization': 'Bearer $authToken',
                      },
                    )
                    : null,
            child:
                photoUrl == null
                    ? const Icon(
                      Icons.person,
                      size: 30,
                      color: Colors.deepPurple,
                    )
                    : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Selamat datang!",
                  style: TextStyle(color: Colors.deepPurple, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  fullName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // PERBAIKAN TAMPILAN SESUAI PERMINTAAN TERAKHIR
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Divisi: ",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        division,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.deepPurple.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(dynamic event) {
    String imagePath = event['photo_url'] ?? '';
    if (imagePath.isEmpty) {
      imagePath = '/uploads/events/2025-05-13/2025-05/1747106713609_0.jpg';
    }

    final imageUrl = "$apiImagePrefix/$imagePath";
    final date =
        event['date'] != null
            ? DateFormat(
              'EEEE, dd MMMM',
              'id_ID',
            ).format(DateTime.parse(event['date']))
            : '-';

    Widget statusIcon;
    switch (event['status']?.toLowerCase()) {
      case 'selesai':
        statusIcon = const Icon(
          Icons.check_circle,
          color: Colors.greenAccent,
          size: 16,
        );
        break;
      case 'akan datang':
        statusIcon = const Icon(
          Icons.update,
          color: Colors.yellowAccent,
          size: 16,
        );
        break;
      case 'sedang berlangsung':
        statusIcon = const Icon(
          Icons.sensors,
          color: Colors.lightBlueAccent,
          size: 16,
        );
        break;
      default:
        statusIcon = const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => EventDetailScreen(event: event),
          ),
        );
      },
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child:
                  (authToken != null && imagePath.isNotEmpty)
                      ? Image(
                        image: CachedNetworkImageProvider(
                          imageUrl,
                          headers: {
                            'accept': 'application/json',
                            'Authorization': 'Bearer $authToken',
                          },
                        ),
                        height: 150,
                        width: 280,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 150,
                            width: 280,
                            color: Colors.grey[300],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        },
                        errorBuilder:
                            (context, error, stackTrace) => Container(
                              height: 150,
                              width: 280,
                              color: Colors.grey[300],
                              child: const Icon(Icons.image_not_supported),
                            ),
                      )
                      : Container(
                        height: 150,
                        width: 280,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image_not_supported),
                      ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event['title'] ?? '-',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event['location'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              date,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            statusIcon,
                            const SizedBox(width: 4),
                            Text(
                              event['status'] ?? '',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildNewsCard(dynamic item) {
    final date =
        item['date'] != null
            ? DateFormat(
              'EEEE, dd MMM widesan',
              'id_ID',
            ).format(DateTime.parse(item['date']))
            : '-';

    String photoUrl = item['photos']?[0]?['photo_url'] ?? '';
    final imageUrl = photoUrl.isNotEmpty ? "$apiImagePrefix$photoUrl" : '';

    final description =
        item['description'] ?? 'Klik untuk membaca selengkapnya...';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => NewsDetailScreen(newsId: item['id']),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 3,
        shadowColor: Colors.black.withOpacity(0.1),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Stack(
          alignment: Alignment.bottomLeft,
          children: [
            // Bagian Image (tidak berubah)
            if (authToken != null && photoUrl.isNotEmpty)
              Image(
                image: CachedNetworkImageProvider(
                  imageUrl,
                  headers: {
                    'accept': 'application/json',
                    'Authorization': 'Bearer $authToken',
                  },
                ),
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 160,
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder:
                    (context, error, stackTrace) => Container(
                      height: 160,
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image),
                    ),
              )
            else
              Container(
                height: 160,
                color: Colors.grey[200],
                child: const Icon(
                  Icons.image_not_supported,
                  color: Colors.grey,
                  size: 40,
                ),
              ),

            // Bagian Gradient (tidak berubah)
            Container(
              height: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.center,
                ),
              ),
            ),

            // Bagian Konten Teks
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // --- PERUBAHAN DI SINI ---
                    Html(
                      data: description,
                      style: {
                        "body": Style(
                          margin: Margins.zero,
                          padding: HtmlPaddings.zero,
                          color: Colors.white.withOpacity(0.9),
                          fontSize: FontSize(12),
                          maxLines: 1,
                          textOverflow: TextOverflow.ellipsis,
                        ),
                        "p": Style(
                          margin: Margins.zero,
                          padding: HtmlPaddings.zero,
                        ),
                      },
                    ),

                    // --- AKHIR PERUBAHAN ---
                    const SizedBox(height: 8),
                    Text(
                      date,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
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

  Widget _buildNavIcons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildNavIcon(Icons.event, 'Event', () {
          Navigator.of(context).pushNamed('/events');
        }),
        _buildNavIcon(Icons.article, 'Berita', () {
          Navigator.of(context).pushNamed('/news');
        }),
        _buildNavIcon(Icons.money, 'Keuangan', () {
          Navigator.of(context).pushNamed('/finance');
        }),
      ],
    );
  }

  Widget _buildNavIcon(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 80,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: Colors.deepPurple.withOpacity(0.1),
                child: Icon(icon, color: Colors.deepPurple, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard() {
    return Card(
      color: Colors.deepPurple[50],
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.deepPurple[700]),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aktifkan Notifikasi',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    'Dapatkan info event dan berita terbaru.',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _requestNotificationPermission,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple[700],
                foregroundColor: Colors.white,
              ),
              child: const Text('Aktifkan'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getSkeletonColor() {
    return Color.lerp(
      Colors.grey[300]!,
      Colors.grey[100]!,
      _skeletonAnimation.value,
    )!;
  }

  Widget _buildSkeletonLoading() {
    return AnimatedBuilder(
      animation: _skeletonAnimation,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User card skeleton
            Container(
              height: 100,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getSkeletonColor(),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 20),

            // Events section skeleton
            Container(
              height: 18,
              width: 120,
              decoration: BoxDecoration(
                color: _getSkeletonColor(),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 150,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 3,
                itemBuilder: (context, index) {
                  return Container(
                    width: 280,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: _getSkeletonColor(),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // Navigation icons skeleton
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                3,
                (index) => Column(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: _getSkeletonColor(),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 14,
                      width: 50,
                      decoration: BoxDecoration(
                        color: _getSkeletonColor(),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // News section skeleton
            Container(
              height: 18,
              width: 120,
              decoration: BoxDecoration(
                color: _getSkeletonColor(),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 10),

            ...List.generate(
              3,
              (index) => Container(
                height: 140,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: _getSkeletonColor(),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
