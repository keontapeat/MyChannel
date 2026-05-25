FROM node:20-slim
WORKDIR /app
COPY services/labs/package.json /app/package.json
RUN npm i --omit=dev
COPY services/labs/src /app/src
ENV PORT=9096
EXPOSE 9096
CMD ["node", "./src/index.js"]



