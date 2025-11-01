FROM node:20-slim
WORKDIR /app
COPY services/protect/package.json /app/package.json
RUN npm i --omit=dev
COPY services/protect/src /app/src
ENV PORT=9091
EXPOSE 9091
CMD ["node", "./src/index.js"]



