FROM node:18-alpine

# Create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy package files first (layer caching)
COPY package*.json ./

RUN npm ci --only=production || true

# Copy application source
COPY . .

# Change ownership
RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 3001

CMD ["node", "index.js"]
