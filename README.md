# İş Takip — Personel İş & Tahsilat Yönetimi

Saha ekibiyle çalışan küçük işletmeler için geliştirilmiş bir **Flutter** mobil uygulaması.
Patron ve personel rolleriyle iş atama/onay akışını, müşteri alacaklarını, tahsilatları,
giderleri ve personel bakiyelerini tek bir yerde yönetir. Arka uç tamamen **Firebase**
(Auth, Firestore, Cloud Functions, Cloud Messaging) üzerine kuruludur.

---

## Özellikler

### İş yönetimi
- **Rol bazlı akış:** Personel iş oluşturur → iş `Onay Bekliyor` durumunda patrona düşer →
  patron bir veya birden fazla personel atayıp onaylar ya da reddeder.
- Patronun oluşturduğu işler doğrudan onaylı başlar; personel formda hemen atanabilir.
- İş durumları: `Onay Bekliyor → Onaylandı → Devam Ediyor → Tamamlandı` (veya `Reddedildi`).
- **Aktif / Onay Bekleyen** sekmeleri, bekleyen iş sayısı rozeti ve **Bugün / Yarın / Tümü**
  tarih filtreleri.
- Personel "İşlerim" sayfasında yalnızca kendisine atanan işleri görür.
- İş düzenleme ve silme (yetki ve ödeme durumuna göre sunucu tarafında korunur).

### Finans
- **Alacaklar:** Fiyatı girilen her iş için otomatik alacak oluşur (`OTOMATİK` rozetiyle);
  ayrıca elle (manuel) alacak eklenebilir. Durum (`Ödeme Bekliyor` / `Kısmi Ödendi` / `Ödendi`)
  her zaman ödeme geçmişinden hesaplanır.
- **Tahsilatlar:** Nakit, havale, kart vb. yöntemlerle ödeme kaydı. Bir alacağa bağlanabilir
  ya da bağımsız girilebilir. Kayıtlar değiştirilemez (immutable).
- **Giderler:** Yakıt, yemek, malzeme, konaklama, ulaşım gibi kategorilerde ay bazlı gider
  takibi; patron için şirket geneli toplam ve kategori kırılımı.
- **Personel bakiyesi:** Personelin yaptığı harcamalar ile şirketin ona yaptığı geri
  ödemeler arasındaki bakiye.

### Diğer
- **Push bildirimleri** (FCM): iş atandı, onaylandı/reddedildi, yeni iş bekliyor vb.
  Bildirime dokununca ilgili iş detayına gidilir.
- **Personel yönetimi:** Patron kullanıcıların rolünü değiştirebilir.
- **Açık / koyu tema**, profil sayfasından seçilebilir.
- **Hesap silme** (App Store 5.1.1(v) uyumlu).

---

## Teknoloji Yığını

| Katman | Kullanılan |
| --- | --- |
| Mobil | Flutter (Dart SDK ^3.12) |
| State yönetimi | `flutter_riverpod` |
| Navigasyon | `go_router` |
| Kimlik doğrulama | Firebase Authentication |
| Veritabanı | Cloud Firestore |
| Sunucu mantığı | Cloud Functions (Node.js 20) |
| Bildirimler | Firebase Cloud Messaging + `flutter_local_notifications` |
| Tasarım | Material 3, `google_fonts` (Lexend + Source Sans 3) |
| Dağıtım | Firebase App Distribution |

---

## Proje Yapısı

```
lib/
├── app/            # Tema, router, sabitler (koleksiyon adları, route path'leri)
├── core/
│   ├── models/     # AppUser, Job, Receivable, Payment, Expense, StaffPayment, AppNotification
│   ├── services/   # AuthService, FirestoreService, MessagingService (Riverpod provider'ları)
│   ├── widgets/    # AppCard, StatusChip, EmptyState, AsyncValueWidget...
│   └── utils/      # Para / tarih formatlayıcıları
└── features/
    ├── auth/           # Giriş & kayıt
    ├── shell/          # Splash + rol bazlı alt navigasyon
    ├── jobs/           # İş listesi, detay, oluşturma, düzenleme
    ├── finance/        # Finans sekmesi kabuğu
    ├── receivables/    # Alacaklar
    ├── payments/       # Tahsilatlar
    ├── expenses/       # Giderler & personel bakiyesi
    ├── staff/          # Personel listesi
    ├── notifications/  # Bildirimler
    └── profile/        # Profil, tema, hesap silme

functions/          # Cloud Functions (index.js)
scripts/            # distribute.sh — App Distribution ile APK dağıtımı
firestore.rules     # Güvenlik kuralları
firestore.indexes.json
```

