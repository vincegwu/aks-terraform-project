FROM node:18-alpine
WORKDIR /app
COPY backend/package*.json ./
RUN npm ci --omit=dev
COPY backend .
EXPOSE 8080
CMD ["npm", "start"]
