# RomFlow’ni iPhone’ga o‘rnatish — Ubuntu Linux orqali

Kompyuter faqat **bir marta** kerak (1-yo‘l). Keyin RomFlow telefonning
o‘zida yangilanib turadi.

## Nima kerak
- Ubuntu 22.04 yoki 24.04 kompyuter, internet.
- iPhone yoki iPad, iOS 15 – 27, ekran paroli qo‘yilgan.
- Asl yoki yaxshi **USB kabel** (faqat quvvat beradigan kabel ishlamaydi).
- **Apple ID** (bepul). Ikki bosqichli tasdiqlash yoqilgan bo‘lsin: kod
  iPhone’ga chiqadi. SMS orqali kod ba’zan ishlamaydi — shuning uchun shu
  iPhone’da kirilgan Apple ID qulayroq.
- **RomFlow IPA**: `RomFlow-2.1.0-25-ios-unsigned.ipa`
  (GitHub → z3wax/RomFlow → **Releases** → eng yangi versiya → *Assets*).

> Dasturlarni faqat rasmiy joydan oling: **iloader.app** (yoki
> github.com/nab138/iloader), **Flathub** (Impactor). Boshqa saytlar sizning
> Apple ID’ingizni o‘g‘irlashi mumkin.

---

## 0. Ubuntu’ni tayyorlash (5 daqiqa)
Terminalni oching (**Ctrl + Alt + T**) va yozing:
```bash
sudo apt update
sudo apt install -y usbmuxd libimobiledevice-utils
```
iPhone’ni kabel bilan ulang va qulfini oching. Telefonda **“Bu kompyuterga
ishonasizmi?” → Ishonish** → parol. Keyin tekshiring:
```bash
idevice_id -l        # iPhone’ning ID raqami chiqishi kerak
idevicepair pair     # "SUCCESS: Paired with device ..." chiqishi kerak
```
Hech narsa chiqmasa — pastdagi **“Muammolar”** bo‘limiga qarang.

---

## 1-yo‘l (tavsiya): iloader + SideStore
Kompyuter bir marta kerak. Keyin RomFlow har 7 kunda telefonning o‘zida,
Wi-Fi orqali yangilanadi.

### 1.1. iloader’ni o‘rnatish
1. Brauzerda **https://iloader.app** → Linux → **.deb** faylni yuklang.
2. Terminalda:
   ```bash
   cd ~/Downloads
   sudo apt install -y ./iloader*.deb
   ```
   (AppImage yuklagan bo‘lsangiz: `sudo apt install -y libfuse2t64`
   — Ubuntu 22.04 da `libfuse2` — keyin
   `chmod +x iloader*.AppImage && ./iloader*.AppImage`.)
3. Ilovalar menyusidan **iloader**’ni oching.

### 1.2. SideStore’ni iPhone’ga o‘rnatish
1. iPhone ulangan va qulfi ochiq tursin.
2. iloader’da **Apple ID** bilan kiring. iPhone’ga chiqqan 6 xonali kodni
   yozing.
3. **Install SideStore** ni tanlang (LiveContainer kerak emas) va tugashini
   kuting. iloader “pairing” faylini SideStore’ga o‘zi joylaydi.

### 1.3. iPhone sozlamalari
1. **Sozlamalar → Umumiy → VPN va qurilmani boshqarish** → Apple ID’ingiz →
   **Ishonish**.
2. **Sozlamalar → Maxfiylik va xavfsizlik → Dasturchi rejimi** → yoqing →
   telefon qayta yonadi → **Yoqish** → parol.
   (Bu band ilova o‘rnatilgandan keyingina ko‘rinadi.)
3. App Store’dan **LocalDevVPN** ni o‘rnating, oching → **Connect**.
4. **SideStore**’ni oching va o‘sha Apple ID bilan kiring.

### 1.4. RomFlow’ni o‘rnatish
**A — telefondan (tavsiya, keyin o‘zi yangilanadi):**
1. IPA faylni iPhone’ga oling: Safari’da GitHub Releases’dan yuklang yoki
   Telegram “Saqlanganlar”ga yuborib, u yerdan **Fayllarga saqlang**.
2. **SideStore → My Apps → +** → Fayllar’dan `RomFlow-…-ios-unsigned.ipa` →
   o‘rnatiladi. RomFlow bosh ekranda paydo bo‘ladi.

**B — kompyuterdan:** iloader → **Import IPA** → RomFlow IPA’ni tanlang.
(Bu holda 7 kundan keyin ham iloader orqali qayta o‘rnatasiz.)

### 1.5. Har 7 kunda (kompyutersiz)
LocalDevVPN → **Connect**, keyin SideStore → **Refresh All**. Ma’lumotlar
o‘chmaydi. Yangi RomFlow versiyasi chiqsa — yangi IPA bilan 1.4 ni
takrorlang (eski ma’lumotlar saqlanadi).

---

## 2-yo‘l: Impactor (to‘g‘ridan-to‘g‘ri, har 7 kunda kompyuter)
```bash
sudo apt install -y flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub dev.khcrysalis.PlumeImpactor
flatpak run dev.khcrysalis.PlumeImpactor
```
(Topilmasa: Flathub’da **Impactor** deb qidiring.)
1. iPhone ulangan, qulfi ochiq. Impactor’da Apple ID bilan kiring.
2. RomFlow IPA faylni tanlang → **Install**.
3. iPhone’da 1.3 bo‘limdagi 1 va 2-qadamlar (Ishonish, Dasturchi rejimi).
4. 7 kundan keyin RomFlow ochilmay qoladi: qayta ulab, yana **Install**.

---

## Muammolar
| Belgi | Yechim |
|---|---|
| `idevice_id -l` bo‘sh | Boshqa kabel/USB port; iPhone qulfini oching; `sudo systemctl restart usbmuxd`; kabelni qayta ulang va **Ishonish** ni bosing. |
| `idevicepair pair` xato | iPhone’da “Ishonish” oynasini kuting va parol kiriting, keyin buyruqni qaytaring. |
| Kod kelmayapti / SMS xatosi | Shu iPhone’da kirilgan Apple ID bilan kiring — kod ekranga chiqadi. |
| “Ishonchsiz dasturchi” | Sozlamalar → Umumiy → VPN va qurilmani boshqarish → **Ishonish**. |
| “Dasturchi rejimi kerak” | Sozlamalar → Maxfiylik va xavfsizlik → Dasturchi rejimi → yoqing. |
| “Maximum number of apps” | Bepul Apple ID’da 3 ta ilova: eski sideload ilovani o‘chiring yoki iloader → sertifikat/App ID’larni tozalang. |
| SideStore: “pairing file” xatosi | iloader → **Manage Pairing File** → SideStore → joylash. |
| 7 kun o‘tib RomFlow ochilmaydi | 1.5 (Refresh All) yoki 2-yo‘lda qayta Install. Ma’lumotlar saqlanadi. |

**Ma’lumotlar xavfsizligi:** RomFlow’ni o‘chirishdan oldin **Sozlamalar →
Zaxira nusxa** saqlang (Fayllar yoki Telegram’ga). Qayta o‘rnatish va
yangilash ma’lumotni o‘chirmaydi.

Boshqa yo‘llar (TestFlight — bir bosishda, kompyutersiz SideInstaller):
[docs/IPHONE-UZ.md](docs/IPHONE-UZ.md).
