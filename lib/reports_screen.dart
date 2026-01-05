import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _selectedPeriod = 'Günlük'; // Günlük, Haftalık, Aylık
  DateTime _selectedDate = DateTime.now();

  final List<String> _periods = ['Günlük', 'Haftalık', 'Aylık'];

  void _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<Map<String, dynamic>> _fetchReportData() async {
    final collection = FirebaseFirestore.instance.collection('cart_records');
    DateTime startDate;
    DateTime endDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);

    if (_selectedPeriod == 'Günlük') {
      startDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    } else if (_selectedPeriod == 'Haftalık') {
      startDate = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
      endDate = startDate.add(const Duration(days: 7, seconds: -1));
    } else {
      // Aylık
      startDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
      endDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 0, 23, 59, 59);
    }

    final snapshot = await collection
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    final docs = snapshot.docs;
    int totalRecords = docs.length;
    int completed = 0;
    int inProgress = 0;
    Map<String, int> statusCount = {};

    for (var doc in docs) {
      final data = doc.data();
      final status = data['status'] ?? 'Yaş İmalat';
      statusCount[status] = (statusCount[status] ?? 0) + 1;

      if (status == 'Pişti' || status == 'Sevkiyat') {
        completed++;
      } else if (status != 'Yaş İmalat') {
        inProgress++;
      }
    }

    return {
      'totalRecords': totalRecords,
      'completed': completed,
      'inProgress': inProgress,
      'statusCount': statusCount,
      'completionRate': totalRecords > 0 ? (completed / totalRecords * 100).toStringAsFixed(1) : '0',
    };
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Yaş İmalat':
        return Colors.green;
      case 'Kurutmaya Gitti':
        return Colors.orange;
      case 'Kurutma':
        return Colors.red;
      case 'Pişirmede':
        return Colors.amber;
      case 'Pişti':
        return Colors.blue;
      case 'Sevkiyat':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raporlar'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dönem seçimi
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rapor Dönemi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedPeriod,
                            items: _periods
                                .map((period) => DropdownMenuItem(
                                      value: period,
                                      child: Text(period),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedPeriod = value);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _selectDate,
                            icon: const Icon(Icons.calendar_today),
                            label: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Rapor verileri
              FutureBuilder<Map<String, dynamic>>(
                future: _fetchReportData(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Hata: ${snapshot.error}'));
                  }

                  final data = snapshot.data ?? {};
                  final totalRecords = data['totalRecords'] ?? 0;
                  final completed = data['completed'] ?? 0;
                  final inProgress = data['inProgress'] ?? 0;
                  final completionRate = data['completionRate'] ?? '0';
                  final statusCount = (data['statusCount'] ?? {}) as Map<String, int>;

                  return Column(
                    children: [
                      // Ana metrikler
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        children: [
                          _buildMetricCard(
                            title: 'Toplam Kayıt',
                            value: totalRecords.toString(),
                            icon: Icons.inventory,
                            color: Colors.blue,
                          ),
                          _buildMetricCard(
                            title: 'Tamamlanan',
                            value: completed.toString(),
                            icon: Icons.check_circle,
                            color: Colors.green,
                          ),
                          _buildMetricCard(
                            title: 'Devamında',
                            value: inProgress.toString(),
                            icon: Icons.hourglass_top,
                            color: Colors.orange,
                          ),
                          _buildMetricCard(
                            title: 'Tamamlanma %',
                            value: '$completionRate%',
                            icon: Icons.trending_up,
                            color: Colors.purple,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Durum dağılımı
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Durum Dağılımı',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 16),
                            statusCount.isEmpty
                                ? Center(
                                    child: Text(
                                      'Bu dönemde kayıt bulunmamaktadır',
                                      style: TextStyle(color: Colors.grey[500]),
                                    ),
                                  )
                                : Column(
                                    children: statusCount.entries.map((entry) {
                                      final percentage = totalRecords > 0
                                          ? ((entry.value / totalRecords) * 100).toStringAsFixed(1)
                                          : '0';

                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 12,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(entry.key),
                                                borderRadius: BorderRadius.circular(2),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                entry.key,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '${entry.value}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey[800],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            SizedBox(
                                              width: 60,
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(4),
                                                child: LinearProgressIndicator(
                                                  value: entry.value / totalRecords,
                                                  minHeight: 6,
                                                  backgroundColor: Colors.grey[200],
                                                  valueColor: AlwaysStoppedAnimation<Color>(
                                                    _getStatusColor(entry.key),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            SizedBox(
                                              width: 40,
                                              child: Text(
                                                '$percentage%',
                                                textAlign: TextAlign.right,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

