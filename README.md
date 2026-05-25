MyChannel Monorepo
===================

Quick start (local)
-------------------

1) Prereqs: Docker Desktop, Node 20, pnpm, Python 3.11.
2) Boot stack:

```
docker compose up -d --build
```

3) Run ChannelBoost migrations/seed (first time):

```
docker compose exec -T channelboost node ./src/migrate.js
docker compose exec -T channelboost node ./src/seed.js
```

4) Run Pay migrations:

```
docker compose exec -T pay node ./src/migrate.js
```

5) Health checks via gateway (port 8088):

```
curl -s http://localhost:8088/health
curl -s http://localhost:8088/boost/health
curl -s http://localhost:8088/pay/health
```

ChannelMind API (port 8089)
---------------------------
Examples:

```
curl -s http://localhost:8089/health
curl -s "http://localhost:8089/search?q=hello&k=5"
```

SDK
---

```
cd packages/sdk && npm i && npm run build
```

Deploy (GCP)
------------
- Use Cloud Run for `gateway`, `channelboost`, `pay`, `channelmind`.
- Cloud SQL Postgres, Memorystore Redis, GCS buckets, Artifact Registry.
- See infra/terraform for provisioning (scaffold).

# MyChannel Web App 🎬

## 🚀 Access Your App

### Option 1: Local Network (Phone + Computer on same WiFi)
**On your phone, go to:** `http://10.0.0.17:8000/app.html`

### Option 2: Computer Only
**On your computer:** `http://localhost:8000/app.html`

### Option 3: Deploy to Free Hosting (Coming up!)
- Netlify (instant deployment)
- Vercel (instant deployment) 
- GitHub Pages (free hosting)

## 📱 Mobile Testing
Make sure your phone and computer are on the same WiFi network, then use the IP address above!

## 🔥 Features Ready
✅ YouTube-style interface  
✅ Upload functionality  
✅ Stories section  
✅ Responsive design  
✅ Google Cloud ready  
✅ 90% revenue share system  

## 🌟 Next Steps
1. Test on phone using IP address
2. Deploy to free hosting
3. Set up Google Cloud integration
4. Launch to users!