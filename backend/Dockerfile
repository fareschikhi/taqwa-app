FROM node:22-alpine

# Prisma's query engine links against OpenSSL, which alpine leaves out.
RUN apk add --no-cache openssl

# package-lock.json is written by npm 11; the npm 10 bundled with node 22
# reads its optional dependencies as missing and `npm ci` refuses to run.
RUN npm install -g npm@11.6.2

WORKDIR /app

COPY package*.json ./

RUN npm ci

COPY . .

RUN npm run build

EXPOSE 3000

# Bring the schema up to date before serving, so a fresh database gets its
# tables and an existing one gets any new migrations.
CMD ["sh", "-c", "npx prisma migrate deploy && node dist/main"]
