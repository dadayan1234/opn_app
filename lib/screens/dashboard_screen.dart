import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';

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
            // Card User
            if (userInfo != null) _buildUserCard(fullName, photoUrl),
            const SizedBox(height: 20),

            // Event Carousel
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
                    onTap: () {
                      // TODO: navigate to event detail
                    },
                    child: _buildEventCard(event),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Navigation Icons (contoh 2)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavIcon(Icons.event, 'Event', () {}),
                _buildNavIcon(Icons.article, 'Berita', () {}),
              ],
            ),

            const SizedBox(height: 20),
            const Text(
              'Berita Terbaru:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Column(
              children:
                  news.map((item) {
                    return ListTile(
                      title: Text(item['title']),
                      subtitle: Text(item['date']),
                      onTap: () {
                        // TODO: navigate to news detail
                      },
                    );
                  }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(String fullName, String? photoUrl) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          radius: 30,
          backgroundImage:
              photoUrl != null
                  ? CachedNetworkImageProvider(
                    "https://beopn.mysesa.site$photoUrl",
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
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event['title'] ?? '-',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              Text(event['location'] ?? ''),
              const Spacer(),
              Text(
                event['status'] ?? '',
                style: const TextStyle(color: Colors.green),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(child: Icon(icon)),
          const SizedBox(height: 5),
          Text(label),
        ],
      ),
    );
  }
}
