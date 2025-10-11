import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_html/flutter_html.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class FinanceDetailScreen extends StatefulWidget {
  final int transactionId;
  final String authToken;

  const FinanceDetailScreen({
    super.key,
    required this.transactionId,
    required this.authToken,
  });

  @override
  State<FinanceDetailScreen> createState() => _FinanceDetailScreenState();
}

class _FinanceDetailScreenState extends State<FinanceDetailScreen> {
  Map<String, dynamic>? transaction;
  bool isLoading = true;

  static const String apiPrefix = 'https://beopn.pemudanambangan.site/api/v1';
  static const String apiImagePrefix = 'https://beopn.pemudanambangan.site';

  @override
  void initState() {
    super.initState();
    _fetchTransactionDetail();
  }

  Future<void> _fetchTransactionDetail() async {
    setState(() {
      isLoading = true;
    });

    final headers = {
      'accept': 'application/json',
      'Authorization': 'Bearer ${widget.authToken}',
    };

    try {
      final response = await http.get(
        Uri.parse('$apiPrefix/finance/${widget.transactionId}'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        setState(() {
          transaction = json.decode(response.body);
        });
      } else {
        _showErrorDialog('Gagal memuat detail transaksi');
      }
    } catch (e) {
      print('Error fetching transaction detail: $e');
      _showErrorDialog('Terjadi kesalahan saat memuat data');
    }

    setState(() {
      isLoading = false;
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Error'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(); // Go back to previous screen
                },
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(date);
    } catch (e) {
      return dateString;
    }
  }

  String _formatDateTime(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Color _getAmountColor(String category) {
    return category.toLowerCase() == 'pemasukan' ? Colors.green : Colors.red;
  }

  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.7,
              child: Stack(
                children: [
                  Center(
                    child: InteractiveViewer(
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        httpHeaders: {
                          'accept': 'application/json',
                          'Authorization': 'Bearer ${widget.authToken}',
                        },
                        fit: BoxFit.contain,
                        placeholder:
                            (context, url) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                        errorWidget:
                            (context, url, error) => const Center(
                              child: Icon(
                                Icons.error,
                                color: Colors.white,
                                size: 50,
                              ),
                            ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Detail Transaksi',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : transaction == null
              ? const Center(
                child: Text(
                  'Data tidak ditemukan',
                  style: TextStyle(fontSize: 16),
                ),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Transaction Summary Card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: [
                              Colors.deepPurple.shade600,
                              Colors.deepPurple.shade800,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  transaction!['category'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Icon(
                                  transaction!['category']?.toLowerCase() ==
                                          'pemasukan'
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _formatCurrency(
                                double.tryParse(
                                      transaction!['amount']?.toString() ?? '0',
                                    ) ??
                                    0,
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatDate(transaction!['date'] ?? ''),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Balance Information
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Informasi Saldo',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Saldo Akhir:'),
                                Text(
                                  _formatCurrency(
                                    double.tryParse(
                                          transaction!['balance_after']
                                                  ?.toString() ??
                                              '0',
                                        ) ??
                                        0,
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Description Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Deskripsi',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Html(
                                data:
                                    transaction!['description'] ??
                                    'Tidak ada deskripsi',
                                style: {
                                  "body": Style(
                                    margin: Margins.zero,
                                    padding: HtmlPaddings.zero,
                                  ),
                                  "p": Style(margin: Margins.only(bottom: 8)),
                                  "ol": Style(
                                    margin: Margins.only(left: 12, bottom: 8),
                                  ),
                                  "ul": Style(
                                    margin: Margins.only(left: 12, bottom: 8),
                                  ),
                                  "li": Style(margin: Margins.only(bottom: 4)),
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Document/Receipt Card
                    if (transaction!['document_url'] != null)
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Nota/Dokumen',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: () {
                                  final imageUrl =
                                      '$apiImagePrefix${transaction!['document_url']}';
                                  _showImageDialog(imageUrl);
                                },
                                child: Container(
                                  width: double.infinity,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CachedNetworkImage(
                                      imageUrl:
                                          '$apiImagePrefix${transaction!['document_url']}',
                                      httpHeaders: {
                                        'accept': 'application/json',
                                        'Authorization':
                                            'Bearer ${widget.authToken}',
                                      },
                                      fit: BoxFit.cover,
                                      placeholder:
                                          (context, url) => Container(
                                            color: Colors.grey[200],
                                            child: const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                          ),
                                      errorWidget:
                                          (context, url, error) => Container(
                                            color: Colors.grey[200],
                                            child: const Center(
                                              child: Icon(
                                                Icons.image_not_supported,
                                                size: 50,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Tap untuk memperbesar',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Metadata Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Informasi Tambahan',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              'ID Transaksi',
                              transaction!['id']?.toString() ?? '-',
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              'Dibuat pada',
                              _formatDateTime(transaction!['created_at'] ?? ''),
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              'Diperbarui pada',
                              _formatDateTime(transaction!['updated_at'] ?? ''),
                            ),
                            if (transaction!['notes'] != null &&
                                transaction!['notes']
                                    .toString()
                                    .isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _buildInfoRow(
                                'Catatan',
                                transaction!['notes']?.toString() ?? '-',
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
        const Text(': '),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
