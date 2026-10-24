# Zavodlar narxi katalogi

RomFlow O‘zbekistondagi rom va eshik profil ishlab chiqaruvchilarining
tizimlari va narxlarini `assets/manufacturers_uz.json` faylida saqlaydi.
Ilova shu faylni o‘zi bilan olib yuradi va kuniga bir marta ochiq repodagi
yangi versiyasini tekshiradi:
`https://raw.githubusercontent.com/z3wax/RomFlow/main/assets/manufacturers_uz.json`.

## Narxlar qanday olingan
O‘zbekistonda zavodlar narxi uchun ochiq API yo‘q: rasmiy prayslar faqat
dilerlarga beriladi. Shuning uchun katalog **ochiq bozor e’lonlariga**
(Flagma.uz, Stroyka.uz, Prom.uz, uzokna.uz, goldplast.uz va zavod saytlari)
moslab tuzilgan:

1. Har bir tizim uchun profil (rama, qanot, impost, shtapik) narxi 1 metrga,
   dollarda yozilgan; shisha, rezina, furnitura va mehnat — umumiy narxlar.
2. Ilova shu narxlar bilan 1400 × 1400 mm, 2 bo‘limli, bitta ochiladigan
   romni hisoblaydi (25% ustama bilan) va 1 m² narxini chiqaradi.
3. Bozorda “… so‘m/m² dan” narxi topilgan tizimlarda bu narx bozor
   narxining 0,85–1,35 baravari oralig‘ida bo‘lishi `test/manufacturers_test.dart`
   bilan tekshiriladi (“dan” narx eng arzon rom, haqiqiy rom qimmatroq).

Bu **taxminiy** narx. O‘z dileringiz narxini kiriting: Profillar →
“Narxlarni tahrirlash” yoki “Narxlarni yangilash (diler / jadval)”. Siz
kiritgan narx katalog yangilanganda ham saqlanadi.

## Manbalar (2026-10)
| Tizim | Bozor narxi | Manba |
|---|---|---|
| AKFA ALDOX (sovuq alyuminiy) | 500 000 so‘m/m² dan, ulgurji | flagma.uz |
| AKFA THERMO 65 | 814 000 so‘m/m² dan (oq) | uzokna.uz |
| AKFA QUATTRO 60 (PVX) | 50 $/m² dan | goldplast.uz |
| ENGELBERG 7000 (PVX) | 800 000 so‘m/m²; 60 $/m² dan | stroyka.uz; goldplast.uz |
| Shishapaket | 160 000 so‘m/m² | stroyka.uz |

Qolgan tizimlar narxi shu tizimlarga nisbatan (profil og‘irligi, chuqurligi,
kamera soni) baholangan; ilovada “Bozor:” qatori yo‘q tizimlar shular.
Seriya nomi ochiq bo‘lmagan zavodlar (BENKAM, Alumin, NPK SM UZ) ro‘yxatda
bor, lekin tizimsiz: ular uchun diler narxini kiriting.

## Katalogni yangilash
1. `assets/manufacturers_uz.json` da narxni o‘zgartiring yoki yangi tizim
   qo‘shing (`systems` ro‘yxati; `manufacturer` — `manufacturers` dagi `id`).
2. `version` ni bittaga oshiring va `date` ni yangilang — ilovalar faqat
   kattaroq versiyani oladi.
3. Bozor narxini `market` ga manbasi (`source`, `url`, `seen`) bilan yozing.
4. `flutter test test/manufacturers_test.dart` — fayl o‘qilishi, har bir
   tizim hisoblanishi va bozor narxiga yaqinligi tekshiriladi.
5. `main` ga birlashtiring: ilovalar ertasi kuni yangi narxni oladi.

Fayl formati: `format: "romflow-manufacturers"`, `version` (butun son),
`referenceUsdRate` (kurs kelguncha ishlatiladigan so‘m/$), `common` (umumiy
narxlar, $), `manufacturers`, `systems` (har birida `recipe` — chizma stoli
o‘lchamlari, `usd` — tizim narxlari, `market` — bozor narxlari). Noto‘g‘ri
fayl ilovada rad etiladi va eski katalog qoladi.
