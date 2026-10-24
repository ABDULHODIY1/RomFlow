# iPhone va iPad’ga o‘rnatish (iOS 15 – iOS 27)

Apple App Store’dan tashqaridagi ilovani faqat Apple imzosi bilan o‘rnatishga
ruxsat beradi. RomFlow’ni iPhone’ga qo‘yishning uchta yo‘li bor:

| Yo‘l | Telefonda | Narxi | Kompyuter | Imzo muddati |
|---|---|---|---|---|
| **1. TestFlight** | havola → **Install** (bir bosish) | Apple Developer, 99 $/yil (faqat ustaxona egasi) | kerak emas | har build 90 kun; yangisi o‘zi keladi |
| **2. SideStore + RomFlow manbasi** | **GET** (bir bosish, birinchi sozlashdan keyin) | bepul (Apple ID) | iOS 27 da kerak emas (SideInstaller) | 7 kun, SideStore yangilaydi |
| **3. Sideloadly** | — | bepul (Apple ID) | har safar | 7 kun |

Ubuntu Linux kompyuter bilan qadamma-qadam: [../IOS-Qollanma.md](../IOS-Qollanma.md).

Ko‘p usta bo‘lsa — **1-yo‘l**: hamma bitta havoladan bir bosishda o‘rnatadi.
Bitta telefon va pul to‘lamasdan — **2** yoki **3-yo‘l**.

---

## 1-yo‘l. TestFlight — bir bosishda o‘rnatish

### Ustaxona egasi bir marta qiladi (≈30 daqiqa + Apple tekshiruvi)
1. **Apple Developer Program**: developer.apple.com/programs → *Enroll* —
   Apple ID bilan, “Individual” yetarli (99 $/yil). Tasdiqlash 1–2 kun.
2. **Bundle ID**: developer.apple.com/account → *Certificates, Identifiers &
   Profiles* → *Identifiers* → **+** → *App IDs* → *App* → Description:
   `RomFlow`, Bundle ID (Explicit): **`uz.romflow.workshop`** → *Register*.
3. **Ilova yozuvi**: appstoreconnect.apple.com → *Apps* → **+** → *New App*
   → Platform: iOS, Name: `RomFlow` (band bo‘lsa `RomFlow Smeta`), Primary
   language: Russian yoki English, Bundle ID: `uz.romflow.workshop`, SKU:
   `romflow` → *Create*.
4. **API kaliti**: App Store Connect → *Users and Access* → *Integrations* →
   *App Store Connect API* → *Team Keys* → **+** → Name: `GitHub`, Access:
   **Admin** → *Generate* → **Download** (`AuthKey_XXXX.p8`, faqat bir marta
   yuklanadi). Sahifadagi **Key ID** va **Issuer ID** ni yozib oling.
5. **Team ID**: developer.apple.com/account → *Membership details* → Team ID.
6. **GitHub secret’lari**: github.com/z3wax/RomFlow → *Settings* → *Secrets
   and variables* → *Actions* → *New repository secret*:
   - `APPLE_TEAM_ID` — Team ID;
   - `ASC_KEY_ID` — Key ID;
   - `ASC_ISSUER_ID` — Issuer ID;
   - `ASC_KEY_P8` — `.p8` faylning butun matni (`-----BEGIN PRIVATE KEY-----`
     dan `-----END PRIVATE KEY-----` gacha).
7. **Yig‘ish**: *Actions* → *Build* → *Run workflow* (main). “iPhone build to
   TestFlight” yashil bo‘lgach, 10–30 daqiqada build App Store Connect →
   *TestFlight* da paydo bo‘ladi. Shifrlash savoli chiqmaydi (ilova faqat
   HTTPS ishlatadi). Keyin har bir `main` push’da yangi build o‘zi yuklanadi.
8. **Havola**: *TestFlight* → *External Testing* → **+** guruh `Ustalar` →
   build qo‘shing → *Test Information* (qisqa tavsif, e-mail) → *Submit for
   Review* (birinchi build’ni Apple 1–2 kunda tekshiradi) → *Public Link* →
   *Enable* → `https://testflight.apple.com/join/…` havolasini nusxalang.
   O‘zingiz va jamoangiz (*Internal Testing*, 100 kishigacha) tekshiruvsiz,
   darhol o‘rnatishingiz mumkin.

### Usta iPhone’da (iOS 27)
1. App Store’dan **TestFlight** ilovasini o‘rnating (Apple’ning, bepul).
2. Havolani Safari’da oching → **Accept** → **Install**. Tamom — RomFlow
   bosh ekranda.
3. Yangi versiya chiqsa, TestFlight “Update” ko‘rsatadi (TestFlight →
   RomFlow → *Automatic Updates* yoqilsa, o‘zi yangilanadi).

---

