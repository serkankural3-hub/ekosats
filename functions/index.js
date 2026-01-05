/**
 * Bu dosya, Firebase projeniz için Cloud Functions içerir.
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");

// Firebase Admin SDK'yı başlat. Bu, sunucu tarafı işlemleri için gereklidir.
admin.initializeApp();

/**
 * Admin kullanıcısını oluşturan HTTP fonksiyonu
 * Kullanım: https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/createAdminUser
 */
exports.createAdminUser = functions
  .region("europe-west1")
  .https.onRequest(async (req, res) => {
    try {
      const email = "admin";
      const password = "123";

      // Kullanıcının zaten var olup olmadığını kontrol et
      let userRecord;
      try {
        userRecord = await admin.auth().getUserByEmail(email);
        functions.logger.log(`Admin kullanıcısı zaten var: ${email}`);
        
        // Firestore'da admin rolü var mı kontrol et
        const userDoc = await admin.firestore().collection('users').doc(userRecord.uid).get();
        if (!userDoc.exists || userDoc.data().role !== 'admin') {
          await admin.firestore().collection('users').doc(userRecord.uid).set({
            email: email,
            role: 'admin',
            status: 'approved',
          }, { merge: true });
          functions.logger.log('Admin rolü güncellendi');
        }
        
        res.status(200).send({
          message: "Admin kullanıcısı zaten mevcut ve rolü güncellendi",
          uid: userRecord.uid
        });
      } catch (error) {
        if (error.code === 'auth/user-not-found') {
          // Kullanıcı yoksa oluştur
          userRecord = await admin.auth().createUser({
            email: email,
            password: password,
            emailVerified: true,
          });

          // Firestore'a admin rolü ile kaydet
          await admin.firestore().collection('users').doc(userRecord.uid).set({
            email: email,
            role: 'admin',
            status: 'approved',
          });

          functions.logger.log(`Admin kullanıcısı oluşturuldu: ${email}`);
          res.status(200).send({
            message: "Admin kullanıcısı başarıyla oluşturuldu",
            uid: userRecord.uid,
            email: email,
            password: password
          });
        } else {
          throw error;
        }
      }
    } catch (error) {
      functions.logger.error("Admin kullanıcısı oluşturulurken hata:", error);
      res.status(500).send({ error: error.message });
    }
  });

/**
 * Firestore'daki 'users' koleksiyonundan bir belge silindiğinde tetiklenir.
 * Bu fonksiyon, silinen kullanıcıya ait kimlik doğrulama (Authentication)
 * kaydını da siler.
 */
exports.onUserDeleted = functions
  .region("europe-west1") // Opsiyonel: Projenizin bölgesine göre ayarlayın.
  .firestore.document("users/{uid}")
  .onDelete(async (snap, context) => {
    const uid = context.params.uid;
    functions.logger.log(
      `Firestore'dan silinen kullanıcı ID'si: ${uid}. Auth kaydı siliniyor.`,
    );

    try {
      await admin.auth().deleteUser(uid);
      functions.logger.log(`Auth'dan ${uid} başarıyla silindi.`);
    } catch (error) {
      functions.logger.error(`Kullanıcı ${uid} silinirken hata:`, error);
    }
  });

/**
 * Her dakika çalışan zamanlanmış fonksiyon.
 * Fırında 100 dakikayı geçen arabaları otomatik olarak "Fırından Çıkış" durumuna alır.
 */
exports.checkOvenTimeout = functions
  .region("europe-west1")
  .pubsub.schedule("every 1 minutes")
  .timeZone("Europe/Istanbul")
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    const hundredMinutesAgo = new Date(now.toDate().getTime() - (100 * 60 * 1000));
    
    try {
      // Fırında durumunda ve 100 dakikadan eski kayıtları bul
      const snapshot = await admin.firestore()
        .collection("cart_records")
        .where("status", "==", "Fırında")
        .where("ovenEntryTime", "<=", admin.firestore.Timestamp.fromDate(hundredMinutesAgo))
        .get();

      if (snapshot.empty) {
        functions.logger.log("Fırından çıkış yapılacak araba yok.");
        return null;
      }

      // Batch işlem için
      const batch = admin.firestore().batch();
      let count = 0;

      snapshot.forEach((doc) => {
        batch.update(doc.ref, {
          status: "Fırından Çıkış",
          ovenExitTime: now,
          autoExited: true, // Otomatik çıkış yapıldığını işaretle
        });
        count++;
      });

      await batch.commit();
      functions.logger.log(`${count} araba otomatik olarak Fırından Çıkış durumuna alındı.`);
      
      return null;
    } catch (error) {
      functions.logger.error("Fırın timeout kontrolü sırasında hata:", error);
      return null;
    }
  });
