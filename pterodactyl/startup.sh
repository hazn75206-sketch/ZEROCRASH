#!/bin/bash
# Startup untuk Pterodactyl VPS Egg quay.io/ydrag0n/pterodactyl-vps-egg - reyhan 10GB
# Jalankan di Console panel https://pterodactyl-free.hostkita.help

set -e
echo "=== Reyhan Pterodactyl - Zero Crash private-server ==="
echo "Panel: https://pterodactyl-free.hostkita.help USER: reyhan PASS: 0yO)WRw7DVS6"

# Update & deps
apt update && apt install -y nodejs npm nginx certbot python3 make g++ git

# Clone private-server (ganti URL private-server banditflow kamu)
# git clone https://github.com/xxx/private-server.git /app/private-server
# cd /app/private-server && npm ci

# Jika sudah upload via File Manager Pterodactyl (egg VPS), masuk folder:
cd /app
if [ -f "package.json" ]; then
  npm ci
else
  echo "Upload private-server banditflow ke /app via File Manager dulu!"
  echo "File harus ada: index.js / app.js, package.json"
fi

# PM2 keep alive (biar tidak Offline 60 menit terhapus)
npm install -g pm2
pm2 start ecosystem.config.js --env production
pm2 save
pm2 startup

# Nginx reverse + keep alive cron (biar tidak suspend)
# Edit /etc/nginx/sites-enabled/default -> proxy_pass http://localhost:2014
# certbot --nginx -d reyhan.pterodactyl-free.hostkita.help

# Cron keep alive tiap 5 menit
(crontab -l 2>/dev/null; echo "*/5 * * * * curl -s http://localhost:2014/ping?key=dummy > /dev/null") | crontab -

# Cek
pm2 list
curl -s http://localhost:2014/ping?key=test || echo "private-server belum jalan, cek logs: pm2 logs"
echo "=== Selesai - ganti lib/login_page.dart:12 baseUrl ke https://IP_PANEL:2014 ==="
echo "Contoh: baseUrl = \"https://reyhan.pterodactyl-free.hostkita.help:2014\" atau IP:2014 yang panel kasih"
