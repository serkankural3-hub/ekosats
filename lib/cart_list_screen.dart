import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ekosatsss/models/cart_model.dart';
import 'package:ekosatsss/models/product_catalog.dart';
import 'package:ekosatsss/services/connectivity_service.dart';
import 'package:ekosatsss/services/offline_cache_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' hide Column, Row, Border;
import 'package:universal_html/html.dart' as html;

class CartListScreen extends StatefulWidget {
  const CartListScreen({super.key});

  @override
  State<CartListScreen> createState() => _CartListScreenState();
}

class _CartListScreenState extends State<CartListScreen> {
  String _searchQuery = '';
  String _filterStatus = 'Tümü';
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  bool _isOnline = true;

  bool _isReadOnlyUser(String? email) {
    final lowerEmail = email?.toLowerCase();
    return lowerEmail == 'mustafaakgul@ekos.com' || lowerEmail == 'senaaydın@ekos.com';
  }

  final List<String> _statusOptions = [
    'Tümü',
    'Yaş İmalat',
    'Kurutmada',
    'Fırında',
  ];

  @override
  Widget build(BuildContext context) {
    _isOnline = Provider.of<ConnectivityService>(context).isOnline;
    final cache = Provider.of<OfflineCacheService>(context, listen: false);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Araba Kayıtları'),
        backgroundColor: Colors.deepPurple[400],
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: "Excel'e Aktar",
            onPressed: _exportToExcel,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Araba No, İş Emri veya Ürün Ara...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _filterStatus,
                        decoration: const InputDecoration(
                          labelText: 'Durum',
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: _statusOptions
                            .map((status) => DropdownMenuItem(
                                value: status, child: Text(status)))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _filterStatus = value ?? 'Tümü'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.date_range),
                      tooltip: 'Tarih Aralığı',
                      onPressed: _selectDateRange,
                      color: _filterStartDate != null ? Colors.blue : null,
                    ),
                    if (_filterStartDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Tarihi Temizle',
                        onPressed: _clearDateFilter,
                      ),
                  ],
                ),
                if (_filterStartDate != null && _filterEndDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${DateFormat('dd/MM/yyyy').format(_filterStartDate!)} - ${DateFormat('dd/MM/yyyy').format(_filterEndDate!)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('cart_records')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!_isOnline) {
                  return FutureBuilder<List<Map<String, dynamic>>>(
                    future: cache.getCachedRecords(),
                    builder: (context, cacheSnap) {
                      if (cacheSnap.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (cacheSnap.hasError || !cacheSnap.hasData) {
                        return const Center(
                            child: Text('Çevrimdışı veri bulunamadı.'));
                      }

                      final cachedMaps = cacheSnap.data!;
                      final records = _mapsToRecords(cachedMaps);
                      records.sort((a, b) => b.dateTime.compareTo(a.dateTime));
                      final filtered = _applyFilters(records);

                      if (filtered.isEmpty) {
                        return const Center(
                            child: Text('Çevrimdışı kayıt bulunamadı.'));
                      }

                      return _buildListView(filtered, rawMaps: cachedMaps);
                    },
                  );
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Hata: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Henüz kayıt yok'));
                }

                final docs = snapshot.data!.docs;
                for (final doc in docs) {
                  final docData = doc.data();
                  if (docData != null && docData is Map<String, dynamic>) {
                    // Timestamp'leri milliseconds'a çevir
                    final sanitizedData = Map<String, dynamic>.from(docData);
                    sanitizedData.forEach((key, value) {
                      if (value is Timestamp) {
                        sanitizedData[key] = value.millisecondsSinceEpoch;
                      }
                    });
                    cache.cacheRecord(doc.id, sanitizedData);
                  }
                }

                List<CartRecord> records = docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final createdAtTs = data['createdAt'];
                  final dateTimeTs = data['dateTime'];
                  final createdAt = createdAtTs is Timestamp
                      ? createdAtTs.toDate()
                      : (createdAtTs is int
                          ? DateTime.fromMillisecondsSinceEpoch(createdAtTs)
                          : DateTime.now());
                  final dateTime = dateTimeTs is Timestamp
                      ? dateTimeTs.toDate()
                      : (dateTimeTs is int
                          ? DateTime.fromMillisecondsSinceEpoch(dateTimeTs)
                          : createdAt);
                  return CartRecord(
                    id: doc.id,
                    cartNumber: (data['cartNumber'] ?? '').toString(),
                    cartType: (data['cartType'] ?? '').toString(),
                    productType: (data['productType'] ?? '').toString(),
                    product: (data['product'] ?? '').toString(),
                    color: (data['color'] ?? '').toString(),
                    dateTime: dateTime,
                    status: (data['status'] ?? '').toString(),
                    productQuantity: data['productQuantity'] is int
                        ? data['productQuantity']
                        : int.tryParse(
                                data['productQuantity']?.toString() ?? '0') ??
                            0,
                    workOrder: (data['workOrder'] ?? '').toString(),
                    description: (data['description'] ?? '').toString(),
                    createdBy: (data['createdBy'] ?? '').toString(),
                    createdAt: createdAt,
                  );
                }).toList();
                records = _applyFilters(records);

                if (records.isEmpty) {
                  return const Center(
                      child:
                          Text('Filtre kriterlerine uygun kayıt bulunamadı'));
                }

                return _buildListView(records, docs: docs);
              },
            ),
          ),
        ],
      ),
    );
  }

  List<CartRecord> _applyFilters(List<CartRecord> records) {
    return records.where((record) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!record.cartNumber.toLowerCase().contains(query) &&
            !record.workOrder.toLowerCase().contains(query) &&
            !record.product.toLowerCase().contains(query) &&
            !record.productType.toLowerCase().contains(query)) {
          return false;
        }
      }
      if (_filterStatus != 'Tümü') {
        final status = record.status.toLowerCase();
        if (_filterStatus == 'Kurutmada') {
          if (!status.contains('kurut')) return false;
        } else if (_filterStatus == 'Fırında') {
          if (!status.contains('fır')) return false;
        } else if (_filterStatus == 'Yaş İmalat') {
          if (!status.contains('yaş')) return false;
        }
      }
      if (_filterStartDate != null &&
          record.dateTime.isBefore(_filterStartDate!)) {
        return false;
      }
      if (_filterEndDate != null && record.dateTime.isAfter(_filterEndDate!)) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _filterStartDate != null && _filterEndDate != null
          ? DateTimeRange(start: _filterStartDate!, end: _filterEndDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _filterStartDate = picked.start;
        // Bitiş tarihini günün sonuna ayarla (23:59:59)
        _filterEndDate = DateTime(
            picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
    }
  }

  void _clearDateFilter() {
    setState(() {
      _filterStartDate = null;
      _filterEndDate = null;
    });
  }

  Future<void> _exportToExcel() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('cart_records')
          .orderBy('dateTime', descending: true)
          .get();
      List<Map<String, dynamic>> docs =
          snapshot.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      List<CartRecord> records =
          snapshot.docs.map((d) => CartRecord.fromFirestore(d)).toList();
      records = _applyFilters(records);

      final filteredIds = records.map((r) => r.id).toSet();
      docs = docs.where((d) => filteredIds.contains(d['id'])).toList();

      if (records.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Dışa aktarılacak veri yok')));
        }
        return;
      }

      final Workbook workbook = Workbook();
      final Worksheet worksheet = workbook.worksheets[0];

      final headers = [
        'Barkod',
        'Araba Tipi',
        'Oluşturma Tarihi',
        'Ürün İsmi',
        'Renk',
        'Ürün Adedi',
        'Toplam Ağırlık (kg)',
        'Durum',
        'İş Emri',
        'Açıklama',
        'Lab Notları',
        'Sorumlu',
        'Kurutma Giriş',
        'Kurutma Çıkış',
      ];

      for (int i = 0; i < headers.length; i++) {
        final range = worksheet.getRangeByIndex(1, i + 1);
        range.setText(headers[i]);
        range.cellStyle.bold = true;
        range.cellStyle.backColor = '#D3D3D3';
      }

      int rowIndex = 2;
      for (final d in docs) {
        final dryingInRaw = d['dryingIn'];
        final dryingIn = dryingInRaw is Timestamp
            ? DateFormat('dd/MM/yyyy HH:mm').format(dryingInRaw.toDate())
            : (dryingInRaw is int
                ? DateFormat('dd/MM/yyyy HH:mm')
                    .format(DateTime.fromMillisecondsSinceEpoch(dryingInRaw))
                : '');

        final dryingOutRaw = d['dryingOut'];
        final dryingOut = dryingOutRaw is Timestamp
            ? DateFormat('dd/MM/yyyy HH:mm').format(dryingOutRaw.toDate())
            : (dryingOutRaw is int
                ? DateFormat('dd/MM/yyyy HH:mm')
                    .format(DateTime.fromMillisecondsSinceEpoch(dryingOutRaw))
                : '');

        final createdAtRaw = d['createdAt'];
        final createdAt = createdAtRaw is Timestamp
            ? DateFormat('dd/MM/yyyy HH:mm').format(createdAtRaw.toDate())
            : (createdAtRaw is int
                ? DateFormat('dd/MM/yyyy HH:mm')
                    .format(DateTime.fromMillisecondsSinceEpoch(createdAtRaw))
                : '');

        // Lab notlarını topla
        String labNotes = '';
        final labNotesField = d['labNotes'];

        if (labNotesField is String) {
          // Yeni format: String labNotes + labCheckedAt + labUserEmail
          if (labNotesField.isNotEmpty) {
            final checkedAtRaw = d['labCheckedAt'];
            final checkedBy = d['labUserEmail']?.toString() ?? '';
            String dateStr = '';

            if (checkedAtRaw is Timestamp) {
              dateStr =
                  DateFormat('dd/MM/yyyy HH:mm').format(checkedAtRaw.toDate());
            } else if (checkedAtRaw is int) {
              dateStr = DateFormat('dd/MM/yyyy HH:mm')
                  .format(DateTime.fromMillisecondsSinceEpoch(checkedAtRaw));
            }

            labNotes = '[$dateStr - $checkedBy]: $labNotesField';
          }
        } else if (labNotesField is Map<String, dynamic>) {
          // Eski format: Map<String, dynamic>
          if (labNotesField.isNotEmpty) {
            final notesList = <String>[];
            labNotesField.forEach((key, value) {
              if (value is Map<String, dynamic>) {
                final note = value['note']?.toString() ?? '';
                final addedBy = value['addedBy']?.toString() ?? '';
                final timestamp = value['timestamp'];
                String dateStr = '';
                if (timestamp is Timestamp) {
                  dateStr =
                      DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate());
                }
                if (note.isNotEmpty) {
                  notesList.add('[$dateStr - $addedBy]: $note');
                }
              }
            });
            labNotes = notesList.join(' | ');
          }
        }

        final rowData = [
          d['cartNumber']?.toString() ?? d['id']?.toString() ?? '', // cartNumber kullan
          d['cartType']?.toString() ?? '',
          createdAt,
          d['product']?.toString() ?? '',
          d['color']?.toString() ?? '',
          d['productQuantity']?.toString() ?? '',
          ProductCatalog.totalWeight(d['product']?.toString(),
                  int.tryParse(d['productQuantity']?.toString() ?? '0') ?? 0)
              .toStringAsFixed(2),
          d['status']?.toString() ?? '',
          d['workOrder']?.toString() ?? '',
          d['description']?.toString() ?? '',
          labNotes,
          d['createdBy']?.toString() ?? '',
          dryingIn,
          dryingOut,
        ];

        for (int i = 0; i < rowData.length; i++) {
          worksheet.getRangeByIndex(rowIndex, i + 1).setText(rowData[i]);
        }
        rowIndex++;
      }

      final columnWidths = [
        15.0,
        12.0,
        20.0,
        25.0,
        16.0,
        12.0,
        15.0,
        15.0,
        12.0,
        25.0,
        40.0,
        18.0,
        20.0,
        20.0
      ];
      for (int i = 0; i < columnWidths.length; i++) {
        worksheet.getRangeByIndex(1, i + 1).columnWidth = columnWidths[i];
      }

      final fileBytes = workbook.saveAsStream();
      workbook.dispose();

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = 'araba_kayitlari_$timestamp.xlsx';

      if (kIsWeb) {
        final blob = html.Blob([
          fileBytes
        ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final link = html.document.createElement('a') as html.AnchorElement
          ..setAttribute('href', url)
          ..setAttribute('download', filename)
          ..style.display = 'none';
        html.document.body?.children.add(link);
        Future.microtask(() {
          link.click();
          link.remove();
          html.Url.revokeObjectUrl(url);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Excel dosyası indirildi: $filename'),
              backgroundColor: Colors.green));
        }
      } else if (Platform.isAndroid || Platform.isIOS) {
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/$filename';
        final file = File(path);
        await file.writeAsBytes(fileBytes);
        await Share.shareXFiles([XFile(path)],
            subject: 'Araba Takip Kayıtları');
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/$filename';
        final file = File(path);
        await file.writeAsBytes(fileBytes);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Dosya kaydedildi: $path')));
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Excel dosyası oluşturuldu ve paylaşıldı'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
      }
    }
  }

  List<CartRecord> _mapsToRecords(List<Map<String, dynamic>> maps) {
    return maps.map((data) {
      final createdAtTs = data['createdAt'];
      final dateTimeTs = data['dateTime'];
      final createdAt = createdAtTs is Timestamp
          ? createdAtTs.toDate()
          : (createdAtTs is int
              ? DateTime.fromMillisecondsSinceEpoch(createdAtTs)
              : DateTime.fromMillisecondsSinceEpoch(0));
      final dateTime = dateTimeTs is Timestamp
          ? dateTimeTs.toDate()
          : (dateTimeTs is int
              ? DateTime.fromMillisecondsSinceEpoch(dateTimeTs)
              : createdAt);
      return CartRecord(
        id: (data['id'] ?? data['cartNumber'] ?? '').toString(),
        cartNumber: (data['cartNumber'] ?? '').toString(),
        cartType: (data['cartType'] ?? '').toString(),
        productType: (data['productType'] ?? '').toString(),
        product: (data['product'] ?? '').toString(),
        color: (data['color'] ?? '').toString(),
        dateTime: dateTime,
        status: (data['status'] ?? '').toString(),
        productQuantity: (data['productQuantity'] ?? 0) is int
            ? data['productQuantity']
            : int.tryParse(data['productQuantity']?.toString() ?? '0') ?? 0,
        workOrder: (data['workOrder'] ?? '').toString(),
        description: (data['description'] ?? '').toString(),
        createdBy: (data['createdBy'] ?? '').toString(),
        createdAt: createdAt,
      );
    }).toList();
  }

  Widget _buildListView(List<CartRecord> records,
      {List<QueryDocumentSnapshot>? docs,
      List<Map<String, dynamic>>? rawMaps}) {
    final docMap = <String, Map<String, dynamic>>{};
    if (docs != null) {
      for (final doc in docs) {
        docMap[doc.id] = doc.data() as Map<String, dynamic>;
      }
    } else if (rawMaps != null) {
      for (final map in rawMaps) {
        final key = (map['id'] ?? map['cartNumber'] ?? '').toString();
        docMap[key] = map;
      }
    }

    return ListView.builder(
      itemCount: records.length,
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, index) {
        final record = records[index];
        final data = docMap[record.id];
        DateTime? dryingIn;
        DateTime? dryingOut;
        if (data != null) {
          if (data['dryingIn'] is Timestamp)
            dryingIn = (data['dryingIn'] as Timestamp).toDate();
          if (data['dryingOut'] is Timestamp)
            dryingOut = (data['dryingOut'] as Timestamp).toDate();
        }

        Color statusColor = Colors.grey[400]!;
        Color statusBgColor = Colors.grey[100]!;
        IconData statusIcon = Icons.info_outline;

        switch (record.status) {
          case 'Yaş İmalat':
            statusColor = Colors.green[700]!;
            statusBgColor = Colors.green[100]!;
            statusIcon = Icons.brightness_1;
            break;
          case 'Kurutmada':
            statusColor = Colors.orange[700]!;
            statusBgColor = Colors.orange[100]!;
            statusIcon = Icons.local_fire_department;
            break;
          case 'Kurutmadan Çıkış':
            statusColor = Colors.deepOrange[700]!;
            statusBgColor = Colors.deepOrange[100]!;
            statusIcon = Icons.exit_to_app;
            break;
          case 'Fırında':
            statusColor = Colors.red[700]!;
            statusBgColor = Colors.red[100]!;
            statusIcon = Icons.local_fire_department;
            break;
          case 'Fırından Çıkış':
            statusColor = Colors.deepOrange[700]!;
            statusBgColor = Colors.deepOrange[100]!;
            statusIcon = Icons.exit_to_app;
            break;
        }

        return Card(
          elevation: 2,
          color: Colors.white,
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border(
                left: BorderSide(color: statusColor, width: 5),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Araba: ${record.cartNumber}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black87)),
                          const SizedBox(height: 4),
                          Text(
                              'Durum: ${record.status}${_isOnline ? '' : ' (Çevrimdışı)'}',
                              style: const TextStyle(
                                  color: Colors.black54, fontSize: 14)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: statusColor, width: 2),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, color: statusColor, size: 20),
                          const SizedBox(height: 2),
                          Text(record.status,
                              style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'Ürün: ${record.product.isNotEmpty ? record.product : record.productType}',
                              style: const TextStyle(
                                  color: Colors.black87, fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          if (record.color.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('Renk: ${record.color}',
                                style: const TextStyle(
                                    color: Colors.black87, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                          const SizedBox(height: 4),
                          Text('Adet: ${record.productQuantity}',
                              style: const TextStyle(
                                  color: Colors.black87, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text('İş Emri: ${record.workOrder}',
                              style: const TextStyle(
                                  color: Colors.black87, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                            'Giriş: ${dryingIn != null ? DateFormat('dd/MM HH:mm').format(dryingIn) : 'N/A'}',
                            style: const TextStyle(
                                color: Colors.black54, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(
                            'Çıkış: ${dryingOut != null ? DateFormat('dd/MM HH:mm').format(dryingOut) : 'N/A'}',
                            style: const TextStyle(
                                color: Colors.black54, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(
                            'Oluşturma: ${DateFormat('dd/MM HH:mm').format(record.createdAt)}',
                            style: const TextStyle(
                                color: Colors.black54, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ],
                ),
                // Lab Notları Gösterimi
                if (data != null && data['labNotes'] != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.purple[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.science,
                                size: 16, color: Colors.purple[700]),
                            const SizedBox(width: 6),
                            Text(
                              'Lab Notları',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.purple[900],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...(() {
                          final notesList = <Widget>[];
                          final labNotes = data['labNotes'];

                          // Yeni format (String)
                          if (labNotes is String && labNotes.isNotEmpty) {
                            final labUserEmail =
                                data['labUserEmail']?.toString() ?? '';
                            final labCheckedAt = data['labCheckedAt'];
                            String dateStr = '';
                            if (labCheckedAt is Timestamp) {
                              dateStr = DateFormat('dd/MM HH:mm')
                                  .format(labCheckedAt.toDate());
                            } else if (labCheckedAt is int) {
                              dateStr = DateFormat('dd/MM HH:mm').format(
                                  DateTime.fromMillisecondsSinceEpoch(
                                      labCheckedAt));
                            }

                            notesList.add(
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('• ',
                                        style: TextStyle(
                                            color: Colors.purple[700],
                                            fontSize: 12)),
                                    Expanded(
                                      child: RichText(
                                        text: TextSpan(
                                          style: const TextStyle(
                                              color: Colors.black87,
                                              fontSize: 12),
                                          children: [
                                            TextSpan(text: labNotes),
                                            if (dateStr.isNotEmpty)
                                              TextSpan(
                                                text:
                                                    '\n$dateStr${labUserEmail.isNotEmpty ? " - $labUserEmail" : ""}',
                                                style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.black54,
                                                    fontStyle:
                                                        FontStyle.italic),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          // Eski format (Map) - geriye dönük uyumluluk
                          else if (labNotes is Map<String, dynamic>) {
                            labNotes.forEach((key, value) {
                              if (value is Map<String, dynamic>) {
                                final note = value['note']?.toString() ?? '';
                                final addedBy =
                                    value['addedBy']?.toString() ?? '';
                                final timestamp = value['timestamp'];
                                String dateStr = '';
                                if (timestamp is Timestamp) {
                                  dateStr = DateFormat('dd/MM HH:mm')
                                      .format(timestamp.toDate());
                                }
                                if (note.isNotEmpty) {
                                  notesList.add(
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('• ',
                                              style: TextStyle(
                                                  color: Colors.purple[700],
                                                  fontSize: 12)),
                                          Expanded(
                                            child: RichText(
                                              text: TextSpan(
                                                style: const TextStyle(
                                                    color: Colors.black87,
                                                    fontSize: 12),
                                                children: [
                                                  TextSpan(text: note),
                                                  TextSpan(
                                                    text:
                                                        '\n$dateStr - $addedBy',
                                                    style: const TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.black54,
                                                        fontStyle:
                                                            FontStyle.italic),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                              }
                            });
                          }
                          return notesList;
                        })(),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(record.createdBy,
                            style: TextStyle(
                                color: Colors.grey[700], fontSize: 13)),
                      ],
                    ),
                    Row(
                      children: [
                        if (!_isReadOnlyUser(
                            FirebaseAuth.instance.currentUser?.email))
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            color: Colors.blue,
                            tooltip: 'Düzenle',
                            onPressed: () => _editRecord(record),
                          ),
                        if (!_isReadOnlyUser(
                            FirebaseAuth.instance.currentUser?.email))
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20),
                            color: Colors.red,
                            tooltip: 'Sil',
                            onPressed: () => _deleteRecord(record),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _editRecord(CartRecord record) async {
    // Edit dialog göster
    String selectedCartType =
        record.cartType.isNotEmpty ? record.cartType : 'Ekos';
    
    // ProductCatalog'dan asıl üretim ürünlerini al (productNames - productToColors'tan)
    final List<String> productTypeOptions = List.from(ProductCatalog.productNames);
    
    // product field kullan, productType değil (productType eski field)
    String selectedProductType = record.product.isNotEmpty
        ? record.product
        : (record.productType.isNotEmpty 
            ? record.productType 
            : productTypeOptions.first);
    
    // Eğer seçili ürün listede yoksa (eski kayıt), listeye ekle
    if (!productTypeOptions.contains(selectedProductType)) {
      productTypeOptions.insert(0, selectedProductType);
    }
    
    String selectedColor = record.color.isNotEmpty ? record.color : 'Nar';
    final TextEditingController productQuantityController =
        TextEditingController(text: record.productQuantity.toString());
    final TextEditingController workOrderController =
        TextEditingController(text: record.workOrder);
    final TextEditingController descriptionController =
        TextEditingController(text: record.description);
    String selectedStatus = record.status;

    final List<String> cartTypeOptions = ['Ekos', 'Ats'];
    // Tüm renkleri al (60 renk)
    final List<String> colorOptions = ProductCatalog.allColors;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Düzenle: ${record.cartNumber}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedCartType,
                      decoration:
                          const InputDecoration(labelText: 'Araba Türü'),
                      items: cartTypeOptions
                          .map((type) =>
                              DropdownMenuItem(value: type, child: Text(type)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedCartType = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedProductType,
                      decoration: const InputDecoration(labelText: 'Ürün İsmi'),
                      items: productTypeOptions
                          .map((type) =>
                              DropdownMenuItem(value: type, child: Text(type)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedProductType = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedColor,
                      decoration: const InputDecoration(labelText: 'Renk'),
                      items: colorOptions
                          .map((color) => DropdownMenuItem(
                              value: color, child: Text(color)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedColor = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: productQuantityController,
                      decoration:
                          const InputDecoration(labelText: 'Ürün Adedi'),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: workOrderController,
                      decoration: const InputDecoration(labelText: 'İş Emri'),
                    ),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'Açıklama'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      decoration: const InputDecoration(labelText: 'Durum'),
                      items: [
                        'Yaş İmalat',
                        'Kurutmada',
                        'Kurutmadan Çıkış',
                        'Fırında',
                        'Fırından Çıkış'
                      ]
                          .map((status) => DropdownMenuItem(
                              value: status, child: Text(status)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedStatus = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('İptal'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      try {
        await FirebaseFirestore.instance
            .collection('cart_records')
            .doc(record.id)
            .update({
          'cartType': selectedCartType,
          'productType': selectedProductType,
          'renk': selectedColor,
          'color': selectedColor,
          'productQuantity': int.tryParse(productQuantityController.text) ?? 0,
          'workOrder': workOrderController.text,
          'description': descriptionController.text,
          'status': selectedStatus,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kayıt güncellendi'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Güncelleme hatası: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    productQuantityController.dispose();
    workOrderController.dispose();
    descriptionController.dispose();
  }

  Future<void> _deleteRecord(CartRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kaydı Sil'),
        content: Text(
            '${record.cartNumber} numaralı araba kaydını silmek istediğinize emin misiniz?'),
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
            .collection('cart_records')
            .doc(record.id)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kayıt silindi'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Silme hatası: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
