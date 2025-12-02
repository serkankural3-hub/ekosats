class Vehicle {
  final int? id;
  final String barcode;
  final String vehicleType; // Araç çeşidi
  final String model;
  final String plate;
  final DateTime createdAt;

  Vehicle({
    this.id,
    required this.barcode,
    required this.vehicleType,
    required this.model,
    required this.plate,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'barcode': barcode,
      'vehicleType': vehicleType,
      'model': model,
      'plate': plate,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Vehicle.fromMap(Map<String, dynamic> map) {
    return Vehicle(
      id: map['id'],
      barcode: map['barcode'],
      vehicleType: map['vehicleType'],
      model: map['model'],
      plate: map['plate'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}
