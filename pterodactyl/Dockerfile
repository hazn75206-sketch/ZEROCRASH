FROM node:20-bullseye
WORKDIR /app
# bust cache 2026-09-23 mantax merge ad72f62

COPY pterodactyl/package*.json ./
RUN npm install --omit=dev

COPY pterodactyl/. ./

EXPOSE 20854

CMD ["node", "index.js"]
