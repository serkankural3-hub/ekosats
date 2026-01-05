import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;
import 'package:ekosatsss/models/product_catalog.dart';

class FinalControlRecordsScreen extends StatefulWidget {
  final String userEmail;

  const FinalControlRecordsScreen({super.key, required this.userEmail});

  @override
  State<FinalControlRecordsScreen> createState() => _FinalControlRecordsScreenState();
}

class _FinalControlRecordsScreenState extends State<FinalControlRecordsScreen> {
  bool _isExporting = false;

  bool _isAdminUser(String email) {
    final lowerEmail = email.toLowerCase();
    return lowerEmail == 'admin@ekos.com' ||
           lowerEmail == 'oytunsidal@ekos.com' ||
           lowerEmail == 'keremsidal@ekos.com' ||
           lowerEmail == 'sefaafyon@ekos.com' ||
           lowerEmail == 'ahmetkuscu@ekos.com' ||
           lowerEmail == 'mustafaakgul@ekos.com' ||
           lowerEmail == 'senaaydın@ekos.com';
  }

  bool _isReadOnlyUser(String email) {
    final lowerEmail = email.toLowerCase();
    return lowerEmail == 'mustafaakgul@ekos.com' || lowerEmail == 'senaaydın@ekos.com';
  }

  Future<void> _deleteRecord(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('final_control_records').doc(docId).delete();
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

  Future<void> _exportToExcel(List<DocumentSnapshot> records) async {
    setState(() {
      _isExporting = true;
    });

    try {
      final xlsio.Workbook workbook = xlsio.Workbook();
      final xlsio.Worksheet sheet = workbook.worksheets[0];
      
      sheet.name = 'Final Kontrol';

      // Header
      final headers = [
        'Sıra', 'Saat', 'Tarih', 'Ürün Adı', 'Toplam Adet', 'Toplam Ağırlık (kg)', 'Fire Adedi', 'Fire Ağırlık (kg)',
        'Kırık', 'Eğri', 'Renk', 'Pişme', 'Beyaz', 'Kabarma', 'Ölçü',
        'Palet No', 'Onay',
        'N1 Ses', 'N1 En', 'N1 Boy', 'N1 Kalınlık',
        'N2 Ses', 'N2 En', 'N2 Boy', 'N2 Kalınlık',
        'N3 Ses', 'N3 En', 'N3 Boy', 'N3 Kalınlık',
        'Onay Num1', 'Onay Num2', 'Onay Num3',
        'Kaydeden'
      ];

      for (int i = 0; i < headers.length; i++) {
        sheet.getRangeByIndex(1, i + 1).setText(headers[i]);
        sheet.getRangeByIndex(1, i + 1).cellStyle.bold = true;
        // Fire Ağırlık (8. kolon) kırmızı, diğerleri turuncu
        if (i == 7) {
          sheet.getRangeByIndex(1, i + 1).cellStyle.backColor = '#FF0000';
          sheet.getRangeByIndex(1, i + 1).cellStyle.fontColor = '#FFFFFF';
        } else {
          sheet.getRangeByIndex(1, i + 1).cellStyle.backColor = '#FFA500';
        }
      }

      // Data
      for (int i = 0; i < records.length; i++) {
        final data = records[i].data() as Map<String, dynamic>;
        final row = i + 2;

        sheet.getRangeByIndex(row, 1).setText(data['sira'] ?? '');
        sheet.getRangeByIndex(row, 2).setText(data['saat'] ?? '');
        sheet.getRangeByIndex(row, 3).setText(data['tarih'] ?? '');
        sheet.getRangeByIndex(row, 4).setText(data['urunAdi'] ?? '');
        sheet.getRangeByIndex(row, 5).setText(data['toplamAdet'] ?? '');
        
        // Toplam Ağırlık hesaplama
        final productName = data['urunAdi'] as String?;
        final quantity = int.tryParse(data['toplamAdet']?.toString() ?? '0') ?? 0;
        final totalWeight = ProductCatalog.totalWeight(productName, quantity);
        sheet.getRangeByIndex(row, 6).setNumber(totalWeight);
        
        sheet.getRangeByIndex(row, 7).setText(data['fireAdedi'] ?? '');
        
        // Fire Ağırlık hesaplama (kırmızı)
        final fireQuantity = int.tryParse(data['fireAdedi']?.toString() ?? '0') ?? 0;
        final fireWeight = ProductCatalog.totalWeight(productName, fireQuantity);
        final fireWeightCell = sheet.getRangeByIndex(row, 8);
        fireWeightCell.setNumber(fireWeight);
        fireWeightCell.cellStyle.backColor = '#FFE6E6';
        fireWeightCell.cellStyle.fontColor = '#FF0000';
        
        sheet.getRangeByIndex(row, 9).setText(data['kirik'] ?? '');
        sheet.getRangeByIndex(row, 10).setText(data['egri'] ?? '');
        sheet.getRangeByIndex(row, 11).setText(data['renk'] ?? '');
        sheet.getRangeByIndex(row, 12).setText(data['pisme'] ?? '');
        sheet.getRangeByIndex(row, 13).setText(data['boyaz'] ?? '');
        sheet.getRangeByIndex(row, 14).setText(data['kabarma'] ?? '');
        sheet.getRangeByIndex(row, 15).setText(data['olcu'] ?? '');
        sheet.getRangeByIndex(row, 16).setText(data['paletNo'] ?? '');
        sheet.getRangeByIndex(row, 17).setText(data['onay'] ?? '');

        // Numune 1
        if (data['numune1'] != null) {
          sheet.getRangeByIndex(row, 18).setText(data['numune1']['sesKontrol'] ?? '');
          sheet.getRangeByIndex(row, 19).setText(data['numune1']['en'] ?? '');
          sheet.getRangeByIndex(row, 20).setText(data['numune1']['boy'] ?? '');
          sheet.getRangeByIndex(row, 21).setText(data['numune1']['kalinlik'] ?? '');
        }

        // Numune 2
        if (data['numune2'] != null) {
          sheet.getRangeByIndex(row, 22).setText(data['numune2']['sesKontrol'] ?? '');
          sheet.getRangeByIndex(row, 23).setText(data['numune2']['en'] ?? '');
          sheet.getRangeByIndex(row, 24).setText(data['numune2']['boy'] ?? '');
          sheet.getRangeByIndex(row, 25).setText(data['numune2']['kalinlik'] ?? '');
        }

        // Numune 3
        if (data['numune3'] != null) {
          sheet.getRangeByIndex(row, 26).setText(data['numune3']['sesKontrol'] ?? '');
          sheet.getRangeByIndex(row, 27).setText(data['numune3']['en'] ?? '');
          sheet.getRangeByIndex(row, 28).setText(data['numune3']['boy'] ?? '');
          sheet.getRangeByIndex(row, 29).setText(data['numune3']['kalinlik'] ?? '');
        }

        // Onay Numaraları
        if (data['onayNumaralar'] != null) {
          sheet.getRangeByIndex(row, 30).setText(data['onayNumaralar']['num1'] ?? '');
          sheet.getRangeByIndex(row, 31).setText(data['onayNumaralar']['num2'] ?? '');
          sheet.getRangeByIndex(row, 32).setText(data['onayNumaralar']['num3'] ?? '');
        }

        sheet.getRangeByIndex(row, 33).setText(data['createdBy'] ?? '');
      }

      // Auto-fit columns
      for (int i = 1; i <= headers.length; i++) {
        sheet.getRangeByIndex(1, i).columnWidth = 12.0;
      }

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      final String fileName = 'Final_Kontrol_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';

      if (kIsWeb) {
        // Web: Blob ile indirme
        final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..style.display = 'none';
        html.document.body?.append(anchor);
        anchor.click();
        anchor.remove();
        html.Url.revokeObjectUrl(url);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Excel dosyası indirildi: $fileName'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Desktop/Mobile: dosyaya yaz
        String path;
        if (Platform.isWindows) {
          final String? userProfile = Platform.environment['USERPROFILE'];
          if (userProfile != null) {
            final downloadsDir = Directory('$userProfile\\Downloads');
            if (!await downloadsDir.exists()) {
              await downloadsDir.create(recursive: true);
            }
            path = '${downloadsDir.path}\\$fileName';
          } else {
            // Fallback
            final Directory directory = await getApplicationDocumentsDirectory();
            path = '${directory.path}\\$fileName';
          }
        } else {
          final Directory directory = await getApplicationDocumentsDirectory();
          path = '${directory.path}/$fileName';
        }
        
        final File file = File(path);
        await file.writeAsBytes(bytes);

        if (mounted) {
          if (Platform.isWindows) {
            // Windows'ta dosya yolunu göster
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Excel dosyası kaydedildi:\n$path'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'Klasörü Aç',
                  textColor: Colors.white,
                  onPressed: () async {
                    final directory = file.parent.path;
                    await Process.run('explorer', [directory]);
                  },
                ),
              ),
            );
          } else {
            await Share.shareXFiles([XFile(path)], text: 'Final Kontrol Kayıtları');
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Excel dosyası oluşturuldu: $fileName'),
              backgroundColor: Colors.green,
            ),
          );
        }
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
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Final Kontrol Kayıtları'),
        backgroundColor: Colors.orange,
        actions: [
          // Admin kullanıcıları Excel'e aktarabilir
          if (_isAdminUser(widget.userEmail))
            if (!_isExporting)
              IconButton(
                icon: const Icon(Icons.file_download),
                tooltip: 'Excel\'e Aktar',
                onPressed: () async {
                  final snapshot = await FirebaseFirestore.instance
                      .collection('final_control_records')
                      .orderBy('createdAt', descending: true)
                      .get();
                  
                  if (snapshot.docs.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Aktarılacak kayıt yok'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                  
                  await _exportToExcel(snapshot.docs);
                },
              )
          else
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('final_control_records')
            .orderBy('createdAt', descending: true)
            .snapshots(),
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Henüz kayıt yok',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 3,
                child: InkWell(
                  onTap: () => _showDetailDialog(context, data),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Seri No: ${data['sira'] ?? 'N/A'}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  data['tarih'] ?? 'N/A',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                if (!_isReadOnlyUser(widget.userEmail))
                                  IconButton(
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
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(data['saat'] ?? 'N/A'),
                            const SizedBox(width: 16),
                            const Icon(Icons.category, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(child: Text('Ürün: ${data['urunAdi'] ?? 'N/A'}', overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.inventory, size: 16, color: Colors.green),
                            const SizedBox(width: 4),
                            Text('Toplam Adet: ${data['toplamAdet'] ?? 'N/A'}'),
                            const SizedBox(width: 16),
                            const Icon(Icons.warning, size: 16, color: Colors.red),
                            const SizedBox(width: 4),
                            Text('Fire: ${data['fireAdedi'] ?? 'N/A'}'),
                          ],
                        ),
                        if (data['createdBy'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Kaydeden: ${data['createdBy']}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showDetailDialog(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sıra No: ${data['sira'] ?? 'N/A'}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailSection('Genel Bilgiler', [
                'Sıra: ${data['sira'] ?? 'N/A'}',
                'Saat: ${data['saat'] ?? 'N/A'}',
                'Tarih: ${data['tarih'] ?? 'N/A'}',
                'Ürün Adı: ${data['urunAdi'] ?? 'N/A'}',
                'Toplam Adet: ${data['toplamAdet'] ?? 'N/A'}',
                'Fire Adedi: ${data['fireAdedi'] ?? 'N/A'}',
              ]),
              
              _buildDetailSection('Kusur Tipleri', [
                'Kırık: ${data['kirik'] ?? 'N/A'}',
                'Eğri: ${data['egri'] ?? 'N/A'}',
                'Renk: ${data['renk'] ?? 'N/A'}',
                'Pişme: ${data['pisme'] ?? 'N/A'}',
                'Beyaz: ${data['boyaz'] ?? 'N/A'}',
                'Kabarma: ${data['kabarma'] ?? 'N/A'}',
                'Ölçü: ${data['olcu'] ?? 'N/A'}',
              ]),
              
              _buildDetailSection('Palet ve Onay', [
                'Palet No: ${data['paletNo'] ?? 'N/A'}',
                'Onay: ${data['onay'] ?? 'N/A'}',
              ]),
              
              if (data['numune1'] != null)
                _buildDetailSection('Numune 1', [
                  'Ses Kontrol: ${data['numune1']['sesKontrol'] ?? 'N/A'}',
                  'En: ${data['numune1']['en'] ?? 'N/A'}',
                  'Boy: ${data['numune1']['boy'] ?? 'N/A'}',
                  'Kalınlık: ${data['numune1']['kalinlik'] ?? 'N/A'}',
                ]),
              
              if (data['numune2'] != null)
                _buildDetailSection('Numune 2', [
                  'Ses Kontrol: ${data['numune2']['sesKontrol'] ?? 'N/A'}',
                  'En: ${data['numune2']['en'] ?? 'N/A'}',
                  'Boy: ${data['numune2']['boy'] ?? 'N/A'}',
                  'Kalınlık: ${data['numune2']['kalinlik'] ?? 'N/A'}',
                ]),
              
              if (data['numune3'] != null)
                _buildDetailSection('Numune 3', [
                  'Ses Kontrol: ${data['numune3']['sesKontrol'] ?? 'N/A'}',
                  'En: ${data['numune3']['en'] ?? 'N/A'}',
                  'Boy: ${data['numune3']['boy'] ?? 'N/A'}',
                  'Kalınlık: ${data['numune3']['kalinlik'] ?? 'N/A'}',
                ]),
              
              if (data['onayNumaralar'] != null)
                _buildDetailSection('Onay Numaraları', [
                  'Num 1: ${data['onayNumaralar']['num1'] ?? 'N/A'}',
                  'Num 2: ${data['onayNumaralar']['num2'] ?? 'N/A'}',
                  'Num 3: ${data['onayNumaralar']['num3'] ?? 'N/A'}',
                ]),
              
              if (data['createdBy'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    'Kaydeden: ${data['createdBy']}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 4),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Text(
                  item,
                  style: const TextStyle(fontSize: 13),
                ),
              )),
        ],
      ),
    );
  }
}
