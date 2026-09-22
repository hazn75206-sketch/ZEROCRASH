FROM node:20-bullseye
WORKDIR /app

RUN apt-get update && apt-get install -y curl dnsutils \
  && curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp \
  && chmod +x /usr/local/bin/yt-dlp \
  && rm -rf /var/lib/apt/lists/*

COPY pterodactyl/package*.json ./
RUN npm install --omit=dev

COPY pterodactyl/. ./

EXPOSE 20854

CMD ["node", "index.js"]
