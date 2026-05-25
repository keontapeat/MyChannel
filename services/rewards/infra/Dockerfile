FROM node:20-slim
WORKDIR /app
COPY services/rewards/package.json /app/package.json
RUN npm i --omit=dev
COPY services/rewards/src /app/src
ENV PORT=9094
EXPOSE 9094
CMD ["node", "./src/index.js"]



