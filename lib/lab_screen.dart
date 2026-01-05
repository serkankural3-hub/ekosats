import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:ekosatsss/lab_edit_screen.dart';

class LabScreen extends StatefulWidget {
  const LabScreen({super.key, this.initialBarcode});

  final String? initialBarcode;

  @override
  State<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen> with TickerProviderStateMixin {
  bool _isScanCompleted = false;
  late MobileScannerController _controller;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
    _tabController = TabController(length: 2, vsync: this);

    // Eğer barkod ScannerScreen'den geldiyse tekrar okutma isteme.
    if (widget.initialBarcode != null && widget.initialBarcode!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleBarcode(widget.initialBarcode!);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(String code) async {
    if (_isScanCompleted) return;

    setState(() {
      _isScanCompleted = true;
    });

    try {
      // Barkoda göre cart_records'dan veriyi bul (cartNumber alanında)
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('cart_records')
          .where('cartNumber', isEqualTo: code)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bu barkod sistemde bulunamadı'),
              backgroundColor: Colors.red,
            ),
          );
        }
        if (mounted) {
          setState(() {
            _isScanCompleted = false;
          });
        }
        return;
      }

      final doc = snapshot.docs.first;
      final docId = doc.id;
      final data = doc.data() as Map<String, dynamic>;
      final createdBy = data['createdBy'] ?? '';

      // Sadece pres kullanıcısı tarafından oluşturulan kayıtlar için lab çalışması yapılabilir
      if (!createdBy.toLowerCase().contains('pres')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bu kayıt pres kullanıcısı tarafından oluşturulmamış'),
              backgroundColor: Colors.red,
            ),
          );
        }
        if (mounted) {
          setState(() {
            _isScanCompleted = false;
          });
        }
        return;
      }

      setState(() {
        _isScanCompleted = true;
      });

      // Lab edit screen'ine yönlendir
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LabEditScreen(
              docId: docId,
              barcode: code,
              recordData: data,
            ),
          ),
        );

        // Başarılı kayıt sonrası "Açıklamalarım" sekmesine geç
        if (mounted) {
          _tabController.animateTo(1);
        }

        setState(() {
          _isScanCompleted = false;
        });
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
      setState(() {
        _isScanCompleted = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = kIsWeb || (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS));
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lab'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Barkod Okut', icon: Icon(Icons.qr_code_2)),
            Tab(text: 'Açıklamalarım', icon: Icon(Icons.list)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Barkod Okuma
          isDesktop
              ? _buildManualBarcodeInput()
              : Stack(
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: (capture) {
                        final List<Barcode> barcodes = capture.barcodes;
                        if (barcodes.isNotEmpty) {
                          final String code = barcodes.first.rawValue ?? '';
                          if (code.isNotEmpty) {
                            _handleBarcode(code);
                          }
                        }
                      },
                    ),
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Barkodu okutunuz',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Tab 2: Lab Açıklamalarım Listesi
          _buildLabHistoryList(),
        ],
      ),
    );
  }

  Widget _buildLabHistoryList() {
    final currentUserEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('cart_records')
          .where('labCheckedAt', isNotEqualTo: null)
          .where('labUserEmail', isEqualTo: currentUserEmail)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Hata: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Henüz açıklama eklemediniz'));
        }

        // Sadece lab notları olan ve bu kullanıcı tarafından işlenen kayıtları göster
        final docs = snapshot.data!.docs
            .where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['labCheckedAt'] != null && data['labUserEmail'] == currentUserEmail;
            })
            .toList();

        if (docs.isEmpty) {
          return const Center(child: Text('Henüz açıklama eklemediniz'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final barcode = data['barcode'] ?? 'N/A';
            final labNotes = data['labNotes'] ?? '';
            final labCheckedAt = data['labCheckedAt'] as Timestamp?;
            final formattedDate = labCheckedAt != null
                ? DateFormat('dd/MM/yyyy HH:mm').format(labCheckedAt.toDate())
                : 'Tarih yok';
            final createdBy = data['createdBy'] ?? 'N/A';

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Barkod: $barcode',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Lab Onaylı',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Pres: $createdBy',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tarih: $formattedDate',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Açıklama:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            labNotes.isEmpty ? 'Açıklama eklenmemiş' : labNotes,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildManualBarcodeInput() {
    final TextEditingController barcodeController = TextEditingController();
    
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.qr_code_scanner,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Manuel Barkod Girişi',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Kamera masaüstünde desteklenmiyor.\nLütfen barkodu manuel olarak giriniz.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: 400,
                  child: TextField(
                    controller: barcodeController,
                    decoration: const InputDecoration(
                      labelText: 'Barkod Numarası',
                      prefixIcon: Icon(Icons.barcode_reader),
                      hintText: 'Barkod numarasını giriniz',
                    ),
                    autofocus: true,
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        _handleBarcode(value.trim());
                        barcodeController.clear();
                      }
                    },
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 400,
                  child: ElevatedButton(
                    onPressed: () {
                      if (barcodeController.text.trim().isNotEmpty) {
                        _handleBarcode(barcodeController.text.trim());
                        barcodeController.clear();
                      }
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text('Barkodu İşle'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


