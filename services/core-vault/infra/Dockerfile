FROM node:20-slim
WORKDIR /app
COPY services/core-vault/package.json /app/package.json
RUN npm i --omit=dev
COPY services/core-vault/src /app/src
ENV PORT=9097
EXPOSE 9097
CMD ["node", "./src/index.js"]



