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

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    final headers = {
      'accept': 'application/json',
      'Authorization': 'Bearer $token',
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

  @override
  Widget build(BuildContext context) {
    final photoUrl = userInfo?['member_info']?['photo_url'];
    var fullName = widget.fullName;
    if (fullName.isEmpty) {
      fullName = userInfo?['member_info']?['full_name'] ?? '';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (userInfo != null) _buildUserCard(fullName, photoUrl),
            const SizedBox(height: 20),

            const Text(
              'Event Terbaru:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 150,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final event = events[index];
                  return GestureDetector(
                    onTap: () {},
                    child: _buildEventCard(event),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavIcon(Icons.event, 'Event', () {}),
                _buildNavIcon(Icons.article, 'Berita', () {}),
                _buildNavIcon(Icons.money, 'Keuangan', () {}),
              ],
            ),

            const SizedBox(height: 20),
            const Text(
              'Berita Terbaru:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Column(children: news.map((item) => _buildNewsCard(item)).toList()),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(String fullName, String? photoUrl) {
    return FutureBuilder<String?>(
      future: SharedPreferences.getInstance().then(
        (prefs) => prefs.getString('access_token'),
      ),
      builder: (context, snapshot) {
        final token = snapshot.data;
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              radius: 30,
              backgroundImage:
                  (photoUrl != null && token != null)
                      ? CachedNetworkImageProvider(
                        "https://beopn.mysesa.site/$photoUrl",
                        headers: {
                          'accept': 'application/json',
                          'Authorization': 'Bearer $token',
                        },
                      )
                      : null,
              child: photoUrl == null ? const Icon(Icons.person) : null,
            ),
            title: Text(fullName, style: const TextStyle(fontSize: 18)),
            subtitle: const Text("Selamat datang!"),
          ),
        );
      },
    );
  }

  Widget _buildEventCard(dynamic event) {
    var imagepath = '/uploads/events/2025-05-13/2025-05/1747106713609_0.jpg';
    final imageUrl =
        imagepath.isNotEmpty ? "https://beopn.mysesa.site/$imagepath" : null;

    final date =
        event['start_date'] != null
            ? DateFormat(
              'dd MMM yyyy',
            ).format(DateTime.parse(event['start_date']))
            : '-';

    return FutureBuilder<String?>(
      future: SharedPreferences.getInstance().then(
        (prefs) => prefs.getString('access_token'),
      ),
      builder: (context, snapshot) {
        final token = snapshot.data;
        return Container(
          width: 220,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child:
                    imageUrl != null && token != null
                        ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          httpHeaders: {
                            'accept': 'application/json',
                            'Authorization': 'Bearer $token',
                          },
                          height: 200,
                          width: 220,
                          fit: BoxFit.cover,
                        )
                        : Container(
                          height: 200,
                          width: 220,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image_not_supported),
                        ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.black.withOpacity(0.4),
                  ),
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
        );
      },
    );
  }

  Widget _buildNewsCard(dynamic item) {
    final date =
        item['date'] != null
            ? DateFormat('dd MMM yyyy').format(DateTime.parse(item['date']))
            : '-';

    final imageUrl =
        item['photo_url'] != null
            ? "https://beopn.mysesa.site/${item['photo_url']}"
            : 'https://via.placeholder.com/150'; // fallback

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Stack(
        children: [
          CachedNetworkImage(
            imageUrl: imageUrl,
            height: 120,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
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
          ListTile(
            contentPadding: const EdgeInsets.all(12),
            title: Text(
              item['title'],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(date, style: const TextStyle(color: Colors.white70)),
            onTap: () {
              // TODO: navigate to detail
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue[100],
            child: Icon(icon, color: Colors.blue[700]),
          ),
          const SizedBox(height: 5),
          Text(label),
        ],
      ),
    );
  }
}
