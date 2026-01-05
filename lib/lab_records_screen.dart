import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LabRecordsScreen extends StatefulWidget {
  const LabRecordsScreen({super.key});

  @override
  State<LabRecordsScreen> createState() => _LabRecordsScreenState();
}

class _LabRecordsScreenState extends State<LabRecordsScreen> {
  String get _currentUserEmail => FirebaseAuth.instance.currentUser?.email ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laborant Kayıtlarım'),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple[50]!, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('cart_records')
              .where('labUserEmail', isEqualTo: _currentUserEmail)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Hata: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.science_outlined, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 20),
                    Text(
                      'Henüz açıklama eklenmemiş',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Barkod okutup açıklama ekleyin',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                ),
              );
            }

            // Client-side sıralama (orderBy için index gerekmez)
            final filteredDocs = snapshot.data!.docs.toList();
            filteredDocs.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aTime = aData['labCheckedAt'];
              final bTime = bData['labCheckedAt'];
              
              if (aTime is Timestamp && bTime is Timestamp) {
                return bTime.compareTo(aTime);
              } else if (aTime is int && bTime is int) {
                return bTime.compareTo(aTime);
              }
              return 0;
            });

            if (filteredDocs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.science_outlined, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 20),
                    Text(
                      'Henüz açıklama eklemediniz',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Barkod okutup açıklama ekleyin',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredDocs.length,
              itemBuilder: (context, index) {
                final doc = filteredDocs[index];
                final data = doc.data() as Map<String, dynamic>;
                final cartNumber = data['cartNumber'] ?? doc.id;
                final product = data['product'] ?? '';
                final color = data['color'] ?? '';
                final productDisplay = product.isNotEmpty && color.isNotEmpty 
                  ? '$product - $color' 
                  : (product.isNotEmpty ? product : (data['productType'] ?? 'Belirtilmemiş'));
                final workOrder = data['workOrder'] ?? '-';
                final labNotes = data['labNotes'] ?? '';
                final labCheckedAt = data['labCheckedAt'];
                
                DateTime? checkedDate;
                if (labCheckedAt is Timestamp) {
                  checkedDate = labCheckedAt.toDate();
                } else if (labCheckedAt is int) {
                  checkedDate = DateTime.fromMillisecondsSinceEpoch(labCheckedAt);
                }

                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.purple[700],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                cartNumber.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (checkedDate != null)
                              Text(
                                _formatDate(checkedDate),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.inventory_2, size: 18, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                productDisplay,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.work_outline, size: 18, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Text(
                              'İş Emri: $workOrder',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        if (labNotes.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.note_alt, size: 18, color: Colors.purple[400]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  labNotes,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}


