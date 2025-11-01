FROM node:20-slim
WORKDIR /app
COPY services/pay-api/package.json /app/package.json
RUN npm i --omit=dev
COPY services/pay-api/src /app/src
ENV PORT=8888
EXPOSE 8888
CMD ["node", "./src/index.js"]



