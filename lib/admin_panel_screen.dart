import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ekosatsss/models/cart_model.dart';
import 'package:intl/intl.dart';
import 'package:ekosatsss/empty_cart_list_screen.dart';
import 'package:ekosatsss/process_fire_records_screen.dart';
import 'package:ekosatsss/depot_control_records_screen.dart';
import 'package:ekosatsss/reports_analytics_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const AdminDashboardTab(),
    const AdminCartRecordsTab(),
    const EmptyCartListScreen(),
    const ProcessFireRecordsScreen(),
    const DepotControlRecordsScreen(),
    // ReportsAnalyticsScreen removed
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Paneli'),
        backgroundColor: Colors.red[400],
        foregroundColor: Colors.white,
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Gösterge Paneli',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car),
            label: 'Araba Kayıtları',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Boş Arabalar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fire_truck),
            label: 'Fire Kayıtları',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2),
            label: 'Depo Kontrol',
          ),
          // 'Raporlar' tab removed
        ],
      ),
    );
  }
}

// Gösterge Paneli
class AdminDashboardTab extends StatelessWidget {
  const AdminDashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Genel İstatistikler',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // İstatistik kartları
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('cart_records')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final records = snapshot.data!.docs;
              final total = records.length;
              final today = DateTime.now();
              final todayRecords = records.where((doc) {
                final dateTime = (doc.data()
                    as Map<String, dynamic>)['dateTime'] as Timestamp;
                final recordDate = dateTime.toDate();
                return recordDate.year == today.year &&
                    recordDate.month == today.month &&
                    recordDate.day == today.day;
              }).length;

