FROM node:20-slim

# install ffmpeg (system binary) and ca-certificates
RUN apt-get update && \
    apt-get install -y ffmpeg ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY package*.json ./
RUN npm install --production

COPY . .

RUN mkdir -p results /tmp

CMD ["node", "worker.js"]
