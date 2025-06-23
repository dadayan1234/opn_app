import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart'; // Import Firebase service
import 'news_screen.dart';

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

  // API endpoint prefix
  static const String apiPrefix = 'https://beopn.penaku.site/api/v1';
  static const String apiImagePrefix = 'https://beopn.penaku.site';

  // Animation controllers for skeleton
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
    _closeDropdown(); // Tutup dropdown saat dispose
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
    setState(() {
      isNotificationEnabled = prefs.getBool('fcm_token_sent') ?? false;
    });
  }

  Future<void> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      authToken = prefs.getString('access_token');
    });
  }

  Future<void> _fetchAll() async {
    if (authToken == null) return;

    setState(() {
      isLoading = true;
    });

    final headers = {
      'accept': 'application/json',
      'Authorization': 'Bearer $authToken',
    };

    try {
      final userRes = await http.get(
        Uri.parse('$apiPrefix/members/me'),
        headers: headers,
      );

      final eventsRes = await http.get(
        Uri.parse('$apiPrefix/events/?page=1&limit=3'),
        headers: headers,
      );

      final newsRes = await http.get(
        Uri.parse('$apiPrefix/news/?skip=0&limit=10&is_published=true'),
        headers: headers,
      );

      if (userRes.statusCode == 200 &&
          eventsRes.statusCode == 200 &&
          newsRes.statusCode == 200) {
        setState(() {
          userInfo = json.decode(userRes.body);
          events = json.decode(eventsRes.body)['data'];
          news = json.decode(newsRes.body);
        });
      }
    } catch (e) {
      print('Error fetching data: $e');
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _onRefresh() async {
    await _fetchAll();
  }

  // Function to request notification permission
  Future<void> _requestNotificationPermission() async {
    bool permissionGranted = await FirebaseService.requestPermission();

    if (permissionGranted) {
      // Get FCM token
      final token = await FirebaseService.getToken();
      if (token != null) {
        // Send the token to your server
        final success = await FirebaseService.sendTokenToServer(token);
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Izin notifikasi ditolak'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    // Navigate to login screen
    if (mounted) {
      Navigator.of(context).pushReplacementNamed(
        '/login',
      ); // Adjust this according to your navigation setup
    }
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = userInfo?['member_info']?['photo_url'];
    var fullName = widget.fullName;
    if (fullName.isEmpty) {
      fullName = userInfo?['member_info']?['full_name'] ?? '';
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildCustomHeader(photoUrl),
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
                        if (userInfo != null)
                          _buildUserCard(fullName, photoUrl),
                        const SizedBox(height: 10),

                        // Notification permission card
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
                              news.map((item) => _buildNewsCard(item)).toList(),
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
    );
  }

  Widget _buildSkeletonLoading() {
    return AnimatedBuilder(
      animation: _skeletonAnimation,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User card skeleton
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  radius: 30,
                  backgroundColor: _getSkeletonColor(),
                ),
                title: Container(
                  height: 18,
                  width: 150,
                  decoration: BoxDecoration(
                    color: _getSkeletonColor(),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                subtitle: Container(
                  height: 14,
                  width: 100,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: _getSkeletonColor(),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
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

            // News cards skeleton
            ...List.generate(
              3,
              (index) => Container(
                height: 120,
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

  Color _getSkeletonColor() {
    return Color.lerp(
      Colors.grey[300]!,
      Colors.grey[100]!,
      _skeletonAnimation.value,
    )!;
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Aktifkan Notifikasi',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Text(
                    'Dapatkan pemberitahuan untuk event dan berita terbaru',
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

  // Tambahkan state variable untuk dropdown
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
            left: offset.dx - 120, // Adjust position
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

  // Method untuk membuka dropdown
  void _openDropdown() {
    if (_overlayEntry == null) {
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
      setState(() {
        _isDropdownOpen = true;
      });
    }
  }

  // Method untuk menutup dropdown
  void _closeDropdown() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
      setState(() {
        _isDropdownOpen = false;
      });
    }
  }

  // Update _buildCustomHeader method
  Widget _buildCustomHeader(String? photoUrl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.deepPurple,
      child: Row(
        children: [
          // Logo on the left
          Container(
            height: 30,
            width: 30,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
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

          // Profile avatar with dropdown
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
                  Icons.person,
                  size: 18,
                  color: Colors.deepPurple[700],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildUserCard(String fullName, String? photoUrl) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          radius: 30,
          backgroundImage:
              (photoUrl != null && authToken != null)
                  ? CachedNetworkImageProvider(
                    "$apiImagePrefix/$photoUrl",
                    headers: {
                      'accept': 'application/json',
                      'Authorization': 'Bearer $authToken',
                    },
                  )
                  : null,
          child: photoUrl == null ? const Icon(Icons.person) : null,
        ),
        title: Text(fullName, style: const TextStyle(fontSize: 18)),
        subtitle: const Text("Selamat datang!"),
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
            ? DateFormat('EEEE, dd MMMM').format(DateTime.parse(event['date']))
            : '-';

    return GestureDetector(
      onTap: () {
        // Navigate to event detail
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (context) => Scaffold(
                  appBar: AppBar(title: Text(event['title'] ?? 'Event Detail')),
                  body: const Center(child: Text('Event Detail Page')),
                ),
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
              blurRadius: 20,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child:
                  authToken != null
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

            // Gradient overlay (not causing blur anymore)
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

            // Content
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
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 16,
                            ),
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
            ? DateFormat('dd MMM yyyy').format(DateTime.parse(item['date']))
            : '-';

    String photoUrl = item['photos']?[0]?['photo_url'] ?? '';
    final imageUrl =
        photoUrl.isNotEmpty
            ? "$apiImagePrefix/$photoUrl"
            : 'https://via.placeholder.com/150';

    return GestureDetector(
      onTap: () {
        // Navigate to news detail
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (context) => Scaffold(
                  appBar: AppBar(title: Text(item['title'] ?? 'News Detail')),
                  body: const Center(child: Text('News Detail Page')),
                ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Stack(
          children: [
            // Image
            authToken != null && photoUrl.isNotEmpty
                ? Image(
                  image: CachedNetworkImageProvider(
                    imageUrl,
                    headers: {
                      'accept': 'application/json',
                      'Authorization': 'Bearer $authToken',
                    },
                  ),
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 120,
                      color: Colors.grey[300],
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder:
                      (context, error, stackTrace) => Container(
                        height: 120,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image_not_supported),
                      ),
                )
                : Container(
                  height: 120,
                  color: Colors.grey[300],
                  child: const Icon(Icons.image_not_supported),
                ),

            // Gradient overlay
            Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),

            // Content
            ListTile(
              contentPadding: const EdgeInsets.all(12),
              title: Text(
                item['title'] ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                date,
                style: const TextStyle(color: Colors.white70),
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
          // Navigate to events page
          Navigator.of(context).pushNamed('/events');
          // .push(
          //   MaterialPageRoute(
          //     builder:
          //         (context) => Scaffold(
          //           appBar: AppBar(title: Text('Events')),
          //           body: const Center(child: Text('Events Page')),
          //         ),
          //   ),
          // );
        }),
        _buildNavIcon(Icons.article, 'Berita', () {
          // Navigate to news page
          Navigator.of(context).pushNamed('/news');
        }),
        _buildNavIcon(Icons.money, 'Keuangan', () {
          // Navigate to finance page
          Navigator.of(context).pushNamed('/finance');
        }),
      ],
    );
  }

  Widget _buildNavIcon(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: Colors.blue[100],
              child: Icon(icon, color: Colors.blue[700], size: 24),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
