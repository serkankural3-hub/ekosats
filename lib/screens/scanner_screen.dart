import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:ekosats/providers/vehicle_provider.dart';
import 'package:ekosats/screens/form_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  late MobileScannerController controller;
  bool _isScanning = true;

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture barcode) async {
    if (!_isScanning) return;

    _isScanning = false;
    final provider = context.read<VehicleProvider>();
    String? barcodeValue;

    for (final line in barcode.barcodes) {
      barcodeValue = line.rawValue;
      if (barcodeValue != null) break;
    }

    if (barcodeValue != null) {
      final exists = await provider.scanBarcode(barcodeValue);

      if (!mounted) return;

      if (exists) {
        // Araç bulundu, form ekranına git
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const FormScreen(),
          ),
        );
      } else {
        // Araç bulunamadı, yeni araç ekleme dialogu
        _showNewVehicleDialog(context, barcodeValue);
      }
    }

    _isScanning = true;
  }

  void _showNewVehicleDialog(BuildContext context, String barcode) {
    final vehicleTypeController = TextEditingController();
    final modelController = TextEditingController();
    final plateController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Yeni Araç Ekle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Barkod: $barcode'),
                const SizedBox(height: 16),
                TextField(
                  controller: vehicleTypeController,
                  decoration: const InputDecoration(
                    labelText: 'Araç Çeşidi',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: modelController,
                  decoration: const InputDecoration(
                    labelText: 'Model',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: plateController,
                  decoration: const InputDecoration(
                    labelText: 'Plaka',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _isScanning = true;
              },
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final provider = context.read<VehicleProvider>();
                await provider.addVehicleIfNew(
                  barcode,
                  vehicleTypeController.text,
                  modelController.text,
                  plateController.text,
                );

                if (!context.mounted) return;
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const FormScreen(),
                  ),
                );
              },
              child: const Text('Ekle ve Devam Et'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Barkod Tara'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: controller,
              onDetect: _onDetect,
              errorBuilder: (context, error, child) {
                return Center(
                  child: Text(error.toString()),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.grey[900],
            child: Column(
              children: [
                const Text(
                  'Lütfen araç barkodunu tarayın',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const FormScreen(),
                      ),
                    );
                  },
                  child: const Text('Manuel Giriş'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
