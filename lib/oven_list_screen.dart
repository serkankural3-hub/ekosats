import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ekosatsss/auth_service.dart';
import 'package:ekosatsss/services/connectivity_service.dart';
import 'package:ekosatsss/services/offline_cache_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ekosatsss/services/auto_exit_service.dart';
import 'package:ekosatsss/oven_form_screen.dart';

class OvenListScreen extends StatefulWidget {
  const OvenListScreen({super.key});

  @override
  State<OvenListScreen> createState() => _OvenListScreenState();
}

class _OvenListScreenState extends State<OvenListScreen> {
  final AuthService _authService = AuthService();
  String? _userRole;
  bool _isOnline = true;
  String _searchQuery = '';
  String _filterStatus = 'Tümü';
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
    // İstemci tarafı otomatik fırından çıkış kontrolü (hafif ve sessiz)
    AutoExitService.runOnce();
  }

  Future<void> _fetchUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Direkt email'den rol belirle
      final email = user.email?.toLowerCase();
      String? role;
      if (email == 'firin@ekos.com') {
        role = 'Fırın Sorumlusu';
      } else if (email == 'admin@ekos.com') {
        role = 'admin';
      } else if (email == 'pres@ekos.com') {
        role = 'Pres sorumlusu';
      } else {
        // Fallback: Firestore'dan oku
        role = await _authService.getUserRole(user.uid);
      }
      if (mounted) setState(() => _userRole = role);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Track connectivity state for offline cache usage
    _isOnline = Provider.of<ConnectivityService>(context).isOnline;
    final cache = Provider.of<OfflineCacheService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fırın Kayıt Listesi'),
        backgroundColor: Colors.red[400],
        foregroundColor: Colors.white,
      ),
      body: _userRole == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: () {
                if (_userRole == 'admin' || _userRole == 'Fırın Sorumlusu') {
                  // Tüm cart_records'ları getir, client-side'da filtreleme yap
                  return FirebaseFirestore.instance
                      .collection('cart_records')
                      .snapshots();
                }
                return const Stream<QuerySnapshot>.empty();
              }(),
              builder: (context, snapshot) {
                if (!_isOnline) {
                  return FutureBuilder<List<Map<String, dynamic>>>(
                    future: cache.getCachedRecords(),
                    builder: (context, cacheSnap) {
                      if (cacheSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (cacheSnap.hasError || !cacheSnap.hasData) {
                        return const Center(child: Text('Çevrimdışı veri bulunamadı.'));
                      }

                        final allowedStatuses = ['kurutmada', 'kurutmadan çıkış', 'fırında'];
                        final cached = cacheSnap.data!
                          .where((data) {
                            final s = ((data['status'] ?? '') as String).toLowerCase();
                            return allowedStatuses.any((a) => s.contains(a));
                          })
                          .toList()
                        ..sort((a, b) {
                          final aCreatedAt = a['createdAt'];
                          final bCreatedAt = b['createdAt'];
                          final aDate = aCreatedAt is Timestamp 
                            ? aCreatedAt.toDate() 
                            : (aCreatedAt is int 
                              ? DateTime.fromMillisecondsSinceEpoch(aCreatedAt) 
                              : DateTime.fromMillisecondsSinceEpoch(0));
                          final bDate = bCreatedAt is Timestamp 
                            ? bCreatedAt.toDate() 
                            : (bCreatedAt is int 
                              ? DateTime.fromMillisecondsSinceEpoch(bCreatedAt) 
                              : DateTime.fromMillisecondsSinceEpoch(0));
                          return bDate.compareTo(aDate);
                        });

                      if (cached.isEmpty) {
                        return const Center(child: Text('Çevrimdışı fırın verisi yok.'));
                      }

                      return _buildListViewFromData(cached, isAdmin: _userRole == 'admin', isOnline: false);
                    },
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Bir hata oluştu: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Henüz fırın verisi kaydedilmemiş.'));
                }

                final docs = snapshot.data!.docs;
                for (final doc in docs) {
                  cache.cacheRecord(doc.id, doc.data() as Map<String, dynamic>);
                }

                // Client-side filtreleme: dryingIn dolu olanlar veya "Fırında" durumundakiler + durum kontrolü
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = (data['status'] ?? '').toString().toLowerCase();
                  final dryingIn = data['dryingIn'];
                  final barcode = (data['cartNumber'] ?? data['id'] ?? '').toString();

                  // Only show records with one of the oven-related statuses: Kurutmada, Kurutmadan Çıkış, Fırında
                  final allowed = ['kurutmada', 'kurutmadan çıkış', 'fırında'];
                  final hasAllowedStatus = allowed.any((a) => status.contains(a));
                  if (!hasAllowedStatus) return false;

                  // Durum filtresi (giriş vs çıkış net ayrımı)
                  if (_filterStatus != 'Tümü') {
                    if (_filterStatus == 'Kurutmada') {
                      // Sadece giriş kayıtları: 'kurut' içerir ve 'çık' içermez
                      if (!status.contains('kurut') || status.contains('çık')) return false;
                    }
                    if (_filterStatus == 'Kurutmadan Çıkış') {
                      // Sadece çıkış kayıtları: 'çık' içerir
                      if (!status.contains('çık')) return false;
                    }
                  }

                  // Arama filtresi
                  if (_searchQuery.isNotEmpty && !barcode.contains(_searchQuery.toLowerCase())) {
                    return false;
                  }

                  // Tarih filtresi
                  final createdAtRaw = data['createdAt'];
                  if (createdAtRaw != null) {
                    final createdAt = createdAtRaw is Timestamp 
                        ? createdAtRaw.toDate() 
                        : (createdAtRaw is int ? DateTime.fromMillisecondsSinceEpoch(createdAtRaw) : null);
                    if (createdAt != null) {
                      if (_filterStartDate != null && createdAt.isBefore(_filterStartDate!)) return false;
                      if (_filterEndDate != null && createdAt.isAfter(_filterEndDate!)) return false;
                    }
                  }

                  return true;
                }).toList();

                // Sort by dryingIn descending
                filteredDocs.sort((a, b) {
                  final aDryingIn = (a.data() as Map<String, dynamic>)['dryingIn'] as Timestamp?;
                  final bDryingIn = (b.data() as Map<String, dynamic>)['dryingIn'] as Timestamp?;
                  if (aDryingIn == null || bDryingIn == null) return 0;
                  return bDryingIn.compareTo(aDryingIn);
                });

                if (filteredDocs.isEmpty) {
                  return const Center(child: Text('Filtre kriterine uygun kayıt yok.'));
                }

                return Column(
                  children: [
                    _buildFilterBar(),
                    Expanded(child: _buildListViewFromDocs(filteredDocs.cast<QueryDocumentSnapshot>(), isAdmin: _userRole == 'admin')),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildListViewFromDocs(List<QueryDocumentSnapshot> docs, {required bool isAdmin}) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final cartNumber = (data['cartNumber'] ?? doc.id).toString();
        return _buildCard(cartNumber, doc.id, data, isAdmin: isAdmin, isOnline: true);
      }).toList(),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey[100],
      child: Column(
        children: [
          // Arama
          TextField(
            onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Barkod ara...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(height: 12),
          // Durum ve Tarih Filtresi
          Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  value: _filterStatus,
                  isExpanded: true,
                  items: ['Tümü', 'Kurutmada', 'Kurutmadan Çıkış']
                      .map((status) => DropdownMenuItem(value: status, child: Text(status)))
                      .toList(),
                  onChanged: (value) => setState(() => _filterStatus = value ?? 'Tümü'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
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
                        _filterEndDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
                      });
                    }
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: const Text('Tarih'),
                ),
              ),
              if (_filterStartDate != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() {
                    _filterStartDate = null;
                    _filterEndDate = null;
                  }),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListViewFromData(List<Map<String, dynamic>> items, {required bool isAdmin, required bool isOnline}) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: items.map((data) {
        final cartNumber = (data['cartNumber'] ?? '').toString();
        final documentId = (data['id'] ?? '').toString();
        return _buildCard(cartNumber, documentId, data, isAdmin: isAdmin, isOnline: isOnline);
      }).toList(),
    );
  }

  Widget _buildCard(String cartNumber, String documentId, Map<String, dynamic> data, {required bool isAdmin, required bool isOnline}) {
    final dryingInRaw = data['dryingIn'];
    final dryingIn = dryingInRaw is Timestamp 
      ? dryingInRaw.toDate() 
      : (dryingInRaw is int 
        ? DateTime.fromMillisecondsSinceEpoch(dryingInRaw) 
        : null);
    
    final dryingOutRaw = data['dryingOut'];
    final dryingOut = dryingOutRaw is Timestamp 
      ? dryingOutRaw.toDate() 
      : (dryingOutRaw is int 
        ? DateTime.fromMillisecondsSinceEpoch(dryingOutRaw) 
        : null);

    // Durum ve renk belirleme
    final String status = (data['status'] ?? '').toString();
    final bool isFirinda = status.toLowerCase().contains('fır');
    final bool isExit = status.toLowerCase().contains('çık');
    final bool isEntry = status.toLowerCase().contains('kurut') && !isExit && !isFirinda;

    late Color iconColor, bgColor, borderColor, textColor;
    if (isFirinda) {
      // Fırında: kırmızı
      iconColor = Colors.red[400]!;
      bgColor = Colors.red[50]!;
      borderColor = Colors.red[400]!;
      textColor = Colors.red[800]!;
    } else if (isExit) {
      // Kurutmadan Çıkış: koyu turuncu
      iconColor = Colors.deepOrange[400]!;
      bgColor = Colors.deepOrange[50]!;
      borderColor = Colors.deepOrange[400]!;
      textColor = Colors.deepOrange[800]!;
    } else {
      // Kurutmada: turuncu
      iconColor = Colors.orange[400]!;
      bgColor = Colors.orange[50]!;
      borderColor = Colors.orange[400]!;
      textColor = Colors.orange[800]!;
    }
    final String displayStatus = status;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isOnline
            ? () {
                if (_userRole == 'admin') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OvenFormScreen(
                        barcode: cartNumber,
                        documentId: documentId,
                        userEmail: FirebaseAuth.instance.currentUser?.email ?? '',
                        isAdmin: true,
                      ),
                    ),
                  );
                } else if (_userRole == 'Fırın Sorumlusu') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OvenFormScreen(
                        barcode: cartNumber,
                        documentId: documentId,
                        userEmail: FirebaseAuth.instance.currentUser?.email ?? '',
                      ),
                    ),
                  );
                }
              }
            : null,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(
                color: borderColor,
                width: 5,
              ),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.local_fire_department, color: iconColor, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Barkod: $cartNumber',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ürün: ${data['product'] ?? 'N/A'} - ${data['color'] ?? 'N/A'}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Durum: $displayStatus',
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderColor, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: borderColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.whatshot, color: iconColor, size: 20),
                        const SizedBox(height: 2),
                        Text(
                          isOnline ? displayStatus : 'Çevrimdışı',
                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Giriş: ${dryingIn != null ? DateFormat('dd/MM HH:mm').format(dryingIn) : 'N/A'}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Çıkış: ${dryingOut != null ? DateFormat('dd/MM HH:mm').format(dryingOut) : 'N/A'}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                  if (isAdmin && isOnline)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _showDeleteConfirmationDialog(documentId),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog(String docId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Kaydı Sil'),
          content: const Text('Bu kaydı kalıcı olarak silmek istediğinizden emin misiniz?'),
          actions: <Widget>[
            TextButton(
              child: const Text('İptal'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Sil', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('cart_records').doc(docId).delete();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
