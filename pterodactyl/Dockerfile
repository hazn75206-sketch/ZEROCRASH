FROM node:20-bullseye
WORKDIR /app

COPY pterodactyl/package*.json ./
RUN npm install --omit=dev

COPY pterodactyl/. ./

EXPOSE 20854

CMD ["node", "index.js"]
