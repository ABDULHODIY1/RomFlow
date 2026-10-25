# RomFlow yangiliklari

## 1.0.0 — Liquid Glass to‘liq tuzatildi, tezroq va silliqroq

- Chizmadagi ochilish belgisi: chiziqlar tutqichda tutashadi, ochiq tomoni petlyalarga qaraydi — 3D bilan bir xil.
- iPhone (Liquid Glass): asbob tugmasini bosib turib chizmaga sudrash endi ishlaydi — Flutter bosishni UIKit’ga darhol beradi.
- Oddiy rejimda ham chizish asboblari alohida dumaloq, faqat ikonli tugmalar; sudralayotgan qism ham faqat ikon.
- Chizish stolining yuqori tugmalari (iPhone) endi Apple strelkalari emas, chizmadagi belgining o‘zini ko‘rsatadi: chiziqlar tutqichda tutashadi.
- Status bar (soat, batareya) och sahifalarda yana ko‘rinadi.
- Shisha endi faqat suzuvchi panellarda (yuqori panel, pastki menyu, asboblar) xiralashtiradi; kartochka, tugma va chiplar xiralashtirishsiz chiziladi. Ro‘yxatlar qotmasdan aylanadi, telefon kamroq qiziydi.
- 3D ko‘rinishda model ustidagi panellar har kadrda xiralashtirilmaydi — aylantirish silliqroq.
- 3D: model to‘xtaganda barcha qurilmalarda qirralar silliqlanadi (antialiasing).
- “Yangi smeta” oq tugmasi o‘qiladi; chip va segmentlar kapsula shaklidagi shishada; maydon yorliqlari (Eni, Bo‘yi) kesilmaydi.
- Katalog: o‘lcham maydonlari klaviatura ustiga chiqadi; bo‘limlar ko‘k fonda to‘q shishada; “AI kamera” kartasi o‘z rangida.
- Chizma ekrani, buyurtmalar va bosh sahifada matnlar kesilmaydi; katta shriftda matn ko‘pi bilan 1.15× kattalashadi.
- Klaviatura ustidagi “Keyingisi / Tayyor” paneli shisha ko‘rinishida.
- Liquid Glass faqat kerakli joyda: yuqori panel, pastki menyu, suzuvchi tugmalar va pastdan chiquvchi oynalar. Boshqa tugma, chip va plitkalar chegarasiz, yumshoq xira fonli — ikki qavat chiziqlar yo‘q.
- Pastki menyu yangilandi: balandroq shisha kapsula, tanlangan bo‘lim ajralib turadi, yozuvlar kesilmaydi.
- Paneldagi ikonka tugmalar (orqaga, bekor qilish, sozlash) qutisiz, Apple uslubida.
- Yuqori panel Apple uslubida: yaxlit plita yo‘q, sahifa sarlavha ostida yumshoq xiralashadi; orqaga tugmasi shisha doirada, panel asboblari bitta shisha kapsulada.
- iOS asbob tugmalarini bosib turib chizmaga sudrash mumkin (bo‘lish, deraza, eshik, to‘ldirma, furnitura) — tushadigan joy oldindan ko‘rsatiladi; 2D/3D tugmalari kengroq.
- Chizma stoli menyusi iOS’ning o‘z Liquid Glass tugmalarida (SF Symbols, tanlangani prominent shisha); yuqori paneldagi orqaga va asbob tugmalari, 2D/3D ham tizim tugmalari. Maydon nomlari maydon ichida; sarlavha ostidan sahifa ko‘rinmaydi.
- Tezlik: tizim (UIKit) shishasi faqat pastki menyu va asosiy tugmalarda; boshqa tugma, chip, panel va oynalar yengil chizilgan shishada, maydon va ro‘yxat qatorlari shishasiz. Telefon qizimaydi va qotmaydi; 3D sahifada tugmalar model ustida qayta yig‘ilmaydi.
- Shisha tugmalar endi to‘g‘ri kapsula (linza shaklida cho‘zilmaydi); chizma stoli mavzuga mos: qorong‘ida qora fon va oq yozuv/o‘lchamlar, och mavzuda oq fon va qora yozuv.
- Chizish qulayroq: ikki barmoq bilan chizmani 5× gacha kattalashtirish va surish (bir barmoq chizishda davom etadi), “Asl o‘lcham” tugmasi; bo‘lim ustiga ikki marta bosish uning sozlamalarini ochadi.
- Chizma stoli butun ekranda: qog‘oz chetdan-chetgacha, asboblar ixcham shisha kapsulalarda ustida suzadi; “To‘liq ekran” tugmasi asboblar va pastki panelni yashiradi. Asbob tugmalari faqat ikonka (nomi uzoq bosganda), 3D va Sarf ham ikonka.
- Rus va ingliz tillari: birinchi ochilishda va har yangilanishdan keyin til so‘raladi; Sozlamalar → Til’dan istalgan payt o‘zgartiriladi. Butun interfeys, xatolar, sana va iOS tugmalari tanlangan tilda.
- Yangi versiya chiqsa, ilova ochilganda shisha oynada “Yangilash” taklif qilinadi (iPhone’da App Store, so‘ng GitHub; Android’da APK).
- Chizma ekrani to‘liq suyuq shishada: ikki qator asboblar, tanlangan bo‘lim, 2D/3D almashtirgich va pastki panel — har biri Apple’ning suzuvchi shisha kapsulasi, tanlangani ichida linzadek ajraladi. Ilova tugmalari, chiplar, segmentlar va qidiruv ham asl shisha kapsulada.
- “Orqaga” doirasidagi belgi markazda.
- iPhone’da asl Apple Liquid Glass: pastki menyu tizimning o‘z UITabBar’i (ekran pastigacha, balandligini iOS o‘zi beradi); yuqori panel, pastdan chiquvchi oynalar, dialoglar, suzuvchi tugmalar va klaviatura paneli ortida UIGlassEffect.

## 1.0.1 — rangli Liquid Glass va 3D tuzatishlari

