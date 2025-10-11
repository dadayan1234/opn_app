import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:opn_app/screens/finance_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  String? authToken;
  Map<String, dynamic>? summary;
  List<dynamic> transactions = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMoreData = true;
  int currentPage = 0;
  final int itemsPerPage = 15; // Menampilkan lebih banyak item per halaman
  final ScrollController _scrollController = ScrollController();

  static const String apiPrefix = 'https://beopn.pemudanambangan.site/api/v1';

  @override
  void initState() {
    super.initState();
    _getToken().then((_) {
      if (authToken != null) {
        _fetchData();
      }
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // Trigger lebih awal
      if (!isLoadingMore && hasMoreData) {
        _loadMoreTransactions();
      }
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

  Future<void> _fetchData() async {
    if (authToken == null) return;

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
      final summaryRes = await http.get(
        Uri.parse('$apiPrefix/finance/summary'),
        headers: headers,
      );
      final historyRes = await http.get(
        Uri.parse('$apiPrefix/finance/history?skip=0&limit=$itemsPerPage'),
        headers: headers,
      );

      if (summaryRes.statusCode == 200 && historyRes.statusCode == 200) {
        final summaryData = json.decode(summaryRes.body);
        final historyData = json.decode(historyRes.body);

        if (mounted) {
          setState(() {
            summary = summaryData;
            transactions = historyData['transactions'];
            currentPage = 0;
            hasMoreData = transactions.length == itemsPerPage;
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

  Future<void> _loadMoreTransactions() async {
    if (authToken == null || isLoadingMore) return;

    if (mounted) {
      setState(() {
        isLoadingMore = true;
      });
    }

    final headers = {
      'accept': 'application/json',
      'Authorization': 'Bearer $authToken',
    };

    try {
      final skip = (currentPage + 1) * itemsPerPage;
      final historyRes = await http.get(
        Uri.parse('$apiPrefix/finance/history?skip=$skip&limit=$itemsPerPage'),
        headers: headers,
      );

      if (historyRes.statusCode == 200) {
        final historyData = json.decode(historyRes.body);
        final newTransactions = historyData['transactions'] as List;

        if (mounted) {
          setState(() {
            transactions.addAll(newTransactions);
            currentPage++;
            hasMoreData = newTransactions.length == itemsPerPage;
          });
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error loading more transactions: $e');
    }

    if (mounted) {
      setState(() {
        isLoadingMore = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    await _fetchData();
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }

  Color _getAmountColor(String category) {
    return category.toLowerCase() == 'pemasukan'
        ? const Color(0xFF22C55E)
        : const Color(0xFFEF4444);
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd MMM yyyy', 'id_ID').format(date);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Keuangan Organisasi',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: Colors.deepPurple,
        child:
            isLoading
                ? const Center(
                  child: CircularProgressIndicator(color: Colors.deepPurple),
                )
                : CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    // Modern Summary Section
                    SliverToBoxAdapter(
                      child: Container(
                        color: Colors.deepPurple,
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildModernSummary(),
                      ),
                    ),

                    // Transaction History Header
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'Riwayat Transaksi',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    // Transaction Table Header
                    SliverAppBar(
                      pinned: true,
                      automaticallyImplyLeading: false,
                      backgroundColor: Colors.grey[50],
                      elevation: 0,
                      toolbarHeight: 50,
                      title: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 0),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                flex: 3,
                                child: Text(
                                  'Uraian',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black54,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                flex: 2,
                                child: Text(
                                  'Jenis',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black54,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                flex: 3,
                                child: Text(
                                  'Nominal / Saldo',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black54,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Transaction List
                    if (transactions.isEmpty)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 50),
                          child: Center(
                            child: Text(
                              "Belum ada riwayat transaksi.",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              _buildTransactionRow(transactions[index], index),
                          childCount: transactions.length,
                        ),
                      ),

                    // Loading and "No More Data" indicator
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child:
                              isLoadingMore
                                  ? const CircularProgressIndicator(
                                    color: Colors.deepPurple,
                                  )
                                  : (!hasMoreData && transactions.isNotEmpty
                                      ? const Text(
                                        'Akhir dari riwayat',
                                        style: TextStyle(color: Colors.grey),
                                      )
                                      : const SizedBox.shrink()),
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildModernSummary() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [Colors.deepPurple, Colors.deepPurple.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Saldo Saat Ini',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatCurrency(summary?['balance']?.toDouble() ?? 0),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white24),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white12,
                      child: Icon(
                        Icons.arrow_upward,
                        color: Colors.greenAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pemasukan',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatCurrency(
                            summary?['total_income']?.toDouble() ?? 0,
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white12,
                      child: Icon(
                        Icons.arrow_downward,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pengeluaran',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatCurrency(
                            summary?['total_expense']?.toDouble() ?? 0,
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionRow(dynamic transaction, int index) {
    final isEven = index % 2 == 0;
    final category = transaction['category'] ?? '';
    final amount =
        double.tryParse(transaction['amount']?.toString() ?? '0') ?? 0;
    final balanceAfter =
        double.tryParse(transaction['balance_after']?.toString() ?? '0') ?? 0;
    final date = _formatDate(transaction['date'] ?? '');

    String description = transaction['description'] ?? '';
    description = description.replaceAll(RegExp(r'<[^>]*>'), '');
    description = description.replaceAll(RegExp(r'\s+'), ' ').trim();

    return Material(
      color: isEven ? Colors.white : Colors.grey[50],
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => FinanceDetailScreen(
                    transactionId: transaction['id'],
                    authToken: authToken!,
                  ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      description.isNotEmpty
                          ? description
                          : 'Tidak ada deskripsi',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      date,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Text(
                  category,
                  style: TextStyle(
                    color: _getAmountColor(category),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatCurrency(amount),
                      style: TextStyle(
                        color: _getAmountColor(category),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatCurrency(balanceAfter),
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
