# is_takip — Personel Tahsilat & İş Takip

Flutter mobil uygulama: patron/personel rolleriyle iş atama-onay akışı ve
tahsilat (alacak) takibi. Firebase (Auth, Firestore, Cloud Messaging, Cloud
Functions) üzerine kurulu.

## Roller ve akış

- **Personel**: iş oluşturur (başlık, müşteri, açıklama, fiyat). İş
  `pending_approval` durumunda patrona düşer. "İşlerim" sayfasında yalnızca
  kendisine atanmış işleri görür (Firestore sorgusu `assignedTo == uid`,
  client-side filtre değil).
- **Patron**: tüm işleri görür ("İşler"), bekleyen bir işe personel atayıp
  onaylar (`assignAndApproveJob`) ya da reddeder. "Personeller" sayfasından
  herhangi bir kullanıcının rolünü değiştirebilir.
- **Rol ataması**: İlk kayıt olan kullanıcı otomatik **patron** olur,
  sonrakiler **personel** başlar — bu, `functions/index.js` içindeki
  `assignPatronRoleOnCreate` Cloud Function'ı tarafından server-side
  belirlenir (`meta/roles.patronAssigned` kilidiyle race condition'a karşı
  korumalı). İstemci kendi rolünü asla değiştiremez; bkz. `firestore.rules`.

## Alacak / Tahsilat modeli — ÖNEMLİ

**Alacak (`receivables/{id}`)** = borç kaydı (kime, ne kadar). **Tahsilat
(`payments/{id}`)** = gerçekten alınan bir ödeme kaydı (ne zaman, ne kadar,
hangi yöntemle). İkisi ayrı koleksiyon, ayrı sayfa (Tahsilat sekmesi altında
Alacaklar/Tahsilatlar alt-sekmeleri, `finance_shell_page.dart`).

- **Receivable.type**: `otomatik` (bir işin `price` alanından `onJobCreated`
  Cloud Function'ı tarafından oluşturulur, `jobId` ile bağlıdır, UI'da her
  zaman **"(OTOMATİK)"** rozetiyle gösterilir — `Receivable.displayTitle`)
  veya `manuel` (Alacaklar sayfasındaki **+** butonundan,
  `add_receivable_sheet.dart`). **İstemci `otomatik` tipte kayıt oluşturamaz**
  — `firestore.rules` bunu reddeder, yalnızca Admin SDK yazabilir.
- **Receivable.paidAmount** UI'dan asla direkt yazılmaz — yalnızca
  `FirestoreService.addPayment` bir transaction içinde günceller (ilgili
  `Payment` yazılırken). `firestore.rules` da `paidAmount`'ın yalnızca
  artabileceğini ve başka hiçbir alanın client tarafından
  değiştirilemeyeceğini zorunlu kılar.
- **Durum** (`Ödeme Bekliyor` / `Kısmi Ödendi` / `Ödendi`) hiçbir yerde
  stored bir alan değil — `Receivable.isUnpaid/isPartiallyPaid/isFullyPaid`
  her zaman `paidAmount` vs `totalAmount`'tan **hesaplanır**, ödeme
  geçmişiyle asla senkron dışı kalamaz.
- **Payment.receivableId**: bir alacağa bağlıysa o alacağın "Ödeme
  Geçmişi"nde görünür ve `paidAmount`'ını artırır (Alacak Detayı →
  **Ödeme Ekle**, `add_payment_sheet.dart`). `null` ise Tahsilatlar
  sayfasındaki **+** ile bağımsız eklenmiş bir kayıttır (herhangi bir
  alacağı etkilemez). Her iki durumda da kayıt Tahsilatlar listesinde
  görünür — `payments` tek, paylaşılan bir koleksiyondur.
- **Payment'lar immutable**: oluşturulduktan sonra düzenlenemez/silinemez
  (`firestore.rules`), gerçek bir ödeme kaydı gibi.

Yeni bir tahsilat kaynağı eklerken bu ayrımı bozmayın: otomatik alacak
oluşturma mantığı yalnızca `functions/index.js` içinde, `paidAmount`
güncelleme mantığı yalnızca `FirestoreService.addPayment` içinde yaşar.

## Mimari

