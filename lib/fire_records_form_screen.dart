import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class FireRecordsFormScreen extends StatefulWidget {
  final String barcode;
  final String? documentId; // Opsiyonel: spesifik döküman ID'si
  final String userEmail;

  const FireRecordsFormScreen({
    super.key,
    required this.barcode,
    this.documentId,
    required this.userEmail,
  });

  @override
  State<FireRecordsFormScreen> createState() => _FireRecordsFormScreenState();
}

class _FireRecordsFormScreenState extends State<FireRecordsFormScreen> {
  late TextEditingController _fireCountController;
  bool _isLoading = false;
  Map<String, dynamic>? _cartData;

  @override
  void initState() {
    super.initState();
    _fireCountController = TextEditingController();
    _loadCartData();
  }

  @override
  void dispose() {
    _fireCountController.dispose();
    super.dispose();
  }

  Future<void> _loadCartData() async {
    try {
      DocumentSnapshot doc;
      
      // Eğer documentId verilmişse, direkt onu kullan
      if (widget.documentId != null) {
        doc = await FirebaseFirestore.instance
            .collection('cart_records')
            .doc(widget.documentId)
            .get();
      } else {
        // Yoksa eski davranış: barcode'u doc ID olarak kullan
        doc = await FirebaseFirestore.instance
            .collection('cart_records')
            .doc(widget.barcode)
            .get();
      }
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final status = (data['status'] ?? '').toString();
        
        // Eğer kayıt "Fırından Çıkış" durumundaysa, işlem yapılmasın
        if (status == 'Fırından Çıkış') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Bu araba zaten "Fırından Çıkış" durumunda. Geçmiş kayıt üzerinde işlem yapılamaz.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
            Navigator.pop(context);
          }
          return;
        }
        
        setState(() {
          _cartData = data;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveFireRecord() async {
    // Fire sayısı boşsa 0 olarak kaydet
    int fireCount = 0;
    if (_fireCountController.text.isNotEmpty) {
      fireCount = int.tryParse(_fireCountController.text) ?? 0;
    }

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

      // Fire kayıtını Firestore'a kaydet
      final productName = _cartData?['product'] ?? '';
      final color = _cartData?['color'] ?? '';
      final productDisplay = color.isNotEmpty ? '$productName - $color' : productName;
      
      await FirebaseFirestore.instance
          .collection('fire_records')
          .add({
        'barcode': widget.barcode,
        'fire_count': fireCount,
        'user_email': widget.userEmail,
        'timestamp': timestamp,
        'created_at': FieldValue.serverTimestamp(),
        'product_name': productDisplay,
        'quantity': _cartData?['productQuantity'] ?? 0,
      });

      // Araba durumunu "Fırında" olarak güncelle
      final docId = widget.documentId ?? widget.barcode;
      await FirebaseFirestore.instance
          .collection('cart_records')
          .doc(docId)
          .update({
        'status': 'Fırında',
        'ovenEntryTime': Timestamp.now(),
        'last_updated': timestamp,
        'last_updated_by': widget.userEmail,
      });

      // Boş araba listesine ekle
      await FirebaseFirestore.instance.collection('empty_carts').add({
        'barcode': _cartData?['cartNumber'] ?? widget.barcode,
        'cartType': _cartData?['cartType'] ?? '',
        'addedAt': Timestamp.now(),
        'addedBy': widget.userEmail,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fire kaydı başarıyla kaydedildi, araba durumu "Fırında" olarak güncellendi ve boş araba listesine eklendi'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fire Kaydı'),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Barkod bilgisi
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Barkod: ${widget.barcode}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_cartData != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Ürün: ${_cartData?['product'] ?? 'N/A'}${_cartData?['color'] != null && (_cartData?['color'] as String).isNotEmpty ? ' - ${_cartData?['color']}' : ''}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      Text(
                        'Miktar: ${_cartData?['productQuantity'] ?? 'N/A'}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Fire sayısı input
            const Text(
              'Fire Sayısı',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _fireCountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Fire sayısını giriniz (boşsa 0 olarak kaydedilecek)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 32),

            // Kaydet butonu
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveFireRecord,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  disabledBackgroundColor: Colors.grey,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Kaydet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
