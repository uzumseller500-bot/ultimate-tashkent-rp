# ULTIMATE TASHKENT RP

Godot 4 3D open-world role-playing game prototype.

## Development roadmap
- V0.2: Improved city, car and HUD
- V0.3: Tashkent-inspired city map
- V0.4: RP economy
- V0.5: Multiplayer foundations

## Deployment
Source code will live here. Chrome play requires a separate Godot Web export and GitHub Pages setup. The project has not yet been deployed to the browser.

Keep `.godot/` cache out of version control.

## V1.3: City Life RP

Shahar endi uchta o‘ynaladigan rolga ega:

- **Fuqaro** kuryer yoki taksi ishini bajaradi. Ish markazi `(8, 16)` dan paket yoki yo‘lovchi olib, GPS manziliga yetkazish 250/400 so‘m beradi.
- **Politsiya** xaritadagi gumondorni topadi, `Q` bilan to‘xtash buyrug‘i beradi va hibs uchun 500 so‘m oladi. Qochayotgan qurolli gumondorni `G` bilan qonli grafikasiz zararsizlantirish mumkin.
- **O‘g‘ri** Markaziy bankka kirib, seyf yonida `R` yoki `E` bosadi. Seyfni ochish 8 soniya davom etadi; 3000 so‘m faqat o‘lja bilan bankdan yetarlicha uzoqlashganda balansga tushadi.

Shaharda 60 nafar piyoda, 12 ta harakatlanuvchi sedan/SUV/kompakt/taksi va politsiya mashinasi bor. `E` eng yaqin mashinani haydashga imkon beradi. Egasi bor yoki politsiya mashinasini olish qidiruv darajasini oshiradi; politsiya roli xizmat uchun mashina olishi mumkin. Mashinalar yoqilg‘i sarflaydi, markaz yaqinida `F` bilan bak to‘ldiriladi.

Ko‘p qavatli turar joylar, do‘konlar, bank va politsiya bo‘limi kirish nuqtasiga ega. `E` orqali ichkariga kirib, ichki chiqish eshigi orqali ko‘chaga qaytiladi. Hozir barcha turar joylar unumdorlik uchun qayta ishlatiladigan namunaviy interyerdan foydalanadi.

Jinoyatdan keyin patrul quvadi va yaqinlashganda besh soniyalik taslim bo‘lish buyrug‘i beradi. `Q` bosilmasa politsiya o‘t ochadi; sog‘liq tugasa o‘yinchi shifoxonada tiklanadi, jarima va bank o‘ljasini yo‘qotadi. Qon, tana qismlari yoki grafik o‘lim animatsiyasi yo‘q.

### Boshqaruv

- `W/A/S/D` yoki strelkalar: yurish va mashina boshqarish
- `Shift`: yugurish
- `E`: bino/mashina/kontekst amali
- `Q`: taslim bo‘lish yoki politsiya buyrug‘i
- `G`: rol quroli
- `R`: bank seyfini ochish
- `F`: ish markazida yoqilg‘i quyish
- `M`: katta xarita
- Sichqonchaning o‘ng tugmasi yoki sensor ekran: kamera

Pul, rol, sog‘liq, yoqilg‘i va fuqaro ishlari mahalliy saqlanadi. Faol bank bosqini va bino ichidagi vaqtinchalik holat saqlanmaydi.

### Multiplayer server

Godot 4.7 bilan repozitoriy papkasida:

```sh
godot --headless --path . -- --server
```

Server TCP 9080 portida WebSocket qabul qiladi. Faqat shu kompyuterda sinash uchun `--server --local` ishlating. O‘yindagi manzil maydoniga `ws://127.0.0.1:9080` yozib **ULANISH** bosing. O‘yinchilar bir-birining interpolatsiyalangan harakati, roli, sog‘ligi va mashinadagi holatini ko‘radi.

HTTPS orqali tarqatilgan Web o‘yin uchun TLS reverse proxy ortidagi **wss://** server kerak; GitHub Pages server jarayonini ishga tushirmaydi. Serverni joylash ushbu o‘zgarish tarkibida bajarilmadi. Pul, bank, trafik, politsiya va jang holati hozircha har bir o‘yinchida alohida. Umumiy iqtisodiyot yoki PvP ochilishidan oldin bu hodisalarni server tasdiqlaydigan qilish, autentifikatsiya va ulanish cheklovlarini qo‘shish kerak.

### Tekshiruvlar

Testlar uchun alohida `XDG_DATA_HOME` katalogidan foydalaning: gameplay testi saqlangan holatga yozadi.

```sh
XDG_DATA_HOME=/tmp/tashkent-gameplay-test godot --headless --path . --script res://tests/gameplay.gd
XDG_DATA_HOME=/tmp/tashkent-rp-test godot --headless --path . --script res://tests/rp_features.gd
```

Multiplayer integratsiya testi: serverni ishga tushiring va bir vaqtda ikkita jarayonda quyidagini bajaring. Har ikkalasi masofaviy o‘yinchi kelganini va ulanish tozalanganini tekshiradi:

```sh
godot --headless --path . --script res://tests/online.gd -- --connect=ws://127.0.0.1:9080
```
