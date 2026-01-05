import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import removed: item_model not needed here
// Assuming this is the list to navigate to
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:ekosatsss/oven_list_screen.dart';
import 'package:ekosatsss/services/connectivity_service.dart';
import 'package:ekosatsss/services/offline_cache_service.dart';
import 'package:provider/provider.dart';

class OvenFormScreen extends StatefulWidget {
  final String barcode; // cartNumber (gösterim için)
  final String documentId; // Gerçek Firestore document ID
  final String userEmail;
  final bool isAdmin;

  const OvenFormScreen(
      {super.key,
      required this.barcode,
      required this.documentId,
      required this.userEmail,
      this.isAdmin = false});

  @override
  State<OvenFormScreen> createState() => _OvenFormScreenState();
}

class _OvenFormScreenState extends State<OvenFormScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _dryingIn;
  DateTime? _dryingOut;
  String _initialStatusRaw = '';
  final _descriptionController = TextEditingController();
  final _responsibleController = TextEditingController();
  String? _productType; // Pres formundan gelen ürün çeşidi
  bool _isSaving = false;
  bool _forceReadOnly = false;
  bool _isEntryMode = true; // Giriş modunda mı çıkış modunda mı

  @override
  void initState() {
    super.initState();
    _responsibleController.text = widget.userEmail;
    // Form hemen gösterilsin, veriler arka planda yüklensin
    _determineModeAndLoad();
  }

  Future<void> _determineModeAndLoad() async {
    // Form hemen açılsın
    if (mounted) {
      setState(() {});
    }

    try {
      // Önce online durumunu kontrol et
      final connectivity =
          Provider.of<ConnectivityService>(context, listen: false);
      final cache = Provider.of<OfflineCacheService>(context, listen: false);
      final isOnline = await connectivity.checkConnectivity();

      Map<String, dynamic>? data;

      if (isOnline) {
        // Online: Firestore'dan çek - documentId kullan
        final doc = await FirebaseFirestore.instance
            .collection('cart_records')
            .doc(widget.documentId)
            .get();
        if (doc.exists) {
          data = doc.data();
        }
      } else {
        // Offline: Cache'den çek - documentId kullan
        data = await cache.getCachedRecord(widget.documentId);
      }

      if (data != null) {
        if (mounted) {
          setState(() {
            final dryingInRaw = data?['dryingIn'];
            if (dryingInRaw is Timestamp) {
              _dryingIn = dryingInRaw.toDate();
            } else if (dryingInRaw is int) {
              _dryingIn = DateTime.fromMillisecondsSinceEpoch(dryingInRaw);
            }

            final dryingOutRaw = data?['dryingOut'];
            if (dryingOutRaw is Timestamp) {
              _dryingOut = dryingOutRaw.toDate();
            } else if (dryingOutRaw is int) {
              _dryingOut = DateTime.fromMillisecondsSinceEpoch(dryingOutRaw);
            }

            // Determine mode primarily by `status` to avoid inconsistent timestamp states.
            final statusRaw = (data?['status'] ?? '').toString().toLowerCase();
            _initialStatusRaw = statusRaw;
            if (statusRaw.contains('yaş')) {
              // Yaş İmalat -> Giriş modu (Kurutmaya giriş yapacak)
              _isEntryMode = true;
            } else if (statusRaw.contains('kurutmadan çıkış') ||
                statusRaw.contains('çık')) {
              // Zaten çıkış yapılmış -> Çıkış modu (salt okunur gibi davran)
              _isEntryMode = false;
            } else if (statusRaw.contains('kurut') &&
                !statusRaw.contains('çık')) {
              // 'Kurutmada' -> Çıkış modu (Kurutmadan Çıkış yapacak)
              _isEntryMode = false;
            } else {
              // Fallback to dryingIn presence
              _isEntryMode = (_dryingIn == null);
            }

            _descriptionController.text = data?['description'] ?? '';
            // Prefer explicit product name; fallback to productType if empty
            final prod = (data?['product'] as String?)?.trim();
            final ptype = (data?['productType'] as String?)?.trim();
            _productType =
                (prod != null && prod.isNotEmpty) ? prod : (ptype ?? '');
            _responsibleController.text =
                data?['createdBy'] ?? widget.userEmail;
          });
        }

        // Sadece online modda ovenUpdatedBy güncelle
        if (isOnline) {
          final currentEmail = FirebaseAuth.instance.currentUser?.email;
          final ovenUpdatedBy = data['ovenUpdatedBy'] as String?;

          if ((ovenUpdatedBy == null || ovenUpdatedBy.isEmpty) &&
              currentEmail != null) {
            try {
              await FirebaseFirestore.instance
                  .collection('cart_records')
                  .doc(widget.documentId) // documentId kullan
                  .update({
                'ovenUpdatedBy': currentEmail,
              });
            } catch (e) {
              // ignore
            }
          }

          // Fırın kullanıcısı ise, başkası kaydettiyse read-only yap
          if (!widget.isAdmin &&
              ovenUpdatedBy != null &&
              ovenUpdatedBy.isNotEmpty &&
              ovenUpdatedBy != currentEmail) {
            if (mounted) {
              setState(() {
                _forceReadOnly = true;
              });
            }
          }
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kayıt bulunamadı'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _saveForm() async {
    // Set timestamps according to the explicit entry/exit mode determined earlier.
    if (_isEntryMode) {
      // Entry: set dryingIn if missing, ensure dryingOut is null
      _dryingIn ??= DateTime.now();
      _dryingOut = null;
    } else {
      // Exit: set dryingOut to now (don't overwrite dryingIn)
      _dryingOut ??= DateTime.now();
    }

    if (!_isEntryMode && _dryingOut == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kurutma Çıkış Tarihi seçiniz'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final connectivity =
        Provider.of<ConnectivityService>(context, listen: false);
    final cache = Provider.of<OfflineCacheService>(context, listen: false);

    final now = DateTime.now();
    // Entry vs Exit flow:
    // - If there is no dryingIn yet, we are saving entry and setting status to Kurutmada.
    // - If dryingIn exists and dryingOut is being set now, we are saving exit and advancing status.
    // Use the explicit mode flag to determine entry vs exit
    final bool isEntry = _isEntryMode;
    final bool isExit = !_isEntryMode && _dryingOut != null;

    final payload = <String, dynamic>{
      'dryingIn': _dryingIn != null ? Timestamp.fromDate(_dryingIn!) : null,
      'dryingOut': _dryingOut != null ? Timestamp.fromDate(_dryingOut!) : null,
      // Status: entry = Kurutmada, exit = Kurutmadan Çıkış
      'status': isExit ? 'Kurutmadan Çıkış' : 'Kurutmada',
      'ovenUpdatedAt': Timestamp.fromDate(now),
      'ovenUpdatedBy': widget.userEmail,
      'updatedAt': Timestamp.fromDate(now),
    };
    if (_descriptionController.text.isNotEmpty) {
      payload['ovenNotes'] = _descriptionController.text;
    }

    try {
      final isOnline = await connectivity.checkConnectivity();

      if (isOnline) {
        await FirebaseFirestore.instance
            .collection('cart_records')
            .doc(widget.documentId) // documentId kullan
            .update(payload);

        // Cache'i güncelle - documentId kullan
        final existingCache = await cache.getCachedRecord(widget.documentId);
        final fullData = existingCache ?? <String, dynamic>{};

        // Güncellenen alanları ekle (Timestamp'ı int'e çevir)
        if (_dryingIn != null)
          fullData['dryingIn'] = _dryingIn!.millisecondsSinceEpoch;
        if (_dryingOut != null)
          fullData['dryingOut'] = _dryingOut!.millisecondsSinceEpoch;
        fullData['status'] = isExit ? 'Kurutmadan Çıkış' : 'Kurutmada';
        fullData['ovenUpdatedAt'] = now.millisecondsSinceEpoch;
        fullData['ovenUpdatedBy'] = widget.userEmail;
        fullData['updatedAt'] = now.millisecondsSinceEpoch;
        fullData['cartNumber'] = widget.barcode; // cartNumber field
        if (_descriptionController.text.isNotEmpty) {
          fullData['ovenNotes'] = _descriptionController.text;
        }

        await cache.cacheRecord(widget.documentId, fullData);
      } else {
        // Çevrimdışı - var olan cache'e güncelle
        final existingCache = await cache.getCachedRecord(widget.documentId);
        final fullData = existingCache ?? <String, dynamic>{};

        if (_dryingIn != null)
          fullData['dryingIn'] = _dryingIn!.millisecondsSinceEpoch;
        if (_dryingOut != null)
          fullData['dryingOut'] = _dryingOut!.millisecondsSinceEpoch;
        fullData['status'] = isExit ? 'Kurutmadan Çıkış' : 'Kurutmada';
        fullData['ovenUpdatedAt'] = now.millisecondsSinceEpoch;
        fullData['ovenUpdatedBy'] = widget.userEmail;
        fullData['updatedAt'] = now.millisecondsSinceEpoch;
        fullData['cartNumber'] = widget.barcode; // cartNumber field
        if (_descriptionController.text.isNotEmpty) {
          fullData['ovenNotes'] = _descriptionController.text;
        }

        await cache.cacheRecord(widget.documentId, fullData);
        await cache.addPendingOperation(
          operation: 'update',
          collection: 'cart_records',
          documentId: widget.documentId, // documentId kullan
          data: fullData,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                isOnline
                    ? 'Fırın verisi kaydedildi!'
                    : 'Çevrimdışı kaydedildi, bağlantıda senkronlanacak',
                style: TextStyle(color: Colors.white)),
            backgroundColor: isOnline ? Colors.orange : Colors.orange.shade700,
          ),
        );
      }

      // setState çağırmadan direkt yönlendir (form kapanmalı)
      if (mounted) {
        // Direkt OvenListScreen'e yönlendir
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) => const OvenListScreen()));
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

  void _showConfirmationDialog() {
    if (_formKey.currentState!.validate()) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Kaydı Onayla'),
            content: const Text(
                'Fırın bilgilerini kaydetmek istediğinizden emin misiniz?'),
            actions: <Widget>[
              TextButton(
                child: const Text('İptal'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text('Onayla'),
                onPressed: () {
                  Navigator.of(context).pop();
                  _saveForm();
                },
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('cart_records')
              .doc(widget.documentId) // documentId kullan
              .get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Fırın Barkod: ${widget.barcode}'),
                ],
              );
            }
            final data = snapshot.data?.data() as Map<String, dynamic>?;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fırın Barkod: ${widget.barcode}'),
                if (data != null)
                  Text(
                    '${data['product'] ?? 'N/A'} - ${data['color'] ?? 'N/A'}',
                    style: const TextStyle(fontSize: 12),
                  ),
              ],
            );
          },
        ),
        backgroundColor: Colors.red[400],
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context)
                  .colorScheme
                  .secondary
                  .withOpacity(0.8), // Using secondary color for oven form
              Theme.of(context).colorScheme.secondary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(
              top: AppBar().preferredSize.height +
                  MediaQuery.of(context).padding.top +
                  16.0,
              left: 16.0,
              right: 16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        // Ürün Çeşidi - Salt Okunur
                        if (_productType != null && _productType!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Ürün Çeşidi',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _productType!,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Kurutma Giriş Tarihi
                        if (_isEntryMode)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Kurutma Giriş Tarihi'),
                            subtitle: Text(_dryingIn == null
                                ? 'Seçilmedi'
                                : DateFormat('dd/MM/yyyy HH:mm')
                                    .format(_dryingIn!)),
                            trailing: IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: _forceReadOnly
                                  ? null
                                  : () async {
                                      DateTime? pickedDate =
                                          await showDatePicker(
                                              context: context,
                                              initialDate: DateTime.now(),
                                              firstDate: DateTime(2020),
                                              lastDate: DateTime(2030));
                                      if (pickedDate != null) {
                                        TimeOfDay? t = await showTimePicker(
                                            context: context,
                                            initialTime: TimeOfDay.now());
                                        if (t != null) {
                                          setState(() {
                                            _dryingIn = DateTime(
                                                pickedDate.year,
                                                pickedDate.month,
                                                pickedDate.day,
                                                t.hour,
                                                t.minute);
                                          });
                                        }
                                      }
                                    },
                            ),
                          ),
                        if (_isEntryMode) const SizedBox(height: 16),
                        // Kurutmadan Çıkış Tarihi sadece giriş yapıldıktan sonra gösterilir
                        if (!_isEntryMode && _dryingOut == null)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Kurutma Çıkış Tarihi'),
                            subtitle: Text(_dryingOut == null
                                ? 'Seçilmedi'
                                : DateFormat('dd/MM/yyyy HH:mm')
                                    .format(_dryingOut!)),
                            trailing: IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: _forceReadOnly
                                  ? null
                                  : () async {
                                      DateTime? pickedDate =
                                          await showDatePicker(
                                              context: context,
                                              initialDate: DateTime.now(),
                                              firstDate: DateTime(2020),
                                              lastDate: DateTime(2030));
                                      if (pickedDate != null) {
                                        TimeOfDay? t = await showTimePicker(
                                            context: context,
                                            initialTime: TimeOfDay.now());
                                        if (t != null) {
                                          setState(() {
                                            _dryingOut = DateTime(
                                                pickedDate.year,
                                                pickedDate.month,
                                                pickedDate.day,
                                                t.hour,
                                                t.minute);
                                          });
                                        }
                                      }
                                    },
                            ),
                          ),
                        if (!_isEntryMode && _dryingOut == null)
                          const SizedBox(height: 16),
                        // Fırın Açıklaması (kullanıcı notu) - her zaman opsiyonel, lab notundan bağımsız
                        TextFormField(
                          controller: _descriptionController,
                          readOnly: _forceReadOnly,
                          decoration: InputDecoration(
                            labelText: 'Fırın Açıklaması',
                            prefixIcon: Icon(Icons.description,
                                color: Theme.of(context).colorScheme.secondary),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.0)),
                            focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                    width: 2.0),
                                borderRadius: BorderRadius.circular(10.0)),
                          ),
                        ),
                        SizedBox(height: 16),
                        // Sorumlu alanı kaldırıldı (gereksiz)
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),
                // Lab Açıklaması - Salt Okunur
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('cart_records')
                      .doc(widget.documentId) // documentId kullan, barcode değil
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SizedBox.shrink();
                    }

                    final data = snapshot.data?.data() as Map<String, dynamic>?;
                    final labNotes = data?['labNotes'] as String? ?? '';

                    if (labNotes.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      color: Colors.blue[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Lab Açıklaması',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFD32F2F),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.blue[200]!),
                              ),
                              child: Text(
                                labNotes,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: 30),
                if (!_forceReadOnly)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      padding:
                          EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                      textStyle:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _isSaving ? null : _showConfirmationDialog,
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Kaydet'),
                  ),
                if (_forceReadOnly)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Text('Bu kayıt mevcut ve düzenleme yetkiniz yok.',
                        style: TextStyle(color: Colors.white70)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
