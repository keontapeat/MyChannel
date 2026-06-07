# Content ID fingerprinting service.
# Needs ffmpeg (audio decode) + libchromaprint-tools (fpcalc) for acoustic
# fingerprinting.
FROM node:20-slim

# System deps: ffmpeg + chromaprint (provides fpcalc)
RUN apt-get update && \
    apt-get install -y --no-install-recommends ffmpeg libchromaprint-tools ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY services/protect/package.json /app/package.json
RUN npm i --omit=dev
COPY services/protect/src /app/src

ENV PORT=9091
EXPOSE 9091
CMD ["node", "./src/index.js"]
