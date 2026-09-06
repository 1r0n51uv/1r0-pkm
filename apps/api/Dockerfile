# Lean single-process image for the custom REST backend (ADR-0022).
FROM node:20-alpine

WORKDIR /app

# Install prod deps first for layer caching. No lockfile in the repo yet;
# `npm install` resolves against the ^ ranges in package.json.
COPY package.json ./
RUN npm install --omit=dev --no-audit --no-fund

COPY src ./src

ENV NODE_ENV=production
ENV PORT=8080
EXPOSE 8080

# Simple healthcheck hitting the public /health route.
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||8080)+'/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "src/server.js"]
