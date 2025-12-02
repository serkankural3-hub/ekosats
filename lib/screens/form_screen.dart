import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:ekosats/providers/vehicle_provider.dart';
import 'package:ekosats/models/vehicle_record.dart';

class FormScreen extends StatefulWidget {
  const FormScreen({super.key});

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  late TextEditingController productTypeController;
  late TextEditingController statusController;
  late TextEditingController productQuantityController;
  late TextEditingController workOrderController;
  late TextEditingController descriptionController;

  late DateTime selectedDateTime;
  final List<String> statusOptions = ['Beklemede', 'İşlemde', 'Tamamlandı', 'Hatalı'];
  late String selectedStatus;

  @override
  void initState() {
    super.initState();
    productTypeController = TextEditingController();
    statusController = TextEditingController();
    productQuantityController = TextEditingController();
    workOrderController = TextEditingController();
    descriptionController = TextEditingController();

    selectedDateTime = DateTime.now();
    selectedStatus = statusOptions[0];
  }

  @override
  void dispose() {
    productTypeController.dispose();
    statusController.dispose();
    productQuantityController.dispose();
    workOrderController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      if (!mounted) return;
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(selectedDateTime),
      );

      if (pickedTime != null) {
        setState(() {
          selectedDateTime = DateTime(
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

  void _submitForm() async {
    if (productTypeController.text.isEmpty ||
        productQuantityController.text.isEmpty ||
        workOrderController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tüm zorunlu alanları doldurun!')),
      );
      return;
    }

    final provider = context.read<VehicleProvider>();
    final vehicle = provider.currentVehicle;

    if (vehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Araç bilgisi bulunamadı!')),
      );
      return;
    }

    try {
      final record = VehicleRecord(
        vehicleId: vehicle.id!,
        vehicleBarcode: vehicle.barcode,
        vehicleType: vehicle.vehicleType,
        productType: productTypeController.text,
        dateTime: selectedDateTime,
        status: selectedStatus,
        productQuantity: int.parse(productQuantityController.text),
        workOrder: workOrderController.text,
        description: descriptionController.text,
      );

      await provider.saveRecord(record);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kayıt başarıyla kaydedildi!'),
          duration: Duration(seconds: 2),
        ),
      );

      // Form temizle
      productTypeController.clear();
      productQuantityController.clear();
      workOrderController.clear();
      descriptionController.clear();
      selectedDateTime = DateTime.now();
      selectedStatus = statusOptions[0];

      // Ana ekrana dön
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        context.read<VehicleProvider>().clearCurrentVehicle();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Araç Bilgi Formu'),
          elevation: 0,
        ),
        body: Consumer<VehicleProvider>(
          builder: (context, provider, _) {
            final vehicle = provider.currentVehicle;

            if (vehicle == null) {
              return const Center(
                child: Text('Araç bilgisi yükleniyor...'),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Araç Bilgileri Özeti
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Araç Bilgileri',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Text('Barkod: ', style: TextStyle(fontWeight: FontWeight.bold)),
                              Expanded(child: Text(vehicle.barcode)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text('Çeşidi: ', style: TextStyle(fontWeight: FontWeight.bold)),
                              Expanded(child: Text(vehicle.vehicleType)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text('Model: ', style: TextStyle(fontWeight: FontWeight.bold)),
                              Expanded(child: Text(vehicle.model)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text('Plaka: ', style: TextStyle(fontWeight: FontWeight.bold)),
                              Expanded(child: Text(vehicle.plate)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Form Alanları
                  const Text(
                    'İşlem Detayları',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Ürün Çeşidi
                  TextField(
                    controller: productTypeController,
                    decoration: InputDecoration(
                      labelText: 'Ürün Çeşidi *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.category),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tarih-Zaman
                  GestureDetector(
                    onTap: () => _selectDateTime(context),
                    child: AbsorbPointer(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'Tarih-Zaman *',
                          hintText: DateFormat('dd/MM/yyyy HH:mm').format(selectedDateTime),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.date_range),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(selectedDateTime),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),

                  // Durum
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: InputDecoration(
                      labelText: 'Durum *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.info),
                    ),
                    items: statusOptions.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(status),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedStatus = value ?? statusOptions[0];
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Ürün Adeti
                  TextField(
                    controller: productQuantityController,
                    decoration: InputDecoration(
                      labelText: 'Ürün Adeti *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.inventory),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),

                  // İş Emri
                  TextField(
                    controller: workOrderController,
                    decoration: InputDecoration(
                      labelText: 'İş Emri *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.assignment),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Açıklama
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Açıklama',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.description),
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 24),

                  // Butonlar
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            provider.clearCurrentVehicle();
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.close),
                          label: const Text('İptal'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _submitForm,
                          icon: const Icon(Icons.save),
                          label: const Text('Kaydet'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
