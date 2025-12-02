class VehicleRecord {
  final int? id;
  final int vehicleId;
  final String vehicleBarcode;
  final String vehicleType;
  final String productType; // Ürün çeşidi
  final DateTime dateTime;
  final String status; // Durum
  final int productQuantity; // Ürün adeti
  final String workOrder; // İş emri
  final String description; // Açıklama
  final DateTime createdAt;

  VehicleRecord({
    this.id,
    required this.vehicleId,
    required this.vehicleBarcode,
    required this.vehicleType,
    required this.productType,
    required this.dateTime,
    required this.status,
    required this.productQuantity,
    required this.workOrder,
    required this.description,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehicleId': vehicleId,
      'vehicleBarcode': vehicleBarcode,
      'vehicleType': vehicleType,
      'productType': productType,
      'dateTime': dateTime.toIso8601String(),
      'status': status,
      'productQuantity': productQuantity,
      'workOrder': workOrder,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory VehicleRecord.fromMap(Map<String, dynamic> map) {
    return VehicleRecord(
      id: map['id'],
      vehicleId: map['vehicleId'],
      vehicleBarcode: map['vehicleBarcode'],
      vehicleType: map['vehicleType'],
      productType: map['productType'],
      dateTime: DateTime.parse(map['dateTime']),
      status: map['status'],
      productQuantity: map['productQuantity'],
      workOrder: map['workOrder'],
      description: map['description'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}
