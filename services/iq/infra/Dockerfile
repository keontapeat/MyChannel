FROM node:20-slim
WORKDIR /app
COPY services/iq/package.json /app/package.json
RUN npm i --omit=dev
COPY services/iq/src /app/src
ENV PORT=9092
EXPOSE 9092
CMD ["node", "./src/index.js"]



