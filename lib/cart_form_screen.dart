import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import 'package:ekosatsss/services/connectivity_service.dart';
import 'package:ekosatsss/services/offline_cache_service.dart';

class CartFormScreen extends StatefulWidget {
  const CartFormScreen({super.key});

  @override
  State<CartFormScreen> createState() => _CartFormScreenState();
}

class _CartFormScreenState extends State<CartFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cartNumberController = TextEditingController();
  final _cartTypeController = TextEditingController();
  final _productTypeController = TextEditingController();
  final _productQuantityController = TextEditingController();
  final _workOrderController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime _selectedDateTime = DateTime.now();
  String _selectedStatus = 'Yaş İmalat';
  bool _isScanning = false;
  bool _isSaving = false;

  final List<String> _statusOptions = [
    'Yaş İmalat',
    'Kurutmada',
    'Kurutmadan Çıkış',
    'Fırında',
    'Fırından Çıkış',
  ];

  final List<String> _cartTypes = [
    'Tip 1',
    'Tip 2',
    'Tip 3',
    'Özel',
  ];

  final List<String> _productTypes = [
    'Briket',
    'Delikli Tuğla',
    'Düz Tuğla',
    'İzolasyon',
    'Diğer',
  ];

  @override
  void dispose() {
    _cartNumberController.dispose();
    _cartTypeController.dispose();
    _productTypeController.dispose();
    _productQuantityController.dispose();
    _workOrderController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  void _startBarcodeScanning() {
    setState(() {
      _isScanning = true;
    });

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          height: 400,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'Araba Barkodunu Okutun',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: MobileScanner(
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty) {
                      final String code = barcodes.first.rawValue ?? '';
                      if (code.isNotEmpty) {
                        setState(() {
                          _cartNumberController.text = code;
                          _isScanning = false;
                        });
                        Navigator.of(context).pop();
                      }
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isScanning = false;
                  });
                  Navigator.of(context).pop();
                },
                child: const Text('İptal'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      final now = DateTime.now();
      final recordData = {
        'cartNumber': _cartNumberController.text.trim(),
        'cartType': _cartTypeController.text.trim(),
        'productType': _productTypeController.text.trim(),
        'dateTime': Timestamp.fromDate(_selectedDateTime),
        'status': _selectedStatus,
        'productQuantity': int.parse(_productQuantityController.text.trim()),
        'workOrder': _workOrderController.text.trim(),
        'description': _descriptionController.text.trim(),
        'createdBy': user.email ?? 'Bilinmeyen',
        'createdAt': Timestamp.fromDate(now),
      };

      final connectivityService = ConnectivityService();
      final isOnline = await connectivityService.checkConnectivity();
      final cacheService = OfflineCacheService();

      if (isOnline) {
        // Çevrimiçi: Doğrudan Firestore'a yaz
        final docRef = await FirebaseFirestore.instance.collection('cart_records').add(recordData);
        
        // Cache'e de ekle (Timestamp'ı int'e çevir)
        final cachePayload = Map<String, dynamic>.from(recordData);
        cachePayload['dateTime'] = _selectedDateTime.millisecondsSinceEpoch;
        cachePayload['createdAt'] = now.millisecondsSinceEpoch;
        await cacheService.cacheRecord(docRef.id, cachePayload);
      } else {
        // Çevrimdışı: Cache'e ve pending operations'a ekle
        final docId = 'temp_${now.millisecondsSinceEpoch}';
        final cachePayload = Map<String, dynamic>.from(recordData);
        cachePayload['dateTime'] = _selectedDateTime.millisecondsSinceEpoch;
        cachePayload['createdAt'] = now.millisecondsSinceEpoch;
        await cacheService.cacheRecord(docId, cachePayload);
        await cacheService.addPendingOperation(
          operation: 'create',
          collection: 'cart_records',
          documentId: docId,
          data: cachePayload,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isOnline 
              ? 'Kayıt başarıyla oluşturuldu!' 
              : 'Çevrimdışı modda kaydedildi. Çevrimiçi olunca senkronize edilecek.'),
            backgroundColor: Colors.green,
          ),
        );

        // Formu temizle
        _formKey.currentState!.reset();
        _cartNumberController.clear();
        _cartTypeController.clear();
        _productTypeController.clear();
        _productQuantityController.clear();
        _workOrderController.clear();
        _descriptionController.clear();
        setState(() {
          _selectedDateTime = DateTime.now();
          _selectedStatus = 'Yaş İmalat';
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
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Araba Takip Formu'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Araba Numarası (Barkod)
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cartNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Araba No *',
                        border: OutlineInputBorder(),
                        hintText: 'Barkod okutun veya manuel girin',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Araba numarası gerekli';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isScanning ? null : _startBarcodeScanning,
                    icon: const Icon(Icons.qr_code_scanner),
                    tooltip: 'Barkod Okut',
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Araba Çeşidi
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Araba Çeşidi *',
                  border: OutlineInputBorder(),
                ),
                items: _cartTypes.map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _cartTypeController.text = value ?? '';
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Araba çeşidi seçin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Ürün Çeşidi
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Ürün Çeşidi *',
                  border: OutlineInputBorder(),
                ),
                items: _productTypes.map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _productTypeController.text = value ?? '';
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ürün çeşidi seçin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Tarih-Zaman
              InkWell(
                onTap: _selectDateTime,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Tarih-Zaman *',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('dd/MM/yyyy HH:mm')
                          .format(_selectedDateTime)),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Durum
              DropdownButtonFormField<String>(
                initialValue: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Durum *',
                  border: OutlineInputBorder(),
                ),
                items: _statusOptions.map((status) {
                  return DropdownMenuItem(value: status, child: Text(status));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedStatus = value ?? 'Yaş İmalat';
                  });
                },
              ),
              const SizedBox(height: 16),

              // Ürün Adedi
              TextFormField(
                controller: _productQuantityController,
                decoration: const InputDecoration(
                  labelText: 'Ürün Adedi *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ürün adedi gerekli';
                  }
                  if (int.tryParse(value.trim()) == null) {
                    return 'Geçerli bir sayı girin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // İş Emri
              TextFormField(
                controller: _workOrderController,
                decoration: const InputDecoration(
                  labelText: 'İş Emri *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'İş emri gerekli';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Açıklama
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Açıklama',
                  border: OutlineInputBorder(),
                  hintText: 'İsteğe bağlı notlar',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Kaydet Butonu
              ElevatedButton(
                onPressed: _isSaving ? null : _saveRecord,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Kaydet',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


