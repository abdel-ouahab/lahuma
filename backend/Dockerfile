FROM node:20-alpine
# Prisma's query engine links against OpenSSL, which Alpine leaves out.
RUN apk add --no-cache openssl
WORKDIR /app
COPY package*.json ./
# Dev dependencies stay: the prisma CLI (migrations) and ts-node (seed,
# adhan import) run inside this image.
RUN npm ci
COPY . .
RUN npx prisma generate && npm run build \
  && mkdir -p public/audio/.tmp \
  && chown -R node:node public
USER node
ENV NODE_ENV=production
EXPOSE 4000
# Apply pending migrations before every start; a no-op when up to date.
CMD ["sh", "-c", "npx prisma migrate deploy && exec node dist/server.js"]
