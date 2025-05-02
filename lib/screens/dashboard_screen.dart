// dashboard_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class DashboardScreen extends StatefulWidget {
  final String fullName;
  const DashboardScreen({super.key, required this.fullName});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _events = [];
  List<dynamic> _news = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    final eventRes = await http.get(
      Uri.parse('https://beopn.mysesa.site/api/v1/events/?skip=0&limit=10'),
      headers: {'accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    final newsRes = await http.get(
      Uri.parse(
        'https://beopn.mysesa.site/api/v1/news/?skip=0&limit=10&is_published=true',
      ),
      headers: {'accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    if (eventRes.statusCode == 200 && newsRes.statusCode == 200) {
      setState(() {
        _events = json.decode(eventRes.body);
        _news = json.decode(newsRes.body);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selamat datang, ${widget.fullName}',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            const Text(
              'Event Terbaru:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ..._events.map(
              (e) => ListTile(
                title: Text(e['title'] ?? '-'),
                subtitle: Text(e['location'] ?? ''),
                trailing: Text(e['status'] ?? ''),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Berita Terbaru:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ..._news.map(
              (n) => ListTile(
                title: Text(n['title'] ?? '-'),
                subtitle: Text(n['date'] ?? ''),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
