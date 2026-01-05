import 'package:cloud_firestore/cloud_firestore.dart';

class Item {
  final String id;
  final String cartType;
  final String productType;
  final DateTime dateTime;
  final String status;
  final int productQuantity;
  final String workOrder;
  final String description;
  final String responsible;

  Item({
    required this.id,
    required this.cartType,
    required this.productType,
    required this.dateTime,
    required this.status,
    required this.productQuantity,
    required this.workOrder,
    required this.description,
    required this.responsible,
  });

  factory Item.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final dateTimeTs = data['dateTime'] as Timestamp?;
    final dateTime = dateTimeTs?.toDate() ?? DateTime.now();

    return Item(
      id: doc.id,
      cartType: data['cartType'] as String? ?? '',
      productType: data['productType'] as String? ?? '',
      dateTime: dateTime,
      status: data['status'] as String? ?? '',
      productQuantity: data['productQuantity'] as int? ?? 0,
      workOrder: data['workOrder'] as String? ?? '',
      description: data['description'] as String? ?? '',
      responsible: data['responsible'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cartType': cartType,
      'productType': productType,
      'dateTime': dateTime,
      'status': status,
      'productQuantity': productQuantity,
      'workOrder': workOrder,
      'description': description,
      'responsible': responsible,
    };
  }
}

