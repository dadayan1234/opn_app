import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'finance_detail_screen.dart';

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
  final int itemsPerPage = 10;
  final ScrollController _scrollController = ScrollController();

  static const String apiPrefix = 'https://beopn.penaku.site/api/v1';

  @override
  void initState() {
    super.initState();
    _getToken().then((_) => _fetchData());
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      if (!isLoadingMore && hasMoreData) {
        _loadMoreTransactions();
      }
    }
  }

  Future<void> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      authToken = prefs.getString('access_token');
    });
  }

  Future<void> _fetchData() async {
    if (authToken == null) return;

    setState(() {
      isLoading = true;
    });

    final headers = {
      'accept': 'application/json',
      'Authorization': 'Bearer $authToken',
    };

    try {
      // Fetch summary
      final summaryRes = await http.get(
        Uri.parse('$apiPrefix/finance/summary'),
        headers: headers,
      );

      // Fetch initial transactions
      final historyRes = await http.get(
        Uri.parse('$apiPrefix/finance/history?skip=0&limit=$itemsPerPage'),
        headers: headers,
      );

      if (summaryRes.statusCode == 200 && historyRes.statusCode == 200) {
        final summaryData = json.decode(summaryRes.body);
        final historyData = json.decode(historyRes.body);

        setState(() {
          summary = summaryData;
          transactions = historyData['transactions'];
          currentPage = 0;
          hasMoreData = transactions.length == itemsPerPage;
        });
      }
    } catch (e) {
      print('Error fetching data: $e');
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _loadMoreTransactions() async {
    if (authToken == null || isLoadingMore) return;

    setState(() {
      isLoadingMore = true;
    });

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

        setState(() {
          transactions.addAll(newTransactions);
          currentPage++;
          hasMoreData = newTransactions.length == itemsPerPage;
        });
      }
    } catch (e) {
      print('Error loading more transactions: $e');
    }

    setState(() {
      isLoadingMore = false;
    });
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
    return category.toLowerCase() == 'pemasukan' ? Colors.green : Colors.red;
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy').format(date);
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
          'Keuangan',
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
                ? const Center(child: CircularProgressIndicator())
                : CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    // Summary Section
                    SliverToBoxAdapter(
                      child: Container(
                        color: Colors.deepPurple,
                        child: Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Keuangan Organisasi',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildSummaryCard(
                                      'Pemasukan',
                                      summary?['total_income']?.toDouble() ?? 0,
                                      Colors.green,
                                      Icons.arrow_upward,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildSummaryCard(
                                      'Pengeluaran',
                                      summary?['total_expense']?.toDouble() ??
                                          0,
                                      Colors.red,
                                      Icons.arrow_downward,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Center(
                                child: _buildBalanceCard(
                                  'Saldo',
                                  summary?['balance']?.toDouble() ?? 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Transaction History Header
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16),
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
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Uraian',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Jenis',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Nominal',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Saldo',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Transaction List
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index < transactions.length) {
                            final transaction = transactions[index];
                            return _buildTransactionRow(transaction, index);
                          } else if (isLoadingMore) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          } else if (!hasMoreData && transactions.isNotEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: Text(
                                  'Tidak ada data lagi',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            );
                          }
                          return null;
                        },
                        childCount:
                            transactions.length +
                            (isLoadingMore ? 1 : 0) +
                            (!hasMoreData && transactions.isNotEmpty ? 1 : 0),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    double amount,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatCurrency(amount),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(String title, double amount) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.account_balance_wallet, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatCurrency(amount),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

    // Get description text (strip HTML tags for display)
    String description = transaction['description'] ?? '';
    description = description.replaceAll(RegExp(r'<[^>]*>'), '');
    description = description.replaceAll(RegExp(r'\s+'), ' ').trim();

    return GestureDetector(
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
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color:
              isEven
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
          border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      description.isNotEmpty
                          ? description
                          : 'Tidak ada deskripsi',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      maxLines: 2,
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
              Expanded(
                child: Text(
                  category,
                  style: TextStyle(
                    color: _getAmountColor(category),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: Text(
                  _formatCurrency(amount),
                  style: TextStyle(
                    color: _getAmountColor(category),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: Text(
                  _formatCurrency(balanceAfter),
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
