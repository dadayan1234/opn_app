import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:flutter_html/flutter_html.dart';

class NewsDetailScreen extends StatefulWidget {
  final int newsId;

  const NewsDetailScreen({super.key, required this.newsId});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? newsDetail;
  String? authToken;
  bool isLoading = true;

  // API endpoint prefix
  static const String apiPrefix = 'https://beopn.pemudanambangan.site/api/v1';
  static const String apiImagePrefix = 'https://beopn.pemudanambangan.site';

  // Animation controllers for skeleton
  late AnimationController _skeletonController;
  late Animation<double> _skeletonAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _getToken().then((_) => _fetchNewsDetail());
  }

  @override
  void dispose() {
    _skeletonController.dispose();
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

  Future<void> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      authToken = prefs.getString('access_token');
    });
  }

  Future<void> _fetchNewsDetail() async {
    if (authToken == null) return;

    setState(() {
      isLoading = true;
    });

    final headers = {
      'accept': 'application/json',
      'Authorization': 'Bearer $authToken',
    };

    try {
      final response = await http.get(
        Uri.parse('$apiPrefix/news/${widget.newsId}'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        setState(() {
          newsDetail = json.decode(response.body);
        });
      }
    } catch (e) {
      print('Error fetching news detail: $e');
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: Text(
          newsDetail?['title'] ?? 'Detail Berita',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
      ),
      body: isLoading ? _buildSkeletonLoading() : _buildContent(),
    );
  }

  Widget _buildSkeletonLoading() {
    return AnimatedBuilder(
      animation: _skeletonAnimation,
      builder: (context, child) {
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image skeleton
              Container(
                height: 250,
                width: double.infinity,
                color: _getSkeletonColor(),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title skeleton
                    Container(
                      height: 24,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: _getSkeletonColor(),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 24,
                      width: 200,
                      decoration: BoxDecoration(
                        color: _getSkeletonColor(),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Meta info skeleton
                    Row(
                      children: [
                        Container(
                          height: 16,
                          width: 80,
                          decoration: BoxDecoration(
                            color: _getSkeletonColor(),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          height: 16,
                          width: 60,
                          decoration: BoxDecoration(
                            color: _getSkeletonColor(),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Content skeleton
                    ...List.generate(
                      6,
                      (index) => Container(
                        height: 16,
                        width: index == 5 ? 150 : double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: _getSkeletonColor(),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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

  Widget _buildContent() {
    if (newsDetail == null) {
      return const Center(
        child: Text(
          'Berita tidak ditemukan',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final date =
        newsDetail!['date'] != null
            ? DateFormat(
              'EEEE, dd MMMM yyyy',
            ).format(DateTime.parse(newsDetail!['date']))
            : '-';

    final author = newsDetail!['created_by'] == 1 ? 'Admin' : 'User';

    String photoUrl = newsDetail!['photos']?[0]?['photo_url'] ?? '';
    final imageUrl = photoUrl.isNotEmpty ? "$apiImagePrefix/$photoUrl" : '';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Image
          if (imageUrl.isNotEmpty)
            SizedBox(
              height: 250,
              width: double.infinity,
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
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 250,
                            color: Colors.grey[300],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        },
                        errorBuilder:
                            (context, error, stackTrace) => Container(
                              height: 250,
                              color: Colors.grey[300],
                              child: const Icon(
                                Icons.image_not_supported,
                                size: 60,
                              ),
                            ),
                      )
                      : Container(
                        height: 250,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image_not_supported, size: 60),
                      ),
            ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  newsDetail!['title'] ?? '',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    height: 1.3,
                  ),
                ),

                const SizedBox(height: 16),

                // Meta information
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.grey[300]!),
                      bottom: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        date,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Icon(Icons.person, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        author,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Description/Content
                Html(
                  data: newsDetail!['description'] ?? '',
                  style: {
                    "body": Style(
                      fontSize: FontSize(16),
                      lineHeight: LineHeight(1.6),
                      color: Colors.black87,
                      margin: Margins.zero,
                      padding: HtmlPaddings.zero,
                    ),
                    "p": Style(
                      fontSize: FontSize(16),
                      lineHeight: LineHeight(1.6),
                      margin: Margins.only(bottom: 16),
                    ),
                    "h1": Style(
                      fontSize: FontSize(24),
                      fontWeight: FontWeight.bold,
                      margin: Margins.only(top: 20, bottom: 16),
                    ),
                    "h2": Style(
                      fontSize: FontSize(20),
                      fontWeight: FontWeight.bold,
                      margin: Margins.only(top: 16, bottom: 12),
                    ),
                    "h3": Style(
                      fontSize: FontSize(18),
                      fontWeight: FontWeight.bold,
                      margin: Margins.only(top: 12, bottom: 8),
                    ),
                    "ul": Style(
                      margin: Margins.only(bottom: 16),
                      padding: HtmlPaddings.only(left: 20),
                    ),
                    "ol": Style(
                      margin: Margins.only(bottom: 16),
                      padding: HtmlPaddings.only(left: 20),
                    ),
                    "li": Style(margin: Margins.only(bottom: 8)),
                    "strong": Style(fontWeight: FontWeight.bold),
                    "em": Style(fontStyle: FontStyle.italic),
                    "u": Style(textDecoration: TextDecoration.underline),
                  },
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