              // Durum bazlı istatistikler
              Map<String, int> statusCounts = {};
              for (var doc in records) {
                final status = (doc.data() as Map<String, dynamic>)['status'] ??
                    'Bilinmeyen';
                statusCounts[status] = (statusCounts[status] ?? 0) + 1;
              }

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Toplam Kayıt',
                          total.toString(),
                          Icons.list_alt,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Bugünkü Kayıtlar',
                          todayRecords.toString(),
                          Icons.today,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Durum istatistikleri
                  const Text(
                    'Durum Bazlı İstatistikler',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...statusCounts.entries.map((entry) {
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(entry.value.toString()),
                        ),
                        title: Text(entry.key),
                        trailing: Text(
                          '${((entry.value / total) * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Kullanıcı istatistikleri
          const Text(
            'Kullanıcı İstatistikleri',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const CircularProgressIndicator();
              }

              final users = snapshot.data!.docs;
              final totalUsers = users.length;

              Map<String, int> roleCounts = {};
              for (var doc in users) {
                final role =
                    (doc.data() as Map<String, dynamic>)['role'] ?? 'user';
                roleCounts[role] = (roleCounts[role] ?? 0) + 1;
              }

              return Column(
                children: [
                  _buildStatCard(
                    'Toplam Kullanıcı',
                    totalUsers.toString(),
                    Icons.people,
                    Colors.orange,
                  ),
                  const SizedBox(height: 8),
                  ...roleCounts.entries.map((entry) {
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(entry.key),
                        trailing: Text(
                          entry.value.toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          // Raporlar butonu (adminler için)
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (c) => const ReportsAnalyticsScreen()));
            },
            child: _buildStatCard('Raporlar', '', Icons.bar_chart, Colors.teal),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Araba Kayıtları Düzenleme
class AdminCartRecordsTab extends StatefulWidget {
  const AdminCartRecordsTab({super.key});

  @override
  State<AdminCartRecordsTab> createState() => _AdminCartRecordsTabState();
}

class _AdminCartRecordsTabState extends State<AdminCartRecordsTab> {
  String _searchQuery = '';
  String _filterStatus = 'Tümü';

  final List<String> _statusOptions = [
    'Tümü',
    'Yaş İmalat',
    'Kurutmada',
    'Kurutmadan Çıkış',
    'Fırında',
    'Fırından Çıkış',
  ];

  Future<void> _deleteRecord(String recordId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kayıt Sil'),
        content: const Text('Bu kaydı silmek istediğinizden emin misiniz?'),
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
            .doc(recordId)
            .delete();
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
  }

  Future<void> _editRecord(CartRecord record) async {
    // Düzenleme formu
    final formKey = GlobalKey<FormState>();
    final cartTypeController = TextEditingController(text: record.cartType);
    final productTypeController =
        TextEditingController(text: record.productType);
    final productQuantityController =
        TextEditingController(text: record.productQuantity.toString());
    final workOrderController = TextEditingController(text: record.workOrder);
    final descriptionController =
        TextEditingController(text: record.description);
    String selectedStatus = record.status;

    final List<String> statusOptions = [
      'Yaş İmalat',
      'Kurutmada',
      'Kurutmadan Çıkış',
      'Fırında',
      'Fırından Çıkış',
    ];

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Araba ${record.cartNumber} Düzenle'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: cartTypeController,
                  decoration: const InputDecoration(labelText: 'Araba Çeşidi'),
                  validator: (v) => v?.isEmpty == true ? 'Gerekli' : null,
                ),
                TextFormField(
                  controller: productTypeController,
                  decoration: const InputDecoration(labelText: 'Ürün Çeşidi'),
                  validator: (v) => v?.isEmpty == true ? 'Gerekli' : null,
                ),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(labelText: 'Durum'),
                  items: statusOptions
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => selectedStatus = v!,
                ),
                TextFormField(
                  controller: productQuantityController,
                  decoration: const InputDecoration(labelText: 'Ürün Adedi'),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      int.tryParse(v ?? '') == null ? 'Sayı girin' : null,
                ),
                TextFormField(
                  controller: workOrderController,
                  decoration: const InputDecoration(labelText: 'İş Emri'),
                  validator: (v) => v?.isEmpty == true ? 'Gerekli' : null,
                ),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Açıklama'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  await FirebaseFirestore.instance
                      .collection('cart_records')
                      .doc(record.id)
                      .update({
                    'cartType': cartTypeController.text.trim(),
                    'productType': productTypeController.text.trim(),
                    'status': selectedStatus,
                    'productQuantity':
                        int.parse(productQuantityController.text.trim()),
                    'workOrder': workOrderController.text.trim(),
                    'description': descriptionController.text.trim(),
                  });
                  Navigator.pop(context);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Kayıt güncellendi'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Hata: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Araba No veya İş Emri Ara...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: DropdownButtonFormField<String>(
            initialValue: _filterStatus,
            decoration: const InputDecoration(
              labelText: 'Durum',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: _statusOptions
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _filterStatus = v);
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('cart_records')
                .orderBy('dateTime', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              var records = snapshot.data!.docs
                  .map((doc) => CartRecord.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
                  .toList();

              if (_searchQuery.isNotEmpty) {
                records = records.where((r) {
                  final query = _searchQuery.toLowerCase();
                  return r.cartNumber.toLowerCase().contains(query) ||
                      r.workOrder.toLowerCase().contains(query);
                }).toList();
              }

              // Durum filtresi uygula (admin için sadece belirli durumlar gösterilir)
              if (_filterStatus != 'Tümü') {
                records = records.where((r) {
                  final status = r.status.toLowerCase();
                  switch (_filterStatus) {
                    case 'Yaş İmalat':
                      return status == 'yaş imalat';
                    case 'Kurutmada':
                      return status.contains('kurut') && !status.contains('çık');
                    case 'Kurutmadan Çıkış':
                      return status.contains('çık');
                    case 'Fırında':
                      return status.contains('fır') && !status.contains('çık');
                    case 'Fırından Çıkış':
                      return status.contains('fır') && status.contains('çık');
                  }
                  return true;
                }).toList();
              }

              if (records.isEmpty) {
                return const Center(child: Text('Kayıt bulunamadı'));
              }

              return ListView.builder(
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final record = records[index];
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(record.cartNumber),
                      ),
                      title: Text(
                          'Araba ${record.cartNumber} - ${record.productType}'),
                      subtitle: Text(
                        '${DateFormat('dd/MM/yyyy HH:mm').format(record.dateTime)} - ${record.status}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _editRecord(record),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteRecord(record.id),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

