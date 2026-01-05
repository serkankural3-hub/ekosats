import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:ekosatsss/models/product_catalog.dart';

class DepotControlFormScreen extends StatefulWidget {
  const DepotControlFormScreen({super.key});

  @override
  State<DepotControlFormScreen> createState() => _DepotControlFormScreenState();
}

class _DepotControlFormScreenState extends State<DepotControlFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Üst kısım alanları
  final _productNameController = TextEditingController();
  String? _selectedProductName;
  String? _selectedProductColor;
  final _sizeController = TextEditingController();
  final _entryBandSpeedController = TextEditingController();
  final _bandSpeedController = TextEditingController();
  final _miterTimeController = TextEditingController();
  final _printTimeController = TextEditingController();
  
  // Çıkan palet (tek)
  final _exitPaletNoController = TextEditingController();

  // Giren palet satırları - her satır bir palet
  final List<Map<String, TextEditingController>> _paletRows = [];

  @override
  void initState() {
    super.initState();
    _addNewRow();
  }

  void _addNewRow() {
    setState(() {
      _paletRows.add({
        'productName': TextEditingController(),
        'totalCount': TextEditingController(),
        'fireCount': TextEditingController(),
        'kirik': TextEditingController(),
        'catlak': TextEditingController(),
        'renk': TextEditingController(),
        'aski': TextEditingController(),
        'kirec': TextEditingController(),
        'kabarma': TextEditingController(),
        'gonye': TextEditingController(),
        'entryPaletNo': TextEditingController(), // Giren palet no
        'paletCount': TextEditingController(),
        'personName': TextEditingController(),
      });
    });
  }

  void _removeRow(int index) {
    if (_paletRows.length > 1) {
      setState(() {
        // Dispose controllers
        for (var controller in _paletRows[index].values) {
          controller.dispose();
        }
        _paletRows.removeAt(index);
      });
    }
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final isDepot = user.email?.toLowerCase() == 'depo@ekos.com';

      // Palet satırlarını kaydet
      final palets = _paletRows.map((row) => {
        'productName': row['productName']!.text,
        'totalCount': int.tryParse(row['totalCount']!.text) ?? 0,
        'fireCount': int.tryParse(row['fireCount']!.text) ?? 0,
        'kirik': int.tryParse(row['kirik']!.text) ?? 0,
        'catlak': int.tryParse(row['catlak']!.text) ?? 0,
        'renk': int.tryParse(row['renk']!.text) ?? 0,
        'aski': int.tryParse(row['aski']!.text) ?? 0,
        'kirec': int.tryParse(row['kirec']!.text) ?? 0,
        'kabarma': int.tryParse(row['kabarma']!.text) ?? 0,
        'gonye': int.tryParse(row['gonye']!.text) ?? 0,
        'entryPaletNo': row['entryPaletNo']!.text, // Giren palet no
        'paletCount': int.tryParse(row['paletCount']!.text) ?? 0,
        'personName': row['personName']!.text,
      }).toList();

      await FirebaseFirestore.instance.collection('depot_control_records').add({
        'productName': _selectedProductName ?? '',
        'productColor': _selectedProductColor ?? '',
        'size': _sizeController.text,
        'entryBandSpeed': _entryBandSpeedController.text,
        'bandSpeed': _bandSpeedController.text,
        'miterTime': _miterTimeController.text,
        'printTime': _printTimeController.text,
        if (isDepot) 'exitPaletNo': _exitPaletNoController.text,
        'palets': palets,
        'userEmail': user.email,
        'createdAt': FieldValue.serverTimestamp(),
        'timestamp': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kayıt başarıyla oluşturuldu')),
        );
        
        // Formu temizle
        _clearForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  void _clearForm() {
    _productNameController.clear();
    _selectedProductName = null;
    _selectedProductColor = null;
    _sizeController.clear();
    _entryBandSpeedController.clear();
    _bandSpeedController.clear();
    _miterTimeController.clear();
    _printTimeController.clear();
    _exitPaletNoController.clear();
    
    setState(() {
      // Tüm satırları temizle
      for (var row in _paletRows) {
        for (var controller in row.values) {
          controller.dispose();
        }
      }
      _paletRows.clear();
      _addNewRow();
    });
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _sizeController.dispose();
    _entryBandSpeedController.dispose();
    _bandSpeedController.dispose();
    _miterTimeController.dispose();
    _printTimeController.dispose();
    _exitPaletNoController.dispose();
    
    for (var row in _paletRows) {
      for (var controller in row.values) {
        controller.dispose();
      }
    }
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDepot = user?.email?.toLowerCase() == 'depo@ekos.com';
    final email = user?.email?.toLowerCase() ?? '';
    final productItems = (email == 'pres@ekos.com') ? ProductCatalog.productWeights.keys.toList() : ProductCatalog.productNames;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Boylandırma Kalite Kontrol Formu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Kullanıcı bilgisi
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  const Icon(Icons.person, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    user?.email ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Üst bilgiler
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Boylandırma Makinesi Ayar Bilgileri',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownSearch<String>(
                                    items: (FirebaseAuth.instance.currentUser?.email?.toLowerCase() == 'pres@ekos.com')
                                        ? ProductCatalog.productWeights.keys.toList()
                                        : productItems,
                                    selectedItem: _selectedProductName,
                                    dropdownDecoratorProps: DropDownDecoratorProps(
                                      dropdownSearchDecoration: InputDecoration(
                                        labelText: 'Ürün Adı',
                                        border: OutlineInputBorder(),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                      ),
                                    ),
                                    onChanged: (value) => setState(() {
                                      _selectedProductName = value;
                                      _selectedProductColor = null;
                                    }),
                                    popupProps: PopupProps.menu(
                                      showSearchBox: true,
                                      searchFieldProps: TextFieldProps(
                                        decoration: InputDecoration(
                                          hintText: 'Ürün ismi ara...',
                                          border: OutlineInputBorder(),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                      ),
                                      fit: FlexFit.loose,
                                    ),
                                    validator: (value) => value?.isEmpty ?? true ? 'Gerekli' : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: DropdownSearch<String>(
                                    items: ProductCatalog.colorsFor(_selectedProductName),
                                    selectedItem: _selectedProductColor,
                                    dropdownDecoratorProps: DropDownDecoratorProps(
                                      dropdownSearchDecoration: InputDecoration(
                                        labelText: 'Renk',
                                        border: OutlineInputBorder(),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                      ),
                                    ),
                                    onChanged: (value) => setState(() => _selectedProductColor = value),
                                    popupProps: PopupProps.menu(
                                      showSearchBox: true,
                                      searchFieldProps: TextFieldProps(
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                      ),
                                      fit: FlexFit.loose,
                                    ),
                                    validator: (value) => value?.isEmpty ?? true ? 'Gerekli' : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _sizeController,
                                    decoration: const InputDecoration(
                                      labelText: 'Boy',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _entryBandSpeedController,
                                    decoration: const InputDecoration(
                                      labelText: 'Giriş Bandı Hızı',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _bandSpeedController,
                                    decoration: const InputDecoration(
                                      labelText: 'Bant Hızı',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _miterTimeController,
                                    decoration: const InputDecoration(
                                      labelText: 'Gönye Zamanı',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _printTimeController,
                                    decoration: const InputDecoration(
                                      labelText: 'Baskı Zamanı',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Giren Palet Tablosu
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Giren Palet Bilgileri',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _addNewRow,
                          icon: const Icon(Icons.add),
                          label: const Text('Yeni Satır'),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Tablo
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _paletRows.length,
                      itemBuilder: (context, index) {
                        return _buildPaletRow(index);
                      },
                    ),
                    
                    if (isDepot) ...[
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _exitPaletNoController,
                              decoration: const InputDecoration(
                                labelText: 'Çıkan Palet No (Tek)',
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Color(0xFFFFEB3B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            // Kaydet butonu
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saveForm,
                      icon: const Icon(Icons.save),
                      label: const Text('Kaydet'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _clearForm,
                    icon: const Icon(Icons.clear),
                    label: const Text('Temizle'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaletRow(int index) {
    final row = _paletRows[index];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Palet ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (_paletRows.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeRow(index),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            // İlk satır
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownSearch<String>(
                    items: ProductCatalog.productNames,
                    selectedItem: row['productName']!.text.isEmpty ? null : row['productName']!.text,
                    dropdownDecoratorProps: DropDownDecoratorProps(
                      dropdownSearchDecoration: InputDecoration(
                        labelText: 'Ürün Adı',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    onChanged: (value) {
                      row['productName']!.text = value ?? '';
                    },
                    popupProps: PopupProps.menu(
                      showSearchBox: true,
                      searchFieldProps: TextFieldProps(
                        decoration: InputDecoration(
                          hintText: 'Ürün ismi ara...',
                          border: OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      fit: FlexFit.loose,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: row['totalCount'],
                    decoration: const InputDecoration(
                      labelText: 'Toplam Adet',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: row['fireCount'],
                    decoration: const InputDecoration(
                      labelText: 'Fire Adet',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // İkinci satır - Hata tipleri
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    controller: row['kirik'],
                    decoration: const InputDecoration(
                      labelText: 'Kırık',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    controller: row['catlak'],
                    decoration: const InputDecoration(
                      labelText: 'Çatlak',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    controller: row['renk'],
                    decoration: const InputDecoration(
                      labelText: 'Renk',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    controller: row['aski'],
                    decoration: const InputDecoration(
                      labelText: 'Askı',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    controller: row['kirec'],
                    decoration: const InputDecoration(
                      labelText: 'Kireç',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    controller: row['kabarma'],
                    decoration: const InputDecoration(
                      labelText: 'Kabarma',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    controller: row['gonye'],
                    decoration: const InputDecoration(
                      labelText: 'Gönye',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Üçüncü satır - Giren palet no (sarı renk)
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: row['entryPaletNo'],
                    decoration: const InputDecoration(
                      labelText: 'Giren Palet No',
                      border: OutlineInputBorder(),
                      isDense: true,
                      fillColor: Color(0xFFFFEB3B),
                      filled: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: row['paletCount'],
                    decoration: const InputDecoration(
                      labelText: 'Palet Adet',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: row['personName'],
                    decoration: const InputDecoration(
                      labelText: 'Y.Kişi İsim',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