---

## Veri Modeli (Firestore)

```
users/{uid}           name, email, role('patron'|'personel'), fcmTokens[], createdAt
jobs/{id}             title, description, price, customerName, address, scheduledDate,
                      status, createdBy, assignedTo[], approvedBy, approvedAt, createdAt, updatedAt
receivables/{id}      title, totalAmount, paidAmount, type('otomatik'|'manuel'), jobId,
                      customerName, createdBy, createdAt
payments/{id}         receivableId?, customerName, description, amount, method, note,
                      createdBy, createdAt
expenses/{id}         amount, description, category, createdBy, createdAt
staffPayments/{id}    staffId, amount, note, createdBy, createdAt
notifications/{id}    userId, title, body, type, read, jobId, createdAt
meta/roles            patronAssigned (yalnızca Cloud Functions kullanır)
```

---

## Cloud Functions

| Fonksiyon | Tetikleyici | Görev |
| --- | --- | --- |
| `assignPatronRoleOnCreate` | `users` create | İlk kayıt olan kullanıcıyı patron yapar |
| `onJobCreated` | `jobs` create | Otomatik alacak oluşturur, ilgili kişilere bildirim yazar |
| `onJobStatusChanged` | `jobs` update | Atama ve onay/red bildirimleri |
| `onJobPriceSet` | `jobs` update | Fiyat değişince bağlı otomatik alacağı senkronlar |
| `onNotificationCreated` | `notifications` create | FCM push gönderir, geçersiz token'ları temizler |
| `deleteJob` | callable | Yetki ve ödeme kontrolüyle iş (ve alacağı) siler |
| `deleteAccount` | callable | Kullanıcının kendi hesabını siler |

---

## Güvenlik

- Roller **sunucu tarafında** belirlenir: ilk kullanıcı patron, sonrakiler personel olur.
  Kullanıcı kendi rolünü değiştiremez; yalnızca bir patron başkasının rolünü değiştirebilir.
- Otomatik alacaklar istemciden yazılamaz; yalnızca Cloud Functions oluşturur.
- `paidAmount` yalnızca tahsilat eklenirken bir transaction içinde artırılabilir.
- Personel yalnızca kendi verilerini (atanan işler, kendi giderleri, kendi bakiyesi) okuyabilir.

Tüm kurallar [`firestore.rules`](firestore.rules) dosyasındadır.

---

## Kurulum

### Gereksinimler
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart ^3.12)
- Node.js 20 ve [Firebase CLI](https://firebase.google.com/docs/cli) (`npm i -g firebase-tools`)
- [FlutterFire CLI](https://firebase.google.com/docs/flutter/setup) (`dart pub global activate flutterfire_cli`)
- **Blaze** planında bir Firebase projesi (Cloud Functions için zorunlu)

### Adımlar

```bash
# 1. Bağımlılıklar
flutter pub get

# 2. Firebase yapılandırması
#    lib/firebase_options.dart, google-services.json ve GoogleService-Info.plist oluşturur
flutterfire configure

# 3. Kurallar, index'ler ve fonksiyonlar
cd functions && npm install && cd ..
firebase deploy --only firestore:rules,firestore:indexes,functions

# 4. Çalıştır
flutter run
```

> **Not:** `android/app/google-services.json` ve `ios/Runner/GoogleService-Info.plist`
> güvenlik nedeniyle repoya eklenmez. `flutterfire configure` ile oluşturun ya da proje
> sahibinden temin edin.

iOS yayınlama (Bundle ID, APNs anahtarı, App Store Connect) için ayrıntılı adımlar
[`SETUP.md`](SETUP.md) dosyasındadır.

---

## Faydalı Komutlar

```bash
flutter analyze                     # Statik analiz
flutter test                        # Testler
cd functions && npm run serve       # Functions emülatörü
cd functions && npm run logs        # Functions logları
./scripts/distribute.sh "notlar"    # Release APK'yı App Distribution ile testerlara gönder
```

---

## Lisans

Bu proje özeldir (private); izinsiz kopyalanması ve dağıtılması yasaktır.
