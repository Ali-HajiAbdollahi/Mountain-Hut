# ---- Fase 1: compila la pagina web Flutter ---
FROM ghcr.io/cirruslabs/flutter:stable AS web
WORKDIR /app/client
COPY client/ ./
RUN flutter pub get
RUN flutter build web --release --dart-define=API_BASE_URL=/api
# ---- Fase 2: server Node con la pagina web dentro ---
FROM node:24-slim
ENV NODE_ENV=production \
    PORT=3001 \
    TZ=Europe/Rome \
    DB_PATH=/data/mountain_hut.db \
    WEB_DIR=/app/client/build/web \
    CLIENT_ORIGIN=http://localhost:3001 \
    MAIL_MODE=disabled
WORKDIR /app
COPY database/ ./database/
COPY server/package*.json ./server/
RUN cd server && npm ci --omit=dev
COPY server/ ./server/
COPY --from=web /app/client/build/web ./client/build/web
VOLUME /data
EXPOSE 3001
WORKDIR /app/server
CMD ["node", "scripts/start-docker-server.js"]