- **State**: `flutter_riverpod` — `lib/core/services/*` içindeki
  `Provider`/`StreamProvider`'lar Firestore/Auth ile UI arasındaki tek
  köprü. Yeni bir ekran eklerken doğrudan `FirebaseFirestore.instance`
  kullanmayın, `FirestoreService` üzerinden geçin.
- **Navigasyon**: `go_router` (`lib/app/router.dart`). Auth/rol durumuna
  göre `redirect` mantığı splash → login/register → `RoleBasedShell`
  akışını yönetir. Bildirime dokunma / push tap → `AppRoutes.jobDetailPath`
  ile derin bağlantı.
- **Kabuk**: `lib/features/shell/role_based_shell.dart` — rol bazlı alt
  navigasyon sekmeleri + `IndexedStack` (sekme geçişinde state korunur).
- **Klasör yapısı**: `lib/app` (tema/router/sabitler),
  `lib/core/{models,services,widgets,utils}` (paylaşılan), `lib/features/*`
  (ekran başına klasör: auth, jobs, receivables, payments, finance (Tahsilat
  sekmesi kabuğu), staff, notifications, profile, shell).

## Veri modeli (Firestore)

```
users/{uid}          name, email, role('patron'|'personel'), fcmTokens[], createdAt
jobs/{id}             title, description, price, customerName, address, scheduledDate,
                       status('pending_approval'|'approved'|'in_progress'|'completed'|'rejected'),
                       createdBy, assignedTo(string[]), approvedBy, approvedAt, createdAt, updatedAt
receivables/{id}       title, totalAmount, paidAmount, type('otomatik'|'manuel'), jobId,
                       customerName, createdBy, createdAt
payments/{id}          receivableId(nullable), customerName, description, amount, method
                       ('nakit'|'havale'|'kart'|'diger'), note, createdBy, createdAt
notifications/{id}     userId, title, body, type, read, jobId, createdAt
meta/roles             patronAssigned:boolean   (yalnızca Cloud Function kullanır)
```

Model sınıfları `lib/core/models/*.dart`; sabitler (koleksiyon adları, rol/
durum string'leri, route path'leri) `lib/app/constants.dart`.

### İş oluşturma & atama kuralları
- **Personel** iş oluşturursa: `status: pending_approval`, `assignedTo: []`
  — bir patron `assignAndApproveJob` ile bir veya daha fazla personel
  seçip onaylamadan aktif olmaz.
- **Patron** iş oluşturursa: kendi onayına gerek yoktur, `status: approved`
  ile direkt oluşur; isterse oluşturma formunda (`PersonnelMultiSelect`)
  direkt bir veya daha fazla personel de seçebilir, isterse boş bırakıp
  sonra "İş Detayı"ndan atayabilir.
- **`assignedTo` bir dizi** (bir işe birden fazla personel atanabilir).
  `watchMyJobs` bu yüzden `arrayContains` sorgusu kullanır — bkz.
  `firestore.indexes.json`'daki composite index. Atama her zaman
  `job_detail_page.dart`'taki `PersonnelMultiSelect` ile sonradan da
  değiştirilebilir (yalnızca patron, iş tamamlanmadığı/reddedilmediği
  sürece).
- **İşler sayfası (patron)**: varsayılan olarak **Aktif** sekmesi açılır;
  **Onay Bekleyen** sekmesinde bekleyen iş sayısı rozet olarak gösterilir;
  Aktif sekmesinde **Bugün/Yarın/Tümü** filtreleri işin `scheduledDate`
  alanına göre süzer ve listeyi tarihe göre sıralar.

## Cloud Functions (`functions/index.js`)

| Fonksiyon | Tetikleyici | Görev |
|---|---|---|
| `assignPatronRoleOnCreate` | `users/{uid}` create | İlk kullanıcıyı patron yapar |
| `onJobCreated` | `jobs/{id}` create | Otomatik alacak (receivable) + (pending ise) patronlara bildirim + (patron direkt atadıysa) atanan personellere bildirim |
| `onJobStatusChanged` | `jobs/{id}` update | `assignedTo` dizisine yeni eklenen her personele "atandınız", oluşturana onay/red bildirimi |
| `onNotificationCreated` | `notifications/{id}` create | `notifications` dokümanını ilgili kullanıcının `fcmTokens`'ına FCM push olarak gönderir, geçersiz token'ları temizler |

