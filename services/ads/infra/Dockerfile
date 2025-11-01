FROM node:20-slim
WORKDIR /app
COPY services/ads/package.json /app/package.json
RUN npm i --omit=dev
COPY services/ads/src /app/src
ENV PORT=9093
EXPOSE 9093
CMD ["node", "./src/index.js"]



