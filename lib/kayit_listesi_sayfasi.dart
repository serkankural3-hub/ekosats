import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ekosatsss/auth_service.dart';
import 'package:intl/intl.dart';
import 'package:ekosatsss/models/item_model.dart';

class KayitListesiSayfasi extends StatefulWidget {
  final bool isAdminLoggedIn; // Yeni parametre: Özel admin girişi yapılıp yapılmadığını belirtir.

  const KayitListesiSayfasi({super.key, this.isAdminLoggedIn = false}); // Varsayılan olarak false

  @override
  State<KayitListesiSayfasi> createState() => _KayitListesiSayfasiState();
}

class _KayitListesiSayfasiState extends State<KayitListesiSayfasi> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  String? _userRole;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final role = await _authService.getUserRole(user.uid);
      if (mounted) {
        setState(() {
        _userRole = role;
        _userEmail = user.email?.toLowerCase();
      });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kaydedilen Veriler'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pres Verileri', icon: Icon(Icons.compress)),
              Tab(text: 'Fırın Verileri', icon: Icon(Icons.whatshot)),
            ],
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
        ),
        body: _userRole == null
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildItemsList(),
                  _buildOvenItemsList(),
                ],
              ),
      ),
    );
  }

  Widget _buildItemsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('items')
          .orderBy('dateTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Bir hata oluştu: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Henüz "Pres Verileri" için kaydedilmiş veri bulunmuyor.'));
        }

        return ListView(
          padding: const EdgeInsets.all(8.0),
          children: snapshot.data!.docs.map((DocumentSnapshot document) {
            final data = document.data() as Map<String, dynamic>;
            final dateTimeTs = data['dateTime'] as Timestamp?;
            final dateTime = dateTimeTs?.toDate() ?? DateTime.now();
            final item = Item(
              id: document.id,
              cartType: (data['cartType'] ?? '').toString(),
              productType: (data['productType'] ?? '').toString(),
              dateTime: dateTime,
              status: (data['status'] ?? '').toString(),
              productQuantity: data['productQuantity'] is int ? data['productQuantity'] : int.tryParse(data['productQuantity']?.toString() ?? '0') ?? 0,
              workOrder: (data['workOrder'] ?? '').toString(),
              description: (data['description'] ?? '').toString(),
              responsible: (data['responsible'] ?? '').toString(),
            );

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                title: Text('Barkod: ${item.id}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ürün: ${item.productType}'),
                    Text('İş Emri: ${item.workOrder}'),
                    Text('Tarih: ${DateFormat('dd/MM/yyyy HH:mm').format(item.dateTime)}'),
                    Text('Sorumlu: ${item.responsible}'),
                  ],
                ),
                trailing: AuthService.canManageRecordsByEmail(_userEmail)
                    ? IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _showDeleteConfirmationDialog('items', document.id),
                      )
                    : null,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildOvenItemsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('oven_items')
          .orderBy('ovenProcessDate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Bir hata oluştu: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Henüz "Fırın Verileri" için kaydedilmiş veri bulunmuyor.'));
        }

        return ListView(
          padding: const EdgeInsets.all(8.0),
          children: snapshot.data!.docs.map((DocumentSnapshot document) {
            final data = document.data() as Map<String, dynamic>;
            final date = (data['ovenProcessDate'] as Timestamp?)?.toDate();

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                title: Text('Barkod: ${document.id}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kurutma Giriş: ${data['dryingIn'] ?? 'N/A'}'),
                    Text('Kurutma Çıkış: ${data['dryingOut'] ?? 'N/A'}'),
                    if (date != null)
                      Text('Tarih: ${DateFormat('dd/MM/yyyy HH:mm').format(date)}'),
                    Text('Sorumlu: ${data['ovenResponsible'] ?? 'N/A'}'),
                  ],
                ),
                trailing: AuthService.canManageRecordsByEmail(_userEmail)
                    ? IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _showDeleteConfirmationDialog('oven_items', document.id),
                      )
                    : null,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(String collection, String docId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Kaydı Sil'),
          content: Text('Bu kaydı kalıcı olarak silmek istediğinizden emin misiniz?'),
          actions: <Widget>[
            TextButton(
              child: const Text('İptal'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Sil', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                await FirebaseFirestore.instance.collection(collection).doc(docId).delete();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