## 2-yo‘l. SideStore — bepul, keyin bir bosishda

### Bir marta sozlash — iOS 27 da kompyutersiz
> ⚠️ Faqat rasmiy sayt: **https://sideinstaller.net**. “sideinstaller.com” —
> soxta sayt, Apple ID’ni o‘g‘irlashi mumkin; u yerga hech narsa yozmang.

1. Sozlamalar → Umumiy → Haqida: **iOS 27** bo‘lsin (iOS 26 va pastida
   SideStore uchun bir marta kompyuter kerak: **docs.sidestore.io**).
2. Alohida, yangi Apple ID oching (appleid.apple.com) — asosiysini ishlatmang.
3. App Store’dan **LocalDevVPN** ni o‘rnating, oching → **Connect** (Wi-Fi).
4. Safari → **sideinstaller.net** → sertifikatlardan birini tanlab
   **SideInstaller** ni o‘rnating. “Ishonchsiz dasturchi” chiqsa: Sozlamalar →
   Umumiy → VPN va qurilmani boshqarish → **Ishonish**.
5. SideInstaller → 2-qadamdagi Apple ID bilan kiring → **Install SideStore**.
6. **Sozlamalar → Maxfiylik va xavfsizlik → Dasturchi rejimi (Developer
   Mode)** → yoqing → telefon qayta yonadi → **Yoqish**.
7. **Sozlamalar → Umumiy → VPN va qurilmani boshqarish** → Apple ID’ingiz →
   **Ishonish (Trust)**.

SideInstaller’ni sayt bergan umumiy sertifikat imzolaydi: Apple uni bekor
qilsa, saytdan boshqasini tanlang. SideStore va RomFlow esa sizning Apple
ID’ingiz bilan imzolanadi.

### RomFlow’ni o‘rnatish
- **Bir bosishda** (SideInstaller o‘rnatilgan bo‘lsa), iPhone’da oching:
  https://sideinstaller.net/open.html?url=https%3A%2F%2Fgithub.com%2Fz3wax%2FRomFlow%2Freleases%2Flatest%2Fdownload%2FRomFlow.ipa
- Yoki SideStore → **Sources** → **+** → manzil:
  ```
  https://github.com/z3wax/RomFlow/releases/latest/download/altstore-source.json
  ```
  → *Add* → *Browse* → **RomFlow** → **GET**. Keyingi versiyalar: **UPDATE**.
- Yoki IPA faylni (Releases → `RomFlow-…-ios-unsigned.ipa`) Fayllar’ga
  saqlab: SideStore → **My Apps** → **+** → faylni tanlang.

Bepul Apple ID imzosi 7 kun amal qiladi: haftada bir LocalDevVPN → Connect,
keyin SideStore → **Refresh All** (ma’lumotlar o‘chmaydi). AltStore
Classic’da ham xuddi shu manba ishlaydi.

---

## 3-yo‘l. Sideloadly — bitta telefon, kompyuter orqali
1. **Releases** dan `RomFlow-…-ios-unsigned.ipa` ni kompyuterga yuklab oling.
2. Windows: **iTunes** va **iCloud** ni apple.com saytidan o‘rnating
   (Microsoft Store versiyasi emas). Mac’da kerak emas.
3. **sideloadly.io** dan Sideloadly’ni o‘rnating va oching.
4. iPhone’ni kabel bilan ulang, qulfini oching → **Bu kompyuterga ishonish**
   → parol.
5. Sideloadly: IPA faylni oynaga tashlang, Apple ID yozing → **Start**.
6. iPhone’da 2-yo‘ldagi 2 va 3-qadamlar (Dasturchi rejimi, Ishonish).
7. 7 kundan keyin ilova ochilmay qoladi — Sideloadly’da yana **Start** bosing
   (ma’lumotlar o‘chmaydi).

---

## Muhim
- **Ma’lumotlar**: yangilash yoki qayta imzolash ma’lumotni saqlaydi.
  Ilovani o‘chirsangiz — hammasi o‘chadi: avval **Sozlamalar → Zaxira nusxa**
  saqlang (Fayllar yoki Telegram’ga).
- **Ruxsatlar**: kamera (AI kamera, Joyida), rasmlar, bildirishnomalar
  (eslatmalar) — birinchi ishlatganda so‘raladi.
- **Mos qurilmalar**: iOS / iPadOS 15 va yangiroq, iOS 27 ham; iPhone va iPad.
- TestFlight build’lari iOS 26 SDK yoki yangirog‘i bilan yig‘iladi (Apple
  talabi) — CI o‘rnatilgan eng yangi Xcode’ni tanlaydi.
- iPhone ilovasi GitHub Actions’da yig‘iladi; uni haqiqiy iPhone’da sinab
  ko‘ring va muammo bo‘lsa Issue oching.
