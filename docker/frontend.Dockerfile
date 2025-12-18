# -------- deps --------
FROM node:18-alpine AS deps
WORKDIR /app
COPY frontend/package*.json ./
RUN npm ci

# -------- builder --------
FROM node:18-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY frontend .
ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build

# -------- runner --------
FROM node:18-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY --from=builder /app .
EXPOSE 3000
CMD ["npm", "start"]
