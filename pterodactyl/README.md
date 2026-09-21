# Pterodactyl Reyhan 10GB - Zero Crash

Panel: https://pterodactyl-free.hostkita.help
USER: reyhan
PASS: 0yO)WRw7DVS6
Egg: quay.io/ydrag0n/pterodactyl-vps-egg
Resource: DISK 10048MB RAM 10048MB CPU 220%

## S&K Panel
- Jaga kerahasiaan akun
- Dilarang script DDoS / Kill Panel
- Dilarang Membuat Panel Jika Tidak Digunakan
- Jika Offline 60 menit Terhapus otomatis
- Dilarang Menjual Panel

## Deploy Zero Crash private-server

### Opsi 1 - Via Panel Console (tanpa Docker)
1. Login https://pterodactyl-free.hostkita.help -> Servers -> reyhan
2. File Manager -> Upload private-server banditflow (index.js, package.json) ke /home/container
3. Startup -> quay.io/ydrag0n/pterodactyl-vps-egg -> Console
4. Jalankan:
```bash
bash pterodactyl/startup.sh
# atau manual:
npm ci
pm2 start ecosystem.config.js
pm2 save
```

### Opsi 2 - Via Docker (jika Egg support Docker)
Upload pterodactyl/Dockerfile + ecosystem.config.js ke panel, rebuild.

## Ganti baseUrl di Flutter
Setelah panel dapat IP/domain + port 2014:
- Edit `lib/login_page.dart:12` `baseUrl = "https://IP:2014"` (dari `https://private-server.banditflow.my.id:2014`)
- Edit `lib/bug_sender.dart:70`, `lib/home_page.dart:93` dll yang masih hardcode `private-server`
- `flutter build apk --release --target-platform android-arm64` -> upload ke GitHub Releases

## Keep Alive (Anti 60 menit hapus)
Panel akan hapus jika Offline 60 menit. Jaga tetap online:
- `pm2` autorestart
- Cron `*/5 * * * * curl http://localhost:2014/ping`
- Jangan stop server

## Test
```bash
curl http://localhost:2014/ping?key=test
curl http://localhost:2014/myInfo?username=owner&password=owner123&key=test
```
Jika `valid:true` -> ganti baseUrl di app jadi IP panel.

## File di repo ini
- `pterodactyl/Dockerfile` - untuk Fly.io / Docker
- `pterodactyl/ecosystem.config.js` - PM2 config
- `pterodactyl/startup.sh` - script Console
- `pterodactyl/README.md` - ini file

Panel info: `panelinfo_Reyhan.txt` (873B) di Telegram
