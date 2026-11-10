# Zavodlar narxi katalogi

RomFlow O‘zbekistondagi rom va eshik profil ishlab chiqaruvchilarining
tizimlari va narxlarini `assets/manufacturers_uz.json` faylida saqlaydi.
Ilova shu faylni o‘zi bilan olib yuradi va kuniga bir marta ochiq repodagi
yangi versiyasini tekshiradi:
`https://raw.githubusercontent.com/ABDULHODIY1/RomFlow/main/assets/manufacturers_uz.json`.

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

## Manbalar (2026-11)
| Tizim | Ochiq narx | Manba |
|---|---|---|
| AKFA ALDOX (sovuq alyuminiy) — profil | rama L 191 100, qanot Z va impost T 220 500, eshik qanoti 431 700, shtapik 70 200 so‘m / 6 m tayoq | ekopen.uz (Aldoks prays varag‘i) |
| AKFA ALDOX — tayyor rom | 500 000 so‘m/m² dan, ulgurji | flagma.uz |
| AKFA TERMO 57 | 60 $/m² dan (BKT-57) | goldplast.uz |
| AKFA TERMO 65 | 814 000 so‘m/m² dan (oq) | uzokna.uz |
| AKFA TRIO 5200 (3 kamera, 52 mm) | 720 000 so‘m/m² dan | okna-akfa.uz |
| AKFA TRIO 5800 (3 kamera, 58 mm) | 50 $/m² dan | goldplast.uz |
| AKFA TRIO 6000 (3 kamera, 60 mm) | 800 000 so‘m/m² dan | okna-akfa.uz |
| AKFA QUATTRO 5200 (4 kamera, 52 mm) | 650 000 so‘m/m² dan | okna-akfa.uz |
| AKFA QUATTRO 5800 (4 kamera, 58 mm) | 750 000 so‘m/m² dan | okna-akfa.uz |
| AKFA QUATTRO 6000 (4 kamera, 60 mm) | 700 000 so‘m/m² dan; 50 $/m² dan | okna-akfa.uz; goldplast.uz |
| ENGELBERG 7000 (5 kamera, 70 mm) | 800 000 so‘m/m²; 60 $/m² dan | stroyka.uz; goldplast.uz |
| Shishapaket | 160 000 so‘m/m² | stroyka.uz |

Faqat ALDOX uchun profilning o‘zining narxi (tayoq bo‘yicha) ochiq e’lon
qilingan — u katalogga aynan shu narxda yozilgan. Qolgan AKFA tizimlarida
ochiq manbada faqat tayyor romning “… dan” narxi bor: profil narxi shunga
moslab baholangan. TERMO 70, TERMO 77, ENGELBERG 7600 / 8000 va surilma
tizim uchun ochiq narx topilmadi — ular qo‘shni seriyalarga nisbatan
baholangan va ilovada “taxminiy” deb belgilangan. AKFA rasmiy diler prays
varag‘i faqat dilerlarga beriladi: aniq narx uchun uni Profillar →
“Narxlarni yangilash (diler / jadval)” orqali yuklang.
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
