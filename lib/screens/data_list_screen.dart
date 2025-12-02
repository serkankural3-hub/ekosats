import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:ekosats/providers/vehicle_provider.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';

class DataListScreen extends StatefulWidget {
  const DataListScreen({super.key});

  @override
  State<DataListScreen> createState() => _DataListScreenState();
}

class _DataListScreenState extends State<DataListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<VehicleProvider>().loadAllRecords();
    });
  }

  Future<void> _exportToCSV() async {
    final provider = context.read<VehicleProvider>();
    final records = provider.records;

    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dışa aktarılacak veri yok!')),
      );
      return;
    }

    try {
      // CSV başlığı
      final List<List<dynamic>> csv = [
        [
          'ID',
          'Araç Barkodu',
          'Araç Çeşidi',
          'Ürün Çeşidi',
          'Tarih-Zaman',
          'Durum',
          'Ürün Adeti',
          'İş Emri',
          'Açıklama',
          'Kayıt Tarihi',
        ]
      ];

      // Veriler
      for (var record in records) {
        csv.add([
          record.id,
          record.vehicleBarcode,
          record.vehicleType,
          record.productType,
          DateFormat('dd/MM/yyyy HH:mm').format(record.dateTime),
          record.status,
          record.productQuantity,
          record.workOrder,
          record.description,
          DateFormat('dd/MM/yyyy HH:mm').format(record.createdAt),
        ]);
      }

      // CSV stringi oluştur
      final csvString = const ListToCsvConverter().convert(csv);

      // Dosya kaydet
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'ekosats_data_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final file = File('${directory.path}/$fileName');

      await file.writeAsString(csvString);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dosya kaydedildi: ${file.path}'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    }
  }

  Future<void> _deleteRecord(int id) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kaydı Sil'),
        content: const Text('Bu kaydı silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              await context.read<VehicleProvider>().deleteRecord(id);
              if (!mounted) return;
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kayıt silindi')),
              );
            },
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kayıtlı Veriler'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportToCSV,
            tooltip: 'CSV olarak indir',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<VehicleProvider>().loadAllRecords();
            },
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: Consumer<VehicleProvider>(
        builder: (context, provider, _) {
          if (provider.records.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Henüz veri kaydı yok',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: provider.records.length,
            itemBuilder: (context, index) {
              final record = provider.records[index];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: ExpansionTile(
                  title: Text(
                    '${record.vehicleBarcode} - ${record.productType}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(record.dateTime),
                  ),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        child: const Text('Sil'),
                        onTap: () => _deleteRecord(record.id!),
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('Araç Barkodu', record.vehicleBarcode),
                          _buildInfoRow('Araç Çeşidi', record.vehicleType),
                          _buildInfoRow('Ürün Çeşidi', record.productType),
                          _buildInfoRow(
                            'Tarih-Zaman',
                            DateFormat('dd/MM/yyyy HH:mm').format(record.dateTime),
                          ),
                          _buildInfoRow('Durum', record.status),
                          _buildInfoRow(
                            'Ürün Adeti',
                            '${record.productQuantity}',
                          ),
                          _buildInfoRow('İş Emri', record.workOrder),
                          if (record.description.isNotEmpty)
                            _buildInfoRow('Açıklama', record.description),
                          _buildInfoRow(
                            'Kayıt Tarihi',
                            DateFormat('dd/MM/yyyy HH:mm')
                                .format(record.createdAt),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
