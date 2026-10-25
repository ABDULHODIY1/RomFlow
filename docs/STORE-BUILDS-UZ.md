# RomFlow: Play Market va App Store fayllari

Oddiy `Build` workflow sinov APK va imzosiz IPA yaratishi mumkin. Ularni do‘kon uchun tayyor fayl deb qabul qilmang.

Do‘kon fayllari: **Actions → Signed store builds → Run workflow**. `main` branchni, platformani va do‘konda ishlatilmagan build raqamini tanlang. Birinchi tavsiya: `29`; takroriy yuklashda oshiring. Workflow o‘zidan yangi signing kaliti yaratmaydi va kalit bo‘lmasa debug imzosiga o‘tmaydi.

## Android

Repository → Settings → Secrets and variables → Actions bo‘limida:

| Secret | Qiymat |
| --- | --- |
| `ROMFLOW_KEYSTORE_BASE64` | Upload keystore faylining base64 nusxasi |
| `ROMFLOW_KEYSTORE_PASSWORD` | Keystore paroli |
| `ROMFLOW_KEY_ALIAS` | Upload kalitining aliasi |
| `ROMFLOW_KEY_PASSWORD` | Upload kalitining paroli |

RomFlow hali Play Console‘ga yuklanmagan bo‘lsa, o‘z kompyuteringizda yangi upload keystore yarating. `keytool` parollarni yashirin tarzda so‘raydi:

```bash
keytool -genkeypair -v -keystore romflow-upload.jks -storetype JKS \
  -alias romflow-upload -keyalg RSA -keysize 2048 -validity 10000
```

Keystore va parollarni xavfsiz, alohida zaxirada saqlang. Keystore/base64/parolni git, release assetlari yoki chatga joylamang. Base64 shifrlash emas. Mavjud Play ilovasini yangilash uchun esa Console‘da ro‘yxatdan o‘tgan upload kalitidan foydalaning.

Natija: `RomFlow-1.0.1-29-play.aab` va `RomFlow-1.0.1-29-signed.apk`. Play Console‘ga **AAB** yuklanadi. Package ID: `uz.romflow.workshop`.

## iOS

Apple Developer hisobida shu bundle ID uchun **Apple Distribution** sertifikati va **App Store Connect** provisioning profili kerak. Sertifikatni uning private key‘i bilan birga parolli `.p12` sifatida eksport qiling. Faqat `.cer` faylning o‘zi yetmaydi.

| Secret | Qiymat |
| --- | --- |
| `APPLE_DISTRIBUTION_P12_BASE64` | Private key bilan eksport qilingan `.p12` faylning base64 nusxasi |
| `APPLE_DISTRIBUTION_P12_PASSWORD` | `.p12` eksport paroli |
| `APPLE_APPSTORE_PROFILE_BASE64` | App Store Connect `.mobileprovision` faylining base64 nusxasi |
| `APPLE_TEAM_ID` | Apple Developer Team ID |

Natija: `RomFlow-1.0.1-29-appstore.ipa`. Bundle ID: `uz.romflow.workshop`. App Store Connect‘da ilova yozuvi shu ID bilan yaratilgan bo‘lishi kerak. IPA‘ni Transporter yoki Xcode orqali tekshirtirib, App Store Connect‘ga yuklang. Store build workflow avtomatik ravishda App Review‘ga yubormaydi.

Sertifikat, provisioning profil va private key runnerning vaqtinchalik fayllarida ishlatiladi, job tugaganda tozalanadi. Ular build artefaktlariga qo‘shilmaydi. Profilning team‘i, bundle ID‘si, App Store turi va amal qilish muddati tekshiriladi.

## Fayllarni topish

Muvaffaqiyatli run‘ning Artifacts bo‘limida `RomFlow-Store-Android` va/yoki `RomFlow-Store-iOS` bo‘ladi. `main`dan olingan imzolangan fayllar mavjud `v1.0.1` GitHub reliziga ham aniq `play.aab`, `signed.apk`, `appstore.ipa` nomlari bilan qo‘shiladi. Build raqamini takrorlamang: mavjud asset ustiga yozilmaydi.

Signing kalitlari hali ulanmagan bo‘lsa, workflow tayyor bo‘lsa ham do‘konga tayyor AAB/IPA mavjud bo‘lmaydi. GitHub build muvaffaqiyati Apple/Google tekshiruvi yoki nashr tasdig‘ining o‘rnini bosmaydi.
