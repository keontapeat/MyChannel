FROM node:20-slim
WORKDIR /app
COPY services/doctor/package.json /app/package.json
RUN npm i --omit=dev
COPY services/doctor/src /app/src
ENV PORT=9099
EXPOSE 9099
CMD ["node", "./src/index.js"]



