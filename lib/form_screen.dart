import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:ekosatsss/services/connectivity_service.dart';
import 'package:ekosatsss/services/offline_cache_service.dart';
import 'package:ekosatsss/auth_service.dart';
import 'package:ekosatsss/list_screen.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:ekosatsss/models/product_catalog.dart';

class FormScreen extends StatefulWidget {
  final String barcode;
  final String? documentId; // Opsiyonel: spesifik doküman ID'si
  final String userEmail;
  final bool isReadOnly;
  final bool isDescriptionOnlyEditable;
  final String? fixedStatus;
  final bool isAdmin;

  const FormScreen({super.key, required this.barcode, this.documentId, required this.userEmail, this.isReadOnly = false, this.isDescriptionOnlyEditable = false, this.fixedStatus, this.isAdmin = false});

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _forceReadOnly = false;

  final _responsibleController = TextEditingController();
  final _workOrderController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _productQuantityController = TextEditingController();

  String? _selectedCartType;
  String? _selectedProductType; // eski alan (geçici uyumluluk)
  String? _selectedProductName;
  String? _selectedProductColor;
  String? _selectedStatus;
  List<String> _availableProductNames = [];

  final List<String> _cartTypeOptions = ['Ekos', 'Ats'];
  final List<String> _statusOptions = ['Yaş İmalat', 'Fırın', 'Paketleme', 'Tamamlandı'];

  @override
  void initState() {
    super.initState();
    _responsibleController.text = widget.userEmail;
    // Use canonical product list for pres@ekos.com, otherwise use productToColors keys
    final email = widget.userEmail.toLowerCase();
    _availableProductNames = (email == 'pres@ekos.com')
        ? ProductCatalog.productWeights.keys.toList()
        : ProductCatalog.productNames;
    _determineModeAndLoad();
  }

