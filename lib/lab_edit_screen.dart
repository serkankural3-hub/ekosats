import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:ekosatsss/services/connectivity_service.dart';
import 'package:ekosatsss/services/offline_cache_service.dart';

class LabEditScreen extends StatefulWidget {
  final String docId;
  final String barcode;
  final Map<String, dynamic> recordData;

  const LabEditScreen({
    super.key,
    required this.docId,
    required this.barcode,
    required this.recordData,
  });

  @override
  State<LabEditScreen> createState() => _LabEditScreenState();
}

class _LabEditScreenState extends State<LabEditScreen> {
  late TextEditingController _labNotesController;

  // Timestamp alanlarını milliseconds'a çevir
  Map<String, dynamic> _sanitizeDataForCache(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);
    result.forEach((key, value) {
      if (value is Timestamp) {
        result[key] = value.millisecondsSinceEpoch;
      }
    });
    return result;
  }
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    
    // Güvenlik: Sadece pres tarafından oluşturulan kayıtlar işlenebilir
    final createdBy = (widget.recordData['createdBy'] ?? '').toString().toLowerCase();
    if (!createdBy.contains('pres')) {
      Future.delayed(Duration.zero, () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bu kayıt pres tarafından oluşturulmamış! İşlem iptal edildi.'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context);
        }
      });
    }
    
    _labNotesController = TextEditingController(
      text: widget.recordData['labNotes'] ?? '',
    );
  }

  @override
  void dispose() {
    _labNotesController.dispose();
    super.dispose();
  }

  Future<void> _saveLab() async {
    if (_labNotesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Açıklama boş bırakılamaz'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final connectivityService = ConnectivityService();
    final cacheService = OfflineCacheService();
    final isOnline = await connectivityService.checkConnectivity();

    try {
      final currentUserEmail = FirebaseAuth.instance.currentUser?.email ?? '';
      final now = Timestamp.now();
      final nowMillis = DateTime.now().millisecondsSinceEpoch;
      
      final payload = {
        'labNotes': _labNotesController.text.trim(),
        'labCheckedAt': now,
        'labUserEmail': currentUserEmail,
        'updatedAt': now,
      };

      if (isOnline) {
        await FirebaseFirestore.instance.collection('cart_records').doc(widget.docId).update(payload);
        
        // Cache'e de ekle (Timestamp yerine milliseconds kullan)
        final currentData = _sanitizeDataForCache(widget.recordData);
        currentData['labNotes'] = _labNotesController.text.trim();
        currentData['labCheckedAt'] = nowMillis;
        currentData['labUserEmail'] = currentUserEmail;
        currentData['updatedAt'] = nowMillis;
        await cacheService.cacheRecord(widget.docId, currentData);
      } else {
        // Çevrimdışı: Cache ve pending
        final currentData = _sanitizeDataForCache(widget.recordData);
        currentData['labNotes'] = _labNotesController.text.trim();
        currentData['labCheckedAt'] = nowMillis;
        currentData['labUserEmail'] = currentUserEmail;
        currentData['updatedAt'] = nowMillis;
        await cacheService.cacheRecord(widget.docId, currentData);
        
        await cacheService.addPendingOperation(
          operation: 'update',
          collection: 'cart_records',
          documentId: widget.docId,
          data: currentData,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isOnline 
              ? 'Açıklama başarıyla kaydedildi' 
              : 'Çevrimdışı kaydedildi, bağlantıda senkronlanacak'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
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

    setState(() {
      _isSaving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = widget.recordData['createdAt'];
    final formattedDate = createdAt != null
        ? DateFormat('dd/MM/yyyy HH:mm').format((createdAt as Timestamp).toDate())
        : 'Tarih belirtilmemiş';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lab Açıklama Ekle'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Pres Formu - Salt Okunur
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pres Formu (Salt Okunur)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD32F2F),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildReadOnlyField('Barkod', widget.recordData['cartNumber'] ?? widget.barcode),
                  _buildReadOnlyField('Ürün', widget.recordData['product'] ?? ''),
                  _buildReadOnlyField('Renk', widget.recordData['color'] ?? ''),
                  _buildReadOnlyField('Oluşturma Tarihi', formattedDate),
                  _buildReadOnlyField('Oluşturan', widget.recordData['createdBy'] ?? 'Belirtilmemiş'),
                  _buildReadOnlyField('Durum', widget.recordData['status'] ?? 'Yaş İmalat'),
                  if (widget.recordData['description'] != null)
                    _buildReadOnlyField('Pres Açıklaması', widget.recordData['description']),
                  if (widget.recordData['quantity'] != null)
                    _buildReadOnlyField('Miktar', widget.recordData['quantity'].toString()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Lab Açıklama - Düzenlenebilir
          const Text(
            'Lab Açıklaması',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFFD32F2F),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _labNotesController,
            maxLines: 6,
            minLines: 4,
            decoration: InputDecoration(
              hintText: 'Lab açıklaması yazınız...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
          ),
          const SizedBox(height: 20),
          // Kaydet Butonu
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveLab,
            icon: _isSaving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  )
                : const Icon(Icons.save),
            label: Text(_isSaving ? 'Kaydediliyor...' : 'Kaydet ve Kapat'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          // İptal Butonu
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
