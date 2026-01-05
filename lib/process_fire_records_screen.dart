import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:ekosatsss/models/product_catalog.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' hide Column, Row, Border;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'package:universal_html/html.dart' as html;

class ProcessFireRecordsScreen extends StatefulWidget {
  const ProcessFireRecordsScreen({super.key});

  @override
  State<ProcessFireRecordsScreen> createState() => _ProcessFireRecordsScreenState();
}

class _ProcessFireRecordsScreenState extends State<ProcessFireRecordsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Stream<QuerySnapshot> _fireRecordsStream;

  bool _isReadOnlyUser(String email) {
    final lowerEmail = email.toLowerCase();
    return lowerEmail == 'mustafaakgul@ekos.com' || lowerEmail == 'senaaydın@ekos.com';
  }

  @override
  void initState() {
    super.initState();
    _fireRecordsStream = _firestore
        .collection('fire_records')
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  Future<void> _deleteRecord(String docId) async {
    try {
      await _firestore.collection('fire_records').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kayıt silindi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportToExcel() async {
    try {
      // Tüm fire kayıtlarını al
      final snapshot = await _firestore
          .collection('fire_records')
          .orderBy('created_at', descending: false)
          .get();

      if (snapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dışa aktarılacak kayıt yok')),
          );
        }
        return;
      }

      // Excel oluştur
      final Workbook workbook = Workbook();
      final Worksheet sheet = workbook.worksheets[0];
      sheet.name = 'Fire Kayıtları';

      // Başlıklar
      sheet.getRangeByIndex(1, 1).setText('Barkod');
      sheet.getRangeByIndex(1, 2).setText('Ürün Adı');
      sheet.getRangeByIndex(1, 3).setText('Fire Adedi');
      sheet.getRangeByIndex(1, 4).setText('Fire Ağırlığı (kg)');
      sheet.getRangeByIndex(1, 5).setText('Kullanıcı');
      sheet.getRangeByIndex(1, 6).setText('Zaman');

      // Başlık stilini ayarla
      final Style headerStyle = workbook.styles.add('HeaderStyle');
      headerStyle.bold = true;
      headerStyle.hAlign = HAlignType.center;
      headerStyle.vAlign = VAlignType.center;
      headerStyle.borders.all.lineStyle = LineStyle.thin;

      for (int i = 1; i <= 6; i++) {
        sheet.getRangeByIndex(1, i).cellStyle = headerStyle;
      }

      // Verileri ekle
      int row = 2;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final productName = data['product_name'] ?? '';
        final fireCount = data['fire_count'] ?? 0;
        final weight = ProductCatalog.weightFor(productName);
        final totalWeight = weight * fireCount;

        sheet.getRangeByIndex(row, 1).setText(data['barcode'] ?? '');
        sheet.getRangeByIndex(row, 2).setText(productName);
        sheet.getRangeByIndex(row, 3).setNumber(fireCount.toDouble());
        sheet.getRangeByIndex(row, 4).setNumber(totalWeight);
        sheet.getRangeByIndex(row, 5).setText(data['user_email'] ?? '');
        sheet.getRangeByIndex(row, 6).setText(data['timestamp'] ?? '');

        // Fire ağırlığı sütununu kırmızı yap
        final Style redStyle = workbook.styles.add('RedStyle$row');
        redStyle.backColor = '#FFE6E6';
        redStyle.borders.all.lineStyle = LineStyle.thin;
        sheet.getRangeByIndex(row, 4).cellStyle = redStyle;

        row++;
      }

      // Sütun genişliklerini ayarla
      sheet.getRangeByIndex(1, 1, row - 1, 1).columnWidth = 12;
      sheet.getRangeByIndex(1, 2, row - 1, 2).columnWidth = 30;
      sheet.getRangeByIndex(1, 3, row - 1, 3).columnWidth = 12;
      sheet.getRangeByIndex(1, 4, row - 1, 4).columnWidth = 18;
      sheet.getRangeByIndex(1, 5, row - 1, 5).columnWidth = 25;
      sheet.getRangeByIndex(1, 6, row - 1, 6).columnWidth = 20;

      // Excel dosyasını kaydet
      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      final now = DateTime.now();
      final fileName = 'Fire_Kayitlari_${DateFormat('yyyyMMdd_HHmmss').format(now)}.xlsx';

      if (kIsWeb) {
        // Web için
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        // Mobil/Desktop için
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/$fileName';
        final file = File(path);
        await file.writeAsBytes(bytes, flush: true);

        // Share disabled for web compatibility
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel dosyası oluşturuldu: $fileName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proses Fire Kayıtları'),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: "Excel'e Aktar",
            onPressed: _exportToExcel,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _fireRecordsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Hata: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('Kayıt bulunamadı'),
            );
          }

          final records = snapshot.data!.docs;

          return ListView.builder(
            itemCount: records.length,
            itemBuilder: (context, index) {
              final doc = records[index];
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Barkod: ${data['barcode'] ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Ürün: ${data['product_name'] ?? 'N/A'}', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fire Sayısı: ${data['fire_count'] ?? 0}'),
                      Text('Miktar: ${data['quantity'] ?? 'N/A'}'),
                      Text('Kullanıcı: ${data['user_email'] ?? 'N/A'}'),
                      Text('Zaman: ${data['timestamp'] ?? 'N/A'}'),
                    ],
                  ),
                  trailing: _isReadOnlyUser(FirebaseAuth.instance.currentUser?.email ?? '') ? null : IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Sil'),
                          content: const Text('Bu kaydı silmek istediğinize emin misiniz?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('İptal'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _deleteRecord(doc.id);
                              },
                              child: const Text('Sil'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}






