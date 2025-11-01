FROM node:20-slim
WORKDIR /app
COPY services/connect/package.json /app/package.json
RUN npm i --omit=dev
COPY services/connect/src /app/src
ENV PORT=9098
EXPOSE 9098
CMD ["node", "./src/index.js"]