- iOS uchun oddiy, ikonka, matnli va qo‘shish tugmalari umumiy rangli glass ko‘rinishiga moslandi; filtrlar, segmentlar, maydonlar va ro‘yxat boshqaruvlari ham shu uslubda.
- Native iOS glass tugmalariga amal ranglari uzatiladi. Yuqori kontrastda shaffoflik o‘chadi; klaviatura va o‘chirilgan holatlar saqlanadi.
- Tor ekran va katta matnda uzun amal tugmasi yorlig‘i sig‘adigan qilib o‘raladi. iPhone/iPad, yotiq holat va katta matn bo‘yicha testlar bor.
- iPhone 13 va yangilariga Studio 4K tekstura profili; kuchsiz qurilmalarga yengil profil. Qizish/xotira bosimida yuklama kamayadi.
- Aylanishda kamera o‘lchami barqaror, qirra qoplamasi va perspektiva teksturasi yaxshilandi. Telefonda FPS o‘lchovi hali bajarilmagan.
- Delfin ruchkasi tortiladi, ikki tishli vilka pastga tushadi, keyin qanot ochiladi. Rama ushlagichlari yupqa va sirtga mahkamlangan; Archa nomi tuzatildi.
- Flutter analyze xatosiz; 195 ta test o‘tdi. Native iOS yig‘ilishi CI’da alohida tekshiriladi.

# RomFlow 1.0.1 — Liquid Glass va 3D render

- 3D aylanishda vintlar va mayda detallar saqlanadi; tekstura darajasi harakat boshlanganida tushirilmaydi.
- Kamera vsync asosida yumshatiladi; 60/120 Hz harakat matematikasi tekshirildi.
- Yuzalarga yengil protsedurali tekstura, shishaga burchakka bog‘liq aks qo‘shildi.
- “Rasmini ulashish” menyusida 4K (uzun tomoni 4096 px) rasm chiqarish bor.
- Chizish buferlari va UV koordinatalari qayta ishlatiladi; tekstura UI oqimidan tashqarida tayyorlanadi.
- Mavjud sahifa tuzilishi, ranglar va chizma hisobi saqlangan.
- Kartalar, tasdiqlash oynalari va shakllar umumiy o‘qilishi qulay glass yuzasidan foydalanadi.
- Yuqori kontrastda shaffoflik va blur o‘chadi; kichik ikonkalarning bosish maydoni 48 px.
- Native iOS tugmalari va navigatsiya tema, matn kattaligi va holat o‘zgarishlarini oladi.
- Native boshqaruv yangilanmasa, Flutter boshqaruviga qaytadi; eskirgan yoki o‘chirilgan tugma hodisalari bajarilmaydi.
- Och va qorong‘i temalar uchun navigatsiya ranglari uyg‘unlashtirildi.

# RomFlow 1.0.0 — birinchi reliz

Eshik va rom ustaxonalari uchun smeta, chizma, 3D va buyurtmalar.
Android, iPhone, iPad, Windows, macOS va Linux. Internetsiz ishlaydi.

## Asosiy imkoniyatlar
- **Chizma stoli**: 59 ta tayyor dizayn (deraza, eshik, arka, boshqa shakllar) yoki bo‘sh rom; bo‘lish, sudrash, chetidan tortish, zinapoya rama, ochilish turlari, shisha/panel, furnitura.
- **Zavodlar narxi**: O‘zbekistondagi 10 ta ishlab chiqaruvchining 14 ta profil tizimi (AKFA, ENGELBERG, IMZO/REHAU, Alubest, ALUTEX…); smetadagi “Zavodlar narxi ›” bilan bitta rom barcha tizimlarda solishtiriladi.
- **Aniq sarf**: profil, shisha, rezina, furnitura, raskroy va chiqindi.
- **3D**: jonli model, ochilish animatsiyasi, detallarni sochish, profil kesimlari.
- **AI kamera va “Joyida”**: rasmdan chizma; jonli kamerada rom haqiqiy darchaga qo‘yiladi.
- **Buyurtmalar**: smeta → PDF → bosqichlar, to‘lov, qarz, bo‘lib to‘lash, razmer, eslatma, ombor, xodimlar, moliya.
- **Narxlar**: Markaziy bank dollar kursi har kuni; diler jadvalidan narx yuklash.
- **iPhone va iPad**: Apple’ning o‘z Liquid Glass’i — pastki tab bar va asosiy tugmalar tizimning o‘zi chizadi (iOS 26+); iPhone SE’dan Pro Max’gacha va iPad’larda tekshirilgan.
- **Kamroq yozuv**: katalogda rasm ostidagi nomlar, bosh sahifa va chizma stolidagi uzun izohlar olib tashlandi.

## O‘rnatish
- Android: `RomFlow-1.0.0-27-arm64.apk` (ko‘p telefonlar), `…-armv7.apk` (eski), `RomFlow-1.0.0-27.apk` (hammasi). Oldingi sinov versiyalari ustiga o‘rnatiladi, ma’lumotlar saqlanadi.
- iPhone / iPad: `RomFlow-1.0.0-27-ios-unsigned.ipa` — qo‘llanma: IOS-Qollanma.md.

# Sinov versiyalari tarixi
Quyida 1.0.0 dan oldingi ichki sinov (pilot) versiyalari.

# RomFlow 2.2.0 — Liquid Glass

## iPhone va iPad’da Liquid Glass dizayn
- **Pastki menyu** — suzuvchi shisha kapsula (iOS 26+ da Apple’ning haqiqiy Liquid Glass materiali); ro‘yxatlar uning ostidan o‘tadi va shisha orqali ko‘rinadi.
- **Tepadagi panel** — shaffof shisha, kontent ostidan o‘tadi; tugmalar dumaloq shisha.
- **Pastdan chiqadigan oynalar** (Zavodlar narxi, Profil va rang, andozalar…) — katta burchakli shisha varaq.
- **Chizma stoli** — asboblar qatori va pastki panel shisha kartalar.
- **3D** — rejim va ko‘rinish tugmalari, pastki ijro paneli to‘q shisha; model ular orqali ko‘rinadi.
- Bosh sahifadagi “Razmer yozish” — shisha tugma.
- Shisha: orqasi xiralashadi va rangi to‘yinadi, cheti yorug‘likni ushlaydi, tepadan yumshoq yaltirash; iOS “Kontrastni oshirish” yoqilgan bo‘lsa — to‘liq qoplangan.
- **Sozlamalar → Ko‘rinish → Dizayn**: Avto (iPhone’da Liquid Glass), Liquid Glass (Android’da ham) yoki Oddiy.

