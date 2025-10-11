import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'news_detail_screen.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> with TickerProviderStateMixin {
  List<dynamic> news = [];
  String? authToken;
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMoreData = true;
  int currentSkip = 0;
  final int pageSize = 10;

  // API endpoint prefix
  static const String apiPrefix = 'https://beopn.penaku.site/api/v1';
  static const String apiImagePrefix = 'https://beopn.penaku.site';

  // Animation controllers for skeleton
  late AnimationController _skeletonController;
  late Animation<double> _skeletonAnimation;

  // Scroll controller untuk pagination
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _scrollController.addListener(_onScroll);
    _getToken().then((_) => _fetchNews());
  }

  @override
  void dispose() {
    _skeletonController.dispose();
    _scrollController.dispose();
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

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!isLoadingMore && hasMoreData) {
        _loadMoreNews();
      }
    }
  }

  Future<void> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      authToken = prefs.getString('access_token');
    });
  }

  Future<void> _fetchNews() async {
    if (authToken == null) return;

    setState(() {
      isLoading = true;
      currentSkip = 0;
      hasMoreData = true;
      news = [];
    });

    final headers = {
      'accept': 'application/json',
      'Authorization': 'Bearer $authToken',
    };

    try {
      final response = await http.get(
        Uri.parse(
          '$apiPrefix/news/?skip=$currentSkip&limit=$pageSize&is_published=true',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> newData = json.decode(response.body);
        setState(() {
          news = newData;
          currentSkip = pageSize;
          hasMoreData = newData.length == pageSize;
        });
      }
    } catch (e) {
      print('Error fetching news: $e');
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _loadMoreNews() async {
    if (authToken == null || !hasMoreData || isLoadingMore) return;

    setState(() {
      isLoadingMore = true;
    });

    final headers = {
      'accept': 'application/json',
      'Authorization': 'Bearer $authToken',
    };

    try {
      final response = await http.get(
        Uri.parse(
          '$apiPrefix/news/?skip=$currentSkip&limit=$pageSize&is_published=true',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> newData = json.decode(response.body);
        setState(() {
          news.addAll(newData);
          currentSkip += pageSize;
          hasMoreData = newData.length == pageSize;
        });
      }
    } catch (e) {
      print('Error loading more news: $e');
    }

    setState(() {
      isLoadingMore = false;
    });
  }

  Future<void> _onRefresh() async {
    await _fetchNews();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text(
          'Berita',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header section with title
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: const Text(
              'Daftar Berita',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),

          // News list
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              color: Colors.deepPurple,
              child:
                  isLoading
                      ? _buildSkeletonLoading()
                      : news.isEmpty
                      ? const Center(
                        child: Text(
                          'Tidak ada berita tersedia',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                      : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: news.length + (isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == news.length) {
                            return _buildLoadingMoreIndicator();
                          }
                          final item = news[index];
                          return _buildNewsCard(item);
                        },
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return AnimatedBuilder(
      animation: _skeletonAnimation,
      builder: (context, child) {
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 5,
          itemBuilder: (context, index) {
            return Container(
              height: 120,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: _getSkeletonColor(),
                borderRadius: BorderRadius.circular(12),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingMoreIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: const CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
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

  Widget _buildNewsCard(dynamic item) {
    final date =
        item['date'] != null
            ? DateFormat('dd MMMM yyyy').format(DateTime.parse(item['date']))
            : '-';

    final author = item['created_by'] == 1 ? 'Admin' : 'User';

    String photoUrl = item['photos']?[0]?['photo_url'] ?? '';
    final imageUrl =
        photoUrl.isNotEmpty
            ? "$apiImagePrefix/$photoUrl"
            : 'https://via.placeholder.com/150';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => NewsDetailScreen(newsId: item['id']),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child:
                  authToken != null && photoUrl.isNotEmpty
                      ? Image(
                        image: CachedNetworkImageProvider(
                          imageUrl,
                          headers: {
                            'accept': 'application/json',
                            'Authorization': 'Bearer $authToken',
                          },
                        ),
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 180,
                            color: Colors.grey[300],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        },
                        errorBuilder:
                            (context, error, stackTrace) => Container(
                              height: 180,
                              color: Colors.grey[300],
                              child: const Icon(
                                Icons.image_not_supported,
                                size: 40,
                              ),
                            ),
                      )
                      : Container(
                        height: 180,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image_not_supported, size: 40),
                      ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'] ?? '',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        date,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.person, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        author,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
