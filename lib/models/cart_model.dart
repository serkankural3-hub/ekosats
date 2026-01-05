import 'package:cloud_firestore/cloud_firestore.dart';

class CartRecord {
  final String id;
  final String cartNumber;
  final String cartType;
  final String productType;
  final String product;
  final String color;
  final DateTime dateTime;
  final String status;
  final int productQuantity;
  final String workOrder;
  final String description;
  final String createdBy;
  final DateTime createdAt;

  CartRecord({
    required this.id,
    required this.cartNumber,
    required this.cartType,
    required this.productType,
    required this.product,
    required this.color,
    required this.dateTime,
    required this.status,
    required this.productQuantity,
    required this.workOrder,
    required this.description,
    required this.createdBy,
    required this.createdAt,
  });

  factory CartRecord.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final createdAtTs = data['createdAt'] as Timestamp?;
    final dateTimeTs = data['dateTime'] as Timestamp?;
    
    final createdAt = createdAtTs?.toDate() ?? DateTime.now();
    final dateTime = dateTimeTs?.toDate() ?? createdAt;

    return CartRecord(
      id: doc.id,
      cartNumber: data['cartNumber'] as String? ?? '',
      cartType: data['cartType'] as String? ?? '',
      productType: data['productType'] as String? ?? '',
      product: data['product'] as String? ?? '',
      color: data['color'] as String? ?? '',
      dateTime: dateTime,
      status: data['status'] as String? ?? '',
      productQuantity: data['productQuantity'] as int? ?? 0,
      workOrder: data['workOrder'] as String? ?? '',
      description: data['description'] as String? ?? '',
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cartNumber': cartNumber,
      'cartType': cartType,
      'productType': productType,
      'dateTime': dateTime,
      'status': status,
      'productQuantity': productQuantity,
      'workOrder': workOrder,
      'description': description,
      'createdBy': createdBy,
      'createdAt': createdAt,
    };
  }
}