## Har qanday iPhone, iPad va kichik telefon
- iPhone SE (1 va 3), mini, oddiy, Pro Max, iPad mini / Air / Pro va yotiq telefonda tekshirildi: hech narsa bir-birini to‘smaydi, sig‘may qolmaydi.
- Juda katta shrift (iOS “Matn o‘lchami”) yoqilganda ham tugma va kartalar shishib ketmaydi: matn ko‘pi bilan 1,3 baravar kattalashadi.
- Bosh sahifadagi ko‘rsatkich kartalari matn kattaligiga moslashadi; pastki menyu tugmalari kichrayib sig‘adi.
- Kichik ekranda (SE, 8) katalog ixcham: sarlavha yig‘ilgan holda ochiladi, dizaynlar darhol ko‘rinadi.
- Smetada 2D | 3D tugmasi chizmani endi to‘smaydi.
- Tarif va moliya sahifalarida uzun yozuvlar qatorga sig‘adi; yotiq telefonda yon menyu faqat belgilar bilan.

# RomFlow 2.1.0 — O‘zbekiston zavodlari narxi

## Ishlab chiqaruvchilar katalogi
- **10 ta ishlab chiqaruvchi va yetkazib beruvchi**: AKFA Aluminium, AKFA Plast, ENGELBERG, IMZO, BENKAM, Alubest, ALUTEX, Alsys, Alumin, NPK SM UZ.
- **14 ta profil tizimi**: AKFA ALDOX, AKFA THERMO 65, AKFA TRIO 60 / QUATTRO 60 / PENTA 65 / INSLIDER, ENGELBERG 7000 / 7600 / 8000 INFINITY, REHAU EURO-DESIGN 70 (IMZO), Alubest ALDOKS va AluThermo-70, ALUTEX va Alsys sovuq profillari.
- Har bir tizimda: chuqurligi, kamerasi, termo yoki sovuq, shisha qavati, profil va furnitura narxi (dollarda, Markaziy bank kursida so‘mga o‘tadi), **1 m² narxi** va ochiq bozordagi narx manbasi (Flagma.uz, Stroyka.uz, uzokna.uz, goldplast.uz…).
- Ochish: bosh sahifada **“Zavodlar”**, Katalog → **“Zavodlar narxi”** yoki Sozlamalar → Narxlar. Bir bosishda tizim profillar ro‘yxatiga qo‘shiladi; birinchi ochilishda AKFA ALDOX, AKFA THERMO 65, AKFA QUATTRO 60 va ENGELBERG 7000 o‘zi qo‘shiladi.

## Smetada zavodlar narxini solishtirish
- Chizma stolida pastda profil nomi va **“Zavodlar narxi ›”**: shu rom (o‘lchami, soni, rangi bilan) barcha 14 ta tizimda hisoblanadi va arzonidan qimmatiga tartiblanadi; har biri eng arzonidan necha foiz qimmatligi ko‘rinadi. Alyuminiy yoki PVX filtri bor.
- Bittasini bossangiz, smeta shu tizimga o‘tadi (rang va furnitura saqlanadi).

## Narxlar yangilanadi, sizniki saqlanadi
- Katalog ilova ichida va ochiq GitHub repodagi `assets/manufacturers_uz.json` faylida. Ilova kuniga bir marta yangi versiyasini tekshiradi: yangi narxlar o‘zi keladi.
- Siz qo‘lda yozgan yoki diler jadvalidan yuklagan narx **katalog yangilanganda ham o‘zgarmaydi**.
- Dollar kursi kiritilmagan bo‘lsa ham narxlar ishlaydi (katalogning taxminiy kursi); Markaziy bank kursi kelgach o‘sha kursga o‘tadi.

## iPhone (iOS 27)
- **TestFlight**: ustaxona egasi Apple Developer akkauntini bir marta ulasa, har bir yangi versiya o‘zi TestFlight’ga yuklanadi — ustalar havoladan bir bosishda o‘rnatadi.
- **Bepul yo‘l**: SideStore uchun RomFlow manbasi — bir marta sozlanadi, keyin **GET** / **UPDATE**.
- Aniq qadamlar: [IPHONE-UZ.md](IPHONE-UZ.md).

## Boshqa
- “Zamer” endi hamma joyda **“Razmer”**: bosh sahifadagi “Razmer yozish” tugmasi, “Razmer” bo‘limi, eslatmalar.
- Sozlamalar: **Litsenziyalar** sahifasi, yangilangan maxfiylik matni (internet qayerda ishlatiladi).
- Android imzo kaliti ochiq repoga qo‘yilmaydi: GitHub secret orqali beriladi (README → “Android imzosi”).
- Zavodlar katalogi qanday tuzilgani va qanday yangilanishi: [NARXLAR-UZ.md](NARXLAR-UZ.md).

# RomFlow 2.0.0 — chiroyli va yengil 3D

## 3D render
- **Yorug‘lik**: asosiy (yuqori-chapdan) va yumshoq qo‘shimcha yorug‘lik, studiya foni, rom ostida yumshoq soya.
- **Materiallar**: tutqich, petlya va qulflar metalldek yaltiraydi, alyuminiy/PVX profil yumshoq jilo beradi, rezina xira.
- **Shisha**: tiniq, och ko‘k-yashil; qiya qaraganda osmonni ko‘proq aks ettiradi, katta oynalarda ikki diagonal yaltirash — model aylanganda ular ham siljiydi.
- **Yengil**: aylantirayotganda faqat burilish qayta hisoblanadi, juda mayda detallar (vint, qopqoq) vaqtincha chizilmaydi — barmoq qo‘yib yuborilgach qaytadi. Chizma stolidagi jonli 3D ham shunday.

