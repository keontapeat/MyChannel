FROM node:20-slim
WORKDIR /app
COPY services/gateway/package.json /app/package.json
RUN npm i --omit=dev
COPY services/gateway/src /app/src
ENV PORT=8088
EXPOSE 8088
CMD ["node", "./src/index.js"]



