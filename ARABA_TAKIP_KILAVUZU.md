# Araba Takip Sistemi Kullanım Kılavuzu

## Sistem Özeti

Bu sistem, tuğla fabrikasında yaş imalattan çıkan ürünlerin arabalarla takibini kolaylaştırmak için geliştirilmiştir.

## Özellikler

### 1. Araba Barkod Sistemi
- Her arabaya 1'den 400'e kadar numaralı barkod yapıştırılır
- Android cihazdan barkod okutularak hızlı veri girişi yapılır
- Manuel araba numarası girişi de desteklenir

### 2. Veri Toplama Formu
Aşağıdaki bilgiler kaydedilir:
- **Araba No**: Barkod ile veya manuel olarak girilir
- **Araba Çeşidi**: Tip 1, Tip 2, Tip 3, Özel
- **Ürün Çeşidi**: Briket, Delikli Tuğla, Düz Tuğla, İzolasyon, Diğer
- **Tarih-Zaman**: Kayıt zamanı (düzenlenebilir)
- **Durum**: Yaş İmalat, Kurutmaya Gitti, Pişirmede, Pişti, Sevkiyat
- **Ürün Adedi**: Arabadaki ürün sayısı
- **İş Emri**: İş emri numarası
- **Açıklama**: Opsiyonel notlar

### 3. Veri Görüntüleme ve Dışa Aktarma
- Tüm kayıtlar canlı olarak görüntülenir
- Filtreleme özellikleri:
  - Araba numarasına, iş emrine veya ürün türüne göre arama
  - Duruma göre filtreleme
  - Tarih aralığına göre filtreleme
- Excel'e aktarma (CSV formatında)
- Kayıtları paylaşma özelliği

## Kullanım Adımları

### Mobil Cihazdan Veri Girişi

1. **Uygulamayı Aç**
   - Giriş yapın

2. **Ana Menüden "Araba Takip Formu" Seç**
   - Yeşil renkli buton

3. **Barkod Okutma**
   - "Araba No" alanının yanındaki QR kod simgesine basın
   - Kamerayı arabanın barkoduna tutun
   - Barkod otomatik olarak okunacak
   - Alternatif: Manuel olarak araba numarasını yazabilirsiniz

4. **Form Doldurma**
   - Araba Çeşidi seçin
   - Ürün Çeşidi seçin
   - Gerekirse Tarih-Zaman'ı değiştirin
   - Durum seçin
   - Ürün Adedi girin
   - İş Emri girin
   - İsteğe bağlı Açıklama ekleyin

5. **Kaydet**
   - "Kaydet" butonuna basın
   - Form otomatik temizlenir, yeni kayıt için hazır olur

### Bilgisayardan Verileri Görüntüleme

1. **Uygulamayı Aç**
   - Web veya masaüstü versiyondan giriş yapın

2. **Ana Menüden "Araba Kayıtlarını Görüntüle" Seç**
   - Turuncu renkli buton

3. **Kayıtları Görüntüleme**
   - Tüm kayıtlar tarih sırasıyla listelenir
   - Her kayıt üzerine tıklayarak detayları görebilirsiniz

4. **Filtreleme**
   - **Arama**: Araba no, iş emri veya ürün türü arayın
   - **Durum Filtresi**: Dropdown'dan durum seçin
   - **Tarih Filtresi**: Takvim simgesine basıp tarih aralığı seçin

5. **Excel'e Aktarma**
   - Sağ üstteki indirme simgesine basın
   - CSV dosyası oluşturulur ve paylaşılır
   - Bu dosyayı Excel ile açabilirsiniz

## Excel'de Veriyi Açma

1. CSV dosyasını indirin
2. Excel'i açın
3. Dosya > Aç > Tüm Dosyalar (*.*) seçin
4. CSV dosyasını seçin
5. İçe Aktarma Sihirbazı'nda:
   - "Ayrılmış" seçeneğini seçin
   - Ayırıcı olarak "Virgül" seçin
   - Bitir'e tıklayın

## Firestore Veritabanı Yapısı

```
cart_records/
  ├─ {recordId}/
      ├─ cartNumber: string
      ├─ cartType: string
      ├─ productType: string
      ├─ dateTime: timestamp
      ├─ status: string
      ├─ productQuantity: number
      ├─ workOrder: string
      ├─ description: string
      ├─ createdBy: string
      └─ createdAt: timestamp
```

## Güvenlik

- Tüm kullanıcılar kendi kayıtlarını oluşturabilir ve görüntüleyebilir
- Sadece giriş yapmış kullanıcılar sisteme erişebilir
- Her kayıt, oluşturan kişinin bilgisiyle birlikte saklanır

## Barkod Etiketleri

- Her araba için 1'den 400'e kadar numara kullanılabilir
- Barkod formatı: QR Code veya standart barkod
- Barkodlar dayanıklı, su geçirmez etiketlere basılmalıdır
- Önerilen barkod boyutu: En az 3x3 cm (QR kod için)

## Sorun Giderme

### Barkod Okutmuyor
- Kamera izninin verildiğinden emin olun
- Barkodun temiz ve net olduğunu kontrol edin
- Işıklandırmayı artırın
- Manuel giriş yapın

### Veriler Görünmüyor
- İnternet bağlantınızı kontrol edin
- Filtrelerinizi kontrol edin (Tümü seçili olmalı)
- Uygulamadan çıkıp tekrar girin

### Excel Dosyası Açılmıyor
- Dosyanın .csv uzantılı olduğundan emin olun
- Excel'de İçe Aktarma işlemini kullanın
- Google Sheets'te açmayı deneyin

## Teknik Destek

Sorun yaşamanız durumunda sistem yöneticinizle iletişime geçin.