## 3D sahifa — yozuvsiz
- Katta qalin “Old / Chap / O‘ng / Tepa / 3D” qatori va izoh yozuvlari olib tashlandi: ko‘rinishlar 3D ustidagi kichik belgilar (bosib tursangiz nomi chiqadi).
- Rejimlar (Ochilish, Sochish / yig‘ish, Mexanizm, Kesimlar, Joyida, Aylanish, Qirralar) — bitta qator belgi.
- Pastda faqat ijro tugmasi va surgich; detal raqamlari endi o‘zi chiqmaydi (kerak bo‘lsa # belgisi). 3D maydoni kattaroq.

# RomFlow 1.9.0 — yangi katalog dizayni

## “Qanday rom?” katalogi
- Tepadagi bo‘limlar (**Derazalar 27, Eshiklar 16, Arkalar 12, Boshqa 4**) yig‘ilganda ham nomi va soni bilan ko‘rinib turadi; tanlangan bo‘lim ramka bilan ajraladi.
- **Bo‘sh rom** va **AI kamera** kichik kartalar bo‘lib yonma-yon turadi — dizaynlarga ko‘proq joy qoladi.
- **Filtrlar**: Fortochkali, Panelli, Surilma, 1 / 2 / 3 / 4+ bo‘limli — bir bosishda keraklisi qoladi (har birining yonida nechta borligi).
- Har bir dizayn kartasida **nomi va o‘lchami**, burchagida **3D** tugmasi — chizishdan oldin 3D’da ko‘rish. Bosing — chizma ochiladi, bosib tursangiz — tanlanadi.
- Telefonda kartalar 3 qatordan, kattaroq; planshetda 4–7 tadan.
- Pastki panel ixcham: Eni, Bo‘yi, soni; joyi (belgi), 3D va o‘qiladigan katta **“Bo‘sh romni chizish”** (yoki tanlangan dizayn nomi) tugmasi.
- Boshqa bo‘limga o‘tganda ro‘yxat boshidan ochiladi.

# RomFlow 1.8.0 — jonli kamera: rom haqiqiy darchada

## Joyida — jonli kamera
- Chizma stolida 2D | 3D yonidagi kamera belgisi (yoki 3D sahifasida “Joyida”) endi **jonli kamerani** ochadi. Telefonni devordagi darchaga yoki eski romga qarating: chizilgan rom yoki eshik **shu zahoti ekranda haqiqiy darchaga qo‘yiladi** va telefon qimirlaganda ham o‘rnida turadi. O‘rin sekundiga bir necha marta telefonning o‘zida topiladi (internet shart emas).
- Tepada holat: “Telefonni darchaga qarating…” → “O‘rin topildi — rom joyida”.
- **Avto / Qo‘lda**: o‘rin noto‘g‘ri topilsa, burchakni barmoq bilan surasiz, rom o‘sha joyda ushlab turiladi.
- **“Rasmga olish”** — kadr olinadi, burchaklarni aniqlashtirasiz (Claude kaliti bo‘lsa, AI yana bir bor tekshiradi) va **“Mijozga yuborish”** bilan rasmni ulashasiz.
- Kamera faqat tasvir uchun: ovoz yozilmaydi (mikrofon ruxsati so‘ralmaydi). Kompyuterda (kamera yo‘q) avvalgidek rasm bilan ishlaydi.

## Dollar kursi
- Markaziy bank sayti javob bermasa, kurs **xalqaro ochiq manbadan** (ExchangeRate-API) olinadi va sozlamalarda “xalqaro kurs” deb yoziladi.

# RomFlow 1.7.0 — narxlar API va “Joyida ko‘rish”

## Dollar kursi — Markaziy bankning ochiq API’sidan
- Ilova ochilganda kuniga bir marta **O‘zbekiston Markaziy bankining rasmiy dollar kursi** olinadi (cbu.uz ochiq JSON xizmati, kalitsiz va bepul).
- Diler narx ro‘yxatidagi **dollardagi narxlar** (valyuta ustunida USD) endi dollarda eslab qolinadi: kurs o‘zgarsa, so‘mdagi narx o‘zi qayta hisoblanadi. So‘mdagi narxlar o‘zgarmaydi.
- Sozlamalar → Dollar kursi: “Markaziy bankdan olish” tugmasi, “Har kuni o‘zi yangilansin” (o‘chirsangiz, kursni qo‘lda yozasiz).
- Diler havolasi yoki Google Sheets manbasida **“Har kuni o‘zi yangilansin”**: ilova ochilganda kuniga bir marta narxlar shu havoladan olinadi va qo‘llanadi, nechta narx o‘zgargani qisqa xabarda chiqadi.
- Eslatma: profil, shisha va furnitura narxlari uchun O‘zbekistonda ochiq API yo‘q — ularni dileringizning narx havolasi yoki o‘z Google Sheets jadvalingiz orqali ulaysiz (avvalgidek).

## Joyida ko‘rish — rom yoki eshikni rasmdagi o‘ringa qo‘yish
- 3D sahifasidagi sun’iy “Devorda” o‘rniga **“Joyida”**: telefonni devordagi darchaga yoki eski romga qarating va rasmga oling.
- Dastur o‘rnini **o‘zi topadi** (telefonda; Claude kaliti bo‘lsa — AI bilan) va chizilgan rom yoki eshikni o‘sha joyga perspektivada, haqiqiy rangida, qanot va tutqichlari bilan qo‘yadi.
- Ko‘k nuqtalarni surib burchaklarni aniqlashtirasiz, romning o‘rtasidan ushlab butunini surasiz. **“Mijozga yuborish”** — tayyor rasmni Telegram va boshqalarga ulashish.
- Chizma stolida 2D | 3D yonidagi kamera belgisi ham shu oynani ochadi. Rasm bo‘lmasa — “Namuna rasm bilan sinab ko‘rish”.

# RomFlow 1.6.0 — zinapoya rom: faqat shu bo‘lakni tortish

## Bo‘lakni pastidan (yoki tepasidan, yonidan) tortish — faqat shu bo‘lak
- Bo‘lakning rama tomonidagi tutqichini torting: **faqat shu bo‘lak** cho‘ziladi yoki qisqaradi, qolgan bo‘laklar joyida qoladi. Rama bo‘lak atrofidan zinapoya bo‘lib aylanib o‘tadi.
- Masalan, **ikki yoni devorli eshik** (balkon bloki): 3 bo‘limli romda chap va o‘ng bo‘lakni pastidan 500 mm yuqoriga torting — ular devor ustida deraza bo‘lib qoladi, o‘rtadagi eshik polgacha boradi. Yoki o‘rtadagi bo‘lakni pastga torting — faqat eshik uzayadi.
- Chizmada zinapoya o‘lchami (devor balandligi) to‘q sariq raqam bilan ko‘rinadi. 3D’da “Devorda” rejimida kesilgan joyni devor to‘ldiradi, deraza ostida podokonnik turadi.
- Hisob zinapoya ramaga qarab: rama detallari har bir tomon bo‘yicha, impostlar kesilgan joygacha, shisha har bo‘lak bo‘yicha.
- Kesilgan bo‘lakni bo‘lsangiz, ikkala yangi bo‘lak ham kesilgan holda qoladi; impost olib tashlansa, birlashgan bo‘lak eng pastgacha (eng uzungacha) yetadi. Bo‘lakni qaytib qo‘shnilari darajasiga tortsangiz, rom yana to‘g‘ri to‘rtburchak bo‘ladi.
- Butun rom o‘lchamini o‘zgartirish uchun pastdagi “Eni / Bo‘yi” yoki “Tortish” asbobidan foydalaning.

## Katalog va bosh sahifa
- Katalogda dizayn kartasiga (yoki “Bo‘sh rom”ga) **bir bosish — chizma darhol ochiladi**, “Chizishni boshlash”ni bosish shart emas. Eni/bo‘yi, soni va joyini kartaga bosishdan oldin yozing. Kartani bosib tursangiz — faqat tanlanadi (3D ko‘rish uchun).
- Bosh sahifadagi **“Yangi smeta”** va **“Razmer yozish”** tugmalari kichik telefonda ham yonma-yon turadi.

# RomFlow 1.5.0 — bo‘lakni tortish, jonli 3D va AI kamera

## Bo‘lakni chetidan tortish
- Chizma stolida bo‘lakni tanlang: uning chetlarida **tutqichlar** chiqadi. Pastki (yoki yon) tutqichni torting — **aynan shu bo‘lak** cho‘ziladi yoki qisqaradi, o‘lchami barmoq yonida mm’da ko‘rinadi (5 mm qadam).
- Chet impost bo‘lsa, impost suriladi va qo‘shni bo‘lak o‘lchami o‘zgaradi. Chet rama bo‘lsa (pastki yoki o‘ng), butun rom kattalashadi, qolgan bo‘laklar o‘lchami o‘zgarmaydi (1.6 dan: faqat shu bo‘lak, rama zinapoya bo‘ladi).
- Bitta “Orqaga” bilan qaytadi; 80 mm dan kichik yoki 6 m dan katta bo‘lmaydi.

## 3D preview
- Kanvas burchagida **2D | 3D** almashtirgich: 3D’da chizma o‘rnida jonli model, barmoq bilan aylantiriladi. Asbob tanlansa, 2D ga qaytadi.
- Katalogda tanlangan dizaynni chizishdan oldin **“3D”** tugmasi bilan ko‘rish mumkin.

## AI kamera — rasmdan chizma
- Bosh sahifada **“AI kamera”**, katalogda **“AI kamera — rasmdan chizish”** kartasi.
- Romni rasmga oling yoki galereyadan tanlang → ramaning 4 burchagini belgilang → dastur rasmni to‘g‘rilaydi va impostlarni topadi.
- **Telefonda aniqlash** — internetsiz: uzun to‘g‘ri chiziqlar bo‘yicha tik va yotiq impostlar, bir xil och kulrang qism — panel.
- **AI bilan** (ixtiyoriy) — Sozlamalar → AI kamera’da o‘z Claude API kalitingizni kiritsangiz, rasm Anthropic’ga yuboriladi va impostlar bilan birga ochilish turlari ham aniqlanadi. Kalit faqat telefonda, zaxira faylga yozilmaydi.
- Natijani tekshirish: **O‘chirish** (chiziqni bosing), **+ Tik**, **+ Yotiq**, **Ochilish** (bo‘limni bosib ochilish turini almashtirish). Eni va bo‘yini razmerdan yozing — rasmdan o‘lcham taxminiy. **“Chizmaga o‘tkazish”** — chizma stolida davom etasiz.

## Olib tashlangan / tuzatilgan noqulay funksiyalar
- Furniturada faqat shu romga mos detallar ko‘rinadi: eshik bo‘lmasa dovodchik va ostona, bir qavatli shishada shpros chiqmaydi (oldin bosilsa qizil xato berardi).
- Xato xabari endi qizil yozuv bo‘lib ekranda qolib ketmaydi — qisqa xabar bo‘lib chiqadi va yo‘qoladi.
- “Batafsil sozlash”da o‘lcham yozilgach “Avval O‘lchamni qo‘llash bilan tasdiqlang” xatosi chiqmaydi: yozilgan o‘lcham hisoblashda va chizma stoliga qaytishda o‘zi qo‘llanadi.
- Tashqi shakl almashtirilganda bo‘linishlar o‘chib ketmaydi (yangi shaklga sig‘sa saqlanadi).

# RomFlow 1.4.0 — tayyor dizaynlar katalogi

## Katalog
- “Yangi smeta” (yoki smetada “Yana rom qo‘shish”) endi **katalog** bilan ochiladi. Tepada to‘rt bo‘lim rasmlar bilan: **Derazalar (27), Eshiklar (16), Arkalar (12), Boshqa (4)**. Pastga aylantirganda sarlavha kichrayadi.
- Derazalar: 1–5 bo‘limli, fortochkali (1–3 fortochka), o‘rtasi yoki yonlari bo‘lingan, vitraj 3×3 / 3×4 / 3×5, panelli balkon romlari, 2–4 qanotli surilma.
- Eshiklar: bitta va 2 tabaqali, tor + keng, panelli, fortochkali, yon oynali, portal, balkon bloki (chap/o‘ng), surilma eshik.
- Arkalar: yarim doira va yassi arka; arka alohida yoki 2 ga bo‘lingan, ostida 1–3 bo‘lim, o‘rtasi yoki yonlari bo‘lingan, arkali eshik. Boshqa: dumaloq, oval, uchburchak, trapetsiya.
- **“Bo‘sh rom”** kartasi — o‘zingiz bo‘lib chizasiz.
- Pastda: eni, bo‘yi, soni, joyi va **“Chizishni boshlash”**. Dizaynni tanlasangiz, uning odatiy o‘lchami yoziladi; o‘lchamni o‘zingiz yozgan bo‘lsangiz, u saqlanib qoladi.
- Rasmlar mahsulot rasmi kabi: och rama, shisha yaltirog‘i, kulrang sendvich panel. Shu uslub smeta va buyurtmalar ro‘yxatida ham.
- Chizma stolida: **Andoza → Katalog** — dizayn joriy chizmani almashtiradi, o‘lcham saqlanadi.

## Chizma stolidagi tuzatishlar
- Andoza tanlanganda o‘lcham endi o‘zgarmaydi (oldin 1200×1500 rom andozani bosganda 700×1400 bo‘lib qolardi).
- Chizma kanvasda kattaroq: o‘lcham chiziqlari faqat chap va pastda, bo‘sh chetlar kamaydi. O‘lcham yozuvlari yiriklashdi.
- **Katta arkalar xato bermaydi:** oldin arka romining butun konturi bitta egilgan detal deb hisoblanib, 1800×1900 arka “6 m tayoqqa sig‘maydi” xatosini berardi. Endi faqat arka qismi egiladi, yon va past tomonlari to‘g‘ri detal; burchaklar ham hisoblanadi.
- Tanlangan bo‘lim yozuvida ochilish nomi qisqa (“Passiv qanot”, “Burilma”), maslahat qatori yangilandi.

# RomFlow 1.3.1 — chizma endi smeta

1.3.1: “Sarf” oynasidagi “Smetaga qo‘shish” tugmasi narxi bilan oyna pastida doim ko‘rinadi (uzun ro‘yxat oxirida qolib ketmaydi).

## Smeta chizmadan boshlanadi
- Bosh sahifadagi asosiy tugma endi **“Yangi smeta”**: avval romni chizasiz, narx o‘zi hisoblanadi. Ikkinchi tugma — **“Razmer yozish”**.
- **“Qanday rom?”** oynasi: rom turini rasmdan tanlang (bo‘sh rom, 2 tabaqali, fortochkali, balkon bloki, eshik, surilma, arka, vitraj…), eni va bo‘yini, sonini va joyini (Zal, Oshxona, Yotoqxona…) yozing → “Chizishni boshlash”.

## Chizma stoli
- Tanlangan bo‘lim kanvas tepasida yoziladi: raqami, o‘lchami, ochilishi va to‘ldirmasi. **“Sozlash”** — ochilish, to‘ldirma, setka, qulf, bo‘lish menyusi (uzoq bosish shart emas).
- Pastki panel telefonga sig‘adi: **Eni, Bo‘yi, Soni, Rang, Joyi** — bosib o‘zgartiriladi.
- **“Smetaga qo‘shish”** tugmasida narx doim ko‘rinadi va rom bir bosishda smetaga qo‘shiladi. **“Sarf”** — materiallar, raskroy va shisha listlari.
- **“Ko‘zgu”** (Bo‘lish → Ko‘zgu): chap va o‘ng almashadi — qanotlar, eshik tomoni va 90° qayt ham.
- “Chizma sozlamalari” endi **“Batafsil sozlash”** deb ataladi.

## Smeta sahifasi
- Har bir rom kartochkada: chizma rasmi, joyi, o‘lchami, profili, **soni (− / +)** va narxi.
- Rom menyusi (⋮): chizmani tahrirlash, joyini yozish, **nusxa olish**, olib tashlash (“Qaytarish” bilan).
- **Jami summa pastda doim ko‘rinadi** (kurs kiritilgan bo‘lsa dollarda ham) va “Saqlash” shu yerda. Mijoz tanlanmagan bo‘lsa, saqlashda darhol mijoz qo‘shish oynasi chiqadi.
- Chizmasiz tezkor hisob “Tezkor hisob (chizmasiz)” bo‘limiga yig‘ildi.
- Rom joyi buyurtma sahifasida, PDF’da va ulashiladigan matnda ko‘rinadi; buyurtmalar ro‘yxatida birinchi rom rasmi chiqadi.

# RomFlow 1.2.0 — narxlar, tarif, yangi dizayn va barcha platformalar

## Android’da o‘rnatish (APK ochilmasa)
- **Qaysi fayl:** ko‘pchilik telefonlar uchun `RomFlow-1.2.0-15-arm64.apk` (~21 MB). U ishlamasa (2015-yilgacha chiqqan arzon telefonlar) — `…-armv7.apk`. Hammasiga mos katta fayl — `RomFlow-1.2.0-15.apk` (~62 MB). Uchalasining versiyasi bir xil, biri ikkinchisining ustiga o‘rnatiladi.
- **Faylni telefonga saqlang:** Telegram/brauzerda faylni oxirigacha yuklab oling (hajmi yuqoridagidek bo‘lishi kerak), keyin “Fayllar” / “Menejer” ilovasidagi *Yuklanmalar* (Download) papkasidan oching. Ba’zi messenjerlar ichida APKni to‘g‘ridan-to‘g‘ri ochib bo‘lmaydi.
- **“Noma’lum ilovalar” ruxsati:** Android so‘rasa “Sozlamalar” → shu fayl ochilgan ilova (Fayllar, Telegram, Chrome) → “Noma’lum manbalardan o‘rnatishga ruxsat” ni yoqing va orqaga qayting.
- **Play Protect** “Xavfli bo‘lishi mumkin” desa: “Batafsil” → “Baribir o‘rnatish”. Ilova Play Market’dan emas, shuning uchun ogohlantiradi.
- **“Ilova o‘rnatilmadi”** chiqsa: telefonda boshqa kalit bilan imzolangan eski “RomFlow” bor. Avval undagi ma’lumotni zaxiraga saqlang, ilovani o‘chiring, keyin yangisini o‘rnating.
- **“Paketni tahlil qilishda xato”** — fayl to‘liq yuklanmagan yoki Android 7.0 dan eski. Faylni qayta yuklab oling.
- Xiaomi/Redmi’da “MIUI optimallashtirish” yoki “Xavfsizlik” ilovasi ham so‘rashi mumkin — “Ruxsat berish”.

## Narxlarni yangilash
- “Katalog → Narxlarni yangilash (diler / jadval)” va “Sozlamalar → Narxlar”. Diler yoki o‘zingizning Google Sheets jadvalingiz havolasini (CSV yoki JSON) qo‘shing, “Yangilash” bilan narxlar yuklanadi. Qaysi profilda nima o‘zgarishi oldindan ko‘rsatiladi, tasdiqlamaguningizcha hech narsa o‘zgarmaydi.
- Jadvalda ustaxona so‘zlari tushuniladi: kosa, qanot, orta/impost, shtapik, shisha, delfin/ruchka, qayt va h.k. Narx so‘mda yoki dollarda; dollar uchun “Sozlamalar → Dollar kursi”.
- “Namuna jadval” tugmasi joriy narxlaringiz bilan to‘ldirilgan CSV beradi.
- Romchi’ning ochiq (hammaga ruxsat etilgan) narx API’si yo‘q, uning yopiq serveridan narx olish uning qoidalariga zid. Shuning uchun narxlar o‘zingiz ruxsatli manbalardan (diler, o‘z jadvalingiz) olinadi.

## Tarif va to‘lov
- “Offline • Bepul” yozuvi olib tashlandi. O‘ng yuqoridagi toj belgisi → “Tarif va to‘lov”: Start, Pro, Biznes tariflari va Click, Payme, Uzum Bank, Uzcard/Humo/Visa to‘lov usullari.
- **Hozircha bepul:** to‘lov o‘chirilgan, hamma Pro imkoniyatlaridan bepul foydalanadi. Haqiqiy to‘lovni yoqish uchun to‘lov tizimlari bilan shartnoma va to‘lovni tasdiqlaydigan server kerak; App Store’da obuna Apple orqali bo‘ladi.

## Dizayn
- Yangi bosh sahifa: “Rom chizish” va “Yangi smeta” tugmali sarlavha, rangli ko‘rsatkichlar, 10 ta tezkor bo‘lim (Mijozlar, Razmer, Qarzlar, Eslatma, Ombor, Xodimlar, Moliya, Statistika, Narxlar, Raskroy).
- Planshet va kompyuterda pastki menyu o‘rniga chap yon panel, keng ekranda matn markazda va o‘qishga qulay kenglikda.

## Yangi funksiyalar
- **Razmer (o‘lchov):** mijoz, sana-vaqt, manzil va har bir oyna o‘lchamlari; “Smetaga” bosilsa shu o‘lchamlar bilan smeta ochiladi. Rejalashtirilgan razmerlar bosh sahifada ko‘rinadi.
- **Qo‘shimcha ishlar smetada:** podokonnik, otliv, otkos, demontaj, yetkazib berish, chiqindi, setka va boshqa — miqdor va narx bilan; oxirgi narx eslab qolinadi. PDF va matnda ham chiqadi.
- **Bo‘lib to‘lash:** buyurtma qoldig‘ini 2–24 oyga bo‘lish; har bir to‘lov “to‘langan / kutilmoqda / kechikkan” deb ko‘rsatiladi.
- **Dollar ekvivalenti:** kurs kiritilsa smeta jami “≈ … $” bilan ko‘rsatiladi.

## Platformalar
- Android, iPhone/iPad, Mac, Windows va Linux uchun bitta kod. Kompyuterda fayl saqlash/ochish oynalari, Linux’da ulashish o‘rniga matn buferga ko‘chiriladi.
- iPhone/iPad/Mac yig‘malari imzosiz: o‘rnatish uchun Apple Developer hisobi bilan imzolash (yoki TestFlight) kerak.

# RomFlow 1.1.0 — ustaxona rasmlari bo‘yicha aniqroq modellar

- **Profil kesimlari** (oddiy AKFA alyuminiy, “Oddiy alyuminiy • 1 ta bo‘sh kamera” kesimi) ustaxonadan yuborilgan rasmlar asosida qayta chizildi:
  - **kosa**: bo‘sh kamera, tashqi tomonda shisha tokchasi va ilgakli lab, kamera devorida shtapik qisqichi;
  - **qanot**: xuddi shunday, xona tomonida ramaga yopiladigan qo‘shimcha lab;
  - **orta (impost)**: simmetrik — o‘rtada kamera, ikki tomonda tokcha va lab, ichki qopqoq;
  - **shtapik**: U shaklidagi profil, kamera devoriga ilinadi va shishani bosib turadi; rangi profil bilan bir xil.
- **Shisha** endi lab orqasiga, tokchaga o‘tiradi. Yangi sozlama: “Shisha profil labi ostiga kirishi (mm)”. AKFA oddiy namunalarida 12 mm, ya’ni shisha ko‘rinadigan oynadan har tomondan 12 − 3 = 9 mm katta buyurtma qilinadi. Boshqa profillarda va eski smetalarda 0 (o‘zgarmaydi). O‘z o‘lchamingizni “Materiallar va narxlar”da kiriting.
- **Delfin tutqich** alyuminiy rom uchun standart bo‘ldi (“Rang → Deraza tutqichi → Delfin”). 3D’da: asos, delfin shaklidagi egri dasta, orqadagi ilgak tili va ramadagi tutgich. Ochishda dasta avval 90° buriladi, ilgak tutgichdan chiqadi, keyin qanot ochiladi. Qo‘shimcha qulf soni bo‘lsa, chetga prujinali zashchelkalar qo‘yiladi. Tortma va buriladigan tutqichlar ham qoldi.
- **Qayt — 90° burchak ulash profili** (balkon burchagi): “Rang → Burchak (qayt) profili 90° → Chap/O‘ng tomonda”. Smetaga rom bo‘yicha uzunlikda qo‘shiladi, 2D chizmada va PDF’da “90°” bilan belgilanadi. 3D’da V/Y kesimli profil ko‘rinadi; “Devorda” ko‘rinishida shu tomonda devor ochiladi va qo‘shni rom xira ko‘rsatiladi. Bir burchakni faqat bitta romda belgilang, aks holda profil ikki marta hisoblanadi.
- **3D → “Kesimlar”**: kosa, qanot, orta, shtapik va qayt kesimlarini alohida, katta qilib aylantirib ko‘rish mumkin. Ularni o‘z profilingiz bilan solishtirsangiz bo‘ladi.

Cheklov: kesimlar rasmlardan olingan nisbatlar bo‘yicha chizilgan, zavod chizmasi emas. Aniq o‘lchamlar (yuz eni, chuqurlik, devor qalinligi, shtapik) retseptda o‘zgartiriladi.

# RomFlow 1.0.0 — yangiliklar va tuzatishlar

Ilova avvalgidek to‘liq offline, bepul, login va reklamasiz. Ma’lumotlar telefonda saqlanadi.

## O‘rnatish
- Paket nomi yangi: `uz.romflow.workshop`, ilova nomi “RomFlow”. Eski “RomFlow Offline” (0.7) boshqa kalit bilan imzolangan edi, shuning uchun yangi APK uning ustiga o‘rnatilmasdi. Endi ikkalasi yonma-yon turadi.
- Eski ilovadagi ma’lumotni ko‘chirish: eski ilova → Sozlamalar → “Zaxirani faylga saqlash”; yangi ilova → Sozlamalar → “Zaxira faylidan tiklash”. Shundan keyin eskisini o‘chirsa bo‘ladi.
- Bundan keyingi barcha RomFlow APKlari bitta pilot kalit bilan imzolanadi va bir-birining ustiga ma’lumot yo‘qotmasdan o‘rnatiladi. Google Play uchun o‘z kalitingiz kerak (PUBLISH-UZ.md).

## Tuzatilgan kamchiliklar
- **Ochilish belgisi.** Asboblar paneli, chizma, PDF va 3D endi bitta qoidaga amal qiladi (GOST 23166): uchburchak uchi petlya tomonini ko‘rsatadi, tutqich qarshi tomonda. Oldin chizmada chapga ochiladigan qanot o‘ngga ochiladigandek chizilardi; tepa/pastga ochiladigan qanotlarda tutqich yon tomonda turardi.
- **Narx.** Oldin bitta 1,5 m² rom uchun butun shisha listi (7,2 m²) va butun profil tayoqlari mijoz narxiga qo‘shilardi. Endi mijoz narxi: ishlatilgan metr/m² + chiqindi foizi (standart 7%). Xarid uchun butun tayoq/list soni hisobotda alohida qoladi. Eski usul “Rang → Narx hisoblash usuli → Butun tayoq/list”da tanlanadi.
- **Drag & drop.** Sudrash boshlanganda yo‘riqnoma qatori balandligi o‘zgarib, chizma siljirdi — tuzatildi. Ramka ustiga tashlangan detal endi eng yaqin bo‘limga tushadi.
- **Snackbar** xabarlari “3D” va “Hisoblash” tugmalarini to‘sib qo‘yardi — endi ulardan yuqorida chiqadi.
- **To‘lov oynasi** bo‘sh summada xato berardi — endi tekshiradi va qoldiqni avtomatik yozadi.
- Sozlamalardagi versiya “0.8.0” deb turardi; to‘q temada buyurtma kartochkasi och rangda qolardi; raskroyda bo‘sh qator xato berardi — tuzatildi.
- 3D’da rama ichidagi burchak ulagichlari tashqaridan ko‘rinib turardi — yig‘ilgan holatda yashiriladi, sochilganda ko‘rinadi.

## Chizma va drag & drop
- **Andoza** guruhi: 13 ta tayyor konstruksiya (yopiq, bir tabaqali, 2/3 bo‘limli, fortochkali, balkon bloki, eshik, eshik+fortochka, 2 tabaqali eshik, surilma, arka, vitraj). Bosilsa butun chizma almashadi; bo‘lim ustiga sudralsa faqat o‘sha bo‘lim almashadi.
- **Furnitura** guruhi: setka, qulf, dovodchik, ostona, shpros — qanot ustiga sudrang. Mos kelmasa (masalan dovodchikni derazaga) bo‘lim qizil bo‘ladi va sababi yoziladi.
- Impostni surganda chap/o‘ng o‘lchamlar millimetrda ko‘rinadi; ½, ⅓, ¼ va qo‘shni impost to‘g‘risida yopishadi (yashil). Pastdagi qizil “O‘chirish” joyiga tashlansa impost olib tashlanadi; “Orqaga” bilan qaytadi.
- Bo‘limni **uzoq bosing**: ochilish, to‘ldirma, setka, qulf, tashqariga ochilish, dovodchik, ostona, “Tik/Yotiq 2–3 ga”, birlashtirish, aniq o‘lcham. Impostni uzoq bosing: o‘lcham kiritish, tenglash, olib tashlash.
- **Tenglash** — barcha bo‘limlarni teng qiladi (impost markazlari bo‘yicha).
- **Rang** tugmasi: profil tizimi, 8 xil rang (oq, kumush, mokri, jigarrang, antratsit, qora, oltin eman, yong‘oq) va rang ustamasi, 1/2 oynali shisha, deraza tutqichi turi, eshik dastasi, furnitura rangi, narx usuli.
- “Hisoblash” tugmasi ostida narx chizma o‘zgarishi bilan darhol yangilanadi.

## 3D
- Yuzalarni orqa tomonini kesish va uchburchaklarni guruhlab chizish — kadr 2–5 barobar tez.
- Tayyor ko‘rinishlar: Old, Chap, O‘ng, Tepa, 3D; “Aylanish” (avtomatik aylantirish); “Devorda” — devor va podokonnik bilan.
- Qanot detaliga bosing — “Shu qanotni ochish/yopish” tugmasi chiqadi.
- Ulashish tugmasi 3D ko‘rinishni rasm qilib yuboradi (mijozga Telegram orqali).
- Profil rangi 3D’da ham ko‘rinadi.

## Romchi’dagi kabi biznes funksiyalari
- **Xodimlar va ish haqi:** oylik, kunlik, m² uchun, buyurtmadan %, har konstruksiya uchun. Ish haqi hisoblash, bonus, jarima, avans, to‘lov, qoldiq. Buyurtmaga biriktirilgan ustaga stavka bo‘yicha ish haqi bitta tugma bilan yoziladi.
- **Moliya:** xarajatlar (material, transport, ijara, kommunal, asbob, reklama, boshqa), davr bo‘yicha tushum, xarajat, ish haqi va sof foyda; 6 oylik grafik; har buyurtma foydasi.
- **Statistika:** buyurtmalar soni, o‘rtacha chek, konstruksiya va m², konversiya, bosqichlar, eng yirik mijozlar.
- **Buyurtmalar:** qidiruv va bosqich filtri; tahrirlash (to‘lovlar saqlanadi), nusxa olish, o‘chirish; montaj sanasi va 2 soat oldin eslatma; matn bilan ulashish; ustaga kesish ro‘yxati (tayoqlar, bo‘laklar, shisha o‘lchamlari); mijozga qo‘ng‘iroq; foyda hisobi.
- **Mijoz sahifasi:** buyurtmalari, jami va qoldiq, qo‘ng‘iroq, shu mijozga yangi smeta.
- **PDF:** ustaxona nomi, telefon, manzil, sana, mijoz manzili, montaj sanasi va materiallar jadvali.
- **Bosh sahifa:** faol buyurtmalar, bu oy tushum, mijozlar qarzi, bu oy foyda, 8 ta tezkor bo‘lim, yaqin montaj va eslatmalar.

## Cheklovlar
- Narxlar va texnik me’yorlar namuna; o‘z praysingizni kiriting.
- Profil va furnitura 3D modellari parametrik namunalar, zavod CAD nusxasi emas.
- iOS loyihasida `Runner.xcodeproj/project.pbxproj` fayli arxivda yo‘q edi, shu sababli iOS yig‘ilmadi va tekshirilmadi.
- Video Android emulyatorida (Android 12, Pixel 6) avtomatik ssenariy bilan yozilgan; jismoniy telefonda sinalmagan.
