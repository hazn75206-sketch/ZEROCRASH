FROM node:20-bullseye
WORKDIR /app

RUN apt-get update && apt-get install -y python3-pip ffmpeg dnsutils \
  && pip3 install --break-system-packages yt-dlp gallery-dl \
  && rm -rf /var/lib/apt/lists/*

COPY pterodactyl/package*.json ./
RUN npm install --omit=dev

COPY pterodactyl/. ./

EXPOSE 20854

CMD ["node", "index.js"]
