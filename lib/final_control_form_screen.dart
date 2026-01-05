import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:ekosatsss/models/product_catalog.dart';

class FinalControlFormScreen extends StatefulWidget {
  final String userEmail;

  const FinalControlFormScreen({super.key, required this.userEmail});

  @override
  State<FinalControlFormScreen> createState() => _FinalControlFormScreenState();
}

class _FinalControlFormScreenState extends State<FinalControlFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Üst Kısım Controllers
  final _siraController = TextEditingController();
  final _saatController = TextEditingController();
  final _urunAdiController = TextEditingController();
  final _toplamAdetController = TextEditingController();
  final _fireAdediController = TextEditingController();
  final _kirikController = TextEditingController();
  final _egriController = TextEditingController();
  final _renkController = TextEditingController();
  final _pismeController = TextEditingController();
  final _boyazController = TextEditingController();
  final _kabarmaController = TextEditingController();
  final _olcuController = TextEditingController();
  final _paletNoController = TextEditingController();
  bool _onayChecked = false;
  
  // Numune 1
  bool _numune1SesKontrolChecked = false;
  final _numune1EnController = TextEditingController();
  final _numune1BoyController = TextEditingController();
  final _numune1KalinlikController = TextEditingController();
  
  // Numune 2
  bool _numune2SesKontrolChecked = false;
  final _numune2EnController = TextEditingController();
  final _numune2BoyController = TextEditingController();
  final _numune2KalinlikController = TextEditingController();
  
  // Numune 3
  bool _numune3SesKontrolChecked = false;
  final _numune3EnController = TextEditingController();
  final _numune3BoyController = TextEditingController();
  final _numune3KalinlikController = TextEditingController();
  
  // Onay
  String? _onayNum1Value;
  String? _onayNum2Value;
  String? _onayNum3Value;

  bool _isLoading = false;
  late final List<String> _availableProductNames;
  
  String? _selectedProductType;
  String? _selectedProductColor;

  @override
  void initState() {
    super.initState();
    _saatController.text = DateFormat('HH:mm').format(DateTime.now());
    final email = widget.userEmail.toLowerCase();
    _availableProductNames = (email == 'pres@ekos.com')
        ? ProductCatalog.productWeights.keys.toList()
        : ProductCatalog.productNames;
  }

  @override
  void dispose() {
    _siraController.dispose();
    _saatController.dispose();
    _urunAdiController.dispose();
    _toplamAdetController.dispose();
    _fireAdediController.dispose();
    _kirikController.dispose();
    _egriController.dispose();
    _renkController.dispose();
    _pismeController.dispose();
    _boyazController.dispose();
    _kabarmaController.dispose();
    _olcuController.dispose();
    _paletNoController.dispose();
    _numune1EnController.dispose();
    _numune1BoyController.dispose();
    _numune1KalinlikController.dispose();

    _numune2EnController.dispose();
    _numune2BoyController.dispose();
    _numune2KalinlikController.dispose();

    _numune3EnController.dispose();
    _numune3BoyController.dispose();
    _numune3KalinlikController.dispose();

    super.dispose();
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance.collection('final_control_records').add({
        'sira': _siraController.text,
        'saat': _saatController.text,
        'urunAdi': _urunAdiController.text,
        'urunRenk': _selectedProductColor ?? '',
        'toplamAdet': _toplamAdetController.text,
        'fireAdedi': _fireAdediController.text,
        'kirik': _kirikController.text,
        'egri': _egriController.text,
        'renk': _renkController.text,
        'pisme': _pismeController.text,
        'boyaz': _boyazController.text,
        'kabarma': _kabarmaController.text,
        'olcu': _olcuController.text,
        'paletNo': _paletNoController.text,
        'onay': _onayChecked ? 'Evet' : 'Hayır',
        'numune1': {
          'sesKontrol': _numune1SesKontrolChecked ? 'Evet' : 'Hayır',
          'en': _numune1EnController.text,
          'boy': _numune1BoyController.text,
          'kalinlik': _numune1KalinlikController.text,
        },
        'numune2': {
          'sesKontrol': _numune2SesKontrolChecked ? 'Evet' : 'Hayır',
          'en': _numune2EnController.text,
          'boy': _numune2BoyController.text,
          'kalinlik': _numune2KalinlikController.text,
        },
        'numune3': {
          'sesKontrol': _numune3SesKontrolChecked ? 'Evet' : 'Hayır',
          'en': _numune3EnController.text,
          'boy': _numune3BoyController.text,
          'kalinlik': _numune3KalinlikController.text,
        },
        'onayNumaralar': {
          'num1': _onayNum1Value ?? '',
          'num2': _onayNum2Value ?? '',
          'num3': _onayNum3Value ?? '',
        },
        'createdBy': widget.userEmail,
        'createdAt': Timestamp.now(),
        'tarih': DateFormat('dd.MM.yyyy').format(DateTime.now()),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Final kontrol formu kaydedildi!'),
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        validator: required ? (value) {
          if (value == null || value.isEmpty) {
            return 'Bu alan zorunludur';
          }
          return null;
        } : null,
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rulo Fırın Final Kontrol Formu'),
        backgroundColor: Colors.orange,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSection('Genel Bilgiler', [
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Sıra', _siraController)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildTextField('Saat', _saatController, required: true)),
                      ],
                    ),
                    // Ürün Adı ve Renk: Pres formuyla uyumlu, aramalı
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: DropdownSearch<String>(
                        items: (widget.userEmail.toLowerCase() == 'pres@ekos.com')
                          ? ProductCatalog.productWeights.keys.toList()
                          : _availableProductNames,
                        selectedItem: _urunAdiController.text.isNotEmpty ? _urunAdiController.text : _selectedProductType,
                        dropdownDecoratorProps: DropDownDecoratorProps(
                          dropdownSearchDecoration: const InputDecoration(
                            labelText: 'Ürün Adı',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        popupProps: PopupProps.menu(
                          showSearchBox: true,
                          searchFieldProps: TextFieldProps(
                            decoration: const InputDecoration(
                              hintText: 'Ürün ara...',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _selectedProductType = value;
                            _urunAdiController.text = value ?? '';
                            _selectedProductColor = null;
                          });
                        },
                        validator: (value) {
                          final v = value ?? _selectedProductType;
                          if (v == null || v.isEmpty) {
                            return 'Bu alan zorunludur';
                          }
                          return null;
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: DropdownSearch<String>(
                        items: ProductCatalog.colorsFor(_urunAdiController.text.isNotEmpty ? _urunAdiController.text : _selectedProductType),
                        selectedItem: _selectedProductColor,
                        dropdownDecoratorProps: DropDownDecoratorProps(
                          dropdownSearchDecoration: const InputDecoration(
                            labelText: 'Renk',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        popupProps: PopupProps.menu(
                          showSearchBox: true,
                          searchFieldProps: TextFieldProps(
                            decoration: const InputDecoration(
                              hintText: 'Renk ara...',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _selectedProductColor = value;
                          });
                        },
                        validator: (value) {
                          final v = value ?? _selectedProductColor;
                          if ((ProductCatalog.colorsFor(_urunAdiController.text).isNotEmpty) && (v == null || v.isEmpty)) {
                            return 'Renk seçiniz';
                          }
                          return null;
                        },
                      ),
                    ),
                  ]),
                  
                  _buildSection('Adet Bilgileri', [
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Toplam Adet', _toplamAdetController, required: true)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildTextField('Fire Adedi', _fireAdediController)),
                      ],
                    ),
                  ]),
                  
                  _buildSection('Kusur Tipleri', [
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Kırık', _kirikController)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildTextField('Eğri', _egriController)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildTextField('Renk', _renkController)),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Pişme', _pismeController)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildTextField('Beyaz', _boyazController)),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Kabarma', _kabarmaController)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildTextField('Ölçü', _olcuController)),
                      ],
                    ),
                  ]),
                  
                  _buildSection('Palet ve Onay', [
                    _buildTextField('Palet No', _paletNoController),
                    CheckboxListTile(
                      title: const Text('Onay'),
                      value: _onayChecked,
                      onChanged: (value) {
                        setState(() {
                          _onayChecked = value ?? false;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ]),
                  
                  _buildSection('Ölçü Kontrolleri ve Uygunsuzluklar', [
                    const Text(
                      '1. Numune',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      title: const Text('Ses Kontrol'),
                      value: _numune1SesKontrolChecked,
                      onChanged: (value) {
                        setState(() {
                          _numune1SesKontrolChecked = value ?? false;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    _buildTextField('En', _numune1EnController),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Boy', _numune1BoyController)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildTextField('Kalınlık', _numune1KalinlikController)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '2. Numune',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      title: const Text('Ses Kontrol'),
                      value: _numune2SesKontrolChecked,
                      onChanged: (value) {
                        setState(() {
                          _numune2SesKontrolChecked = value ?? false;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    _buildTextField('En', _numune2EnController),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Boy', _numune2BoyController)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildTextField('Kalınlık', _numune2KalinlikController)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '3. Numune',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      title: const Text('Ses Kontrol'),
                      value: _numune3SesKontrolChecked,
                      onChanged: (value) {
                        setState(() {
                          _numune3SesKontrolChecked = value ?? false;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    _buildTextField('En', _numune3EnController),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Boy', _numune3BoyController)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildTextField('Kalınlık', _numune3KalinlikController)),
                      ],
                    ),
                  ]),
                  
                  _buildSection('Onay Numaraları (Onay/Red)', [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Numune 1',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            initialValue: _onayNum1Value,
                            items: const [
                              DropdownMenuItem(value: 'Onay', child: Text('Onay (O)')),
                              DropdownMenuItem(value: 'Red', child: Text('Red (R)')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _onayNum1Value = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Numune 2',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            initialValue: _onayNum2Value,
                            items: const [
                              DropdownMenuItem(value: 'Onay', child: Text('Onay (O)')),
                              DropdownMenuItem(value: 'Red', child: Text('Red (R)')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _onayNum2Value = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Numune 3',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            initialValue: _onayNum3Value,
                            items: const [
                              DropdownMenuItem(value: 'Onay', child: Text('Onay (O)')),
                              DropdownMenuItem(value: 'Red', child: Text('Red (R)')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _onayNum3Value = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ]),
                  
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _saveForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Kaydet',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

