import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EmptyCartListScreen extends StatefulWidget {
  const EmptyCartListScreen({super.key});

  @override
  State<EmptyCartListScreen> createState() => _EmptyCartListScreenState();
}

class _EmptyCartListScreenState extends State<EmptyCartListScreen> {
  DateTime? _selectedDate;

  void _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  bool _matchesDateFilter(Timestamp? addedAt) {
    if (_selectedDate == null || addedAt == null) return true;
    final date = addedAt.toDate();
    return date.year == _selectedDate!.year &&
           date.month == _selectedDate!.month &&
           date.day == _selectedDate!.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Boş Araba Listesi'),
        backgroundColor: Colors.purple[400],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[100],
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_selectedDate == null ? 'Tarih Seç' : DateFormat('dd/MM/yyyy').format(_selectedDate!)),
                  ),
                ),
                if (_selectedDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _selectedDate = null),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('empty_carts')
                  .snapshots(),
              builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          var allDocs = snapshot.data?.docs ?? [];
          // Hafızada addedAt'e göre sırala
          allDocs = (allDocs).toList();
          (allDocs as List).sort((a, b) {
            final aTime = ((a as QueryDocumentSnapshot).data() as Map<String, dynamic>)['addedAt'] as Timestamp?;
            final bTime = ((b as QueryDocumentSnapshot).data() as Map<String, dynamic>)['addedAt'] as Timestamp?;
            final aDate = aTime?.toDate() ?? DateTime.now();
            final bDate = bTime?.toDate() ?? DateTime.now();
            return bDate.compareTo(aDate);
          });
          final filteredDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final addedAt = data['addedAt'] as Timestamp?;
            return _matchesDateFilter(addedAt);
          }).toList();

          if (filteredDocs.isEmpty) {
            return const Center(
              child: Text(
                'Henüz boş araba kaydı yok',
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          return ListView.builder(
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) {
              final data = filteredDocs[index].data() as Map<String, dynamic>;
              final barcode = data['barcode'] ?? 'N/A';
              final cartType = data['cartType'] ?? 'N/A';
              final addedAt = data['addedAt'] as Timestamp?;
              final dateStr = addedAt != null 
                  ? DateFormat('dd/MM/yyyy HH:mm').format(addedAt.toDate())
                  : 'N/A';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.purple[400],
                    child: const Icon(Icons.shopping_cart, color: Colors.white),
                  ),
                  title: Text(
                    'Barkod: $barcode',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Araba Tipi: $cartType'),
                      Text('Eklenme: $dateStr'),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteEmptyCart(context, filteredDocs[index].id),
                  ),
                ),
              );
            },
          );
        },
      ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.purple[50],
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('empty_carts').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                
                final allDocs = snapshot.data!.docs;
                final filteredCount = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final addedAt = data['addedAt'] as Timestamp?;
                  return _matchesDateFilter(addedAt);
                }).length;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.info_outline, color: Colors.purple),
                    const SizedBox(width: 8),
                    Text(
                      'Toplam: $filteredCount barkod',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEmptyCart(BuildContext context, String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Silme Onayı'),
        content: const Text('Bu boş araba kaydını silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('empty_carts').doc(docId).delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kayıt silindi'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
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
}
