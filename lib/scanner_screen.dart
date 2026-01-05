import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ekosatsss/form_screen.dart';
import 'package:ekosatsss/oven_form_screen.dart';
import 'package:ekosatsss/lab_screen.dart';
import 'package:ekosatsss/auth_service.dart';
import 'package:ekosatsss/fire_records_form_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _isScanCompleted = false;
  final AuthService _authService = AuthService();
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Direkt email'den rol belirle
      final email = user.email?.toLowerCase();
      String? role;
      if (email == 'pres@ekos.com') {
        role = 'Pres sorumlusu';
      } else if (email == 'firin@ekos.com') {
        role = 'Fırın Sorumlusu';
      } else if (email == 'laborant@ekos.com' || email == 'lab@ekos.com') {
        role = 'Laborant';
      } else if (email == 'tugla@ekos.com') {
        role = 'Tugla Sorumlusu';
      } else if (email == 'admin@ekos.com') {
        role = 'admin';
      } else {
        // Fallback: Firestore'dan oku
        final uid = user.uid;
        role = await _authService.getUserRole(uid);
      }
      if (mounted) {
        print('ScannerScreen: role=$role');
        setState(() => _userRole = role);
      }
    }
  }

  void _handleBarcode(BarcodeCapture capture) async {
    // Eğer zaten bir barkod işleniyorsa veya ekran kapanma sürecindeyse, tekrar işlem yapma.
    if (_isScanCompleted) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String code = barcodes.first.rawValue ?? "Barkod okunamadı";
      await _handleBarcodeValue(code);
    }
  }

  Future<void> _handleBarcodeValue(String code) async {
    if (_isScanCompleted) return;
    
    final User? currentUser = FirebaseAuth.instance.currentUser;
    final String? userEmail = currentUser?.email;
    final String? uid = currentUser?.uid;

    if (uid == null || userEmail == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kullanıcı bilgileri alınamadı. Lütfen tekrar giriş yapın.'), backgroundColor: Colors.red),
        );
        Navigator.of(context).pop();
      }
      return;
    }

    // Direkt email'den rol belirle
    String? userRole;
    final email = userEmail.toLowerCase();
    if (email == 'pres@ekos.com') {
      userRole = 'Pres sorumlusu';
    } else if (email == 'firin@ekos.com') {
      userRole = 'Fırın Sorumlusu';
    } else if (email == 'laborant@ekos.com' || email == 'lab@ekos.com') {
      userRole = 'Laborant';
    } else if (email == 'tugla@ekos.com') {
      userRole = 'Tugla Sorumlusu';
    } else if (email == 'admin@ekos.com') {
      userRole = 'admin';
    } else {
      // Fallback: Firestore'dan oku
      userRole = await _authService.getUserRole(uid);
    }

    if (userRole == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kullanıcı rolü belirlenemedi.'), backgroundColor: Colors.red),
        );
        Navigator.of(context).pop();
      }
      return;
    }

    print('ScannerScreen._handleBarcode: userRole=$userRole, code=$code');

    // Role göre farklı form ekranlarına yönlendirme
    if (userRole == 'Pres sorumlusu') {
      setState(() { _isScanCompleted = true; });
      
      // Pres@ekos.com: Sadece kayıt yoksa veya "Fırından Çıkış" durumundaysa yeni kayıt açılır
      try {
        // cartNumber field'ından son kaydı bul (hafızada sırala - index yok)
        final query = await FirebaseFirestore.instance
            .collection('cart_records')
            .where('cartNumber', isEqualTo: code)
            .get();
        
        if (query.docs.isNotEmpty) {
          // Hafızada sırala ve en yenisini kontrol et
          var docs = query.docs.toList();
          docs.sort((a, b) {
            final aCreated = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
            final bCreated = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
            return bCreated.compareTo(aCreated);
          });
          
          final data = docs.first.data();
          final status = (data['status'] ?? '').toString().toLowerCase();
          // "Fırından Çıkış" durumundaysa yeni kayıt aç, diğer durumlar için uyarı ver
          if (!status.contains('fırından çıkış') && !status.contains('fırında')) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bu araba henüz fırından çıkmadı. Yeni kayıt açmak için önce "Fırından Çıkış" durumuna getirin.'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 3),
                ),
              );
            }
            setState(() { _isScanCompleted = false; });
            return;
          }
        }
      } catch (e) {
        // ignore - kayıt yoksa yeni form açılır
      }
      
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => FormScreen(barcode: code, userEmail: userEmail, fixedStatus: 'Yaş İmalat', isReadOnly: false)),
      ).then((_) {
        setState(() { _isScanCompleted = false; });
        // FormScreen direkt ListScreen'e yönlendiriyor
      });
    } else if (userRole == 'Fırın Sorumlusu') {
      // Fırın sorumlusu: Sadece "Yaş İmalat" (->Kurutmada) veya "Kurutmada" (->Kurutmadan Çıkış) işleyebilir
      try {
        // cartNumber field'ından son aktif kaydı bul (hafızada sırala - index gereksinimi yok)
        final query = await FirebaseFirestore.instance
            .collection('cart_records')
            .where('cartNumber', isEqualTo: code)
            .get();
        
        if (query.docs.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bu barkod kaydı bulunamadı'), backgroundColor: Colors.red),
            );
          }
          return;
        }
        
        // Hafızada createdAt'e göre sırala ve en yenisini al
        var docs = query.docs.toList();
        docs.sort((a, b) {
          final aCreated = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
          final bCreated = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
          return bCreated.compareTo(aCreated);
        });
        
        final doc = docs.first;
        final data = doc.data();
        final status = (data['status'] ?? '').toString().toLowerCase();
        
        // Sadece "Yaş İmalat" veya "Kurutmada" (ama "Kurutmadan Çıkış" değil!)
        final isYasImalat = status.contains('yaş');
        final isKurutmada = status.contains('kurutmada') && !status.contains('çıkış');
        
        if (!isYasImalat && !isKurutmada) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Bu araba işlenemez. Sadece "Yaş İmalat" veya "Kurutmada" durumundaki arabalar kurutma işlemine alınabilir.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
        
        setState(() { _isScanCompleted = true; });
        // Document ID'yi OvenFormScreen'e geç (cartNumber değil!)
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => OvenFormScreen(barcode: code, documentId: doc.id, userEmail: userEmail)),
        ).then((_) {
          setState(() { _isScanCompleted = false; });
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
          );
        }
      }
    } else if (userRole == 'Tugla Sorumlusu') {
      // Tugla Sorumlusu: sadece "Kurutmadan Çıkış" durumundaki arabalar için modal açılır
      setState(() { _isScanCompleted = true; });
      try {
        // cart_records dokümanları barkod ID'siyle değil auto-ID ile, bu yüzden cartNumber ile ara
        final query = await FirebaseFirestore.instance
            .collection('cart_records')
            .where('cartNumber', isEqualTo: code)
            .get();

        if (query.docs.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bu barkod kaydı bulunamadı'), backgroundColor: Colors.red),
            );
          }
          return;
        }

        // Hafızada "Kurutmadan Çıkış" durumundaki kayıtları filtrele ve en yenisini al
        final docs = query.docs.where((doc) {
          final status = (doc.data()['status'] ?? '').toString();
          return status == 'Kurutmadan Çıkış';
        }).toList();
        
        if (docs.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Bu barkod için "Kurutmadan Çıkış" durumunda araba bulunamadı'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
        
        // En yeni "Kurutmadan Çıkış" kaydını al
        docs.sort((a, b) {
          final aCreated = a.data()['createdAt'] as Timestamp? ?? Timestamp.now();
          final bCreated = b.data()['createdAt'] as Timestamp? ?? Timestamp.now();
          return bCreated.compareTo(aCreated);
        });

        final doc = docs.first;
        final data = doc.data();
        final status = (data['status'] ?? '').toString();

        await showModalBottomSheet(
          context: context,
          builder: (ctx) {
            final statusText = status.isEmpty ? 'Durum yok' : status;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Barkod: $code', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Durum: $statusText'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.visibility),
                            label: const Text('Barkodu Gör (Read-only)'),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FormScreen(
                                    barcode: code, // cartNumber (barkod numarası)
                                    documentId: doc.id, // Spesifik doküman ID'si
                                    userEmail: userEmail,
                                    isReadOnly: true,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.local_fire_department),
                            label: const Text('Fırına Al / Fire'),
                            onPressed: () {
                              Navigator.pop(ctx);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FireRecordsFormScreen(
                                    barcode: code,
                                    documentId: doc.id, // Spesifik doküman ID'si
                                    userEmail: userEmail,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() { _isScanCompleted = false; });
        }
      }
    } else if (userRole == 'Laborant') {
      // Laborant kullanıcısını direkt LabScreen'e yönlendir
      setState(() { _isScanCompleted = true; });
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => LabScreen(initialBarcode: code)),
      ).then((_) => setState(() { _isScanCompleted = false; }));
    } else if (userRole == 'admin') {
      // Admin tam düzenleme yetkisine sahip
      setState(() { _isScanCompleted = true; });
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => FormScreen(barcode: code, userEmail: userEmail)),
      ).then((_) => setState(() { _isScanCompleted = false; }));
    } else {
      // Diğer roller için formu sadece okunebilir modda aç
      setState(() { _isScanCompleted = true; });
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => FormScreen(barcode: code, userEmail: userEmail, isReadOnly: true)),
      ).then((_) => setState(() { _isScanCompleted = false; }));
    }
  }

  Future<void> _updateBarcodeStatusToOven(String barcode, String userEmail) async {
    try {
      // Barkodu cartNumber alanına göre ara (doküman ID'si barkod değil)
      final query = await FirebaseFirestore.instance
          .collection('cart_records')
          .where('cartNumber', isEqualTo: barcode)
          .get();
      
      // hafızada createdAt ile sırala
      var docs = query.docs.toList();
      docs.sort((a, b) {
        final aCreated = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bCreated = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        return bCreated.compareTo(aCreated);
      });

      if (docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bu barkod kaydı bulunamadı'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final doc = docs.first;
      final data = doc.data();
      final status = (data['status'] ?? '').toString();

      // Tugla Sorumlusu sadece "Kurutmadan Çıkış" durumundaki barkodları "Fırında" olarak alabilir
      if (status != 'Kurutmadan Çıkış') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Bu araba "$status" durumunda. Sadece "Kurutmadan Çıkış" durumundaki arabalar fırına alınabilir.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Durumunu "Fırında" olarak güncelle
      await FirebaseFirestore.instance.collection('cart_records').doc(doc.id).update({
        'status': 'Fırında',
        'ovenEntryTime': Timestamp.now(),
        'ovenEnteredBy': userEmail,
      });

      // Boş araba listesine ekle (otomatik doc ID ile, barcode alanı korunacak)
      await FirebaseFirestore.instance.collection('empty_carts').add({
        'barcode': barcode,
        'cartType': data['cartType'] ?? '',
        'addedAt': Timestamp.now(),
        'addedBy': userEmail,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Barkod durumu Fırında olarak güncellendi ve boş araba listesine eklendi'),
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
    final bool isDesktop = _isDesktop();
    
    // If current user is Pres sorumlusu, show scanner + pres records list
    if (_userRole == 'Pres sorumlusu') {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Pres - Barkod Okut'),
          backgroundColor: Colors.green[400],
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        body: isDesktop 
            ? _buildManualBarcodeInput()
            : Container(
                height: double.infinity,
                color: Colors.black,
                child: MobileScanner(
                  onDetect: _handleBarcode,
                ),
              ),
      );
    }

    // If current user is Fırın Sorumlusu, show scanner + oven records list
    if (_userRole == 'Fırın Sorumlusu') {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Fırın - Barkod Okut'),
          backgroundColor: Colors.red[400],
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        body: isDesktop
            ? _buildManualBarcodeInput()
            : Container(
                height: double.infinity,
                color: Colors.black,
                child: MobileScanner(
                  onDetect: _handleBarcode,
                ),
              ),
      );
    }

    // If current user is Tugla Sorumlusu, show scanner for updating status
    if (_userRole == 'Tugla Sorumlusu') {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Tuğla - Barkod Okut'),
          backgroundColor: Colors.orange[700],
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        body: isDesktop
            ? _buildManualBarcodeInput()
            : Container(
                height: double.infinity,
                color: Colors.black,
                child: MobileScanner(
                  onDetect: _handleBarcode,
                ),
              ),
      );
    }

    // If current user is Laborant, show scanner + description history
    if (_userRole == 'Laborant') {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Laborant - Barkod Okut'),
          backgroundColor: const Color(0xFFD32F2F),
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        body: isDesktop
            ? _buildManualBarcodeInput()
            : Stack(
                children: [
                  Container(
                    height: double.infinity,
                    color: Colors.black,
                    child: MobileScanner(
                      onDetect: _handleBarcode,
                    ),
                  ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.black87,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Barkodu okutunuz',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Açıklamaları görmek için kayıt seçiniz',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Barkod Okuyucu'),
        backgroundColor: Colors.indigo[400],
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: _isDesktop()
          ? _buildManualBarcodeInput()
          : MobileScanner(
              onDetect: _handleBarcode,
            ),
    );
  }

  bool _isDesktop() {
    if (kIsWeb) return true;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
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
                  color: Colors.indigo[400],
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
                        _processBarcode(value.trim());
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
                        _processBarcode(barcodeController.text.trim());
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

  void _processBarcode(String barcode) {
    _handleBarcodeValue(barcode);
  }
}