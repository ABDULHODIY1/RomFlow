# Hissa qo‘shish

Rahmat! Xato, taklif yoki eskirgan narx haqida Issue oching. Kod o‘zgarishi
uchun Pull Request yuboring.

## Kod
- Flutter 3.35.7 (stable). Yuborishdan oldin:
  ```bash
  dart format lib test integration_test
  flutter analyze
  flutter test
  ```
- Har bir o‘zgarish uchun test qo‘shing (`test/`). Hisob-kitobni o‘zgartirsangiz,
  `test/fixtures/calculation.json` bilan solishtiruvchi testlar o‘tishi kerak.
- Ilova matnlari o‘zbek tilida (lotin, `o‘`, `g‘` — to‘g‘ri tutuq belgisi bilan).
- Kalit, parol, keystore yoki shaxsiy ma’lumotni repoga qo‘ymang.

## Zavodlar narxi
Narx yoki tizim qo‘shish: [docs/NARXLAR-UZ.md](docs/NARXLAR-UZ.md) →
“Katalogni yangilash”. Har bir bozor narxiga manba (havola va sana) yozing.
Dilerlarning yopiq prayslarini ruxsatsiz joylamang.

## Tekshiruvlar
GitHub Actions har bir PR’da tahlil va testlarni ishga tushiradi, ilovani
barcha platformalar uchun yig‘adi.
