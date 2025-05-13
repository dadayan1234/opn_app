import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  final String fullName;
  const DashboardScreen({super.key, required this.fullName});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? userInfo;
  List<dynamic> events = [];
  List<dynamic> news = [];
  String? authToken;

  @override
  void initState() {
    super.initState();
    _getToken().then((_) => _fetchAll());
  }

  Future<void> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      authToken = prefs.getString('access_token');
    });
  }

  Future<void> _fetchAll() async {
    if (authToken == null) return;

    final headers = {
      'accept': 'application/json',
      'Authorization': 'Bearer $authToken',
    };

    final userRes = await http.get(
      Uri.parse('https://beopn.mysesa.site/api/v1/members/me'),
      headers: headers,
    );

    final eventsRes = await http.get(
      Uri.parse('https://beopn.mysesa.site/api/v1/events/?page=1&limit=3'),
      headers: headers,
    );

    final newsRes = await http.get(
      Uri.parse(
        'https://beopn.mysesa.site/api/v1/news/?skip=0&limit=10&is_published=true',
      ),
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (userInfo != null) _buildUserCard(fullName, photoUrl),
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomHeader(String? photoUrl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.deepPurple,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo on the left
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                "SESA",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
            ),
          ),

          const Text(
            "Dashboard",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          // Profile and logout icons on the right
          Row(
            children: [
              if (photoUrl != null && authToken != null)
                GestureDetector(
                  onTap: () {
                    // Navigate to profile page
                  },
                  child: CircleAvatar(
                    radius: 16,
                    backgroundImage: CachedNetworkImageProvider(
                      "https://beopn.mysesa.site/$photoUrl",
                      headers: {
                        'accept': 'application/json',
                        'Authorization': 'Bearer $authToken',
                      },
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: () {
                    // Navigate to profile page
                  },
                  child: const CircleAvatar(
                    radius: 16,
                    child: Icon(Icons.person, size: 18),
                  ),
                ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _logout,
                child: const Icon(Icons.logout, color: Colors.white),
              ),
            ],
          ),
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
                    "https://beopn.mysesa.site/$photoUrl",
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

    final imageUrl = "https://beopn.mysesa.site/$imagePath";

    final date =
        event['start_date'] != null
            ? DateFormat(
              'dd MMM yyyy',
            ).format(DateTime.parse(event['start_date']))
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
        width: 220,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
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
                        width: 220,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 150,
                            width: 220,
                            color: Colors.grey[300],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        },
                        errorBuilder:
                            (context, error, stackTrace) => Container(
                              height: 150,
                              width: 220,
                              color: Colors.grey[300],
                              child: const Icon(Icons.image_not_supported),
                            ),
                      )
                      : Container(
                        height: 150,
                        width: 220,
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
            ? "https://beopn.mysesa.site/$photoUrl"
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
          Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (context) => Scaffold(
                    appBar: AppBar(title: Text('Events')),
                    body: const Center(child: Text('Events Page')),
                  ),
            ),
          );
        }),
        _buildNavIcon(Icons.article, 'Berita', () {
          // Navigate to news page
          Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (context) => Scaffold(
                    appBar: AppBar(title: Text('Berita')),
                    body: const Center(child: Text('Berita Page')),
                  ),
            ),
          );
        }),
        _buildNavIcon(Icons.money, 'Keuangan', () {
          // Navigate to finance page
          Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (context) => Scaffold(
                    appBar: AppBar(title: Text('Keuangan')),
                    body: const Center(child: Text('Keuangan Page')),
                  ),
            ),
          );
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
