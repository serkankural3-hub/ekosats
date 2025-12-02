import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:ekosats/models/vehicle.dart';
import 'package:ekosats/models/vehicle_record.dart';

class DatabaseService {
  static const String vehiclesTable = 'vehicles';
  static const String recordsTable = 'vehicle_records';
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'ekosats.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    // Araçlar tablosu
    await db.execute('''
      CREATE TABLE $vehiclesTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        barcode TEXT UNIQUE NOT NULL,
        vehicleType TEXT NOT NULL,
        model TEXT NOT NULL,
        plate TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    // Araç kayıtları tablosu
    await db.execute('''
      CREATE TABLE $recordsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vehicleId INTEGER NOT NULL,
        vehicleBarcode TEXT NOT NULL,
        vehicleType TEXT NOT NULL,
        productType TEXT NOT NULL,
        dateTime TEXT NOT NULL,
        status TEXT NOT NULL,
        productQuantity INTEGER NOT NULL,
        workOrder TEXT NOT NULL,
        description TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        FOREIGN KEY(vehicleId) REFERENCES $vehiclesTable(id)
      )
    ''');
  }

  // Vehicle işlemleri
  Future<Vehicle> addVehicle(Vehicle vehicle) async {
    final db = await database;
    try {
      final id = await db.insert(vehiclesTable, vehicle.toMap());
      return Vehicle(
        id: id,
        barcode: vehicle.barcode,
        vehicleType: vehicle.vehicleType,
        model: vehicle.model,
        plate: vehicle.plate,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<Vehicle?> getVehicleByBarcode(String barcode) async {
    final db = await database;
    final result = await db.query(
      vehiclesTable,
      where: 'barcode = ?',
      whereArgs: [barcode],
    );

    if (result.isNotEmpty) {
      return Vehicle.fromMap(result.first);
    }
    return null;
  }

  Future<List<Vehicle>> getAllVehicles() async {
    final db = await database;
    final result = await db.query(vehiclesTable);
    return result.map((map) => Vehicle.fromMap(map)).toList();
  }

  // Record işlemleri
  Future<VehicleRecord> addRecord(VehicleRecord record) async {
    final db = await database;
    final id = await db.insert(recordsTable, record.toMap());
    return VehicleRecord(
      id: id,
      vehicleId: record.vehicleId,
      vehicleBarcode: record.vehicleBarcode,
      vehicleType: record.vehicleType,
      productType: record.productType,
      dateTime: record.dateTime,
      status: record.status,
      productQuantity: record.productQuantity,
      workOrder: record.workOrder,
      description: record.description,
    );
  }

  Future<List<VehicleRecord>> getAllRecords() async {
    final db = await database;
    final result = await db.query(
      recordsTable,
      orderBy: 'createdAt DESC',
    );
    return result.map((map) => VehicleRecord.fromMap(map)).toList();
  }

  Future<List<VehicleRecord>> getRecordsByVehicleId(int vehicleId) async {
    final db = await database;
    final result = await db.query(
      recordsTable,
      where: 'vehicleId = ?',
      whereArgs: [vehicleId],
      orderBy: 'createdAt DESC',
    );
    return result.map((map) => VehicleRecord.fromMap(map)).toList();
  }

  Future<void> deleteRecord(int id) async {
    final db = await database;
    await db.delete(
      recordsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteAllData() async {
    final db = await database;
    await db.delete(vehiclesTable);
    await db.delete(recordsTable);
  }
}
