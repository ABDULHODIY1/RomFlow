# Google Play va App Store’ga chiqarish
Ilova server, login yoki pullik obunaga bog‘liq emas. Backend domeni kerak emas.

## Android / Google Play
1. Play Console’da developer hisobi oching va talab qilinadigan shaxs/qurilma tekshiruvini bajaring. Standart ro‘yxatdan o‘tish to‘lovi bir martalik 25 USD; Console’dagi yakuniy shartlarni tekshiring.
2. Doimiy applicationId, mahsulot nomi, ikonka, skrinshotlar, support sahifasi va maxfiylik siyosatini tayyorlang. Hozir `uz.romflow.workshop` ishlatilgan.
3. O‘z upload keystore’ingizni himoyalangan joyda yarating va `android/key.properties` (repoga qo‘yilmaydi) yoki CI secret’lari orqali bering — README → “Android imzosi”.
4. `flutter analyze` va `flutter test` bajaring. Haqiqiy qurilmalarda ilovani birinchi ochish, qayta ochish, samolyot rejimi, PDF/JSON fayl saqlash/tanlash va zaxiradan tiklashni tekshiring.
5. `flutter build appbundle --release` bajaring va `build/app/outputs/bundle/release/app-release.aab` faylini yuklang. Ushbu loyiha API36 target qiladi.
6. Data safety, content rating, reklama va app-access deklaratsiyalarini to‘g‘ri to‘ldiring. Ilovada login va reklama yo‘q. Mijoz yozuvlari qurilmada, eksport esa foydalanuvchining tanlovi bilan amalga oshadi.
7. Yangi personal hisobga tatbiq etilsa, kamida 12 opted-in tester bilan uzluksiz 14 kun closed testing o‘tkazib, production access so‘rang.
8. Store listing va siyosat tekshiruvlarini tugatib review’ga yuboring.

## iOS / App Store
Mac va Xcode, Apple Developer Program (standart 99 USD/yil), doimiy Bundle ID, Apple signing va App Store Connect yozuvi kerak. `flutter build ipa --release` bilan build oling, TestFlight’da haqiqiy iPhone’da tekshiring, App Privacy/support/privacy-policy ma’lumotlarini to‘ldirib review’ga yuboring. iOS/iPadOS ilovasi CI’da imzosiz yig‘iladi; haqiqiy iPhone’da sinalmagan.

## Rasmiy manbalar
- https://docs.flutter.dev/deployment/android
- https://docs.flutter.dev/deployment/ios
- https://support.google.com/googleplay/android-developer/answer/6112435
- https://support.google.com/googleplay/android-developer/answer/14151465
- https://support.google.com/googleplay/android-developer/answer/11926878
- https://developer.apple.com/help/account/membership/program-enrollment/

Ilova hisob yaratmagani sababli server hisobi yo‘q. Mahalliy ma’lumotlarni tozalash mavjud. Hozirgi APK’lar GitHub Releases’da; Google/Apple do‘konlariga hali yuborilmagan.
