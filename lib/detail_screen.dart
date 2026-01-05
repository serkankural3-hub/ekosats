import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ekosatsss/models/cart_model.dart';

class DetailScreen extends StatelessWidget {
  final CartRecord record;

  const DetailScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kayıt Detayları'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildInfoCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.deepPurple[100],
            child: Icon(Icons.qr_code_2, size: 40, color: Colors.deepPurple[800]),
          ),
          const SizedBox(height: 12),
          Text(
            'Araba No: ${record.cartNumber}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Chip(
            label: Text(record.status, style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.deepPurple[400],
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildDetailRow(Icons.shopping_cart, 'Araba Çeşidi', record.cartType),
            // Hide 'Ürün Çeşidi' for pres@ekos.com since Pres shows product name + color instead.
            if (FirebaseAuth.instance.currentUser?.email?.toLowerCase() != 'pres@ekos.com')
              _buildDetailRow(Icons.category, 'Ürün Çeşidi', record.productType),
            _buildDetailRow(Icons.palette, 'Ürün Adı', '${record.product} - ${record.color}'),
            _buildDetailRow(Icons.production_quantity_limits, 'Ürün Adedi', record.productQuantity.toString()),
            _buildDetailRow(Icons.assignment, 'İş Emri', record.workOrder),
            _buildDetailRow(Icons.person, 'Sorumlu', record.createdBy),
            _buildDetailRow(Icons.calendar_today, 'Oluşturma Tarihi', DateFormat('dd/MM/yyyy HH:mm').format(record.createdAt)),
            if (record.description.isNotEmpty)
              _buildDetailRow(Icons.description, 'Açıklama', record.description),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.deepPurple[300], size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}