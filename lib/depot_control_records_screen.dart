import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:ekosatsss/models/product_catalog.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' hide Column, Row, Border;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;

class DepotControlRecordsScreen extends StatefulWidget {
  const DepotControlRecordsScreen({super.key});

  @override
  State<DepotControlRecordsScreen> createState() => _DepotControlRecordsScreenState();
}

class _DepotControlRecordsScreenState extends State<DepotControlRecordsScreen> {
  String _searchQuery = '';

  bool _isReadOnlyUser(String email) {
    final lowerEmail = email.toLowerCase();
    return lowerEmail == 'mustafaakgul@ekos.com' || lowerEmail == 'senaaydın@ekos.com';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Depo Kontrol Kayıtları'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: "Excel'e Aktar",
            onPressed: _exportToExcel,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Ürün adı, palet no veya kişi ara...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('depot_control_records')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Henüz depo kontrol kaydı yok',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          var records = snapshot.data!.docs;

          // Arama filtresi
          if (_searchQuery.isNotEmpty) {
            records = records.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final productName = (data['productName'] ?? '').toString().toLowerCase();
              final userEmail = (data['userEmail'] ?? '').toString().toLowerCase();
              
              // Palet bilgilerinde ara
              final palets = data['palets'] as List<dynamic>? ?? [];
              final paletMatch = palets.any((palet) {
                final paletNo = (palet['paletNo'] ?? '').toString().toLowerCase();
                final paletProduct = (palet['productName'] ?? '').toString().toLowerCase();
                final personName = (palet['personName'] ?? '').toString().toLowerCase();
                return paletNo.contains(_searchQuery) ||
                    paletProduct.contains(_searchQuery) ||
                    personName.contains(_searchQuery);
              });
              
              return productName.contains(_searchQuery) ||
                  userEmail.contains(_searchQuery) ||
                  paletMatch;
            }).toList();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: records.length,
            itemBuilder: (context, index) {
              final doc = records[index];
              final data = doc.data() as Map<String, dynamic>;
              return _buildRecordCard(doc.id, data);
            },
          );
        },
      ),
    );
  }

  Future<void> _exportToExcel() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('depot_control_records')
          .orderBy('createdAt', descending: false)
          .get();

      if (snapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dışa aktarılacak kayıt yok')),
          );
        }
        return;
      }

      final Workbook workbook = Workbook();
      final Worksheet sheet = workbook.worksheets[0];
      sheet.name = 'Depo Kontrol Kayıtları';

      // Başlıklar
      sheet.getRangeByIndex(1, 1).setText('Ürün Adı');
      sheet.getRangeByIndex(1, 2).setText('Renk');
      sheet.getRangeByIndex(1, 3).setText('Palet Sayısı');
      sheet.getRangeByIndex(1, 4).setText('Toplam Adet');
      sheet.getRangeByIndex(1, 5).setText('Toplam Ağırlık (kg)');
      sheet.getRangeByIndex(1, 6).setText('Fire Adedi');
      sheet.getRangeByIndex(1, 7).setText('Fire Ağırlığı (kg)');
      sheet.getRangeByIndex(1, 8).setText('Giren Palet No');
      sheet.getRangeByIndex(1, 9).setText('Çıkan Palet No');
      sheet.getRangeByIndex(1, 10).setText('Kullanıcı');
      sheet.getRangeByIndex(1, 11).setText('Tarih');

      final Style headerStyle = workbook.styles.add('HeaderStyle');
      headerStyle.bold = true;
      headerStyle.hAlign = HAlignType.center;
      headerStyle.vAlign = VAlignType.center;
      headerStyle.borders.all.lineStyle = LineStyle.thin;
      for (int i = 1; i <= 11; i++) {
        sheet.getRangeByIndex(1, i).cellStyle = headerStyle;
      }

      int row = 2;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final palets = data['palets'] as List<dynamic>? ?? [];
        
        final totalCount = palets.fold<int>(0, (sum, p) => sum + (p['totalCount'] as int? ?? 0));
        
        final totalWeight = palets.fold<double>(0.0, (sum, p) {
          final pname = (p as Map<String, dynamic>)['productName'] ?? '';
          final weight = ProductCatalog.weightFor(pname);
          final tcount = (p['totalCount'] as int? ?? 0);
          return sum + weight * tcount;
        });
        
        final totalFire = palets.fold<int>(0, (sum, p) => sum + (p['fireCount'] as int? ?? 0));
        
        final totalFireWeight = palets.fold<double>(0.0, (sum, p) {
          final pname = (p as Map<String, dynamic>)['productName'] ?? '';
          final weight = ProductCatalog.weightFor(pname);
          final f = (p['fireCount'] as int? ?? 0);
          return sum + weight * f;
        });

        sheet.getRangeByIndex(row, 1).setText(data['productName'] ?? '');
        sheet.getRangeByIndex(row, 2).setText(data['productColor'] ?? '');
        sheet.getRangeByIndex(row, 3).setNumber(palets.length.toDouble());
        sheet.getRangeByIndex(row, 4).setNumber(totalCount.toDouble());
        sheet.getRangeByIndex(row, 5).setNumber(totalWeight);
        sheet.getRangeByIndex(row, 6).setNumber(totalFire.toDouble());
        sheet.getRangeByIndex(row, 7).setNumber(totalFireWeight);
        
        // Giren palet nolarını virgülle ayırarak göster
        final entryPaletNos = palets.map((p) => (p as Map<String, dynamic>)['entryPaletNo'] ?? '').where((no) => no.isNotEmpty).toList().join(', ');
        sheet.getRangeByIndex(row, 8).setText(entryPaletNos);
        
        // Çıkan palet no
        sheet.getRangeByIndex(row, 9).setText(data['exitPaletNo'] ?? '');
        
        sheet.getRangeByIndex(row, 10).setText(data['userEmail'] ?? '');

        final ts = data['createdAt'] as Timestamp?;
        final dateStr = ts != null ? DateFormat('dd/MM/yyyy HH:mm').format(ts.toDate()) : '';
        sheet.getRangeByIndex(row, 11).setText(dateStr);

        // Fire alanlarını kırmızı tonla vurgula
        final Style redStyle1 = workbook.styles.add('RedCount$row');
        redStyle1.backColor = '#FFE6E6';
        redStyle1.borders.all.lineStyle = LineStyle.thin;
        sheet.getRangeByIndex(row, 6).cellStyle = redStyle1;

        final Style redStyle2 = workbook.styles.add('RedWeight$row');
        redStyle2.backColor = '#FFE6E6';
        redStyle2.borders.all.lineStyle = LineStyle.thin;
        sheet.getRangeByIndex(row, 7).cellStyle = redStyle2;

        row++;
      }

      // Sütun genişlikleri
      sheet.getRangeByIndex(1, 1, row - 1, 1).columnWidth = 28;
      sheet.getRangeByIndex(1, 2, row - 1, 2).columnWidth = 16;
      sheet.getRangeByIndex(1, 3, row - 1, 3).columnWidth = 14;
      sheet.getRangeByIndex(1, 4, row - 1, 4).columnWidth = 14;
      sheet.getRangeByIndex(1, 5, row - 1, 5).columnWidth = 18;
      sheet.getRangeByIndex(1, 6, row - 1, 6).columnWidth = 20;
      sheet.getRangeByIndex(1, 7, row - 1, 7).columnWidth = 24;
      sheet.getRangeByIndex(1, 8, row - 1, 8).columnWidth = 20;
      sheet.getRangeByIndex(1, 9, row - 1, 9).columnWidth = 20;
      sheet.getRangeByIndex(1, 10, row - 1, 10).columnWidth = 24;
      sheet.getRangeByIndex(1, 11, row - 1, 11).columnWidth = 20;

      final bytes = workbook.saveAsStream();
      workbook.dispose();

      final fileName = 'Depo_Kontrol_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/$fileName';
        final file = File(path);
        await file.writeAsBytes(bytes, flush: true);
        await Share.shareXFiles([XFile(path)], text: 'Depo Kontrol Excel Raporu');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel dosyası oluşturuldu: $fileName'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildRecordCard(String docId, Map<String, dynamic> data) {
    final timestamp = data['createdAt'] as Timestamp?;
    final dateStr = timestamp != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate())
        : 'Tarih yok';
    
    final palets = data['palets'] as List<dynamic>? ?? [];
    final totalPaletCount = palets.length;
    final totalFire = palets.fold<int>(0, (sum, palet) {
      return sum + (palet['fireCount'] as int? ?? 0);
    });

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: const Icon(Icons.inventory, color: Colors.blue),
        ),
        title: Text(
          data['productName'] ?? 'Ürün Adı Yok',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(data['userEmail'] ?? ''),
              ],
            ),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(dateStr),
              ],
            ),
            Row(
              children: [
                Icon(Icons.inventory_2, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text('$totalPaletCount Palet • $totalFire Toplam Fire'),
              ],
            ),
          ],
        ),
        trailing: _isReadOnlyUser(FirebaseAuth.instance.currentUser?.email ?? '') 
          ? null 
          : IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _deleteRecord(docId),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Makine ayar bilgileri
                _buildInfoSection('Makine Ayar Bilgileri', [
                  _buildInfoRow('Boy', data['size']),
                  _buildInfoRow('Giriş Bandı Hızı', data['entryBandSpeed']),
                  _buildInfoRow('Bant Hızı', data['bandSpeed']),
                  _buildInfoRow('Gönye Zamanı', data['miterTime']),
                  _buildInfoRow('Baskı Zamanı', data['printTime']),
                ]),
                
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                
                // Palet detayları
                const Text(
                  'Palet Detayları',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                
                ...palets.asMap().entries.map((entry) {
                  final index = entry.key;
                  final palet = entry.value as Map<String, dynamic>;
                  return _buildPaletDetail(index + 1, palet);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? '-',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaletDetail(int index, Map<String, dynamic> palet) {
    return Card(
      color: Colors.grey.shade50,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.yellow.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Palet $index - ${palet['entryPaletNo'] ?? 'No Yok'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                Text(
                  '${palet['paletCount'] ?? 0} Adet',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            _buildInfoRow('Ürün', palet['productName']),
            _buildInfoRow('Toplam Adet', palet['totalCount']),
            _buildInfoRow('Fire Adet', palet['fireCount']),
            _buildInfoRow('Yapan Kişi', palet['personName']),
            
            const Divider(),
            
            const Text(
              'Hata Dağılımı:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _buildDefectChip('Kırık', palet['kirik']),
                _buildDefectChip('Çatlak', palet['catlak']),
                _buildDefectChip('Renk', palet['renk']),
                _buildDefectChip('Askı', palet['aski']),
                _buildDefectChip('Kireç', palet['kirec']),
                _buildDefectChip('Kabarma', palet['kabarma']),
                _buildDefectChip('Gönye', palet['gonye']),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefectChip(String label, dynamic count) {
    final value = count as int? ?? 0;
    final hasDefect = value > 0;
    
    return Chip(
      label: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          color: hasDefect ? Colors.red.shade700 : Colors.grey.shade700,
          fontWeight: hasDefect ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      backgroundColor: hasDefect ? Colors.red.shade50 : Colors.grey.shade100,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Future<void> _deleteRecord(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kaydı Sil'),
        content: const Text('Bu kaydı silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('depot_control_records')
            .doc(docId)
            .delete();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kayıt silindi')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e')),
          );
        }
      }
    }
  }
}