  Future<void> _determineModeAndLoad() async {
    if (widget.fixedStatus != null) {
      // fixedStatus varsa: YENİ kayıt modu - eski verileri yükleme
      _selectedStatus = widget.fixedStatus;
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    if (widget.isReadOnly || widget.isDescriptionOnlyEditable) {
      await _loadItemData();
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadItemData() async {
    try {
      DocumentSnapshot doc;
      
      // Eğer documentId verilmişse, direkt onu kullan
      if (widget.documentId != null) {
        doc = await FirebaseFirestore.instance.collection('cart_records').doc(widget.documentId).get();
      } else {
        // Yoksa eski davranış: önce barcode doc ID olarak dene
        doc = await FirebaseFirestore.instance.collection('cart_records').doc(widget.barcode).get();
        
        // Eğer doc yoksa (barcode doğrudan doc ID değilse), cartNumber'dan ara
        if (!doc.exists) {
          final query = await FirebaseFirestore.instance
              .collection('cart_records')
              .where('cartNumber', isEqualTo: widget.barcode)
              .orderBy('createdAt', descending: true)
              .limit(1)
              .get();
          
          if (query.docs.isNotEmpty) {
            doc = query.docs.first;
          }
        }
      }
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _selectedCartType = data['cartType'] as String?;
        _selectedProductType = data['productType'] as String?;

        // Yeni ürün alanları: tercih sırası -> 'product' then 'productType'
        final prod = (data['product'] as String?)?.trim();
        final ptype = (data['productType'] as String?)?.trim();
        _selectedProductName = (prod != null && prod.isNotEmpty) ? prod : ptype;
        _selectedProductColor = (data['color'] as String?)?.trim();
        
        _productQuantityController.text = (data['productQuantity'] ?? '').toString();
        _workOrderController.text = data['workOrder'] ?? '';
        _descriptionController.text = data['description'] ?? '';
        _responsibleController.text = data['createdBy'] ?? widget.userEmail;
        _selectedStatus = data['status'] as String?;
        
        // Status dropdown'a eklenmemiş bir değerse, onu da ekle
        if (_selectedStatus != null && !_statusOptions.contains(_selectedStatus)) {
          _statusOptions.add(_selectedStatus!);
        }

        // Pres@ekos.com kullanıcısı kontrol: sadece "Yaş İmalat" ve "Boş Araba" düzenleyebilir
        final currentUser = FirebaseAuth.instance.currentUser?.email;
        if (currentUser?.toLowerCase() == 'pres@ekos.com') {
          final status = (_selectedStatus ?? '').toLowerCase();
          if (!status.contains('yaş') && !status.contains('boş')) {
            if (mounted) {
              setState(() {
                _forceReadOnly = true;
              });
            }
          }
        }
      }
    } catch (e) {
      // ignore
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveForm() async {
    // Check for required fields before form validation
    if (!widget.isDescriptionOnlyEditable) {
      // Validate that all required fields are filled
      if (_selectedCartType == null || _selectedCartType!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Araba Çeşidi seçiniz'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      if (_selectedProductName == null || _selectedProductName!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ürün İsmi seçiniz'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      if (_selectedProductColor == null || _selectedProductColor!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Renk seçiniz'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      if (_selectedStatus == null || _selectedStatus!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Durum seçiniz'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      if (_productQuantityController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ürün Adedi giriniz'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      if (_workOrderController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('İş Emri giriniz'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    if (widget.isDescriptionOnlyEditable) {
      await _updateDescription();
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
      return;
    }

    final connectivity = Provider.of<ConnectivityService>(context, listen: false);
    final cache = Provider.of<OfflineCacheService>(context, listen: false);

    final statusToSave = widget.fixedStatus ?? _selectedStatus ?? '';
    final now = DateTime.now();
    final payload = {
      'cartNumber': widget.barcode,
      'cartType': _selectedCartType ?? '',
      'productType': _selectedProductType ?? '',
      'product': _selectedProductName ?? '',
      'color': _selectedProductColor ?? '',
      'dateTime': Timestamp.fromDate(now),
      'status': statusToSave,
      'productQuantity': int.tryParse(_productQuantityController.text) ?? 0,
      'workOrder': _workOrderController.text,
      'description': _descriptionController.text,
      'createdBy': widget.userEmail,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    };

    try {
      final isOnline = await connectivity.checkConnectivity();

      if (isOnline) {
        // Auto-generated ID kullan, her seferinde yeni kayıt oluştur
        final docRef = await FirebaseFirestore.instance.collection('cart_records').add(payload);
        // Cache'e kaydet
        payload['id'] = docRef.id;
        final cachePayload = Map<String, dynamic>.from(payload);
        cachePayload['dateTime'] = now.millisecondsSinceEpoch;
        cachePayload['createdAt'] = now.millisecondsSinceEpoch;
        cachePayload['updatedAt'] = now.millisecondsSinceEpoch;
        await cache.cacheRecord(docRef.id, cachePayload);
      } else {
        // Offline: Geçici ID ile cache'e kaydet
        final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
        payload['id'] = tempId;
        final cachePayload = Map<String, dynamic>.from(payload);
        cachePayload['dateTime'] = now.millisecondsSinceEpoch;
        cachePayload['createdAt'] = now.millisecondsSinceEpoch;
        cachePayload['updatedAt'] = now.millisecondsSinceEpoch;
        await cache.cacheRecord(tempId, cachePayload);
        await cache.addPendingOperation(
          operation: 'add',
          collection: 'cart_records',
          documentId: tempId,
          data: cachePayload,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isOnline ? 'Kaydedildi' : 'Çevrimdışı kaydedildi', style: TextStyle(color: Colors.white)),
            backgroundColor: isOnline ? Theme.of(context).primaryColor : Colors.orange,
          ),
        );
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ListScreen()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e', style: TextStyle(color: Colors.white)),
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

  Future<void> _updateDescription() async {
    final newDescription = _descriptionController.text.trim();

    if (newDescription.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Açıklama boş bırakılamaz'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('cart_records')
          .doc(widget.barcode)
          .update({
        'description': newDescription,
        'descriptionHistory': FieldValue.arrayUnion([
          {
            'text': newDescription,
            'addedBy': widget.userEmail,
            'addedAt': Timestamp.now(),
          }
        ]),
        'lastDescriptionUpdate': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Açıklama kaydedildi'),
            backgroundColor: Colors.green,
          ),
        );
        _descriptionController.clear();
        setState(() {});
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
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Yükleniyor...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final bool isReadOnlyMode = widget.isReadOnly || _forceReadOnly || widget.isDescriptionOnlyEditable;

    return Scaffold(
      appBar: AppBar(
        title: Text('Barkod: ${widget.barcode}'),
        backgroundColor: Colors.brown[700],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.isDescriptionOnlyEditable) ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedCartType,
                  decoration: InputDecoration(
                    labelText: 'Araba Çeşidi',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                  ),
                  items: _cartTypeOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: isReadOnlyMode ? null : (value) => setState(() => _selectedCartType = value),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Araba Çeşidi seçiniz';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Ürün İsmi (aramalı)
                DropdownSearch<String>(
                  items: (FirebaseAuth.instance.currentUser?.email?.toLowerCase() == 'pres@ekos.com')
                      ? ProductCatalog.productWeights.keys.toList()
                      : _availableProductNames,
                  selectedItem: _selectedProductName,
                  enabled: !isReadOnlyMode,
                  dropdownDecoratorProps: DropDownDecoratorProps(
                    dropdownSearchDecoration: InputDecoration(
                      labelText: 'Ürün İsmi',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                  ),
                  onChanged: isReadOnlyMode ? null : (value) => setState(() {
                    _selectedProductName = value;
                    // Ürün ismi değişince rengi sıfırla
                    _selectedProductColor = null;
                  }),
                  popupProps: PopupProps.menu(
                    showSearchBox: true,
                    searchFieldProps: TextFieldProps(
                      decoration: InputDecoration(
                        hintText: 'Ürün ismi ara...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    fit: FlexFit.loose,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ürün İsmi seçiniz';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                // Renk (aramalı, ürüne bağlı)
                DropdownSearch<String>(
                  items: ProductCatalog.colorsFor(_selectedProductName),
                  selectedItem: _selectedProductColor,
                  enabled: !isReadOnlyMode,
                  dropdownDecoratorProps: DropDownDecoratorProps(
                    dropdownSearchDecoration: InputDecoration(
                      labelText: 'Renk',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                  ),
                  onChanged: isReadOnlyMode ? null : (value) => setState(() => _selectedProductColor = value),
                  popupProps: PopupProps.menu(
                    showSearchBox: true,
                    searchFieldProps: TextFieldProps(
                      decoration: InputDecoration(
                        hintText: 'Renk ara...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    fit: FlexFit.loose,
                  ),
                  validator: (value) {
                    final colors = ProductCatalog.colorsFor(_selectedProductName);
                    if (colors.isNotEmpty && (value == null || value.isEmpty)) {
                      return 'Renk seçiniz';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedStatus,
                  decoration: InputDecoration(
                    labelText: 'Durum',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                  ),
                  items: _statusOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (isReadOnlyMode || widget.fixedStatus != null) ? null : (value) => setState(() => _selectedStatus = value),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Durum seçiniz';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _productQuantityController,
                  decoration: InputDecoration(
                    labelText: 'Ürün Adedi',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                  ),
                  keyboardType: TextInputType.number,
                  readOnly: isReadOnlyMode,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ürün Adedi giriniz';
                    }
                    final number = int.tryParse(value);
                    if (number == null || number <= 0) {
                      return 'Geçerli bir sayı giriniz';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _workOrderController,
                  decoration: InputDecoration(
                    labelText: 'İş Emri',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                  ),
                  readOnly: isReadOnlyMode,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'İş Emri giriniz';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Açıklama',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
                maxLines: 4,
                readOnly: widget.isReadOnly || _forceReadOnly,
              ),
              const SizedBox(height: 16),
              if (!widget.isDescriptionOnlyEditable) ...[
                TextFormField(
                  controller: _responsibleController,
                  decoration: InputDecoration(
                    labelText: 'Sorumlu',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                  ),
                  readOnly: true,
                ),
                const SizedBox(height: 16),
              ],
              if (!widget.isReadOnly && !_forceReadOnly)
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveForm,
                  icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Kaydediliyor...' : 'Kaydet'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.brown[700],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _responsibleController.dispose();
    _workOrderController.dispose();
    _descriptionController.dispose();
    _productQuantityController.dispose();
    super.dispose();
  }
}
