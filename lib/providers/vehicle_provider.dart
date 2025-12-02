import 'package:flutter/material.dart';
import 'package:ekosats/models/vehicle.dart';
import 'package:ekosats/models/vehicle_record.dart';
import 'package:ekosats/services/database_service.dart';

class VehicleProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  Vehicle? _currentVehicle;
  List<VehicleRecord> _records = [];
  List<Vehicle> _vehicles = [];

  Vehicle? get currentVehicle => _currentVehicle;
  List<VehicleRecord> get records => _records;
  List<Vehicle> get vehicles => _vehicles;

  Future<void> loadAllRecords() async {
    _records = await _databaseService.getAllRecords();
    notifyListeners();
  }

  Future<void> loadAllVehicles() async {
    _vehicles = await _databaseService.getAllVehicles();
    notifyListeners();
  }

  Future<bool> scanBarcode(String barcode) async {
    try {
      _currentVehicle = await _databaseService.getVehicleByBarcode(barcode);
      notifyListeners();
      return _currentVehicle != null;
    } catch (e) {
      return false;
    }
  }

  Future<void> addVehicleIfNew(String barcode, String vehicleType,
      String model, String plate) async {
    final existing = await _databaseService.getVehicleByBarcode(barcode);
    if (existing == null) {
      final vehicle = Vehicle(
        barcode: barcode,
        vehicleType: vehicleType,
        model: model,
        plate: plate,
      );
      _currentVehicle = await _databaseService.addVehicle(vehicle);
      await loadAllVehicles();
    } else {
      _currentVehicle = existing;
    }
    notifyListeners();
  }

  Future<void> saveRecord(VehicleRecord record) async {
    try {
      await _databaseService.addRecord(record);
      await loadAllRecords();
      _currentVehicle = null;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteRecord(int id) async {
    await _databaseService.deleteRecord(id);
    await loadAllRecords();
    notifyListeners();
  }

  void clearCurrentVehicle() {
    _currentVehicle = null;
    notifyListeners();
  }
}
