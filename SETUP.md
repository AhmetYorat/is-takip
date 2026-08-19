# 📱 iOS Yayınlama Kurulum Kılavuzu

Bu dosyayı okuyan kişi, projeyi kendi Apple Developer hesabından yayınlayacak.

---

## ⚠️ GitHub'dan Eksik Gelecek Dosyalar

Bu dosyalar güvenlik nedeniyle GitHub'a yüklenmedi. Senden **ayrıca** alman gerekiyor:

```
ios/Runner/GoogleService-Info.plist   ← Firebase iOS config
android/app/google-services.json      ← Firebase Android config (gerekirse)
```

Ahmet'ten bu dosyaları al ve ilgili klasörlere yerleştir.

---

## 🔧 Kurulum Adımları

### 1. Flutter Ortamını Hazırla
```bash
flutter doctor
```
Tüm checkmark'lar yeşil olmalı (özellikle Xcode).

### 2. Bağımlılıkları Yükle
```bash
flutter pub get
cd ios && pod install && cd ..
```

### 3. Firebase Dosyalarını Yerleştir
- `GoogleService-Info.plist` → `ios/Runner/` klasörüne koy

### 4. Bundle ID'yi Değiştir
Mevcut Bundle ID: `com.is.istakip`

Kendi Apple Developer hesabında yeni bir App ID oluştur ve Bundle ID'yi değiştir:
- Xcode'u aç: `open ios/Runner.xcworkspace`
- Runner > Signing & Capabilities
- Team = kendi Apple Developer hesabın
- Bundle Identifier = kendi belirlediğin ID (örn: `com.seninfirman.istakip`)

> ⚠️ Bundle ID'yi değiştirirsen Firebase'de de yeni bir iOS app kaydı oluşturman gerekir!

### 5. Firebase'i Güncelle (Bundle ID değiştirdiysen)
- Firebase Console > Project Settings > iOS app
- "Add app" → yeni Bundle ID ile kaydet
- Yeni `GoogleService-Info.plist` indir, `ios/Runner/` klasörüne koy

### 6. Push Notification (APNs) Ayarı
Firebase Messaging kullanıldığı için:
- Apple Developer Portal → Certificates > Keys → yeni APNs Key oluştur
- Firebase Console → Project Settings → Cloud Messaging → Apple app configuration → APNs key yükle

### 7. Build & Archive
```bash
flutter build ios --release
```
Sonra Xcode'da:
- Product → Archive
- Distribute App → App Store Connect

---

## 📋 App Store Connect'te Yapılacaklar
1. [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → My Apps → Yeni uygulama ekle
2. Bundle ID'yi eşleştir
3. İsim, açıklama, ekran görüntüleri ekle
4. Build'i yükle → Review'a gönder

---

## 🆘 Sorun Çıkarsa
- `pod install` hata verirse: `cd ios && pod repo update && pod install`
- Signing hataları: Xcode → Preferences → Accounts → Apple ID ekle
