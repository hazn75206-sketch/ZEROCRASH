FROM node:20-bullseye
WORKDIR /app

# Install deps for Baileys (sharp, qrcode)
RUN apt-get update && apt-get install -y \
    python3 make g++ git nginx certbot \
    && rm -rf /var/lib/apt/lists/*

COPY package*.json ./
RUN npm ci --omit=dev

COPY . .

# PM2 for keep alive (offline 60min auto-delete S&K)
RUN npm install -g pm2

EXPOSE 2014 3000 8080

CMD ["pm2-runtime", "start", "ecosystem.config.js"]
