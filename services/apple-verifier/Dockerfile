FROM node:22-bookworm-slim
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --ignore-scripts
COPY server.js verifier.js apple-roots.js ./
USER node
ENV NODE_ENV=production
CMD ["node", "server.js"]
