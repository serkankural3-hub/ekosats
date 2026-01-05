import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ekosatsss/services/offline_cache_service.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final OfflineCacheService _cacheService = OfflineCacheService();
  
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  // Connectivity dinle
  Stream<bool> get connectivityStream {
    return _connectivity.onConnectivityChanged.map((results) {
      // results is now List<ConnectivityResult>
      _isOnline = results.isNotEmpty && !results.contains(ConnectivityResult.none);
      return _isOnline;
    });
  }

  // İlk connectivity durumunu kontrol et
  Future<bool> checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = results.isNotEmpty && !results.contains(ConnectivityResult.none);
    return _isOnline;
  }

  // Pending operations'ı sync et
  Future<void> syncPendingOperations() async {
    if (!_isOnline) return;

    final pendingOps = await _cacheService.getPendingOperations();
    
    for (var op in pendingOps) {
      try {
        final collection = FirebaseFirestore.instance.collection(op['collection']);
        
        // Int'leri Timestamp'a çevir
        final firestoreData = _convertIntsToTimestamp(op['data']);
        
        switch (op['operation']) {
          case 'create':
            await collection.doc(op['documentId']).set(firestoreData);
            break;
          case 'set':
            await collection.doc(op['documentId']).set(firestoreData);
            break;
          case 'update':
            await collection.doc(op['documentId']).update(firestoreData);
            break;
          case 'delete':
            await collection.doc(op['documentId']).delete();
            break;
        }
        
        // Başarılıysa pending'den sil
        await _cacheService.deletePendingOperation(op['id']);
        print('✓ Synced operation ${op['id']} successfully');
      } catch (e) {
        // Hata olursa logla ve veritabanına kaydet
        print('✗ Sync error for operation ${op['id']}: $e');
        await _cacheService.recordSyncError(op['id'], e.toString());
      }
    }
    
    // Eski sync hatalarını temizle
    await _cacheService.clearOldSyncErrors();
  }

  // Cache'i Firestore'dan güncelle
  Future<void> updateCache(String collection) async {
    if (!_isOnline) return;

    try {
      final snapshot = await FirebaseFirestore.instance.collection(collection).get();
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        // Timestamp'ları int'e çevir
        final cacheData = _convertTimestampsToInt(data);
        await _cacheService.cacheRecord(doc.id, cacheData);
      }
    } catch (e) {
      print('Cache update error: $e');
    }
  }

  // Timestamp'ları milliseconds'a çevir
  Map<String, dynamic> _convertTimestampsToInt(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    for (var entry in data.entries) {
      if (entry.value is Timestamp) {
        result[entry.key] = (entry.value as Timestamp).millisecondsSinceEpoch;
      } else {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  // Milliseconds'ı Timestamp'a çevir (sync için)
  Map<String, dynamic> _convertIntsToTimestamp(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    final timestampFields = ['createdAt', 'dateTime', 'labCheckedAt', 'ovenUpdatedAt', 'dryingIn', 'dryingOut'];
    
    for (var entry in data.entries) {
      if (timestampFields.contains(entry.key) && entry.value is int) {
        result[entry.key] = Timestamp.fromMillisecondsSinceEpoch(entry.value as int);
      } else {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }
}

