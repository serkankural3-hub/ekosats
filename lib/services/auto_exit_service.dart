import 'package:cloud_firestore/cloud_firestore.dart';

class AutoExitService {
  static const int _timeoutMinutes = 100;

  static Future<void> runOnce() async {
    try {
      final now = DateTime.now();
      final threshold = now.subtract(const Duration(minutes: _timeoutMinutes));

      final snap = await FirebaseFirestore.instance
          .collection('cart_records')
          .where('status', isEqualTo: 'Fırında')
          .get();

      if (snap.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      int count = 0;

      for (final doc in snap.docs) {
        final data = doc.data();
        final ts = data['ovenEntryTime'];
        DateTime? entry;
        if (ts is Timestamp) {
          entry = ts.toDate();
        } else if (ts is DateTime) {
          entry = ts;
        }
        if (entry != null && entry.isBefore(threshold)) {
          batch.update(doc.reference, {
            'status': 'Fırından Çıkış',
            'ovenExitTime': Timestamp.fromDate(now),
            'autoExited': true,
          });
          count++;
        }
      }

      if (count > 0) {
        await batch.commit();
      }
    } catch (_) {
      // Sessizce geç: istemci-side kontrol, başarısızlık kritik değil
    }
  }
}