## Tasarım sistemi

"Enterprise SaaS (Mobile)" — kurumsal güven veren, kart tabanlı. Token'lar
`lib/app/theme.dart` içinde (`AppTheme`, `AppColors` extension, `AppSpacing`,
`AppRadius`). Özet:

- Primary `#2563EB`, Accent/para `#059669` (light) — tutarlar, "ödendi",
  tahsilat FAB'ı hep accent renkte.
  Otomatik rozet rengi ayrı: `AppColors.badgeAutomatic` (mor).
- Başlık fontu **Lexend**, gövde **Source Sans 3** (`google_fonts`).
- Kartlar: 12pt radius, yumuşak renkli gölge (`AppCard` widget'ı kullanın,
  yeni bir `Container`+`BoxShadow` yazmayın).
- Açık + koyu tema birlikte tasarlandı (`AppTheme.light()` / `.dark()`),
  kullanıcı `Profil` sayfasından seçebilir (`themeModeProvider`).
- İkon kuralı: emoji yok, Material ikon seti; tüm dokunma hedefleri ≥44pt.
- Para/tarih formatı: `lib/core/utils/formatters.dart` (`formatCurrency`,
  `formatDate`, `formatRelative`) — yeni yerlerde `NumberFormat`/`DateFormat`
  tekrar tekrar oluşturmayın, bunları kullanın.

## Firebase kurulumu (bir kereye mahsus, kullanıcı aksiyonu)

1. [Firebase Console](https://console.firebase.google.com)'da proje
   oluşturun ve **Blaze (kullandıkça öde)** planına yükseltin (Cloud
   Functions için zorunlu).
2. `dart pub global activate flutterfire_cli` (yoksa), sonra proje kökünde:
   ```
   flutterfire configure
   ```
   Bu, `lib/firebase_options.dart` içindeki yer tutucu değerleri gerçek
   proje bilgileriyle değiştirir ve `android/app/google-services.json` /
   `ios/Runner/GoogleService-Info.plist` dosyalarını oluşturur. Ayrıca
   `.firebaserc` oluşturur/günceller.
3. Kuralları ve fonksiyonları deploy edin:
   ```
   cd functions && npm install && cd ..
   firebase deploy --only firestore:rules,firestore:indexes,functions
   ```
4. (Öneri) `android/app/build.gradle.kts` içindeki
   `applicationId = "com.example.is_takip"` değerini gerçek bir paket
   adıyla değiştirin (yayın öncesi).

`lib/firebase_options.dart` şu an **yer tutucu** değerler içeriyor —
`flutterfire configure` çalıştırılmadan `flutter run` Firebase'e
bağlanamaz (Dart analiz/derleme yine de çalışır).

## Komutlar

```
flutter pub get
flutter analyze
flutter run
cd functions && npm install && npm run deploy   # veya: firebase deploy --only functions
firebase deploy --only firestore:rules,firestore:indexes
```

## Dikkat edilmesi gerekenler

- Rol yükseltmeyi asla istemcide varsayılan yapmayın — `firestore.rules`
  yalnızca mevcut bir patronun başka bir kullanıcının `role` alanını
  değiştirmesine izin verir; kullanıcı kendi rolünü değiştiremez.
- `receivables.type == 'otomatik'` istemciden yazılamaz; bu her zaman
  `onJobCreated` Cloud Function'ından gelir. `paidAmount`'ı da UI'dan direkt
  güncellemeyin — her zaman `FirestoreService.addPayment` üzerinden.
- Yeni bir Firestore sorgusu `where` + `orderBy` (farklı alanlarda)
  kullanıyorsa `firestore.indexes.json`'a composite index eklemeyi
  unutmayın (örnek: `jobs.assignedTo + createdAt`,
  `notifications.userId + createdAt`, `payments.receivableId + createdAt`).
- Push bildirimi göndermek için doğrudan istemciden FCM çağırmayın; her
  zaman bir `notifications/{id}` dokümanı yazın —
  `onNotificationCreated` gerisini halleder.
